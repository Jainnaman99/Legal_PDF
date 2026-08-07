import os
from typing import Optional

from fastapi import APIRouter, Depends, File, HTTPException, Query, Request, UploadFile, status
from fastapi.responses import FileResponse

from app.core.config import settings
from app.core.dependencies import get_act_parts_service, get_audit_service, get_current_user, get_pdf_service, get_rag_service, require_roles
from app.models.user import User
from app.schemas.audit import AuditLogOut
from app.schemas.pdf import (
    ActChildDocument,
    ActChildrenResponse,
    ActFullDetailResponse,
    AllDepartmentLinkItem,
    DepartmentLinkItem,
    DocumentNameItem,
    DocumentNameSearchResponse,
    DuplicateCheckItem,
    FileUploadResponse,
    LinkDocumentRequest,
    LinkReviewRequest,
    LinkedDocumentItem,
    PDFCreateRequest,
    PDFListResponse,
    PDFReviewRequest,
    PDFUpdateRequest,
    PDFUploadResponse,
    SearchResponse,
    SearchResultItem,
)
from app.schemas.semantic_search import SemanticSearchResponse
from app.repositories.pdf_repository import PDFRepository
from app.services.act_parts_service import ActPartsService
from app.services.audit_service import AuditService
from app.services.pdf_service import PDFService
from app.services.rag_service import RAGService
from app.utils.request_utils import get_client_ip

router = APIRouter(prefix="/pdf", tags=["PDF Documents"])

ALLOWED_CONTENT_TYPES = {
    "application/pdf",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
}

_approver_roles = require_roles("approver", "admin", "super Admin")


@router.post(
    "/upload-file",
    response_model=FileUploadResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Step 1 — Upload the PDF binary, receive a file_ref",
)
async def upload_file(
    request: Request,
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    service: PDFService = Depends(get_pdf_service),
    audit: AuditService = Depends(get_audit_service),
):
    if file.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Only PDF and Word (.docx) files are allowed",
        )
    try:
        result = await service.store_file(file)
    except ValueError as exc:
        raise HTTPException(status_code=status.HTTP_422_UNPROCESSABLE_ENTITY, detail=str(exc))
    audit.log(
        "pdf_uploaded", "pdf",
        actor_user_id=current_user.id,
        details={"original_filename": result.original_filename, "file_size": result.file_size, "file_ref": result.file_ref},
        ip_address=get_client_ip(request),
    )
    return result


@router.post(
    "/upload",
    response_model=PDFUploadResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Step 2 — Submit metadata with the file_ref from Step 1",
)
def create_document(
    body: PDFCreateRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
    service: PDFService = Depends(get_pdf_service),
    audit: AuditService = Depends(get_audit_service),
):
    try:
        doc = service.create_from_ref(
            file_ref=body.file_ref,
            user_id=current_user.id,
            department_id=current_user.department_id,
            document_type_id=body.document_type_id,
            document_name=body.document_name,
            issue_date=body.issue_date,
            reference_number=body.reference_number,
            effective_from=body.effective_from,
            gazette_reference=body.gazette_reference,
            legal_authority=body.legal_authority,
            short_title=body.short_title,
            valid_until=body.valid_until,
            sector_domain=body.sector_domain,
            implementing_agency=body.implementing_agency,
            next_review_date=body.next_review_date,
            rule_making_authority=body.rule_making_authority,
            version_no=body.version_no,
            tag_ids=body.tag_ids,
            relationships=body.relationships,
            description=body.description,
            act_year=body.act_year,
            long_title=body.long_title,
            regional_title=body.regional_title,
            notification_no=body.notification_no,
            act_code=body.act_code,
            so_reason=body.so_reason,
            no_of_rules=body.no_of_rules,
            no_of_notifications=body.no_of_notifications,
            no_of_regulations=body.no_of_regulations,
            no_of_circulars=body.no_of_circulars,
            no_of_statutes=body.no_of_statutes,
            no_of_ordinances=body.no_of_ordinances,
            no_of_orders=body.no_of_orders,
            keywords=body.keywords,
            is_repealed=body.is_repealed,
        )
    except FileNotFoundError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    audit.log(
        "pdf_created", "pdf",
        actor_user_id=current_user.id,
        entity_id=doc.id,
        details={"document_name": body.document_name, "document_type_id": body.document_type_id, "department_id": current_user.department_id, "file_ref": body.file_ref},
        ip_address=get_client_ip(request),
    )
    return doc


@router.get(
    "/pending",
    response_model=PDFListResponse,
    summary="Approver queue — documents awaiting review",
)
def list_pending_documents(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(_approver_roles),
    service: PDFService = Depends(get_pdf_service),
):
    # Pure approvers only see documents from their mapped uploaders.
    # Admins / nodal officers / super-admins see everything.
    role_name = current_user.role.name if current_user.role else ""
    approver_filter = current_user.id if role_name == "approver" else None
    total, documents = service.get_pending(skip, limit, approver_id=approver_filter)
    return PDFListResponse(total=total, documents=documents)


@router.post(
    "/review",
    response_model=PDFUploadResponse,
    summary="Approve or reject a document",
)
def review_document(
    body: PDFReviewRequest,
    request: Request,
    current_user: User = Depends(_approver_roles),
    service: PDFService = Depends(get_pdf_service),
    audit: AuditService = Depends(get_audit_service),
):
    if body.action not in ("approved", "rejected"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="action must be 'approved' or 'rejected'",
        )
    doc = service.review_document(body.pdf_id, current_user.id, body.action, body.comments, body.annotations_json)
    if not doc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found")
    audit.log(
        f"pdf_{body.action}", "pdf",
        actor_user_id=current_user.id,
        entity_id=body.pdf_id,
        details={"action": body.action, "comments": body.comments},
        ip_address=get_client_ip(request),
    )
    return doc


@router.get(
    "/approver/documents",
    response_model=PDFListResponse,
    summary="Approver — list all documents with optional status filter",
)
def list_documents_for_approver(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=1000),
    status: Optional[str] = Query(None, description="Filter by status: pending | approved | rejected"),
    current_user: User = Depends(_approver_roles),
    service: PDFService = Depends(get_pdf_service),
):
    if status and status not in ("pending", "approved", "rejected"):
        raise HTTPException(
            status_code=400,
            detail="status must be one of: pending, approved, rejected",
        )
    total, documents = service.list_all_documents(skip, limit, status)
    return PDFListResponse(total=total, documents=documents)


VALID_DOCUMENT_TYPES = {"Act", "Amendment", "Notification", "Circular", "Policy", "Rules & Regulations", "Order/Gazette"}


@router.get("/search-documents", response_model=DocumentNameSearchResponse, summary="Autocomplete — search document names by type and keyword")
def search_documents_by_type(
    document_type: str = Query(..., description="Document type: Act | Amendment | Notification | Circular | Policy | Rules & Regulations | Order/Gazette"),
    q: str = Query(..., min_length=1, description="Keyword to match against document names"),
    limit: int = Query(20, ge=1, le=100),
    # current_user: User = Depends(get_current_user),  # public — no citizen auth
    service: PDFService = Depends(get_pdf_service),
):
    if document_type not in VALID_DOCUMENT_TYPES:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"document_type must be one of: {', '.join(sorted(VALID_DOCUMENT_TYPES))}",
        )
    rows = service.search_documents_by_type(document_type, q, limit)
    results = [
        DocumentNameItem(
            id=r["id"],
            document_name=r["document_name"],
            reference_number=r.get("reference_number"),
            status=r["status"],
            document_type_name=r.get("document_type_name"),
        )
        for r in rows
    ]
    return DocumentNameSearchResponse(query=q, document_type=document_type, total=len(results), results=results)


@router.get("/search", response_model=SearchResponse)
def search_pdfs(
    q: str = Query(..., min_length=2, description="Word or phrase to search across all PDFs"),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    service: PDFService = Depends(get_pdf_service),
):
    rows = service.search(q, skip, limit)
    results = [
        SearchResultItem(
            pdf_id=r["pdf_id"],
            original_filename=r["original_filename"],
            page_number=r["page_number"],
            relevance_score=r["relevance_score"],
            snippet=r["page_text"],
        )
        for r in rows
    ]
    return SearchResponse(query=q, total=len(results), results=results)


@router.get("/my-documents", response_model=PDFListResponse)
def list_my_documents(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(get_current_user),
    service: PDFService = Depends(get_pdf_service),
):
    total, documents = service.list_my_documents(current_user.id, skip, limit)
    return PDFListResponse(total=total, documents=documents)


_VALID_DOC_TYPES = {"Act", "Amendment", "Notification", "Circular", "Policy", "Rules & Regulations", "Order/Gazette"}
_VALID_STATUSES = {"pending", "approved", "rejected"}


@router.get("/my-department/acts", response_model=PDFListResponse, summary="List all Acts uploaded in the current user's department(s)")
def list_acts_by_my_department(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=1000),
    status: Optional[str] = Query(None, description="Filter by status: pending | approved | rejected"),
    current_user: User = Depends(get_current_user),
    service: PDFService = Depends(get_pdf_service),
):
    if not current_user.department_id:
        raise HTTPException(status_code=400, detail="Your account has no department assigned")
    if status and status not in _VALID_STATUSES:
        raise HTTPException(status_code=400, detail="status must be one of: pending, approved, rejected")
    total, documents = service.list_acts_by_department(current_user.department_id, skip, limit, status)
    return PDFListResponse(total=total, documents=documents)


@router.get(
    "/my-department/by-type",
    response_model=PDFListResponse,
    summary="List documents of a given type uploaded in the current user's department(s)",
)
def list_docs_by_my_department_and_type(
    doc_type_id: int = Query(..., description="document_types.id from the document types table"),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=1000),
    status: Optional[str] = Query(None, description="Filter by status: pending | approved | rejected"),
    current_user: User = Depends(get_current_user),
    service: PDFService = Depends(get_pdf_service),
):
    if not current_user.department_id:
        raise HTTPException(status_code=400, detail="Your account has no department assigned")
    if status and status not in _VALID_STATUSES:
        raise HTTPException(status_code=400, detail="status must be one of: pending, approved, rejected")
    total, documents = service.list_docs_by_dept_and_type(current_user.department_id, doc_type_id, skip, limit, status)
    return PDFListResponse(total=total, documents=documents)


@router.put("/{document_id}", response_model=PDFUploadResponse, summary="Update document metadata")
def update_document(
    document_id: int,
    body: PDFUpdateRequest,
    current_user: User = Depends(get_current_user),
    service: PDFService = Depends(get_pdf_service),
):
    doc = service.get_by_id(document_id)
    if not doc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found")
    if doc.uploaded_by != current_user.id and not any(
        r in (current_user.role.name if current_user.role else "") for r in ("admin", "super Admin")
    ):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Not authorised to edit this document")

    updated = service.update_document(
        document_id=document_id,
        tag_ids=body.tag_ids,
        relationships=body.relationships,
        document_name=body.document_name,
        reference_number=body.reference_number,
        issue_date=body.issue_date,
        effective_from=body.effective_from,
        gazette_reference=body.gazette_reference,
        legal_authority=body.legal_authority,
        short_title=body.short_title,
        valid_until=body.valid_until,
        sector_domain=body.sector_domain,
        implementing_agency=body.implementing_agency,
        next_review_date=body.next_review_date,
        rule_making_authority=body.rule_making_authority,
        version_no=body.version_no,
        department_id=body.department_id,
        document_type_id=body.document_type_id,
        description=body.description,
        act_year=body.act_year,
        long_title=body.long_title,
        regional_title=body.regional_title,
        notification_no=body.notification_no,
        act_code=body.act_code,
        so_reason=body.so_reason,
        no_of_rules=body.no_of_rules,
        no_of_notifications=body.no_of_notifications,
        no_of_regulations=body.no_of_regulations,
        no_of_circulars=body.no_of_circulars,
        no_of_statutes=body.no_of_statutes,
        no_of_ordinances=body.no_of_ordinances,
        no_of_orders=body.no_of_orders,
        keywords=body.keywords,
        is_repealed=body.is_repealed,
    )
    return updated


@router.get(
    "/public/semantic-search",
    response_model=SemanticSearchResponse,
    summary="Semantic / AI search — no token required",
)
def semantic_search(
    request: Request,
    q: str = Query(..., min_length=5, description="Natural language question"),
    top_k: int = Query(5, ge=1, le=10),
    rag: RAGService = Depends(get_rag_service),
):
    result = rag.answer(q, top_k)
    base = str(request.base_url).rstrip("/")
    for source in result["sources"]:
        source["file_url"] = f"{base}/api/v1/pdf/{source['pdf_id']}/file"
    return SemanticSearchResponse(question=q, **result)


@router.get("/public/search", response_model=PDFListResponse, summary="Public citizen search — no token required")
def citizen_search(
    document_type_id: Optional[int] = Query(None, description="Filter by document type ID"),
    name: Optional[str] = Query(None, description="Document name starts with"),
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=100),
    service: PDFService = Depends(get_pdf_service),
):
    total, documents = service.citizen_search(document_type_id, name, skip, limit)
    return PDFListResponse(total=total, documents=documents)


@router.get("/all", response_model=PDFListResponse)
def list_all_documents(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, ge=1, le=1000),
    status: Optional[str] = Query(None, description="Filter by status: pending | approved | rejected"),
    service: PDFService = Depends(get_pdf_service),
):
    if status and status not in ("pending", "approved", "rejected"):
        raise HTTPException(
            status_code=400,
            detail="status must be one of: pending, approved, rejected",
        )
    total, documents = service.list_all_documents(skip, limit, status)
    return PDFListResponse(total=total, documents=documents)


@router.get(
    "/check-duplicate",
    response_model=list[DuplicateCheckItem],
    summary="Check if a document with the same name and type already exists in another department",
)
def check_duplicate_document(
    document_name: str = Query(..., min_length=1),
    document_type_id: int = Query(...),
    current_user: User = Depends(get_current_user),
    service: PDFService = Depends(get_pdf_service),
):
    # Parse first dept id as int; use 0 when user has no department (SP treats all as 'other_dept')
    dept_id = int(current_user.department_id.split(',')[0]) if current_user.department_id else 0
    rows = service.check_duplicate_document(document_name, document_type_id, dept_id)
    return [
        DuplicateCheckItem(
            id=r["id"],
            document_name=r["document_name"],
            version_no=r.get("version_no"),
            status=r["status"],
            created_at=r["created_at"],
            department_id=r.get("department_id"),
            department_name=r.get("department_name"),
            document_type_name=r.get("document_type_name"),
            uploader_username=r.get("uploader_username"),
            match_type=r["match_type"],
        )
        for r in rows
    ]


@router.post(
    "/link-department",
    summary="Request to link an existing document to the caller's department",
)
def link_document_to_department(
    body: LinkDocumentRequest,
    current_user: User = Depends(get_current_user),
    service: PDFService = Depends(get_pdf_service),
):
    if not current_user.department_id:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="User has no department assigned")
    dept_id = int(current_user.department_id.split(',')[0])
    result = service.link_document_to_department(body.pdf_id, dept_id, current_user.id)
    return result


@router.get(
    "/linked-documents",
    response_model=list[LinkedDocumentItem],
    summary="Documents linked to caller's department (all statuses by default)",
)
def get_linked_documents(
    link_status: Optional[str] = Query(None, description="Filter by link status: pending | approved | rejected"),
    current_user: User = Depends(get_current_user),
    service: PDFService = Depends(get_pdf_service),
):
    if not current_user.department_id:
        return []
    dept_id = int(current_user.department_id.split(',')[0])
    rows = service.get_linked_documents_for_department(dept_id, link_status)
    return [
        LinkedDocumentItem(
            id=r["id"],
            original_filename=r["original_filename"],
            file_path=r.get("file_path"),
            file_size=r["file_size"],
            status=r["status"],
            document_name=r.get("document_name"),
            version_no=r.get("version_no"),
            reference_number=r.get("reference_number"),
            issue_date=r.get("issue_date"),
            document_type_id=r.get("document_type_id"),
            document_type_name=r.get("document_type_name"),
            department_id=r.get("department_id"),
            department_name=r.get("department_name"),
            uploaded_by=r["uploaded_by"],
            uploader_username=r.get("uploader_username"),
            uploader_first_name=r.get("uploader_first_name"),
            uploader_last_name=r.get("uploader_last_name"),
            created_at=r["created_at"],
            link_id=r["link_id"],
            link_status=r["link_status"],
            review_comments=r.get("review_comments"),
            reviewed_at=r.get("reviewed_at"),
            link_annotations_json=r.get("link_annotations_json"),
            link_reviewed_by_username=r.get("link_reviewed_by_username"),
            link_reviewed_by_first_name=r.get("link_reviewed_by_first_name"),
            link_reviewed_by_last_name=r.get("link_reviewed_by_last_name"),
        )
        for r in rows
    ]


@router.get(
    "/department-link-requests",
    response_model=list[DepartmentLinkItem],
    summary="Approver — link requests for their department (pending by default)",
)
def get_department_link_requests(
    link_status: Optional[str] = Query("pending", description="pending | approved | rejected | null for all"),
    current_user: User = Depends(_approver_roles),
    service: PDFService = Depends(get_pdf_service),
):
    if not current_user.department_id:
        return []
    dept_id = int(current_user.department_id.split(',')[0])
    status_param = None if link_status == "all" else link_status
    rows = service.get_links_for_department(dept_id, status_param)
    return [
        DepartmentLinkItem(
            link_id=r["link_id"],
            pdf_id=r["pdf_id"],
            link_status=r["link_status"],
            requested_at=r["requested_at"],
            reviewed_at=r.get("reviewed_at"),
            review_comments=r.get("review_comments"),
            annotations_json=r.get("annotations_json"),
            document_name=r.get("document_name"),
            version_no=r.get("version_no"),
            document_status=r["document_status"],
            document_type_name=r.get("document_type_name"),
            original_department_name=r.get("original_department_name"),
            requested_by_username=r.get("requested_by_username"),
            requested_by_first_name=r.get("requested_by_first_name"),
            requested_by_last_name=r.get("requested_by_last_name"),
            reviewed_by_username=r.get("reviewed_by_username"),
            reviewed_by_first_name=r.get("reviewed_by_first_name"),
            reviewed_by_last_name=r.get("reviewed_by_last_name"),
        )
        for r in rows
    ]


_admin_roles = require_roles("admin", "super Admin", "nodal Officer")


@router.get(
    "/all-department-links",
    response_model=list[AllDepartmentLinkItem],
    summary="Admin/Nodal — all department link requests across all departments",
)
def get_all_department_links(
    link_status: Optional[str] = Query(None, description="Filter: pending | approved | rejected (null = all)"),
    department_id: Optional[int] = Query(None, description="Filter by linked-to department id"),
    current_user: User = Depends(_admin_roles),
    service: PDFService = Depends(get_pdf_service),
):
    rows = service.get_all_department_links(link_status, department_id)
    return [
        AllDepartmentLinkItem(
            link_id=r["link_id"],
            pdf_id=r["pdf_id"],
            link_status=r["link_status"],
            requested_at=r["requested_at"],
            reviewed_at=r.get("reviewed_at"),
            review_comments=r.get("review_comments"),
            annotations_json=r.get("annotations_json"),
            document_name=r.get("document_name"),
            version_no=r.get("version_no"),
            document_status=r["document_status"],
            document_type_name=r.get("document_type_name"),
            original_department_name=r.get("original_department_name"),
            linked_department_name=r.get("linked_department_name"),
            requested_by_username=r.get("requested_by_username"),
            requested_by_first_name=r.get("requested_by_first_name"),
            requested_by_last_name=r.get("requested_by_last_name"),
            reviewed_by_username=r.get("reviewed_by_username"),
            reviewed_by_first_name=r.get("reviewed_by_first_name"),
            reviewed_by_last_name=r.get("reviewed_by_last_name"),
        )
        for r in rows
    ]


@router.post(
    "/review-link",
    summary="Approver — approve or reject a department link request",
)
def review_department_link(
    body: LinkReviewRequest,
    current_user: User = Depends(_approver_roles),
    service: PDFService = Depends(get_pdf_service),
):
    if body.action not in ("approved", "rejected"):
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail="action must be 'approved' or 'rejected'")
    try:
        service.review_department_link(body.link_id, body.action, current_user.id, body.comments, body.annotations_json)
    except ValueError as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
    return {"ok": True, "link_id": body.link_id, "action": body.action}


@router.get("/{pdf_id}/children", response_model=ActChildrenResponse, summary="Get all documents linked to an Act, grouped by document type (for tab rendering)")
def get_act_children(
    pdf_id: int,
    service: PDFService = Depends(get_pdf_service),
):
    rows = service.get_act_full_related_docs(pdf_id)
    grouped: dict[str, list[ActChildDocument]] = {}
    for row in rows:
        doc_type = row.get("document_type_name") or "Other"
        child = ActChildDocument(
            **{k: v for k, v in row.items() if k != "tags"},
            tags=PDFRepository._parse_tags(row.get("tags")),
        )
        grouped.setdefault(doc_type, []).append(child)
    return ActChildrenResponse(act_id=pdf_id, children=grouped)


@router.get("/{document_id}", response_model=PDFUploadResponse, summary="Get document details by ID — approved documents only")
def get_document_by_id(
    document_id: int,
    service: PDFService = Depends(get_pdf_service),
):
    doc = service.get_by_id(document_id)
    if not doc or doc.status != "approved":
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found")
    return doc


@router.get("/{document_id}/file", summary="Stream the original PDF file")
def get_pdf_file(
    document_id: int,
    service: PDFService = Depends(get_pdf_service),
):
    doc = service.get_by_id(document_id)
    if not doc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Document not found")
    # Normalise Windows-style separators before extracting basename so this works
    # on Linux hosts even when the path was stored on a Windows dev machine.
    _stored = doc.file_path.replace("\\", "/")
    fp = _stored if os.path.isabs(_stored) else os.path.join(
        settings.UPLOAD_DIR, os.path.basename(_stored)
    )
    if not os.path.exists(fp):
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="File not found on server")
    ext = os.path.splitext(fp)[1].lower()
    media_type = (
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        if ext == ".docx" else "application/pdf"
    )
    return FileResponse(fp, media_type=media_type, filename=doc.original_filename or "document", content_disposition_type="inline")


@router.get(
    "/{act_id}/full",
    response_model=ActFullDetailResponse,
    summary="Get full ACT detail — document info + related documents by type + all ACT parts",
)
def get_act_full_detail(
    act_id: int,
    pdf_service: PDFService = Depends(get_pdf_service),
    parts_service: ActPartsService = Depends(get_act_parts_service),
):
    doc = pdf_service.get_by_id(act_id)
    if not doc:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="ACT document not found")

    # Group related/child documents by their document type name (all relationship types)
    related_documents: dict[str, list[ActChildDocument]] = {}
    for row in pdf_service.get_act_full_related_docs(act_id):
        type_name = row.get("document_type_name") or "Other"
        child = ActChildDocument(
            **{k: v for k, v in row.items() if k != "tags"},
            tags=PDFRepository._parse_tags(row.get("tags")),
        )
        related_documents.setdefault(type_name, []).append(child)

    # Fetch all ACT parts (chapters, sections, schedules, annexures, appendices, forms)
    act_parts = parts_service.get_all_parts(act_id)

    return ActFullDetailResponse(
        id=doc.id,
        filename=doc.filename,
        original_filename=doc.original_filename,
        file_size=doc.file_size,
        status=doc.status,
        document_name=doc.document_name,
        issue_date=doc.issue_date,
        reference_number=doc.reference_number,
        effective_from=doc.effective_from,
        gazette_reference=doc.gazette_reference,
        legal_authority=doc.legal_authority,
        short_title=doc.short_title,
        valid_until=doc.valid_until,
        sector_domain=doc.sector_domain,
        implementing_agency=doc.implementing_agency,
        next_review_date=doc.next_review_date,
        rule_making_authority=doc.rule_making_authority,
        version_no=doc.version_no,
        act_year=doc.act_year,
        long_title=doc.long_title,
        regional_title=doc.regional_title,
        notification_no=doc.notification_no,
        act_code=doc.act_code,
        so_reason=doc.so_reason,
        no_of_rules=doc.no_of_rules,
        no_of_notifications=doc.no_of_notifications,
        no_of_regulations=doc.no_of_regulations,
        no_of_circulars=doc.no_of_circulars,
        no_of_statutes=doc.no_of_statutes,
        no_of_ordinances=doc.no_of_ordinances,
        no_of_orders=doc.no_of_orders,
        keywords=doc.keywords,
        is_repealed=doc.is_repealed,
        department_id=doc.department_id,
        department_name=getattr(doc, "department_name", None),
        document_type_id=doc.document_type_id,
        document_type_name=getattr(doc, "document_type_name", None),
        description=doc.description,
        summary=doc.summary,
        tags=getattr(doc, "tags", []),
        relationships=getattr(doc, "relationships", []),
        latest_approval=getattr(doc, "latest_approval", None),
        uploaded_by=doc.uploaded_by,
        uploader_username=getattr(doc, "uploader_username", None),
        uploader_first_name=getattr(doc, "uploader_first_name", None),
        uploader_last_name=getattr(doc, "uploader_last_name", None),
        created_at=doc.created_at,
        related_documents=related_documents,
        act_parts=act_parts,
    )
