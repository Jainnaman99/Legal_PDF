from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.core.dependencies import get_current_user, get_role_service
from app.models.user import User
from app.schemas.auth import RoleOut
from app.services.role_service import RoleService

router = APIRouter(prefix="/roles", tags=["Roles"])


@router.get("/", response_model=list[RoleOut])
def list_roles(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=200),
    current_user: User = Depends(get_current_user),
    service: RoleService = Depends(get_role_service),
):
    return service.list_all(skip, limit)


@router.get("/{role_id}", response_model=RoleOut)
def get_role(
    role_id: int,
    current_user: User = Depends(get_current_user),
    service: RoleService = Depends(get_role_service),
):
    role = service.get_by_id(role_id)
    if not role:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Role not found")
    return role
