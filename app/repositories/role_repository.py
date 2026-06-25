from typing import Optional

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.interfaces.role_repository import IRoleRepository
from app.models.role import Role


class RoleRepository(IRoleRepository):

    def __init__(self, db: Session):
        self._db = db

    def get_by_id(self, role_id: int) -> Optional[Role]:
        result = self._db.execute(
            text("EXEC sp_get_role_by_id @role_id = :role_id"),
            {"role_id": role_id},
        )
        row = result.mappings().fetchone()
        return self._map_row(row) if row else None

    def list_all(self, skip: int = 0, limit: int = 100) -> list[Role]:
        result = self._db.execute(
            text("EXEC sp_list_roles @skip = :skip, @limit = :limit"),
            {"skip": skip, "limit": limit},
        )
        return [self._map_row(row) for row in result.mappings().fetchall()]

    @staticmethod
    def _map_row(row) -> Role:
        return Role(
            id=row["id"],
            name=row["name"],
            description=row["description"],
            created_at=row["created_at"],
        )
