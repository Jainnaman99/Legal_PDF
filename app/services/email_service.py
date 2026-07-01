import logging
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

from app.core.config import settings

logger = logging.getLogger(__name__)


class EmailService:

    def send_otp(self, to_email: str, username: str, otp: str) -> None:
        if not settings.SMTP_HOST or not settings.SMTP_USER:
            logger.warning("[EmailService] SMTP not configured — OTP for %s: %s", to_email, otp)
            return

        subject = "Haryana Legal Knowledge System — Password Reset OTP"
        body_html = f"""
        <div style="font-family:sans-serif;max-width:480px;margin:0 auto;padding:24px">
          <h2 style="color:#1a56db;margin-bottom:8px">Password Reset Request</h2>
          <p>Hello <strong>{username}</strong>,</p>
          <p>Your one-time password (OTP) to reset your HLKS account password is:</p>
          <div style="font-size:36px;font-weight:800;letter-spacing:10px;color:#1a56db;
                      background:#f0f4ff;border-radius:8px;padding:16px 24px;
                      text-align:center;margin:16px 0">{otp}</div>
          <p>This OTP is valid for <strong>10 minutes</strong> and can only be used once.</p>
          <p style="color:#6c757d;font-size:12px">
            If you did not request this, please ignore this email.
            Your password will not change unless you use this OTP.
          </p>
          <hr style="border:none;border-top:1px solid #eee;margin:20px 0"/>
          <p style="color:#adb5bd;font-size:11px">
            Government of Haryana · Legal Knowledge System · HARTRON
          </p>
        </div>
        """

        msg = MIMEMultipart("alternative")
        msg["Subject"] = subject
        msg["From"] = settings.SMTP_FROM or settings.SMTP_USER
        msg["To"] = to_email
        msg.attach(MIMEText(body_html, "html"))

        try:
            with smtplib.SMTP(settings.SMTP_HOST, settings.SMTP_PORT) as server:
                server.ehlo()
                if settings.SMTP_PORT != 465:
                    server.starttls()
                server.login(settings.SMTP_USER, settings.SMTP_PASSWORD)
                server.sendmail(settings.SMTP_FROM or settings.SMTP_USER, to_email, msg.as_string())
            logger.info("[EmailService] OTP sent to %s", to_email)
        except Exception as exc:
            logger.error("[EmailService] Failed to send OTP to %s: %s", to_email, exc)
            raise
