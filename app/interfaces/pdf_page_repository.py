from abc import ABC, abstractmethod


class IPDFPageRepository(ABC):

    @abstractmethod
    def save_pages(self, pdf_document_id: int, pages: list[tuple[int, str]]) -> None:
        ...

    @abstractmethod
    def search(self, search_term: str, skip: int, limit: int) -> list[dict]:
        ...

    @abstractmethod
    def delete_by_document(self, pdf_document_id: int) -> None:
        ...
