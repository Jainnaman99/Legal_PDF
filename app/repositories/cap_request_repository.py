from typing import Optional

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.interfaces.cap_request_repository import ICapRequestRepository

_SELECT_COLS = """
    cr.id,
    cr.department_id,
    d.name   AS department_name,
    cr.role_id,
    r.name   AS role_name,
    cr.requested_by,
    CONCAT(COALESCE(u.first_name,''), ' ', COALESCE(u.last_name,'')) AS requested_by_name,
    u.username                                                        AS requested_by_username,
    cr.current_cap,
    cr.requested_cap,
    cr.reason,
    cr.status,
    cr.super_admin_note,
    cr.resolved_by,
    cr.resolved_at,
    cr.created_at
"""

_FROM_JOINS = """
    FROM cap_change_requests cr
    LEFT JOIN departments d ON d.id = cr.department_id
    LEFT JOIN roles       r ON r.id = cr.role_id
    LEFT JOIN users       u ON u.id = cr.requested_by
"""


class CapRequestRepository(ICapRequestRepository):

    def __init__(self, db: Session):
        self._db = db

    def create(
        self,
        department_id: int,
        role_id: int,
        requested_by: int,
        current_cap: Optional[int],
        requested_cap: int,
        reason: Optional[str],
    ) -> dict:
        result = self._db.execute(
            text("""
                INSERT INTO cap_change_requests
                    (department_id, role_id, requested_by, current_cap, requested_cap, reason)
                VALUES
                    (:dept, :role, :by, :cur, :req, :rsn)
            """),
            {"dept": department_id, "role": role_id, "by": requested_by,
             "cur": current_cap, "req": requested_cap, "rsn": reason},
        )
        self._db.commit()
        new_id = result.lastrowid
        return self.get_by_id(new_id)

    def list_pending(self) -> list[dict]:
        rows = self._db.execute(
            text(f"SELECT {_SELECT_COLS} {_FROM_JOINS} WHERE cr.status = 'pending' ORDER BY cr.created_at DESC")
        ).mappings().fetchall()
        return [dict(r) for r in rows]

    def list_by_department(self, department_id: int) -> list[dict]:
        rows = self._db.execute(
            text(f"SELECT {_SELECT_COLS} {_FROM_JOINS} WHERE cr.department_id = :dept ORDER BY cr.created_at DESC"),
            {"dept": department_id},
        ).mappings().fetchall()
        return [dict(r) for r in rows]

    def get_by_id(self, request_id: int) -> Optional[dict]:
        row = self._db.execute(
            text(f"SELECT {_SELECT_COLS} {_FROM_JOINS} WHERE cr.id = :id"),
            {"id": request_id},
        ).mappings().fetchone()
        return dict(row) if row else None

    def review(
        self,
        request_id: int,
        status: str,
        resolved_by: int,
        super_admin_note: Optional[str],
    ) -> Optional[dict]:
        self._db.execute(
            text("""
                UPDATE cap_change_requests
                SET status           = :status,
                    resolved_by      = :by,
                    resolved_at      = NOW(),
                    super_admin_note = :note
                WHERE id = :id AND status = 'pending'
            """),
            {"status": status, "by": resolved_by, "note": super_admin_note, "id": request_id},
        )
        self._db.commit()
        return self.get_by_id(request_id)
