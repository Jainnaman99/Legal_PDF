import logging

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)

BSNL_URL = "https://crid.cerfgs.com/index.php/sendmsg"


class SmsService:

    def send_admin_login_otp(self, to_number: str, otp: str) -> str:
        return self._send(
            to_number,
            f"Your OTP for logging in to Haryana Government Digital Repository Portal is {otp}. Please do not share with anyone. Team HGDR.",
        )

    def send_otp(self, to_number: str, otp: str) -> str:
        return self._send(
            to_number,
            f"Your OTP for logging in to Haryana Government Digital Repository Portal is {otp}. Please do not share with anyone. Team HGDR.",
        )

    def _send(self, to_number: str, content: str) -> str:
        if not settings.BSNL_USERNAME or not settings.BSNL_KEY:
            logger.warning("[SmsService] BSNL credentials not configured — message to %s: %s", to_number, content)
            return "BSNL credentials not configured"

        # BSNL expects a 10-digit Indian mobile number (no country code)
        mobile = to_number
        if mobile.startswith("+91"):
            mobile = mobile[3:]
        elif mobile.startswith("91") and len(mobile) == 12:
            mobile = mobile[2:]

        payload = {
            "username":       settings.BSNL_USERNAME,
            "content":        content,
            "mobileno":       mobile,
            "senderid":       settings.BSNL_SENDER_ID,
            "key":            settings.BSNL_KEY,
            "smsservicetype": "otpmsg",
            "entityid":       settings.BSNL_ENTITY_ID,
        }
        if settings.BSNL_OTP_TEMPLATE_ID:
            payload["templateid"] = settings.BSNL_OTP_TEMPLATE_ID
        try:
            logger.debug("[SmsService] BSNL request to %s — username=%s senderid=%s entityid=%s mobile=%s",
                         BSNL_URL, payload["username"], payload["senderid"], payload["entityid"], mobile)
            resp = httpx.post(BSNL_URL, data=payload, timeout=10)
            resp_text = resp.text.strip()
            if resp_text.startswith("402"):
                logger.info("[SmsService] BSNL SMS sent to %s: %s", mobile, resp_text)
            else:
                logger.error("[SmsService] BSNL SMS failed to %s: %s", mobile, resp_text)
            return resp_text
        except Exception as exc:
            logger.error("[SmsService] BSNL SMS exception for %s: %s", mobile, exc)
            return f"Exception: {exc}"
