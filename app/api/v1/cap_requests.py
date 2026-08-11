from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

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

_admin_only      = require_roles("admin")
_super_admin     = require_roles("super Admin")


class CapRequestCreate(BaseModel):
    role_id:       int
    requested_cap: int = Field(..., ge=0)
    reason:        Optional[str] = None


class CapRequestReview(BaseModel):
    status:           str            # "approved" or "rejected"
    super_admin_note: Optional[str] = None
    approved_cap:     Optional[int] = None  # super admin can override the requested value on approval


# ── Admin: submit a request ───────────────────────────────────────────────────

@router.post("", status_code=status.HTTP_201_CREATED)
def submit_cap_request(
    body: CapRequestCreate,
    current_user: User = Depends(_admin_only),
    repo: ICapRequestRepository = Depends(get_cap_request_repository),
    limit_repo: IDeptRoleLimitRepository = Depends(get_dept_role_limit_repository),
):
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

    current_cap = limit_repo.get_limit(dept_id, body.role_id)
    return repo.create(
        department_id=dept_id,
        role_id=body.role_id,
        requested_by=current_user.id,
        current_cap=current_cap,
        requested_cap=body.requested_cap,
        reason=body.reason,
    )


# ── Admin: view own department's requests ────────────────────────────────────

@router.get("/my-requests")
def list_my_requests(
    current_user: User = Depends(_admin_only),
    repo: ICapRequestRepository = Depends(get_cap_request_repository),
):
    dept_id = current_user.department_id
    if not dept_id:
        return []
    try:
        dept_id = int(str(dept_id).split(",")[0].strip())
    except (ValueError, AttributeError):
        return []
    return repo.list_by_department(dept_id)


# ── Super Admin: list all pending requests ───────────────────────────────────

@router.get("/pending")
def list_pending_requests(
    current_user: User = Depends(_super_admin),
    repo: ICapRequestRepository = Depends(get_cap_request_repository),
):
    return repo.list_pending()


# ── Super Admin: approve or reject ───────────────────────────────────────────

@router.patch("/{request_id}/review")
def review_cap_request(
    request_id: int,
    body: CapRequestReview,
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

    updated = repo.review(
        request_id=request_id,
        status=body.status,
        resolved_by=current_user.id,
        super_admin_note=body.super_admin_note,
    )

    if body.status == "approved":
        final_cap = body.approved_cap if body.approved_cap is not None else cap_req["requested_cap"]
        limit_repo.upsert(
            dept_id=cap_req["department_id"],
            role_id=cap_req["role_id"],
            max_users=final_cap,
        )

    return updated
