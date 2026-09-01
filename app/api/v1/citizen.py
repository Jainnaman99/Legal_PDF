from typing import Optional

from fastapi import APIRouter, Depends, Query

from app.core.dependencies import get_department_service, get_pdf_service
from app.schemas.auth import DepartmentOut
from app.schemas.pdf import PDFListResponse, PDFListItem
from app.services.department_service import DepartmentService
from app.services.pdf_service import PDFService

router = APIRouter(prefix="/citizen", tags=["Citizen Portal"])


@router.get(
    "/recent-documents",
    response_model=list[PDFListItem],
    summary="Top 5 recently approved documents — no token required",
)
def recent_documents(
    service: PDFService = Depends(get_pdf_service),
):
    docs = service.citizen_recent_documents(limit=5)
    return [PDFListItem.model_validate(d) for d in docs]


@router.get(
    "/documents",
    response_model=PDFListResponse,
    summary="List approved documents — no token required",
)
def list_approved_documents(
    department_id:    Optional[int] = Query(None, description="Filter by department ID. Omit for all departments."),
    document_type_id: Optional[int] = Query(None, description="Filter by document type ID. Omit for all types."),
    skip:  int = Query(0,  ge=0,  description="Number of records to skip (pagination)"),
    limit: int = Query(20, ge=1, le=100, description="Maximum records to return"),
    service: PDFService = Depends(get_pdf_service),
):
    total, docs = service.citizen_list_documents(department_id, document_type_id, skip, limit)
    return PDFListResponse(
        total=total,
        documents=[PDFListItem.model_validate(d) for d in docs],
    )


@router.get(
    "/departments",
    response_model=list[DepartmentOut],
    summary="List all active departments — no token required",
)
def list_departments_public(
    service: DepartmentService = Depends(get_department_service),
):
    return service.list_all(skip=0, limit=500)
