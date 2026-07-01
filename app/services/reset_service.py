import hashlib
import random
from datetime import datetime, timedelta, timezone
from typing import Optional

from app.core.security import create_access_token, hash_password
from app.interfaces.reset_otp_repository import IResetOtpRepository
from app.interfaces.user_repository import IUserRepository
from app.models.user import User
from app.services.email_service import EmailService
from app.services.sms_service import SmsService

_OTP_TTL_MINUTES = 10


class ResetService:

    def __init__(
        self,
        user_repo: IUserRepository,
        otp_repo: IResetOtpRepository,
        email_svc: EmailService,
        sms_svc: SmsService,
    ):
        self._user_repo  = user_repo
        self._otp_repo   = otp_repo
        self._email_svc  = email_svc
        self._sms_svc    = sms_svc

    # ── helpers ───────────────────────────────────────────────

    @staticmethod
    def _generate_otp() -> str:
        return str(random.randint(100000, 999999))

    @staticmethod
    def _hash_otp(otp: str) -> str:
        return hashlib.sha256(otp.encode()).hexdigest()

    def _find_user(self, identifier: str) -> Optional[User]:
        if "@" in identifier:
            return self._user_repo.get_by_email(identifier)
        return self._user_repo.get_by_mobile(identifier.strip())

    def _build_token(self, user: User) -> str:
        return create_access_token({
            "sub":                  str(user.id),
            "username":             user.username,
            "email":                user.email,
            "is_active":            user.is_active,
            "must_change_password": False,
            "role_id":              user.role_id,
            "role":                 user.role.name if user.role else None,
            "department_id":        user.department_id,
            "department":           user.department.name if user.department else None,
        })

    # ── public API ────────────────────────────────────────────

    def request_otp(self, identifier: str) -> str:
        """
        Generate and send a 6-digit OTP.
        Returns the channel used ('email' | 'sms').
        Raises ValueError if no active account is found for the identifier.
        """
        user = self._find_user(identifier)
        if not user or not user.is_active:
            label = "email address" if "@" in identifier else "mobile number"
            raise ValueError(f"No active account found with this {label}.")

        otp = self._generate_otp()
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=_OTP_TTL_MINUTES)

        if "@" in identifier:
            self._otp_repo.create(user.id, self._hash_otp(otp), "email", expires_at)
            self._email_svc.send_otp(user.email, user.username, otp)
            return "email"
        else:
            if not user.mobile_number:
                raise ValueError("No mobile number registered for this account. Please contact the administrator.")
            self._otp_repo.create(user.id, self._hash_otp(otp), "sms", expires_at)
            self._sms_svc.send_otp(user.mobile_number, otp)
            return "sms"

    def verify_and_reset(self, identifier: str, otp: str, new_password: str) -> Optional[str]:
        """
        Verify OTP and reset the password.
        Returns a fresh JWT on success, None on failure.
        """
        user = self._find_user(identifier)
        if not user or not user.is_active:
            return None

        record = self._otp_repo.get_valid(user.id)
        if not record:
            return None

        if record["otp_hash"] != self._hash_otp(otp):
            return None

        self._otp_repo.mark_used(record["id"])
        self._user_repo.change_password(user.id, hash_password(new_password))

        user = self._user_repo.get_by_id(user.id)
        return self._build_token(user)
