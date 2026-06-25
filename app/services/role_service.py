from typing import Optional

from app.interfaces.role_repository import IRoleRepository
from app.models.role import Role


class RoleService:

    def __init__(self, repo: IRoleRepository):
        self._repo = repo

    def get_by_id(self, role_id: int) -> Optional[Role]:
        return self._repo.get_by_id(role_id)

    def list_all(self, skip: int = 0, limit: int = 100) -> list[Role]:
        return self._repo.list_all(skip, limit)
