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
        matching user), and return (otp, sms_response).
        """
        users = self._user_repo.get_all_admin_by_mobile(mobile_number.strip())
        if not users:
            raise ValueError("No active admin account found with this mobile number.")

        otp        = self._generate_otp()
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=_OTP_TTL_MINUTES)
        otp_hash   = self._hash_otp(otp)

        for user in users:
            self._otp_repo.create(user.id, otp_hash, expires_at)

        sms_response = self._sms_svc.send_admin_login_otp(mobile_number, otp)
        return otp, sms_response

    def verify_otp(self, mobile_number: str, otp: str) -> Optional[list[dict]]:
        """
        Validate the OTP against any admin user with this mobile.
        Returns the departments list if the OTP is correct (does NOT mark it as used yet —
        the user still needs to select a department via complete_login).
        Returns None if OTP is invalid or expired.
        """
        users = self._user_repo.get_all_admin_by_mobile(mobile_number.strip())
        if not users:
            return None

        otp_hash = self._hash_otp(otp)
        # Check OTP against any matching user — all share the same hash.
        for user in users:
            record = self._otp_repo.get_valid(user.id)
            if record and record["otp_hash"] == otp_hash:
                break
        else:
            return None  # No valid matching OTP found

        # Build deduplicated department list.
        departments = []
        seen = set()
        for user in users:
            for dept in (user.departments or []):
                if dept.id not in seen:
                    seen.add(dept.id)
                    departments.append({"id": dept.id, "name": dept.name})

        return departments

    def _all_departments_for_mobile(self, mobile_number: str) -> list:
        """Collect every unique department linked to this mobile across all admin users."""
        users = self._user_repo.get_all_admin_by_mobile(mobile_number)
        seen: dict[int, object] = {}
        for u in users:
            for dept in (u.departments or []):
                if dept.id not in seen:
                    seen[dept.id] = dept
        return list(seen.values())

    def switch_department(self, mobile_number: str, department_id: int) -> Optional[str]:
        """
        Already-authenticated admin switches to a different department linked to
        the same mobile number.  No OTP required — the caller must already hold
        a valid JWT.
        """
        user = self._user_repo.get_by_mobile_and_dept(mobile_number.strip(), department_id)
        if not user or not user.is_active:
            return None
        if not user.role or user.role.name not in _ADMIN_ROLES:
            return None
        fresh_user = self._user_repo.get_by_id(user.id)
        fresh_user.departments = self._all_departments_for_mobile(mobile_number)
        return build_user_token(fresh_user)

    def complete_login(self, mobile_number: str, otp: str, department_id: int) -> Optional[str]:
        """
        Final login step: find the specific user by (mobile, department_id), re-verify
        the OTP, mark it as used, and return a JWT access token.
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
        fresh_user.departments = self._all_departments_for_mobile(mobile_number)
        return build_user_token(fresh_user)
