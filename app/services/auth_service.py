from typing import Optional

from app.core.security import create_access_token, decode_access_token, hash_password, verify_password
from app.interfaces.user_repository import IUserRepository
from app.models.user import User


class AuthService:

    def __init__(self, user_repo: IUserRepository):
        self._user_repo = user_repo

    def register(
        self,
        username: str,
        email: str,
        password: str,
        role_id: Optional[int] = None,
    ) -> User:
        return self._user_repo.create(username, email, hash_password(password), role_id)

    def login(self, username: str, password: str) -> Optional[str]:
        user = self._user_repo.get_by_username(username)
        if not user or not user.is_active:
            return None
        if not verify_password(password, user.hashed_password):
            return None
        return create_access_token({"sub": str(user.id)})

    def get_current_user(self, token: str) -> Optional[User]:
        payload = decode_access_token(token)
        if not payload:
            return None
        user_id = payload.get("sub")
        if not user_id:
            return None
        return self._user_repo.get_by_id(int(user_id))
