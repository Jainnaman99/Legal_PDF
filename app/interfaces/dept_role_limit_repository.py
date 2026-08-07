from abc import ABC, abstractmethod
from typing import Optional


class IDeptRoleLimitRepository(ABC):

    @abstractmethod
    def get_limit(self, dept_id: int, role_id: int) -> Optional[int]:
        """Return the max_users cap for this (dept, role) pair, or None if not set."""
        ...

    @abstractmethod
    def list_all(self) -> list[dict]:
        """Return all custom limit rows."""
        ...

    @abstractmethod
    def upsert(self, dept_id: int, role_id: int, max_users: int) -> None:
        """Create or update the cap for a (dept, role) pair."""
        ...

    @abstractmethod
    def delete(self, dept_id: int, role_id: int) -> bool:
        """Remove a custom cap. Returns True if a row was deleted."""
        ...
