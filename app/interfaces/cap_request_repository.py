from abc import ABC, abstractmethod
from typing import Optional


class ICapRequestRepository(ABC):

    @abstractmethod
    def create(
        self,
        department_id: int,
        role_id: int,
        requested_by: int,
        current_cap: Optional[int],
        requested_cap: int,
        reason: Optional[str],
    ) -> dict:
        """Insert a new cap-change request and return it as a dict."""
        ...

    @abstractmethod
    def list_pending(self) -> list[dict]:
        """Return all requests with status='pending', newest first."""
        ...

    @abstractmethod
    def list_by_department(self, department_id: int) -> list[dict]:
        """Return all requests for a given department, newest first."""
        ...

    @abstractmethod
    def get_by_id(self, request_id: int) -> Optional[dict]:
        """Return a single request row or None."""
        ...

    @abstractmethod
    def review(
        self,
        request_id: int,
        status: str,
        resolved_by: int,
        super_admin_note: Optional[str],
    ) -> Optional[dict]:
        """Set status to 'approved' or 'rejected' and record who resolved it."""
        ...
