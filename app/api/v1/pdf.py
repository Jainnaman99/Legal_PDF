from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, UploadFile, File, Form, status

from app.core.dependencies import get_current_user, get_pdf_service
from app.models.user import User
from app.schemas.pdf import PDFListItem, PDFUploadResponse
from app.services.pdf_service import PDFService

router = APIRouter(prefix="/pdf", tags=["PDF Documents"])

ALLOWED_CONTENT_TYPES = {"application/pdf"}


@router.post("/upload", response_model=PDFUploadResponse, status_code=status.HTTP_201_CREATED)
async def upload_pdf(
    file: UploadFile = File(...),
    description: Optional[str] = Form(None),
    current_user: User = Depends(get_current_user),
    service: PDFService = Depends(get_pdf_service),
):
    if file.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only PDF files are allowed",
        )
    doc = await service.upload(file, current_user.id, description)
    return doc


@router.get("/my-documents", response_model=list[PDFListItem])
def list_my_documents(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    service: PDFService = Depends(get_pdf_service),
):
    return service.list_my_documents(current_user.id, skip, limit)


@router.get("/all", response_model=list[PDFListItem])
def list_all_documents(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    service: PDFService = Depends(get_pdf_service),
):
    return service.list_all_documents(skip, limit)
