import hashlib
import logging

from fastapi import APIRouter, Depends, HTTPException, Request, status

logger = logging.getLogger(__name__)

from app.core.dependencies import get_audit_service, get_auth_service, get_current_user, get_reset_service, get_user_repository
from app.core.rsa_keys import decrypt_login_payload
from app.core.security import build_user_token, decode_access_token, hash_password
from app.interfaces.user_repository import IUserRepository
from app.models.user import User
from app.schemas.auth import (
    ChangePasswordRequest,
    FirstLoginOtpSentResponse,
    FirstLoginResetRequest,
    FirstLoginVerifyOtpRequest,
    ForgotPasswordRequest,
    LoginRequest,
    ResetPasswordRequest,
    TokenResponse,
    UserCreate,
    UserOut,
)
from app.services.audit_service import AuditService
from app.services.auth_service import AuthService
from app.services.reset_service import ResetService
from app.utils.request_utils import get_client_ip

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", response_model=UserOut, status_code=status.HTTP_201_CREATED)
def register(
    body: UserCreate,
    request: Request,
    service: AuthService = Depends(get_auth_service),
    audit: AuditService = Depends(get_audit_service),
):
    try:
        user = service.register(
            body.username, body.email, body.password,
            body.first_name, body.last_name,
            body.role_id, body.department_id, body.mobile_number,
            approver_id=body.approver_id,
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(e))
    audit.log(
        "user_registered", "user",
        entity_id=user.id,
        details={"username": user.username, "email": user.email, "role_id": body.role_id, "department_id": body.department_id},
        ip_address=get_client_ip(request),
    )
    return user


@router.post("/login", response_model=TokenResponse)
def login(
    body: LoginRequest,
    request: Request,
    service: AuthService = Depends(get_auth_service),
    audit: AuditService = Depends(get_audit_service),
):
    ip = get_client_ip(request)
    if body.encrypted_payload:
        try:
            data = decrypt_login_payload(body.encrypted_payload)
            username = data.get("username", "")
            password = data.get("password", "")
        except Exception:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid encrypted payload",
            )
    else:
        username = body.username or ""
        password = body.password or ""
    token = service.login(username, password, ip)
    if not token:
        audit.log(
            "login_failed", "auth",
            details={"username": username},
            ip_address=ip,
            status="failure",
        )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    payload = decode_access_token(token)
    actor_id = int(payload["sub"]) if payload and "sub" in payload else None
    audit.log("login", "auth", actor_user_id=actor_id, entity_id=actor_id, details={"username": username}, ip_address=ip)
    return TokenResponse(access_token=token)


@router.post("/refresh", response_model=TokenResponse)
def refresh_token(
    current_user: User = Depends(get_current_user),
):
    """Issue a fresh token for an authenticated user who is still active."""
    token = build_user_token(current_user)
    return TokenResponse(access_token=token)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(
    request: Request,
    current_user: User = Depends(get_current_user),
    service: AuthService = Depends(get_auth_service),
    audit: AuditService = Depends(get_audit_service),
):
    ip = get_client_ip(request)
    service.logout(current_user.id, ip)
    audit.log("logout", "auth", actor_user_id=current_user.id, entity_id=current_user.id, ip_address=ip)


@router.post("/change-password", response_model=TokenResponse)
def change_password(
    body: ChangePasswordRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
    service: AuthService = Depends(get_auth_service),
    audit: AuditService = Depends(get_audit_service),
):
    ip = get_client_ip(request)
    token = service.change_password(current_user.id, body.current_password, body.new_password)
    if not token:
        audit.log("password_change_failed", "user", actor_user_id=current_user.id, entity_id=current_user.id, ip_address=ip, status="failure")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect",
        )
    audit.log("password_changed", "user", actor_user_id=current_user.id, entity_id=current_user.id, ip_address=ip)
    return TokenResponse(access_token=token)


@router.post("/forgot-password")
def forgot_password(
    body: ForgotPasswordRequest,
    request: Request,
    service: ResetService = Depends(get_reset_service),
    audit: AuditService = Depends(get_audit_service),
):
    ip = get_client_ip(request)
    try:
        result = service.request_otp_by_username(body.username)
    except ValueError as exc:
        audit.log("forgot_password_failed", "auth", details={"username": body.username, "error": str(exc)}, ip_address=ip, status="failure")
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))
    except Exception as exc:
        logger.exception("[forgot-password] Unexpected error: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Could not send OTP. Please try again later.",
        )
    audit.log("forgot_password", "auth", details={"username": body.username, "channel": "sms"}, ip_address=ip)
    return {"masked_mobile": result["masked_mobile"]}


@router.post("/reset-password", response_model=TokenResponse)
def reset_password(
    body: ResetPasswordRequest,
    request: Request,
    service: ResetService = Depends(get_reset_service),
    audit: AuditService = Depends(get_audit_service),
):
    ip = get_client_ip(request)
    if len(body.new_password) < 8:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Password must be at least 8 characters.")
    token = service.verify_and_reset(body.username, body.otp, body.new_password)
    if not token:
        audit.log("password_reset_failed", "auth", details={"username": body.username}, ip_address=ip, status="failure")
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired OTP. Please request a new one.",
        )
    payload = decode_access_token(token)
    actor_id = int(payload["sub"]) if payload and "sub" in payload else None
    audit.log("password_reset", "auth", actor_user_id=actor_id, entity_id=actor_id, details={"username": body.username}, ip_address=ip)
    return TokenResponse(access_token=token)


@router.get("/me", response_model=UserOut)
def get_me(current_user: User = Depends(get_current_user)):
    return current_user


# ── First-login mobile OTP flow ───────────────────────────────────────────────

@router.get("/first-login/status")
def first_login_status(
    current_user: User = Depends(get_current_user),
    user_repo: IUserRepository = Depends(get_user_repository),
):
    return {"mobile_verified": user_repo.get_mobile_verified(current_user.id)}


@router.post("/first-login/send-mobile-otp", response_model=FirstLoginOtpSentResponse)
def first_login_send_mobile_otp(
    request: Request,
    current_user: User = Depends(get_current_user),
    reset_svc: ResetService = Depends(get_reset_service),
    audit: AuditService = Depends(get_audit_service),
):
    ip = get_client_ip(request)
    if not current_user.mobile_number:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No mobile number registered for this account. Please contact the administrator.",
        )
    try:
        reset_svc.send_first_login_otp(current_user)
    except Exception as exc:
        logger.exception("[first-login/send-mobile-otp] %s", exc)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Could not send OTP. Please try again later.",
        )
    audit.log("first_login_otp_sent", "auth", actor_user_id=current_user.id, entity_id=current_user.id, ip_address=ip)
    masked = _mask_mobile(current_user.mobile_number)
    return FirstLoginOtpSentResponse(
        masked_mobile=masked,
        message=f"OTP sent to {masked}",
    )


@router.post("/first-login/verify-mobile-otp", response_model=TokenResponse)
def first_login_verify_mobile_otp(
    body: FirstLoginVerifyOtpRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
    reset_svc: ResetService = Depends(get_reset_service),
    user_repo: IUserRepository = Depends(get_user_repository),
    audit: AuditService = Depends(get_audit_service),
):
    ip = get_client_ip(request)
    if not current_user.mobile_number:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="No mobile number on record.")

    otp_hash = hashlib.sha256(body.otp.encode()).hexdigest()
    record = reset_svc._otp_repo.get_valid(current_user.id)
    if not record or record["otp_hash"] != otp_hash:
        audit.log("first_login_otp_verify_failed", "auth", actor_user_id=current_user.id, entity_id=current_user.id, ip_address=ip, status="failure")
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid or expired OTP.")

    reset_svc._otp_repo.mark_used(record["id"])
    user_repo.set_mobile_verified(current_user.id, True)

    # Fetch fresh user and build token with mobile_verified=True
    user = user_repo.get_by_id(current_user.id)
    user.mobile_verified = True
    token = build_user_token(user)

    audit.log("first_login_mobile_verified", "auth", actor_user_id=current_user.id, entity_id=current_user.id, ip_address=ip)
    return TokenResponse(access_token=token)


@router.post("/first-login/reset-password", response_model=TokenResponse)
def first_login_reset_password(
    body: FirstLoginResetRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
    user_repo: IUserRepository = Depends(get_user_repository),
    audit: AuditService = Depends(get_audit_service),
):
    ip = get_client_ip(request)

    # Re-check mobile_verified directly from DB to prevent bypass
    # (sp_get_user_by_id may not return mobile_verified, so we query it directly)
    if not user_repo.get_mobile_verified(current_user.id):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Mobile number must be verified before resetting your password.",
        )
    if len(body.new_password) < 8:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Password must be at least 8 characters.")

    user_repo.change_password(current_user.id, hash_password(body.new_password))

    user = user_repo.get_by_id(current_user.id)
    user.mobile_verified = True
    token = build_user_token(user)

    audit.log("first_login_password_reset", "user", actor_user_id=current_user.id, entity_id=current_user.id, ip_address=ip)
    return TokenResponse(access_token=token)


def _mask_mobile(mobile: str) -> str:
    mobile = mobile.strip()
    if len(mobile) <= 4:
        return mobile
    return mobile[:2] + "x" * (len(mobile) - 4) + mobile[-2:]


def _mask_identifier(identifier: str) -> str:
    if "@" in identifier:
        local, domain = identifier.split("@", 1)
        return local[:2] + "***@" + domain
    return identifier[:3] + "****" + identifier[-2:]
