from abc import ABC, abstractmethod
from typing import Optional


class IUnlockRequestRepository(ABC):

    @abstractmethod
    def create(
        self,
        pdf_id: int,
        department_id: int,
        request_type: str,
        requested_by: int,
        reason: Optional[str],
    ) -> dict:
        ...

    @abstractmethod
    def get_by_id(self, request_id: int) -> Optional[dict]:
        ...

    @abstractmethod
    def get_pending_for_pdf(self, pdf_id: int) -> Optional[dict]:
        ...

    @abstractmethod
    def list_pending_for_departments(self, department_ids: list[int]) -> list[dict]:
        ...

    @abstractmethod
    def list_by_requester(self, requested_by: int) -> list[dict]:
        ...

    @abstractmethod
    def review(
        self,
        request_id: int,
        status: str,
        reviewed_by: int,
        review_note: Optional[str],
    ) -> Optional[dict]:
        ...
