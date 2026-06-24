from abc import ABC, abstractmethod
from typing import Optional

from app.models.pdf_document import PDFDocument


class IPDFRepository(ABC):

    @abstractmethod
    def create(
        self,
        filename: str,
        original_filename: str,
        file_path: str,
        file_size: int,
        uploaded_by: int,
        description: Optional[str] = None,
    ) -> PDFDocument:
        ...

    @abstractmethod
    def get_by_id(self, document_id: int) -> Optional[PDFDocument]:
        ...

    @abstractmethod
    def list_by_user(self, user_id: int, skip: int = 0, limit: int = 100) -> list[PDFDocument]:
        ...

    @abstractmethod
    def list_all(self, skip: int = 0, limit: int = 100) -> list[PDFDocument]:
        ...
