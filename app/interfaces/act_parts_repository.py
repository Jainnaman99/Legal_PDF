from abc import ABC, abstractmethod
from typing import Optional


class IActPartsRepository(ABC):

    @abstractmethod
    def save_sections(
        self,
        pdf_document_id: int,
        created_by: int,
        has_chapters: bool,
        chapters_json: Optional[str],
        flat_json: Optional[str],
    ) -> None: ...

    @abstractmethod
    def get_sections(self, pdf_document_id: int) -> dict: ...

    @abstractmethod
    def save_entries(
        self,
        part_type: str,
        pdf_document_id: int,
        created_by: int,
        entries_json: str,
    ) -> None: ...

    @abstractmethod
    def get_entries(self, part_type: str, pdf_document_id: int) -> list[dict]: ...

    @abstractmethod
    def get_all_parts(self, pdf_document_id: int) -> dict: ...

    @abstractmethod
    def submit_for_approval(self, pdf_document_id: int, part_type: str, submitted_by: int) -> dict: ...

    @abstractmethod
    def review_act_parts(
        self, pdf_document_id: int, part_type: str,
        reviewed_by: int, action: str, comments: Optional[str],
    ) -> dict: ...

    @abstractmethod
    def get_approvals(self, pdf_document_id: int) -> list[dict]: ...

    @abstractmethod
    def list_pending(self) -> list[dict]: ...

    @abstractmethod
    def list_my_submissions(self, submitted_by: int) -> list[dict]: ...

    @abstractmethod
    def list_all_submissions(self) -> list[dict]: ...
