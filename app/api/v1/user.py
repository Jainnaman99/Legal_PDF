from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, Request, status

from app.core.dependencies import get_audit_service, get_current_user, get_department_service, get_dept_role_limit_repository, get_user_repository, require_roles
from app.interfaces.dept_role_limit_repository import IDeptRoleLimitRepository
from app.interfaces.user_repository import IUserRepository
from app.models.user import User
from app.schemas.auth import DepartmentOut, UserListResponse, UserOut, UserUpdate
from app.services.audit_service import AuditService
from app.services.department_service import DepartmentService
from app.utils.request_utils import get_client_ip

_DEFAULT_MAX_USERS = 5  # fallback when no custom limit is configured

router = APIRouter(prefix="/users", tags=["Users"])

_manage_users = require_roles("super Admin", "admin", "nodal Officer")
_admin_only   = require_roles("super Admin", "admin")


def _is_nodal_officer(user: User) -> bool:
    return user.role is not None and user.role.name == "nodal Officer"


def _managed_dept_ids(user: User) -> set[int]:
    return {d.id for d in getattr(user, "departments", [])}


def _assert_in_managed_departments(current_user: User, target: User) -> None:
    """Raise 403 if a nodal officer tries to act on a user outside their managed departments."""
    if _is_nodal_officer(current_user):
        target_dept_ids = {d.id for d in getattr(target, "departments", [])}
        if not target_dept_ids.intersection(_managed_dept_ids(current_user)):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Nodal officers can only manage users within their assigned departments",
            )


@router.get("/", response_model=UserListResponse)
def list_users(
    skip: int = Query(0, ge=0),
    limit: int = Query(10, ge=1, le=1000),
    status: Optional[str] = Query(None, description="Filter by status: active | inactive"),
    department_id: Optional[int] = Query(None, description="Filter by department ID"),
    current_user: User = Depends(_manage_users),
    repo: IUserRepository = Depends(get_user_repository),
):
    is_active: int | None = None
    if status == "active":
        is_active = 1
    elif status == "inactive":
        is_active = 0

    role_name = current_user.role.name if current_user.role else ""

    if role_name in ("nodal Officer", "admin"):
        caller_dept_ids = {d.id for d in getattr(current_user, "departments", [])}
        # If a specific dept is requested and it's within the caller's scope, use it;
        # otherwise fall back to the caller's full set of departments.
        if department_id and department_id in caller_dept_ids:
            dept_csv = str(department_id)
        else:
            dept_csv = ",".join(str(i) for i in caller_dept_ids) or None
        if role_name == "nodal Officer":
            users, counts = repo.list_for_nodal(skip, limit, current_user.id, dept_csv, is_active)
        else:
            users, counts = repo.list_for_admin(skip, limit, current_user.id, dept_csv, is_active)
    else:  # super Admin
        dept_csv = str(department_id) if department_id else None
        users, counts = repo.list_all(skip, limit, exclude_user_id=current_user.id, department_ids=dept_csv, is_active=is_active)

    return UserListResponse(
        total=counts["total"],
        count_active=counts["count_active"],
        count_inactive=counts["count_inactive"],
        pagination_total=counts["pagination_total"],
        users=users,
    )


@router.get("/approvers", response_model=list[UserOut])
def get_approvers_by_department(
    department_id: int = Query(..., description="Department ID to fetch approvers for"),
    current_user: User = Depends(_manage_users),
    repo: IUserRepository = Depends(get_user_repository),
):
    """Return active approvers belonging to the given department (used when creating an uploader)."""
    return repo.list_by_role_and_department("approver", department_id)


@router.get("/my-departments", response_model=list[DepartmentOut])
def get_my_departments(
    current_user: User = Depends(_manage_users),
    dept_service: DepartmentService = Depends(get_department_service),
):
    """
    Returns departments scoped to the caller:
      - admin / super Admin → all departments
      - nodal Officer       → only their assigned departments
    """
    if _is_nodal_officer(current_user):
        return getattr(current_user, "departments", [])
    role_name = current_user.role.name if current_user.role else ""
    if role_name == "admin":
        admin_depts = getattr(current_user, "departments", [])
        return admin_depts if admin_depts else dept_service.list_all(0, 200)
    return dept_service.list_all(0, 200)


@router.get("/{user_id}", response_model=UserOut)
def get_user(
    user_id: int,
    current_user: User = Depends(_manage_users),
    repo: IUserRepository = Depends(get_user_repository),
):
    user = repo.get_by_id(user_id)
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    _assert_in_managed_departments(current_user, user)
    return user


@router.patch("/", response_model=UserOut)
def update_user(
    body: UserUpdate,
    request: Request,
    current_user: User = Depends(_manage_users),
    repo: IUserRepository = Depends(get_user_repository),
    limit_repo: IDeptRoleLimitRepository = Depends(get_dept_role_limit_repository),
    audit: AuditService = Depends(get_audit_service),
):
    target = repo.get_by_id(body.user_id)
    if not target:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    _assert_in_managed_departments(current_user, target)

    if _is_nodal_officer(current_user):
        if body.role_id is not None:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Nodal officers cannot change a user's role",
            )
        if body.department_id is not None:
            managed = _managed_dept_ids(current_user)
            new_dept_ids = {
                int(i.strip()) for i in body.department_id.split(",")
                if i.strip().isdigit()
            }
            if not new_dept_ids.issubset(managed):
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="Nodal officers can only assign users to their managed departments",
                )

    changes: dict = {}
    if body.first_name is not None and body.first_name != target.first_name:
        changes["first_name"] = {"old": target.first_name, "new": body.first_name}
    if body.last_name is not None and body.last_name != target.last_name:
        changes["last_name"] = {"old": target.last_name, "new": body.last_name}
    if body.email is not None and body.email != target.email:
        changes["email"] = {"old": target.email, "new": body.email}
    if body.is_active is not None and body.is_active != target.is_active:
        changes["is_active"] = {"old": target.is_active, "new": body.is_active}
    if body.role_id is not None and body.role_id != target.role_id:
        changes["role_id"] = {"old": target.role_id, "new": body.role_id}
    if body.department_id is not None and body.department_id != target.department_id:
        changes["department_id"] = {"old": target.department_id, "new": body.department_id}

    # Resolve the effective role, department, and active status after the update
    effective_role_id   = body.role_id      if body.role_id      is not None else target.role_id
    effective_dept_id   = body.department_id if body.department_id is not None else target.department_id
    effective_is_active = body.is_active    if body.is_active    is not None else target.is_active
    # Only enforce the per-dept-role cap when the user will be active after the update.
    # Deactivating a user should never be blocked by the cap.
    if effective_role_id and effective_dept_id and effective_is_active:
        dept_ids = [d.strip() for d in str(effective_dept_id).split(",") if d.strip().isdigit()]
        for dept_id in dept_ids:
            max_allowed = limit_repo.get_limit(int(dept_id), effective_role_id)
            if max_allowed is None:
                max_allowed = _DEFAULT_MAX_USERS
            count = repo.count_by_dept_and_role(int(dept_id), effective_role_id, exclude_user_id=body.user_id)
            if count >= max_allowed:
                raise HTTPException(
                    status_code=status.HTTP_409_CONFLICT,
                    detail=f"Department already has the maximum of {max_allowed} active users for this role.",
                )

    try:
        user = repo.update(
            body.user_id,
            first_name=body.first_name,
            last_name=body.last_name,
            email=body.email,
            is_active=body.is_active,
            role_id=body.role_id,
            department_id=body.department_id,
            approver_id=body.approver_id,
            mobile_number=body.mobile_number,
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(e))
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")

    audit.log(
        "user_updated", "user",
        actor_user_id=current_user.id,
        entity_id=body.user_id,
        details={"target_username": target.username, "changes": changes},
        ip_address=get_client_ip(request),
    )
    return user


