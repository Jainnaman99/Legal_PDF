from typing import Optional

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.interfaces.login_log_repository import ILoginLogRepository


class LoginLogRepository(ILoginLogRepository):

    def __init__(self, db: Session):
        self._db = db

    def log(self, user_id: int, action: str, ip_address: Optional[str] = None) -> None:
        self._db.execute(
            text(
                "EXEC sp_log_user_action "
                "@user_id = :user_id, @action = :action, @ip_address = :ip_address"
            ),
            {"user_id": user_id, "action": action, "ip_address": ip_address},
        )
        self._db.commit()
