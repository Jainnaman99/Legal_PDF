from abc import ABC, abstractmethod
from typing import Optional


class IPDFApprovalDraftRepository(ABC):

    @abstractmethod
    def upsert(
        self,
        pdf_id: int,
        approver_id: int,
        comments: Optional[str],
        annotations_json: Optional[str],
    ) -> None:
        ...

    @abstractmethod
    def get(self, pdf_id: int, approver_id: int) -> Optional[dict]:
        ...

    @abstractmethod
    def delete(self, pdf_id: int, approver_id: int) -> None:
        ...
