from typing import Optional

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.interfaces.unlock_request_repository import IUnlockRequestRepository

_SELECT_COLS = """
    ur.id,
    ur.pdf_id,
    p.document_name,
    p.original_filename,
    ur.department_id,
    d.name AS department_name,
    ur.request_type,
    ur.requested_by,
    CONCAT(COALESCE(ru.first_name,''), ' ', COALESCE(ru.last_name,'')) AS requested_by_name,
    ru.username AS requested_by_username,
    ur.reason,
    ur.status,
    ur.reviewed_by,
    CONCAT(COALESCE(rvu.first_name,''), ' ', COALESCE(rvu.last_name,'')) AS reviewed_by_name,
    rvu.username AS reviewed_by_username,
    ur.review_note,
    ur.reviewed_at,
    ur.created_at
"""

_FROM_JOINS = """
    FROM pdf_unlock_requests ur
    JOIN pdf_documents p       ON p.id  = ur.pdf_id
    LEFT JOIN departments d    ON d.id  = ur.department_id
    LEFT JOIN users ru         ON ru.id = ur.requested_by
    LEFT JOIN users rvu        ON rvu.id = ur.reviewed_by
"""


class UnlockRequestRepository(IUnlockRequestRepository):

    def __init__(self, db: Session):
        self._db = db

    def create(
        self,
        pdf_id: int,
        department_id: int,
        request_type: str,
        requested_by: int,
        reason: Optional[str],
    ) -> dict:
        result = self._db.execute(
            text("""
                INSERT INTO pdf_unlock_requests (pdf_id, department_id, request_type, requested_by, reason)
                VALUES (:pdf_id, :dept, :rtype, :by, :reason)
            """),
            {"pdf_id": pdf_id, "dept": department_id, "rtype": request_type, "by": requested_by, "reason": reason},
        )
        self._db.commit()
        return self.get_by_id(result.lastrowid)

    def get_by_id(self, request_id: int) -> Optional[dict]:
        row = self._db.execute(
            text(f"SELECT {_SELECT_COLS} {_FROM_JOINS} WHERE ur.id = :id"),
            {"id": request_id},
        ).mappings().fetchone()
        return dict(row) if row else None

    def get_pending_for_pdf(self, pdf_id: int) -> Optional[dict]:
        row = self._db.execute(
            text(f"SELECT {_SELECT_COLS} {_FROM_JOINS} WHERE ur.pdf_id = :pdf_id AND ur.status = 'pending'"),
            {"pdf_id": pdf_id},
        ).mappings().fetchone()
        return dict(row) if row else None

    def list_pending_for_departments(self, department_ids: list[int]) -> list[dict]:
        if not department_ids:
            return []
        placeholders = ", ".join(f":d{i}" for i in range(len(department_ids)))
        params = {f"d{i}": v for i, v in enumerate(department_ids)}
        rows = self._db.execute(
            text(f"""
                SELECT {_SELECT_COLS} {_FROM_JOINS}
                WHERE ur.status = 'pending' AND ur.department_id IN ({placeholders})
                ORDER BY ur.created_at DESC
            """),
            params,
        ).mappings().fetchall()
        return [dict(r) for r in rows]

    def list_by_requester(self, requested_by: int) -> list[dict]:
        rows = self._db.execute(
            text(f"SELECT {_SELECT_COLS} {_FROM_JOINS} WHERE ur.requested_by = :by ORDER BY ur.created_at DESC"),
            {"by": requested_by},
        ).mappings().fetchall()
        return [dict(r) for r in rows]

    def review(
        self,
        request_id: int,
        status: str,
        reviewed_by: int,
        review_note: Optional[str],
    ) -> Optional[dict]:
        self._db.execute(
            text("""
                UPDATE pdf_unlock_requests
                SET status      = :status,
                    reviewed_by = :by,
                    reviewed_at = NOW(),
                    review_note = :note
                WHERE id = :id AND status = 'pending'
            """),
            {"status": status, "by": reviewed_by, "note": review_note, "id": request_id},
        )
        self._db.commit()
        return self.get_by_id(request_id)
