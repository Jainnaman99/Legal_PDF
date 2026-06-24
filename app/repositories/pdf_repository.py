from typing import Optional

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.interfaces.pdf_repository import IPDFRepository
from app.models.pdf_document import PDFDocument


class PDFRepository(IPDFRepository):

    def __init__(self, db: Session):
        self._db = db

    def create(
        self,
        filename: str,
        original_filename: str,
        file_path: str,
        file_size: int,
        uploaded_by: int,
        description: Optional[str] = None,
    ) -> PDFDocument:
        result = self._db.execute(
            text(
                "EXEC sp_create_pdf_document "
                "@filename = :filename, @original_filename = :original_filename, "
                "@file_path = :file_path, @file_size = :file_size, "
                "@uploaded_by = :uploaded_by, @description = :description"
            ),
            {
                "filename": filename,
                "original_filename": original_filename,
                "file_path": file_path,
                "file_size": file_size,
                "uploaded_by": uploaded_by,
                "description": description,
            },
        )
        row = result.mappings().fetchone()
        self._db.commit()
        return self._map_row(row)

    def get_by_id(self, document_id: int) -> Optional[PDFDocument]:
        result = self._db.execute(
            text("EXEC sp_get_pdf_by_id @document_id = :document_id"),
            {"document_id": document_id},
        )
        row = result.mappings().fetchone()
        return self._map_row(row) if row else None

    def list_by_user(self, user_id: int, skip: int = 0, limit: int = 100) -> list[PDFDocument]:
        result = self._db.execute(
            text("EXEC sp_list_pdfs_by_user @user_id = :user_id, @skip = :skip, @limit = :limit"),
            {"user_id": user_id, "skip": skip, "limit": limit},
        )
        return [self._map_row(row) for row in result.mappings().fetchall()]

    def list_all(self, skip: int = 0, limit: int = 100) -> list[PDFDocument]:
        result = self._db.execute(
            text("EXEC sp_list_all_pdfs @skip = :skip, @limit = :limit"),
            {"skip": skip, "limit": limit},
        )
        return [self._map_row(row) for row in result.mappings().fetchall()]

    @staticmethod
    def _map_row(row) -> PDFDocument:
        return PDFDocument(
            id=row["id"],
            filename=row["filename"],
            original_filename=row["original_filename"],
            file_path=row["file_path"],
            file_size=row["file_size"],
            uploaded_by=row["uploaded_by"],
            description=row["description"],
            created_at=row["created_at"],
        )
