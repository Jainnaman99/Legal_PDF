import logging

from fastapi import APIRouter, Depends, HTTPException, Request, status

from app.core.dependencies import get_admin_auth_service, get_audit_service, get_current_user
from app.core.security import decode_access_token
from app.models.user import User
from app.schemas.auth import AdminOtpRequest, AdminOtpVerifyRequest, AdminCompleteLoginRequest, AdminSwitchDeptRequest, TokenResponse
from app.services.admin_auth_service import AdminAuthService
from app.services.audit_service import AuditService
from app.utils.request_utils import get_client_ip

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/admin/auth", tags=["Admin Authentication"])


@router.post("/request-otp", status_code=status.HTTP_200_OK)
def request_admin_otp(
    body: AdminOtpRequest,
    request: Request,
    service: AdminAuthService = Depends(get_admin_auth_service),
    audit: AuditService = Depends(get_audit_service),
):
    ip = get_client_ip(request)
    try:
        otp, sms_response = service.request_otp(body.mobile_number)
    except ValueError as exc:
        audit.log(
            "admin_otp_request_failed", "auth",
            details={"mobile": body.mobile_number, "error": str(exc)},
            ip_address=ip,
            status="failure",
        )
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))
    except Exception as exc:
        logger.exception("[admin/request-otp] Unexpected error: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Could not send OTP. Please try again later.",
        )
    audit.log("admin_otp_requested", "auth", details={"mobile": body.mobile_number}, ip_address=ip)
    return {
        "message": "OTP generated. Valid for 10 minutes.",
        "sms_response": sms_response,
        # TODO: remove once real SMS delivery is confirmed in production
        "otp": otp,
    }


@router.post("/verify-otp", status_code=status.HTTP_200_OK)
def verify_admin_otp(
    body: AdminOtpVerifyRequest,
    request: Request,
    service: AdminAuthService = Depends(get_admin_auth_service),
    audit: AuditService = Depends(get_audit_service),
):
    """
    Validates the OTP. On success returns the departments linked to this mobile
    number so the user can pick one. The OTP is NOT consumed here — call
    /select-department with the same OTP to complete login.
    """
    ip = get_client_ip(request)
    departments = service.verify_otp(body.mobile_number, body.otp)
    if departments is None:
        audit.log(
            "admin_otp_verify_failed", "auth",
            details={"mobile": body.mobile_number},
            ip_address=ip,
            status="failure",
        )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired OTP.",
        )
    audit.log("admin_otp_verified", "auth", details={"mobile": body.mobile_number}, ip_address=ip)
    return {"departments": departments}


@router.post("/select-department", response_model=TokenResponse)
def select_department(
    body: AdminCompleteLoginRequest,
    request: Request,
    service: AdminAuthService = Depends(get_admin_auth_service),
    audit: AuditService = Depends(get_audit_service),
):
    """
    Final login step: re-verifies the OTP for the specific (mobile, department_id)
    user, marks it as used, and returns a JWT access token.
    """
    ip = get_client_ip(request)
    token = service.complete_login(body.mobile_number, body.otp, body.department_id)
    if not token:
        audit.log(
            "admin_login_failed", "auth",
            details={"mobile": body.mobile_number, "department_id": body.department_id},
            ip_address=ip,
            status="failure",
        )
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired OTP, or department not linked to this account.",
        )
    payload = decode_access_token(token)
    actor_id = int(payload["sub"]) if payload and "sub" in payload else None
    audit.log(
        "admin_login", "auth",
        actor_user_id=actor_id, entity_id=actor_id,
        details={"mobile": body.mobile_number, "department_id": body.department_id},
        ip_address=ip,
    )
    return TokenResponse(access_token=token)


@router.post("/switch-department", response_model=TokenResponse)
def switch_department(
    body: AdminSwitchDeptRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
    service: AdminAuthService = Depends(get_admin_auth_service),
    audit: AuditService = Depends(get_audit_service),
):
    """
    Authenticated admin/super_admin switches to a different department linked to
    the same mobile number.  Returns a new JWT for the target department account.
    No OTP is required since the caller is already authenticated.
    """
    ip = get_client_ip(request)
    mobile = getattr(current_user, "mobile_number", None)
    if not mobile:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="No mobile number associated with this account.",
        )
    token = service.switch_department(mobile, body.department_id)
    if not token:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Department not linked to this mobile account, or account is inactive.",
        )
    payload = decode_access_token(token)
    actor_id = int(payload["sub"]) if payload and "sub" in payload else None
    audit.log(
        "admin_dept_switch", "auth",
        actor_user_id=actor_id, entity_id=actor_id,
        details={"from_user_id": current_user.id, "to_department_id": body.department_id},
        ip_address=ip,
    )
    return TokenResponse(access_token=token)
