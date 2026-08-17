
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.orm import Session

from app.db.session import get_db, set_audit_user_id
from app.interfaces.act_parts_repository import IActPartsRepository
from app.interfaces.cap_request_repository import ICapRequestRepository
from app.interfaces.dept_role_limit_repository import IDeptRoleLimitRepository
from app.interfaces.act_structure_repository import IActStructureRepository
from app.interfaces.admin_otp_repository import IAdminOtpRepository
from app.interfaces.audit_log_repository import IAuditLogRepository
from app.interfaces.department_repository import IDepartmentRepository
from app.interfaces.document_type_repository import IDocumentTypeRepository
from app.interfaces.login_log_repository import ILoginLogRepository
from app.interfaces.pdf_approval_repository import IPDFApprovalRepository
from app.interfaces.pdf_page_repository import IPDFPageRepository
from app.interfaces.pdf_repository import IPDFRepository
from app.interfaces.reset_otp_repository import IResetOtpRepository
from app.interfaces.role_repository import IRoleRepository
from app.interfaces.tag_repository import ITagRepository
from app.interfaces.user_repository import IUserRepository
from app.models.user import User
from app.repositories.act_parts_repository import ActPartsRepository
from app.repositories.cap_request_repository import CapRequestRepository
from app.repositories.dept_role_limit_repository import DeptRoleLimitRepository
from app.repositories.act_structure_repository import ActStructureRepository
from app.repositories.admin_otp_repository import AdminOtpRepository
from app.repositories.audit_log_repository import AuditLogRepository
from app.repositories.department_repository import DepartmentRepository
from app.repositories.document_type_repository import DocumentTypeRepository
from app.repositories.login_log_repository import LoginLogRepository
from app.repositories.pdf_approval_repository import PDFApprovalRepository
from app.repositories.pdf_page_repository import PDFPageRepository
from app.repositories.pdf_repository import PDFRepository
from app.repositories.reset_otp_repository import ResetOtpRepository
from app.repositories.role_repository import RoleRepository
from app.repositories.tag_repository import TagRepository
from app.repositories.user_repository import UserRepository
from app.services.act_parts_service import ActPartsService
from app.services.act_structure_service import ActStructureService
from app.services.admin_auth_service import AdminAuthService
from app.services.audit_service import AuditService
from app.services.auth_service import AuthService
from app.services.sms_service import SmsService
from app.services.department_service import DepartmentService
from app.services.email_service import EmailService
from app.services.pdf_service import PDFService
from app.services.rag_service import RAGService
from app.services.reset_service import ResetService
from app.services.role_service import RoleService
from app.services.sms_service import SmsService
from app.services.vector_store_service import VectorStoreService

bearer_scheme = HTTPBearer()


def get_user_repository(db: Session = Depends(get_db)) -> IUserRepository:
    return UserRepository(db)


def get_audit_log_repository(db: Session = Depends(get_db)) -> IAuditLogRepository:
    return AuditLogRepository(db)


def get_audit_service(
    repo: IAuditLogRepository = Depends(get_audit_log_repository),
) -> AuditService:
    return AuditService(repo)


def get_admin_otp_repository(db: Session = Depends(get_db)) -> IAdminOtpRepository:
    return AdminOtpRepository(db)


def get_admin_auth_service(
    user_repo: IUserRepository = Depends(get_user_repository),
    otp_repo: IAdminOtpRepository = Depends(get_admin_otp_repository),
) -> AdminAuthService:
    return AdminAuthService(user_repo, otp_repo, SmsService())


def get_pdf_repository(db: Session = Depends(get_db)) -> IPDFRepository:
    return PDFRepository(db)


def get_pdf_page_repository(db: Session = Depends(get_db)) -> IPDFPageRepository:
    return PDFPageRepository(db)


def get_department_repository(db: Session = Depends(get_db)) -> IDepartmentRepository:
    return DepartmentRepository(db)


def get_login_log_repository(db: Session = Depends(get_db)) -> ILoginLogRepository:
    return LoginLogRepository(db)


def get_dept_role_limit_repository(db: Session = Depends(get_db)) -> IDeptRoleLimitRepository:
    return DeptRoleLimitRepository(db)


def get_cap_request_repository(db: Session = Depends(get_db)) -> ICapRequestRepository:
    return CapRequestRepository(db)


def get_auth_service(
    repo: IUserRepository = Depends(get_user_repository),
    log_repo: ILoginLogRepository = Depends(get_login_log_repository),
    limit_repo: IDeptRoleLimitRepository = Depends(get_dept_role_limit_repository),
) -> AuthService:
    return AuthService(repo, log_repo, limit_repo)


def get_document_type_repository(db: Session = Depends(get_db)) -> IDocumentTypeRepository:
    return DocumentTypeRepository(db)


def get_tag_repository(db: Session = Depends(get_db)) -> ITagRepository:
    return TagRepository(db)


def get_pdf_approval_repository(db: Session = Depends(get_db)) -> IPDFApprovalRepository:
    return PDFApprovalRepository(db)


_vs_instance: "VectorStoreService | None" = None
_vs_tried = False


def _get_vector_store() -> "VectorStoreService | None":
    global _vs_instance, _vs_tried
    if not _vs_tried:
        try:
            _vs_instance = VectorStoreService()
        except Exception:
            _vs_instance = None
        _vs_tried = True
    return _vs_instance


def get_rag_service() -> RAGService:
    return RAGService(_get_vector_store())


def get_pdf_service(
    repo: IPDFRepository = Depends(get_pdf_repository),
    page_repo: IPDFPageRepository = Depends(get_pdf_page_repository),
    tag_repo: ITagRepository = Depends(get_tag_repository),
    approval_repo: IPDFApprovalRepository = Depends(get_pdf_approval_repository),
) -> PDFService:
    return PDFService(repo, page_repo, tag_repo, approval_repo, _get_vector_store())


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


def get_reset_otp_repository(db: Session = Depends(get_db)) -> IResetOtpRepository:
    return ResetOtpRepository(db)


def get_reset_service(
    user_repo: IUserRepository = Depends(get_user_repository),
    otp_repo: IResetOtpRepository = Depends(get_reset_otp_repository),
) -> ResetService:
    return ResetService(user_repo, otp_repo, EmailService(), SmsService())


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
    set_audit_user_id(user.id)
    return user


def require_roles(*roles: str):
    """
    Dependency factory for role-based access control.

    Usage:
        current_user: User = Depends(require_roles("super Admin", "admin"))
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


def get_act_parts_service(db: Session = Depends(get_db)) -> ActPartsService:
    return ActPartsService(ActPartsRepository(db))


def get_act_structure_repository(db: Session = Depends(get_db)) -> IActStructureRepository:
    return ActStructureRepository(db)


def get_act_structure_service(
    repo: IActStructureRepository = Depends(get_act_structure_repository),
) -> ActStructureService:
    return ActStructureService(repo)
