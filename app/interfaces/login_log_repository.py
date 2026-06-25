from abc import ABC, abstractmethod
from typing import Optional


class ILoginLogRepository(ABC):

    @abstractmethod
    def log(self, user_id: int, action: str, ip_address: Optional[str] = None) -> None:
        ...
