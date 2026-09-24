from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from app.core.dependencies import (
    get_pdf_repository,
    get_unlock_request_repository,
    require_roles,
)
from app.interfaces.pdf_repository import IPDFRepository
from app.interfaces.unlock_request_repository import IUnlockRequestRepository
from app.models.user import User

router = APIRouter(prefix="/unlock-requests", tags=["Document Unlock Requests"])

# Whoever can approve/reject a document (Approver, Admin, Super Admin acting as
# reviewer) can also ask to have an already-approved one unlocked.
_requester_roles = require_roles("approver", "admin", "super Admin")
_nodal_officer    = require_roles("nodal Officer")


class UnlockRequestCreate(BaseModel):
    pdf_id:       int
    request_type: str            # "edit" or "delete"
    reason:       str            # mandatory — the only record of why the unlock was requested


class UnlockRequestReview(BaseModel):
    status:      str             # "approved" or "rejected"
    review_note: Optional[str] = None


def _managed_department_ids(user: User) -> list[int]:
    try:
        return [int(d.strip()) for d in str(user.department_id).split(",") if d.strip()]
    except (ValueError, AttributeError):
        return []


# ── Approver: request an unlock ───────────────────────────────────────────────

@router.post("", status_code=status.HTTP_201_CREATED)
def create_unlock_request(
    body: UnlockRequestCreate,
    current_user: User = Depends(_requester_roles),
    pdf_repo: IPDFRepository = Depends(get_pdf_repository),
    repo: IUnlockRequestRepository = Depends(get_unlock_request_repository),
):
    if body.request_type not in ("edit", "delete"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="request_type must be 'edit' or 'delete'.",
        )
    reason = body.reason.strip()
    if not reason:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="A reason is required.")

    doc = pdf_repo.get_by_id(body.pdf_id)
    if not doc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found.")
    if doc.status != "approved":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Only approved documents can have an unlock request.",
        )
    if not doc.department_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Document has no department assigned.")

    if repo.get_pending_for_pdf(body.pdf_id):
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An unlock request is already pending for this document.",
        )

    return repo.create(
        pdf_id=body.pdf_id,
        department_id=doc.department_id,
        request_type=body.request_type,
        requested_by=current_user.id,
        reason=reason,
    )


# ── Approver: view own request history ────────────────────────────────────────

@router.get("/my-requests")
def list_my_unlock_requests(
    current_user: User = Depends(_requester_roles),
    repo: IUnlockRequestRepository = Depends(get_unlock_request_repository),
):
    return repo.list_by_requester(current_user.id)


# ── Nodal Officer: list pending requests for their department(s) ─────────────

@router.get("/pending")
def list_pending_unlock_requests(
    current_user: User = Depends(_nodal_officer),
    repo: IUnlockRequestRepository = Depends(get_unlock_request_repository),
):
    return repo.list_pending_for_departments(_managed_department_ids(current_user))


# ── Nodal Officer: approve or reject ──────────────────────────────────────────

@router.patch("/{request_id}/review")
def review_unlock_request(
    request_id: int,
    body: UnlockRequestReview,
    current_user: User = Depends(_nodal_officer),
    repo: IUnlockRequestRepository = Depends(get_unlock_request_repository),
    pdf_repo: IPDFRepository = Depends(get_pdf_repository),
):
    if body.status not in ("approved", "rejected"):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="status must be 'approved' or 'rejected'.",
        )

    req = repo.get_by_id(request_id)
    if not req:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Request not found.")
    if req["status"] != "pending":
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Request has already been reviewed.")
    if req["department_id"] not in _managed_department_ids(current_user):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to review unlock requests for this department.",
        )

    updated = repo.review(
        request_id=request_id,
        status=body.status,
        reviewed_by=current_user.id,
        review_note=body.review_note,
    )

    if body.status == "approved":
        new_doc_status = "returned" if req["request_type"] == "edit" else "deleted"
        pdf_repo.set_status(req["pdf_id"], new_doc_status)

    return updated
