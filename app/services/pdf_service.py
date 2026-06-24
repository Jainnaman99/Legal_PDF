import os
import uuid
from typing import Optional

from fastapi import UploadFile

from app.core.config import settings
from app.interfaces.pdf_repository import IPDFRepository
from app.models.pdf_document import PDFDocument


class PDFService:

    def __init__(self, pdf_repo: IPDFRepository):
        self._pdf_repo = pdf_repo

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

        return self._pdf_repo.create(
            filename=unique_name,
            original_filename=file.filename,
            file_path=file_path,
            file_size=len(content),
            uploaded_by=user_id,
            description=description,
        )

    def list_my_documents(self, user_id: int, skip: int = 0, limit: int = 100) -> list[PDFDocument]:
        return self._pdf_repo.list_by_user(user_id, skip, limit)

    def list_all_documents(self, skip: int = 0, limit: int = 100) -> list[PDFDocument]:
        return self._pdf_repo.list_all(skip, limit)
