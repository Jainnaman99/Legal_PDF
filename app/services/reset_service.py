import hashlib
import random
from datetime import datetime, timedelta, timezone
from typing import Optional

from app.core.security import build_user_token, hash_password
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

    # ── public API ────────────────────────────────────────────

    def request_otp_by_username(self, username: str) -> dict:
        """
        Look up user by username, send OTP via SMS.
        Returns {"masked_mobile": "XXXXXX1234"}.
        Raises ValueError if the user is not found, inactive, or has no mobile number.
        """
        user = self._user_repo.get_by_username(username.strip())
        if not user or not user.is_active:
            raise ValueError("No active account found with this username.")
        if not user.mobile_number:
            raise ValueError("No mobile number registered for this account. Please contact the administrator.")

        otp = self._generate_otp()
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=_OTP_TTL_MINUTES)
        self._otp_repo.create(user.id, self._hash_otp(otp), "sms", expires_at)
        self._sms_svc.send_otp(user.mobile_number, otp)

        mobile = user.mobile_number
        masked = "X" * (len(mobile) - 4) + mobile[-4:]
        return {"masked_mobile": masked}

    def send_first_login_otp(self, user: User) -> None:
        """Generate and SMS an OTP for the first-login mobile verification flow.
        Stores the OTP against the user's own ID — no mobile-number lookup needed."""
        otp = self._generate_otp()
        expires_at = datetime.now(timezone.utc) + timedelta(minutes=_OTP_TTL_MINUTES)
        self._otp_repo.create(user.id, self._hash_otp(otp), "sms", expires_at)
        self._sms_svc.send_verification_otp(user.mobile_number, otp)

    def verify_and_reset(self, username: str, otp: str, new_password: str) -> Optional[str]:
        """
        Verify OTP and reset the password.
        Returns a fresh JWT on success, None on failure.
        """
        user = self._user_repo.get_by_username(username.strip())
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
        return build_user_token(user)
