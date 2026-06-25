from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.interfaces.department_repository import IDepartmentRepository
from app.interfaces.document_type_repository import IDocumentTypeRepository
from app.interfaces.login_log_repository import ILoginLogRepository
from app.interfaces.pdf_page_repository import IPDFPageRepository
from app.interfaces.pdf_repository import IPDFRepository
from app.interfaces.role_repository import IRoleRepository
from app.interfaces.tag_repository import ITagRepository
from app.interfaces.user_repository import IUserRepository
from app.models.user import User
from app.repositories.department_repository import DepartmentRepository
from app.repositories.document_type_repository import DocumentTypeRepository
from app.repositories.login_log_repository import LoginLogRepository
from app.repositories.pdf_page_repository import PDFPageRepository
from app.repositories.pdf_repository import PDFRepository
from app.repositories.role_repository import RoleRepository
from app.repositories.tag_repository import TagRepository
from app.repositories.user_repository import UserRepository
from app.services.auth_service import AuthService
from app.services.department_service import DepartmentService
from app.services.pdf_service import PDFService
from app.services.role_service import RoleService

bearer_scheme = HTTPBearer()


def get_user_repository(db: Session = Depends(get_db)) -> IUserRepository:
    return UserRepository(db)


def get_pdf_repository(db: Session = Depends(get_db)) -> IPDFRepository:
    return PDFRepository(db)


def get_pdf_page_repository(db: Session = Depends(get_db)) -> IPDFPageRepository:
    return PDFPageRepository(db)


def get_department_repository(db: Session = Depends(get_db)) -> IDepartmentRepository:
    return DepartmentRepository(db)


def get_login_log_repository(db: Session = Depends(get_db)) -> ILoginLogRepository:
    return LoginLogRepository(db)


def get_auth_service(
    repo: IUserRepository = Depends(get_user_repository),
    log_repo: ILoginLogRepository = Depends(get_login_log_repository),
) -> AuthService:
    return AuthService(repo, log_repo)


def get_document_type_repository(db: Session = Depends(get_db)) -> IDocumentTypeRepository:
    return DocumentTypeRepository(db)


def get_tag_repository(db: Session = Depends(get_db)) -> ITagRepository:
    return TagRepository(db)


def get_pdf_service(
    repo: IPDFRepository = Depends(get_pdf_repository),
    page_repo: IPDFPageRepository = Depends(get_pdf_page_repository),
    tag_repo: ITagRepository = Depends(get_tag_repository),
) -> PDFService:
    return PDFService(repo, page_repo, tag_repo)


def get_role_repository(db: Session = Depends(get_db)) -> IRoleRepository:
    return RoleRepository(db)


def get_department_service(
    repo: IDepartmentRepository = Depends(get_department_repository),
) -> DepartmentService:
    return DepartmentService(repo)


def get_role_service(
    repo: IRoleRepository = Depends(get_role_repository),
) -> RoleService:
    return RoleService(repo)


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


def require_roles(*roles: str):
    """
    Dependency factory for role-based access control.

    Usage:
        current_user: User = Depends(require_roles("super_admin", "admin"))
    """
    def _check(current_user: User = Depends(get_current_user)) -> User:
        user_role = current_user.role.name if current_user.role else None
        if user_role not in roles:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access denied. Required role(s): {', '.join(roles)}",
            )
        return current_user
    return _check
