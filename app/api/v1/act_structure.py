from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile, status

from app.core.dependencies import get_act_structure_service, get_current_user
from app.models.user import User
from app.schemas.act_structure import (
    ActStructureOut,
    ActStructureSummary,
    AvailableActItem,
)
from app.services.act_structure_service import ActStructureService

router = APIRouter(prefix="/act-structure", tags=["Act Structure"])


@router.get(
    "/available-acts",
    response_model=list[AvailableActItem],
    summary="List approved ACT documents for dropdown (no auth required)",
)
def available_acts(
    q: str = Query("", description="Optional partial name filter"),
    service: ActStructureService = Depends(get_act_structure_service),
):
    return service.list_available_acts(q)


@router.post(
    "/upload-and-analyze",
    response_model=ActStructureOut,
    status_code=status.HTTP_201_CREATED,
    summary="Upload a PDF/Word file and extract Act structure (chapters, sections, schedules)",
)
async def upload_and_analyze(
    file: UploadFile = File(..., description="PDF or Word (.docx) file of the Act"),
    pdf_document_id: int = Form(
        ..., description="ID of the existing ACT document selected from the dropdown"
    ),
    current_user: User = Depends(get_current_user),
    service: ActStructureService = Depends(get_act_structure_service),
):
    contents = await file.read()
    if not contents:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST, detail="Uploaded file is empty"
        )
    try:
        return service.upload_and_analyze(pdf_document_id, file.filename or "", contents)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc))


@router.get(
    "/by-document/{pdf_document_id}",
    response_model=ActStructureOut,
    summary="Get extracted Act structure by PDF document ID",
)
def get_by_document(
    pdf_document_id: int,
    service: ActStructureService = Depends(get_act_structure_service),
):
    result = service.get_by_document(pdf_document_id)
    if not result:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Act structure not found for this document"
        )
    return result


@router.get(
    "/",
    response_model=list[ActStructureSummary],
    summary="List all analyzed Act structures (summaries)",
)
def list_structures(
    service: ActStructureService = Depends(get_act_structure_service),
):
    return service.list_all()


@router.get(
    "/{structure_id}",
    response_model=ActStructureOut,
    summary="Get full Act structure by ID (nested: chapters + sections + schedules)",
)
def get_structure(
    structure_id: int,
    service: ActStructureService = Depends(get_act_structure_service),
):
    result = service.get_by_id(structure_id)
    if not result:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")
    return result
