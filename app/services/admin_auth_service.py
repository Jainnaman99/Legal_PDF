import hashlib
import random
from datetime import datetime, timedelta, timezone
from typing import Optional

from app.core.security import build_user_token
from app.interfaces.admin_otp_repository import IAdminOtpRepository
from app.interfaces.user_repository import IUserRepository
from app.services.sms_service import SmsService

_OTP_TTL_MINUTES = 10
_ADMIN_ROLES = {"super Admin", "admin"}


class AdminAuthService:

    def __init__(
        self,
        user_repo: IUserRepository,
        otp_repo: IAdminOtpRepository,
        sms_svc: SmsService,
    ):
        self._user_repo = user_repo
        self._otp_repo  = otp_repo
        self._sms_svc   = sms_svc

    @staticmethod
    def _generate_otp() -> str:
        return str(random.randint(100000, 999999))

    @staticmethod
    def _hash_otp(otp: str) -> str:
        return hashlib.sha256(otp.encode()).hexdigest()

    def request_otp(self, mobile_number: str):
        """
        Find all active admin users with this mobile, send one OTP (stored for each
        matching user), and return (otp, departments, sms_response).
        departments is a list of {"id": int, "name": str} for the frontend picker.
        """
        users = self._user_repo.get_all_admin_by_mobile(mobile_number.strip())
        if not users:
            raise ValueError("No active admin account found with this mobile number.")

        otp        = self._generate_otp()
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=_OTP_TTL_MINUTES)
        otp_hash   = self._hash_otp(otp)

        # Store the same OTP for every matching user so any of them can verify.
        for user in users:
            self._otp_repo.create(user.id, otp_hash, expires_at)

        sms_response = self._sms_svc.send_admin_login_otp(mobile_number, otp)

        # Build a deduplicated department list for the selection step.
        departments = []
        seen = set()
        for user in users:
            for dept in (user.departments or []):
                if dept.id not in seen:
                    seen.add(dept.id)
                    departments.append({"id": dept.id, "name": dept.name})

        return otp, departments, sms_response

    def verify_otp(self, mobile_number: str, otp: str, department_id: int) -> Optional[str]:
        """
        Verify the OTP for the user identified by (mobile_number, department_id).
        Returns a JWT on success, None on failure.
        """
        user = self._user_repo.get_by_mobile_and_dept(mobile_number.strip(), department_id)
        if not user or not user.is_active:
            return None
        if not user.role or user.role.name not in _ADMIN_ROLES:
            return None

        record = self._otp_repo.get_valid(user.id)
        if not record:
            return None
        if record["otp_hash"] != self._hash_otp(otp):
            return None

        self._otp_repo.mark_used(record["id"])
        fresh_user = self._user_repo.get_by_id(user.id)
        return build_user_token(fresh_user)
