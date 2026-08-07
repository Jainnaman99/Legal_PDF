from typing import Optional

from app.core.security import build_user_token, decode_access_token, hash_password, verify_password
from app.interfaces.login_log_repository import ILoginLogRepository
from app.interfaces.user_repository import IUserRepository
from app.models.user import User

_MAX_USERS_PER_DEPT_ROLE = 2


class AuthService:

    def __init__(self, user_repo: IUserRepository, log_repo: ILoginLogRepository):
        self._user_repo = user_repo
        self._log_repo = log_repo

    def register(
        self,
        username: str,
        email: str,
        password: str,
        first_name: Optional[str] = None,
        last_name: Optional[str] = None,
        role_id: Optional[int] = None,
        department_id: Optional[str] = None,
        mobile_number: Optional[str] = None,
        approver_id: Optional[int] = None,
    ) -> User:
        if role_id and department_id:
            dept_ids = [d.strip() for d in department_id.split(",") if d.strip().isdigit()]
            for dept_id in dept_ids:
                count = self._user_repo.count_by_dept_and_role(int(dept_id), role_id)
                if count >= _MAX_USERS_PER_DEPT_ROLE:
                    raise ValueError(
                        f"Department already has the maximum of {_MAX_USERS_PER_DEPT_ROLE} "
                        f"active users for this role."
                    )
        return self._user_repo.create(
            username, email, hash_password(password),
            first_name, last_name, role_id, department_id, mobile_number,
            approver_id=approver_id,
        )

    def login(self, username: str, password: str, ip_address: Optional[str] = None) -> Optional[str]:
        user = self._user_repo.get_by_username(username)
        if not user or not user.is_active:
            return None
        if not verify_password(password, user.hashed_password):
            return None
        self._log_repo.log(user.id, "login", ip_address)
        return build_user_token(user)

    def change_password(self, user_id: int, current_password: str, new_password: str) -> Optional[str]:
        user = self._user_repo.get_by_id_for_auth(user_id)
        if not user or not verify_password(current_password, user.hashed_password):
            return None
        self._user_repo.change_password(user_id, hash_password(new_password))
        user = self._user_repo.get_by_id(user_id)
        return build_user_token(user)

    def logout(self, user_id: int, ip_address: Optional[str] = None) -> None:
        self._log_repo.log(user_id, "logout", ip_address)

    def get_current_user(self, token: str) -> Optional[User]:
        payload = decode_access_token(token)
        if not payload:
            return None
        user_id = payload.get("sub")
        if not user_id:
            return None
        return self._user_repo.get_by_id(int(user_id))
