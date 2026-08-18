from typing import Optional

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.interfaces.pdf_approval_draft_repository import IPDFApprovalDraftRepository


class PDFApprovalDraftRepository(IPDFApprovalDraftRepository):

    def __init__(self, db: Session):
        self._db = db

    def upsert(
        self,
        pdf_id: int,
        approver_id: int,
        comments: Optional[str],
        annotations_json: Optional[str],
    ) -> None:
        self._db.execute(
            text("""
                INSERT INTO pdf_approval_drafts (pdf_id, approver_id, comments, annotations_json, saved_at)
                VALUES (:pdf_id, :approver_id, :comments, :annotations_json, UTC_TIMESTAMP())
                ON DUPLICATE KEY UPDATE
                    comments         = VALUES(comments),
                    annotations_json = VALUES(annotations_json),
                    saved_at         = UTC_TIMESTAMP()
            """),
            {
                "pdf_id":           pdf_id,
                "approver_id":      approver_id,
                "comments":         comments,
                "annotations_json": annotations_json,
            },
        )
        self._db.commit()

    def get(self, pdf_id: int, approver_id: int) -> Optional[dict]:
        result = self._db.execute(
            text("""
                SELECT pdf_id, approver_id, comments, annotations_json, saved_at
                FROM pdf_approval_drafts
                WHERE pdf_id = :pdf_id AND approver_id = :approver_id
            """),
            {"pdf_id": pdf_id, "approver_id": approver_id},
        )
        row = result.mappings().fetchone()
        if not row:
            return None
        return dict(row)

    def delete(self, pdf_id: int, approver_id: int) -> None:
        self._db.execute(
            text("""
                DELETE FROM pdf_approval_drafts
                WHERE pdf_id = :pdf_id AND approver_id = :approver_id
            """),
            {"pdf_id": pdf_id, "approver_id": approver_id},
        )
        self._db.commit()
