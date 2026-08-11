from fastapi import APIRouter

from app.api.v1 import act_parts, act_structure, admin_auth, audit, auth, cap_requests, department, dept_role_limits, document_type, pdf, role, tag, user

router = APIRouter(prefix="/api/v1")
router.include_router(auth.router)
router.include_router(admin_auth.router)
router.include_router(audit.router)
router.include_router(role.router)
router.include_router(department.router)
router.include_router(document_type.router)
router.include_router(tag.router)
router.include_router(user.router)
router.include_router(pdf.router)
router.include_router(act_structure.router)
router.include_router(act_parts.router)
router.include_router(dept_role_limits.router)
router.include_router(cap_requests.router)
