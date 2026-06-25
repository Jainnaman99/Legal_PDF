from fastapi import APIRouter, Depends, HTTPException, Query, status

from app.core.dependencies import get_user_repository, require_roles
from app.interfaces.user_repository import IUserRepository
from app.models.user import User
from app.schemas.auth import UserOut, UserUpdate

router = APIRouter(prefix="/users", tags=["Users"])

_admin_only = require_roles("super_admin", "admin")


@router.get("/", response_model=list[UserOut])
def list_users(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(_admin_only),
    repo: IUserRepository = Depends(get_user_repository),
):
    return repo.list_all(skip, limit, exclude_user_id=current_user.id)


@router.get("/{user_id}", response_model=UserOut)
def get_user(
    user_id: int,
    current_user: User = Depends(_admin_only),
    repo: IUserRepository = Depends(get_user_repository),
):
    user = repo.get_by_id(user_id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return user


@router.patch("/", response_model=UserOut)
def update_user(
    body: UserUpdate,
    current_user: User = Depends(_admin_only),
    repo: IUserRepository = Depends(get_user_repository),
):
    try:
        user = repo.update(
            body.user_id,
            first_name=body.first_name,
            last_name=body.last_name,
            email=body.email,
            is_active=body.is_active,
            role_id=body.role_id,
            department_id=body.department_id,
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(e))
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return user
