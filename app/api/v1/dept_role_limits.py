from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field

from app.core.dependencies import get_current_user, get_dept_role_limit_repository, require_roles
from app.interfaces.dept_role_limit_repository import IDeptRoleLimitRepository
from app.models.user import User

router = APIRouter(prefix="/dept-role-limits", tags=["Dept Role Limits"])

DEFAULT_MAX = 5


class UpsertLimitRequest(BaseModel):
    department_id: int
    role_id:       int
    max_users:     int = Field(..., ge=0)


@router.get("")
def list_limits(
    repo: IDeptRoleLimitRepository = Depends(get_dept_role_limit_repository),
    _: User = Depends(require_roles("admin", "super Admin")),
):
    return {"default_max": DEFAULT_MAX, "limits": repo.list_all()}


@router.put("")
def upsert_limit(
    body: UpsertLimitRequest,
    repo: IDeptRoleLimitRepository = Depends(get_dept_role_limit_repository),
    _: User = Depends(require_roles("admin", "super Admin")),
):
    repo.upsert(body.department_id, body.role_id, body.max_users)
    return {"detail": "Limit saved."}


@router.get("/user-count")
def active_user_count(
    dept_id: int = Query(...),
    role_id: int = Query(...),
    repo: IDeptRoleLimitRepository = Depends(get_dept_role_limit_repository),
    _: User = Depends(require_roles("admin", "super Admin")),
):
    return {"active_count": repo.count_active_users(dept_id, role_id)}


@router.delete("/{dept_id}/{role_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_limit(
    dept_id: int,
    role_id: int,
    repo: IDeptRoleLimitRepository = Depends(get_dept_role_limit_repository),
    _: User = Depends(require_roles("admin", "super Admin")),
):
    deleted = repo.delete(dept_id, role_id)
    if not deleted:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Limit not found.")
