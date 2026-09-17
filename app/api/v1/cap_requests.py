import os
import uuid
from typing import Optional

from fastapi import APIRouter, Depends, File, Form, HTTPException, Request, UploadFile, status
from fastapi.responses import FileResponse
from pydantic import BaseModel

from app.api.v1.dept_role_limits import DEFAULT_MAX
from app.core.config import settings
from app.core.dependencies import (
    get_cap_request_repository,
    get_current_user,
    get_dept_role_limit_repository,
    require_roles,
)
from app.interfaces.cap_request_repository import ICapRequestRepository
from app.interfaces.dept_role_limit_repository import IDeptRoleLimitRepository
from app.models.user import User

router = APIRouter(prefix="/cap-requests", tags=["Cap Change Requests"])

_requester_roles = require_roles("admin", "nodal Officer")
_super_admin     = require_roles("super Admin")

_ALLOWED_ATTACHMENT_TYPES = {
    "application/pdf",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "image/jpeg",
    "image/png",
}


class CapRequestReview(BaseModel):
    status:           str            # "approved" or "rejected"
    super_admin_note: Optional[str] = None
    # Amount to add to the LIVE current cap at approval time (current_cap + approved_cap).
    # Defaults to the requester's own requested_cap when the super admin doesn't override it.
    approved_cap:     Optional[int] = None


def _public(item: dict, request: Request) -> dict:
    """Add a browser-viewable attachment URL alongside the stored file path."""
    item = dict(item)
    base = str(request.base_url).rstrip("/")
    item["attachment_url"] = f"{base}/api/v1/cap-requests/{item['id']}/attachment"
    return item


# ── Admin: submit a request ───────────────────────────────────────────────────

@router.post("", status_code=status.HTTP_201_CREATED)
def submit_cap_request(
    request: Request,
    role_id: int = Form(...),
    requested_cap: int = Form(..., description="Number of additional users to add to the current cap (negative to request a decrease)"),
    reason: Optional[str] = Form(None),
    file: UploadFile = File(..., description="Mandatory supporting document (approval memo, justification, etc.)"),
    current_user: User = Depends(_requester_roles),
    repo: ICapRequestRepository = Depends(get_cap_request_repository),
    limit_repo: IDeptRoleLimitRepository = Depends(get_dept_role_limit_repository),
):
    if file.content_type not in _ALLOWED_ATTACHMENT_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Attachment must be a PDF, Word (.docx), or image (jpg/png) file.",
        )

    dept_id = current_user.department_id
    if not dept_id:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Admin user has no department assigned.",
        )
    try:
        dept_id = int(str(dept_id).split(",")[0].strip())
    except (ValueError, AttributeError):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid department.")

    os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
    unique_name = f"{uuid.uuid4().hex}_{file.filename}"
    file_path = os.path.join(settings.UPLOAD_DIR, unique_name)
    content = file.file.read()
    with open(file_path, "wb") as f:
        f.write(content)

    current_cap = limit_repo.get_limit(dept_id, role_id)
    base_cap = current_cap if current_cap is not None else DEFAULT_MAX
    if base_cap + requested_cap < 0:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Current cap is {base_cap}; this would take it below 0.",
        )

    created = repo.create(
        department_id=dept_id,
        role_id=role_id,
        requested_by=current_user.id,
        current_cap=current_cap,
        requested_cap=requested_cap,
        reason=reason,
        attachment_filename=unique_name,
        attachment_original_filename=file.filename,
        attachment_file_path=file_path,
        attachment_file_size=len(content),
    )
    return _public(created, request)


# ── Admin: view own department's requests ────────────────────────────────────

@router.get("/my-requests")
def list_my_requests(
    request: Request,
    current_user: User = Depends(_requester_roles),
    repo: ICapRequestRepository = Depends(get_cap_request_repository),
):
    dept_id = current_user.department_id
    if not dept_id:
        return []
    try:
        dept_id = int(str(dept_id).split(",")[0].strip())
    except (ValueError, AttributeError):
        return []
    return [_public(r, request) for r in repo.list_by_department(dept_id)]


# ── Admin (own dept) / Super Admin: download the attached supporting document ─

@router.get(
    "/{request_id}/attachment",
    summary="Download the supporting document attached to a cap request",
    responses={200: {"content": {"application/octet-stream": {}}}},
)
def get_cap_request_attachment(
    request_id: int,
    current_user: User = Depends(get_current_user),
    repo: ICapRequestRepository = Depends(get_cap_request_repository),
):
    cap_req = repo.get_by_id(request_id)
    if not cap_req:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Request not found.")

    role_name = current_user.role.name if current_user.role else ""
    if role_name == "super Admin":
        pass
    elif role_name in ("admin", "nodal Officer"):
        try:
            requester_dept_ids = {int(d.strip()) for d in str(current_user.department_id).split(",") if d.strip()}
        except (ValueError, AttributeError):
            requester_dept_ids = set()
        if cap_req["department_id"] not in requester_dept_ids:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized to view this attachment.")
    else:
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorized to view this attachment.")

    fp = cap_req.get("attachment_file_path")
    if not fp or not os.path.exists(fp):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Attachment not found on server.")

    return FileResponse(
        fp,
        filename=cap_req.get("attachment_original_filename") or "attachment",
        content_disposition_type="inline",
    )


# ── Super Admin: list all pending requests ───────────────────────────────────

@router.get("/pending")
def list_pending_requests(
    request: Request,
    current_user: User = Depends(_super_admin),
    repo: ICapRequestRepository = Depends(get_cap_request_repository),
):
    return [_public(r, request) for r in repo.list_pending()]


# ── Super Admin: approve or reject ───────────────────────────────────────────

@router.patch("/{request_id}/review")
def review_cap_request(
    request_id: int,
    body: CapRequestReview,
    request: Request,
    current_user: User = Depends(_super_admin),
    repo: ICapRequestRepository = Depends(get_cap_request_repository),
    limit_repo: IDeptRoleLimitRepository = Depends(get_dept_role_limit_repository),
):
    if body.status not in ("approved", "rejected"):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="status must be 'approved' or 'rejected'.",
        )

    cap_req = repo.get_by_id(request_id)
    if not cap_req:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Request not found.")
    if cap_req["status"] != "pending":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Request has already been reviewed.",
        )

    final_cap: Optional[int] = None
    if body.status == "approved":
        dept_id = cap_req["department_id"]
        role_id = cap_req["role_id"]
        increment = body.approved_cap if body.approved_cap is not None else cap_req["requested_cap"]
        live_current_cap = limit_repo.get_limit(dept_id, role_id)
        base_cap = live_current_cap if live_current_cap is not None else DEFAULT_MAX
        final_cap = base_cap + increment

        # Validate before writing anything — a rejected computation should
        # leave the request pending, not stuck "approved" with no cap change.
        if final_cap < 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Current cap is {base_cap}; this would take it below 0.",
            )
        active_count = limit_repo.count_active_users(dept_id, role_id)
        if final_cap < active_count:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=f"{active_count} user(s) are currently active in this role. Resulting cap ({final_cap}) must be at least {active_count}.",
            )

    updated = repo.review(
        request_id=request_id,
        status=body.status,
        resolved_by=current_user.id,
        super_admin_note=body.super_admin_note,
    )

    if body.status == "approved":
        limit_repo.upsert(dept_id=cap_req["department_id"], role_id=cap_req["role_id"], max_users=final_cap)

    return _public(updated, request)
