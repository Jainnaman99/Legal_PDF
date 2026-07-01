import logging

from fastapi import APIRouter, Depends, HTTPException, Request, status

logger = logging.getLogger(__name__)

from app.core.dependencies import get_auth_service, get_current_user, get_reset_service
from app.models.user import User
from app.schemas.auth import (
    ChangePasswordRequest,
    ForgotPasswordRequest,
    LoginRequest,
    ResetPasswordRequest,
    TokenResponse,
    UserCreate,
    UserOut,
)
from app.services.auth_service import AuthService
from app.services.reset_service import ResetService

router = APIRouter(prefix="/auth", tags=["Authentication"])


def _client_ip(request: Request) -> str | None:
    forwarded = request.headers.get("X-Forwarded-For")
    if forwarded:
        return forwarded.split(",")[0].strip()
    return request.client.host if request.client else None


@router.post("/register", response_model=UserOut, status_code=status.HTTP_201_CREATED)
def register(
    body: UserCreate,
    service: AuthService = Depends(get_auth_service),
):
    try:
        user = service.register(
            body.username, body.email, body.password,
            body.first_name, body.last_name,
            body.role_id, body.department_id,
        )
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(e))
    return user


@router.post("/login", response_model=TokenResponse)
def login(
    body: LoginRequest,
    request: Request,
    service: AuthService = Depends(get_auth_service),
):
    token = service.login(body.username, body.password, _client_ip(request))
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return TokenResponse(access_token=token)


@router.post("/logout", status_code=status.HTTP_204_NO_CONTENT)
def logout(
    request: Request,
    current_user: User = Depends(get_current_user),
    service: AuthService = Depends(get_auth_service),
):
    service.logout(current_user.id, _client_ip(request))


@router.post("/change-password", response_model=TokenResponse)
def change_password(
    body: ChangePasswordRequest,
    current_user: User = Depends(get_current_user),
    service: AuthService = Depends(get_auth_service),
):
    token = service.change_password(current_user.id, body.current_password, body.new_password)
    if not token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect",
        )
    return TokenResponse(access_token=token)


@router.post("/forgot-password")
def forgot_password(
    body: ForgotPasswordRequest,
    service: ResetService = Depends(get_reset_service),
):
    try:
        channel = service.request_otp(body.identifier)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc))
    except Exception as exc:
        logger.exception("[forgot-password] Unexpected error: %s", exc)
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Could not send OTP. Please try again later.",
        )
    masked = _mask_identifier(body.identifier)
    return {"message": f"OTP sent to your {channel} ({masked})", "channel": channel}


@router.post("/reset-password", response_model=TokenResponse)
def reset_password(
    body: ResetPasswordRequest,
    service: ResetService = Depends(get_reset_service),
):
    if len(body.new_password) < 8:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Password must be at least 8 characters.")
    token = service.verify_and_reset(body.identifier, body.otp, body.new_password)
    if not token:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid or expired OTP. Please request a new one.",
        )
    return TokenResponse(access_token=token)


def _mask_identifier(identifier: str) -> str:
    if "@" in identifier:
        local, domain = identifier.split("@", 1)
        return local[:2] + "***@" + domain
    return identifier[:3] + "****" + identifier[-2:]


@router.get("/me", response_model=UserOut)
def get_me(current_user: User = Depends(get_current_user)):
    return current_user
