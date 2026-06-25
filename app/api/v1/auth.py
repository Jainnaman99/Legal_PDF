from fastapi import APIRouter, Depends, HTTPException, status

from app.core.dependencies import get_auth_service, get_current_user
from app.models.user import User
from app.schemas.auth import LoginRequest, TokenResponse, UserCreate, UserOut
from app.services.auth_service import AuthService

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post("/register", response_model=UserOut, status_code=status.HTTP_201_CREATED)
def register(
    body: UserCreate,
    service: AuthService = Depends(get_auth_service),
):
    try:
        user = service.register(body.username, body.email, body.password, body.role_id, body.department_id)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail=str(e))
    return user


@router.post("/login", response_model=TokenResponse)
def login(
    body: LoginRequest,
    service: AuthService = Depends(get_auth_service),
):
    token = service.login(body.username, body.password)
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return TokenResponse(access_token=token)


@router.get("/me", response_model=UserOut)
def get_me(current_user: User = Depends(get_current_user)):
    return current_user
