import os
import uuid
from typing import Optional

from fastapi import UploadFile

from app.core.config import settings
from app.interfaces.pdf_page_repository import IPDFPageRepository
from app.interfaces.pdf_repository import IPDFRepository
from app.models.pdf_document import PDFDocument
from app.services.pdf_extractor import extract_pages
from app.utils.text_utils import prepare_fts_query, build_snippet


class PDFService:

    def __init__(self, pdf_repo: IPDFRepository, page_repo: IPDFPageRepository):
        self._pdf_repo = pdf_repo
        self._page_repo = page_repo

    async def upload(
        self,
        file: UploadFile,
        user_id: int,
        description: Optional[str] = None,
    ) -> PDFDocument:
        os.makedirs(settings.UPLOAD_DIR, exist_ok=True)

        unique_name = f"{uuid.uuid4().hex}_{file.filename}"
        file_path = os.path.join(settings.UPLOAD_DIR, unique_name)

        content = await file.read()
        with open(file_path, "wb") as f:
            f.write(content)

        doc = self._pdf_repo.create(
            filename=unique_name,
            original_filename=file.filename,
            file_path=file_path,
            file_size=len(content),
            uploaded_by=user_id,
            description=description,
        )

        try:
            pages = [(num, txt) for num, txt in extract_pages(file_path) if txt.strip()]
            if pages:
                self._page_repo.save_pages(doc.id, pages)
        except Exception:
            pass  # upload still succeeds even if text extraction fails

        return doc

    def search(self, query: str, skip: int = 0, limit: int = 20) -> list[dict]:
        fts_term = prepare_fts_query(query)
        rows = self._page_repo.search(fts_term, skip, limit)
        for row in rows:
            row["snippet"] = build_snippet(row["page_text"], query)
        return rows

    def list_my_documents(self, user_id: int, skip: int = 0, limit: int = 100) -> list[PDFDocument]:
        return self._pdf_repo.list_by_user(user_id, skip, limit)

    def list_all_documents(self, skip: int = 0, limit: int = 100) -> list[PDFDocument]:
        return self._pdf_repo.list_all(skip, limit)
