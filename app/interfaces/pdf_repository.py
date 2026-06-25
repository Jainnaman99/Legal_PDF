from abc import ABC, abstractmethod
from datetime import date
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
        act_name: Optional[str] = None,
        gazette_reference: Optional[str] = None,
        issuing_authority: Optional[str] = None,
        enactment_date: Optional[date] = None,
        version_no: Optional[str] = "1.0",
        department_id: Optional[int] = None,
        document_type_id: Optional[int] = None,
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
