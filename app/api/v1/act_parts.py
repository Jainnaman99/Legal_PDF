import os

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile, status
from fastapi.responses import FileResponse

from app.core.dependencies import get_act_parts_service, get_current_user
from app.models.user import User
from app.schemas.act_parts import (
    ActPartFileUploadResponse,
    AllActPartsResponse,
    EntryOut,
    SaveEntriesRequest,
    SaveSectionsRequest,
    SectionsResponse,
)
from app.core.config import settings
from app.services.act_parts_service import ActPartsService, _ACT_PARTS_SUBDIR

router = APIRouter(prefix="/act-parts", tags=["Act Parts"])

_FLAT_TYPES = {"schedule", "annexure", "appendix", "forms"}


@router.post(
    "/upload-file",
    response_model=ActPartFileUploadResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Upload a file for any act part (section / schedule / annexure / appendix / form)",
)
async def upload_file(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    service: ActPartsService = Depends(get_act_parts_service),
):
    content = await file.read()
    if not content:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Uploaded file is empty")
    return service.store_file(file.filename or "upload", content)


_MIME = {
    ".pdf":  "application/pdf",
    ".doc":  "application/msword",
    ".docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
}


@router.get(
    "/file/{file_ref}",
    summary="Serve an uploaded act-part file inline (opens in browser)",
)
def serve_file(
    file_ref: str,
    current_user: User = Depends(get_current_user),
):
    # Reject any path traversal attempts
    if "/" in file_ref or "\\" in file_ref or ".." in file_ref:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="Invalid file reference")
    file_path = os.path.join(settings.UPLOAD_DIR, _ACT_PARTS_SUBDIR, file_ref)
    if not os.path.exists(file_path):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="File not found")
    ext = os.path.splitext(file_ref)[1].lower()
    media_type = _MIME.get(ext, "application/octet-stream")
    return FileResponse(
        file_path,
        media_type=media_type,
        headers={"Content-Disposition": "inline"},
    )


@router.post(
    "/{pdf_document_id}/sections",
    response_model=SectionsResponse,
    status_code=status.HTTP_200_OK,
    summary="Save all sections for an Act (replaces existing)",
)
def save_sections(
    pdf_document_id: int,
    body: SaveSectionsRequest,
    current_user: User = Depends(get_current_user),
    service: ActPartsService = Depends(get_act_parts_service),
):
    try:
        return service.save_sections(pdf_document_id, current_user.id, body)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc))


@router.get(
    "/{pdf_document_id}/sections",
    response_model=SectionsResponse,
    summary="Get sections for an Act",
)
def get_sections(
    pdf_document_id: int,
    service: ActPartsService = Depends(get_act_parts_service),
):
    return service.get_sections(pdf_document_id)


@router.post(
    "/{pdf_document_id}/schedules",
    response_model=list[EntryOut],
    status_code=status.HTTP_200_OK,
    summary="Save schedule entries for an Act (replaces existing)",
)
def save_schedules(
    pdf_document_id: int,
    body: SaveEntriesRequest,
    current_user: User = Depends(get_current_user),
    service: ActPartsService = Depends(get_act_parts_service),
):
    return service.save_entries("schedule", pdf_document_id, current_user.id, body)


@router.get("/{pdf_document_id}/schedules", response_model=list[EntryOut], summary="Get schedule entries")
def get_schedules(pdf_document_id: int, service: ActPartsService = Depends(get_act_parts_service)):
    return service.get_entries("schedule", pdf_document_id)


@router.post(
    "/{pdf_document_id}/annexures",
    response_model=list[EntryOut],
    status_code=status.HTTP_200_OK,
    summary="Save annexure entries for an Act (replaces existing)",
)
def save_annexures(
    pdf_document_id: int,
    body: SaveEntriesRequest,
    current_user: User = Depends(get_current_user),
    service: ActPartsService = Depends(get_act_parts_service),
):
    return service.save_entries("annexure", pdf_document_id, current_user.id, body)


@router.get("/{pdf_document_id}/annexures", response_model=list[EntryOut], summary="Get annexure entries")
def get_annexures(pdf_document_id: int, service: ActPartsService = Depends(get_act_parts_service)):
    return service.get_entries("annexure", pdf_document_id)


@router.post(
    "/{pdf_document_id}/appendices",
    response_model=list[EntryOut],
    status_code=status.HTTP_200_OK,
    summary="Save appendix entries for an Act (replaces existing)",
)
def save_appendices(
    pdf_document_id: int,
    body: SaveEntriesRequest,
    current_user: User = Depends(get_current_user),
    service: ActPartsService = Depends(get_act_parts_service),
):
    return service.save_entries("appendix", pdf_document_id, current_user.id, body)


@router.get("/{pdf_document_id}/appendices", response_model=list[EntryOut], summary="Get appendix entries")
def get_appendices(pdf_document_id: int, service: ActPartsService = Depends(get_act_parts_service)):
    return service.get_entries("appendix", pdf_document_id)


@router.post(
    "/{pdf_document_id}/forms",
    response_model=list[EntryOut],
    status_code=status.HTTP_200_OK,
    summary="Save form entries for an Act (replaces existing)",
)
def save_forms(
    pdf_document_id: int,
    body: SaveEntriesRequest,
    current_user: User = Depends(get_current_user),
    service: ActPartsService = Depends(get_act_parts_service),
):
    return service.save_entries("forms", pdf_document_id, current_user.id, body)


@router.get("/{pdf_document_id}/forms", response_model=list[EntryOut], summary="Get form entries")
def get_forms(pdf_document_id: int, service: ActPartsService = Depends(get_act_parts_service)):
    return service.get_entries("forms", pdf_document_id)


@router.get(
    "/{pdf_document_id}",
    response_model=AllActPartsResponse,
    summary="Get ALL parts for an Act (sections + schedules + annexures + appendices + forms)",
)
def get_all_parts(
    pdf_document_id: int,
    service: ActPartsService = Depends(get_act_parts_service),
):
    return service.get_all_parts(pdf_document_id)
