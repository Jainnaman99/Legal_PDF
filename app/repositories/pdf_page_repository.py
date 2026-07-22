from sqlalchemy import text
from sqlalchemy.orm import Session

from app.interfaces.pdf_page_repository import IPDFPageRepository


class PDFPageRepository(IPDFPageRepository):

    def __init__(self, db: Session):
        self._db = db

    def save_pages(self, pdf_document_id: int, pages: list[tuple[int, str]]) -> None:
        for page_number, page_text in pages:
            self._db.execute(
                text("CALL sp_save_pdf_page(:doc_id, :page_num, :page_text)"),
                {"doc_id": pdf_document_id, "page_num": page_number, "page_text": page_text},
            )
        self._db.commit()

    def search(self, search_term: str, skip: int = 0, limit: int = 20) -> list[dict]:
        result = self._db.execute(
            text("CALL sp_search_pdf_pages(:term, :skip, :limit)"),
            {"term": search_term, "skip": skip, "limit": limit},
        )
        return [dict(row) for row in result.mappings().fetchall()]

    def delete_by_document(self, pdf_document_id: int) -> None:
        self._db.execute(
            text("CALL sp_delete_pdf_pages_by_doc(:doc_id)"),
            {"doc_id": pdf_document_id},
        )
        self._db.commit()

    def get_pages_by_document(self, pdf_document_id: int) -> list[tuple[int, str]]:
        result = self._db.execute(
            text("SELECT page_number, page_text FROM pdf_pages WHERE pdf_document_id = :doc_id ORDER BY page_number"),
            {"doc_id": pdf_document_id},
        )
        return [(row["page_number"], row["page_text"]) for row in result.mappings().fetchall()]
