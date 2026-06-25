from abc import ABC, abstractmethod
from typing import Optional

from app.models.tag import Tag


class ITagRepository(ABC):

    @abstractmethod
    def list_all(self) -> list[Tag]:
        ...

    @abstractmethod
    def get_by_id(self, tag_id: int) -> Optional[Tag]:
        ...

    @abstractmethod
    def create(self, name: str, parent_id: Optional[int] = None) -> Tag:
        ...

    @abstractmethod
    def save_document_tags(self, pdf_id: int, tag_ids: list[int]) -> None:
        ...
