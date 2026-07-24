from abc import ABC, abstractmethod
from typing import Optional

from app.models.act_structure import ActStructure


class IActStructureRepository(ABC):

    @abstractmethod
    def create_structure(
        self,
        pdf_document_id: Optional[int],
        act_title: str,
        act_number: Optional[str],
        act_year: Optional[int],
    ) -> ActStructure: ...

    @abstractmethod
    def update_status(
        self, structure_id: int, status: str, error_message: Optional[str] = None
    ) -> None: ...

    @abstractmethod
    def update_totals(
        self, structure_id: int, chapters: int, sections: int, schedules: int
    ) -> None: ...

    @abstractmethod
    def add_chapter(
        self,
        structure_id: int,
        chapter_number: Optional[str],
        chapter_title: Optional[str],
        display_order: int,
    ) -> int: ...

    @abstractmethod
    def add_section(
        self,
        structure_id: int,
        chapter_id: Optional[int],
        section_number: Optional[str],
        section_title: Optional[str],
        section_content: Optional[str],
        display_order: int,
    ) -> None: ...

    @abstractmethod
    def add_schedule(
        self,
        structure_id: int,
        schedule_number: Optional[str],
        schedule_title: Optional[str],
        schedule_content: Optional[str],
        display_order: int,
    ) -> None: ...

    @abstractmethod
    def get_by_id(self, structure_id: int) -> Optional[ActStructure]: ...

    @abstractmethod
    def get_by_pdf_document_id(self, pdf_document_id: int) -> Optional[ActStructure]: ...

    @abstractmethod
    def list_all(self) -> list[ActStructure]: ...

    @abstractmethod
    def list_available_acts(self, query: str) -> list[dict]: ...
