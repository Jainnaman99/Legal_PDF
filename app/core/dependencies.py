from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.interfaces.pdf_page_repository import IPDFPageRepository
from app.interfaces.pdf_repository import IPDFRepository
from app.interfaces.user_repository import IUserRepository
from app.models.user import User
from app.repositories.pdf_page_repository import PDFPageRepository
from app.repositories.pdf_repository import PDFRepository
from app.repositories.user_repository import UserRepository
from app.services.auth_service import AuthService
from app.services.pdf_service import PDFService

bearer_scheme = HTTPBearer()


def get_user_repository(db: Session = Depends(get_db)) -> IUserRepository:
    return UserRepository(db)


def get_pdf_repository(db: Session = Depends(get_db)) -> IPDFRepository:
    return PDFRepository(db)


def get_pdf_page_repository(db: Session = Depends(get_db)) -> IPDFPageRepository:
    return PDFPageRepository(db)


def get_auth_service(repo: IUserRepository = Depends(get_user_repository)) -> AuthService:
    return AuthService(repo)


def get_pdf_service(
    repo: IPDFRepository = Depends(get_pdf_repository),
    page_repo: IPDFPageRepository = Depends(get_pdf_page_repository),
) -> PDFService:
    return PDFService(repo, page_repo)


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer_scheme),
    service: AuthService = Depends(get_auth_service),
) -> User:
    user = service.get_current_user(credentials.credentials)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired token",
            headers={"WWW-Authenticate": "Bearer"},
        )
    return user
