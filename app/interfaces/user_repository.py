from abc import ABC, abstractmethod
from typing import Optional

from app.models.user import User


class IUserRepository(ABC):

    @abstractmethod
    def get_by_id(self, user_id: int) -> Optional[User]:
        ...

    @abstractmethod
    def get_by_username(self, username: str) -> Optional[User]:
        ...

    @abstractmethod
    def get_by_email(self, email: str) -> Optional[User]:
        ...

    @abstractmethod
    def create(
        self,
        username: str,
        email: str,
        hashed_password: str,
        role_id: Optional[int] = None,
        department_id: Optional[int] = None,
    ) -> User:
        ...

    @abstractmethod
    def list_all(self, skip: int = 0, limit: int = 100) -> list[User]:
        ...
