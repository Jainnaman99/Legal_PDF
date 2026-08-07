from typing import Optional

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.interfaces.dept_role_limit_repository import IDeptRoleLimitRepository


class DeptRoleLimitRepository(IDeptRoleLimitRepository):

    def __init__(self, db: Session):
        self._db = db

    def get_limit(self, dept_id: int, role_id: int) -> Optional[int]:
        row = self._db.execute(
            text("SELECT max_users FROM dept_role_limits WHERE department_id = :d AND role_id = :r"),
            {"d": dept_id, "r": role_id},
        ).mappings().fetchone()
        return int(row["max_users"]) if row else None

    def list_all(self) -> list[dict]:
        rows = self._db.execute(
            text("""
                SELECT
                    drl.id,
                    drl.department_id,
                    d.name  AS department_name,
                    drl.role_id,
                    r.name  AS role_name,
                    drl.max_users,
                    drl.updated_at
                FROM dept_role_limits drl
                LEFT JOIN departments  d ON d.id = drl.department_id
                LEFT JOIN roles        r ON r.id = drl.role_id
                ORDER BY d.name, r.name
            """)
        ).mappings().fetchall()
        return [dict(row) for row in rows]

    def upsert(self, dept_id: int, role_id: int, max_users: int) -> None:
        self._db.execute(
            text("""
                INSERT INTO dept_role_limits (department_id, role_id, max_users)
                VALUES (:d, :r, :m)
                ON DUPLICATE KEY UPDATE max_users = :m, updated_at = NOW()
            """),
            {"d": dept_id, "r": role_id, "m": max_users},
        )
        self._db.commit()

    def delete(self, dept_id: int, role_id: int) -> bool:
        result = self._db.execute(
            text("DELETE FROM dept_role_limits WHERE department_id = :d AND role_id = :r"),
            {"d": dept_id, "r": role_id},
        )
        self._db.commit()
        return result.rowcount > 0

    def count_active_users(self, dept_id: int, role_id: int) -> int:
        row = self._db.execute(
            text("""
                SELECT COUNT(*) AS cnt
                FROM users
                WHERE is_active = 1
                  AND role_id = :r
                  AND FIND_IN_SET(:d, REPLACE(department_id, ' ', '')) > 0
            """),
            {"d": str(dept_id), "r": role_id},
        ).mappings().fetchone()
        return int(row["cnt"]) if row else 0
