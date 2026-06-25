from abc import ABC, abstractmethod
from typing import Optional

from app.models.role import Role


class IRoleRepository(ABC):

    @abstractmethod
    def get_by_id(self, role_id: int) -> Optional[Role]:
        ...

    @abstractmethod
    def list_all(self, skip: int = 0, limit: int = 100) -> list[Role]:
        ...
