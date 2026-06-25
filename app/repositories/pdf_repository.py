from datetime import date
from typing import Optional

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.interfaces.pdf_repository import IPDFRepository
from app.models.pdf_document import PDFDocument
from app.schemas.tag import TagRef


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
        act_name: Optional[str] = None,
        gazette_reference: Optional[str] = None,
        issuing_authority: Optional[str] = None,
        enactment_date: Optional[date] = None,
        version_no: Optional[str] = "1.0",
        department_id: Optional[int] = None,
        document_type_id: Optional[int] = None,
        description: Optional[str] = None,
    ) -> PDFDocument:
        result = self._db.execute(
            text(
                "EXEC sp_create_pdf_document "
                "@filename = :filename, @original_filename = :original_filename, "
                "@file_path = :file_path, @file_size = :file_size, "
                "@uploaded_by = :uploaded_by, @act_name = :act_name, "
                "@gazette_reference = :gazette_reference, @issuing_authority = :issuing_authority, "
                "@enactment_date = :enactment_date, @version_no = :version_no, "
                "@department_id = :department_id, @document_type_id = :document_type_id, "
                "@description = :description"
            ),
            {
                "filename": filename,
                "original_filename": original_filename,
                "file_path": file_path,
                "file_size": file_size,
                "uploaded_by": uploaded_by,
                "act_name": act_name,
                "gazette_reference": gazette_reference,
                "issuing_authority": issuing_authority,
                "enactment_date": enactment_date,
                "version_no": version_no,
                "department_id": department_id,
                "document_type_id": document_type_id,
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
    def _parse_tags(tags_str: Optional[str]) -> list[TagRef]:
        if not tags_str:
            return []
        result = []
        for part in tags_str.split(","):
            part = part.strip()
            if ":" in part:
                tag_id_str, tag_name = part.split(":", 1)
                try:
                    result.append(TagRef(id=int(tag_id_str), name=tag_name))
                except ValueError:
                    pass
        return result

    @staticmethod
    def _map_row(row) -> PDFDocument:
        d = dict(row)
        doc = PDFDocument(
            id=d["id"],
            filename=d["filename"],
            original_filename=d["original_filename"],
            file_path=d["file_path"],
            file_size=d["file_size"],
            act_name=d.get("act_name"),
            gazette_reference=d.get("gazette_reference"),
            issuing_authority=d.get("issuing_authority"),
            enactment_date=d.get("enactment_date"),
            version_no=d.get("version_no"),
            department_id=d.get("department_id"),
            document_type_id=d.get("document_type_id"),
            description=d.get("description"),
            uploaded_by=d["uploaded_by"],
            created_at=d["created_at"],
        )
        doc.department_name = d.get("department_name")
        doc.document_type_name = d.get("document_type_name")
        doc.tags = PDFRepository._parse_tags(d.get("tags"))
        return doc
