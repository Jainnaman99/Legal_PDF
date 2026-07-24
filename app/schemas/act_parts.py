from datetime import datetime
from typing import Optional, List, Literal

from pydantic import BaseModel


# ── File upload ────────────────────────────────────────────────────────────────

class ActPartFileUploadResponse(BaseModel):
    file_ref: str
    original_filename: str
    file_size: int


# ── Sections ───────────────────────────────────────────────────────────────────

class SectionInput(BaseModel):
    id: Optional[int] = None               # None = new row; set = existing row to upsert
    section_number: Optional[str] = None
    section_title: Optional[str] = None
    section_content: Optional[str] = None
    file_ref: Optional[str] = None          # from /upload-file step
    is_deleted: bool = False


class ChapterInput(BaseModel):
    id: Optional[int] = None               # None = new row; set = existing row to upsert
    chapter_number: Optional[str] = None
    chapter_title: Optional[str] = None
    sections: List[SectionInput] = []
    is_deleted: bool = False


class SaveSectionsRequest(BaseModel):
    has_chapters: bool
    chapters: Optional[List[ChapterInput]] = None       # when has_chapters=True
    flat_sections: Optional[List[SectionInput]] = None  # when has_chapters=False


class SectionOut(BaseModel):
    id: int
    section_number: Optional[str]
    section_title: Optional[str]
    section_content: Optional[str]
    file_path: Optional[str]
    file_size: Optional[int]
    original_filename: Optional[str]
    file_ref: Optional[str] = None   # basename of file_path — used by frontend to open the file
    display_order: int

    class Config:
        from_attributes = True


class ChapterOut(BaseModel):
    id: int
    chapter_number: Optional[str]
    chapter_title: Optional[str]
    display_order: int
    sections: List[SectionOut] = []

    class Config:
        from_attributes = True


class SectionsResponse(BaseModel):
    has_chapters: bool
    chapters: List[ChapterOut] = []
    flat_sections: List[SectionOut] = []


# ── Schedule / Annexure / Appendix / Form (shared shape) ──────────────────────

class EntryInput(BaseModel):
    id: Optional[int] = None               # None = new row; set = existing row to upsert
    entry_number: Optional[str] = None
    title: Optional[str] = None
    description: Optional[str] = None
    file_ref: Optional[str] = None          # from /upload-file step
    is_deleted: bool = False


class SaveEntriesRequest(BaseModel):
    entries: List[EntryInput] = []


class EntryOut(BaseModel):
    id: int
    entry_number: Optional[str]
    title: Optional[str]
    description: Optional[str]
    file_path: Optional[str]
    file_size: Optional[int]
    original_filename: Optional[str]
    file_ref: Optional[str] = None   # basename of file_path — used by frontend to open the file
    display_order: int
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True


# ── All-parts combined response ────────────────────────────────────────────────

class AllActPartsResponse(BaseModel):
    pdf_document_id: int
    has_chapters: bool
    chapters: List[ChapterOut] = []
    flat_sections: List[SectionOut] = []
    schedules: List[EntryOut] = []
    annexures: List[EntryOut] = []
    appendices: List[EntryOut] = []
    forms: List[EntryOut] = []
    approvals: List["ActPartApprovalOut"] = []


# ── Approval ───────────────────────────────────────────────────────────────────

PartType = Literal["sections", "schedule", "annexure", "appendix", "forms"]

class ActPartApprovalOut(BaseModel):
    id: int
    pdf_document_id: int
    part_type: str
    status: str                         # 'pending' | 'approved' | 'rejected'
    submitted_by: int
    submitted_at: Optional[datetime]
    reviewed_by: Optional[int] = None
    reviewed_at: Optional[datetime] = None
    comments: Optional[str] = None
    submitter_username: Optional[str] = None
    submitter_first_name: Optional[str] = None
    submitter_last_name: Optional[str] = None
    reviewer_username: Optional[str] = None
    reviewer_first_name: Optional[str] = None
    reviewer_last_name: Optional[str] = None

    class Config:
        from_attributes = True


class ActPartPendingItem(BaseModel):
    """Extended approval row returned in the approver's pending queue — includes act metadata."""
    id: int
    pdf_document_id: int
    part_type: str
    status: str
    submitted_by: int
    submitted_at: Optional[datetime]
    reviewed_by: Optional[int] = None
    reviewed_at: Optional[datetime] = None
    comments: Optional[str] = None
    submitter_username: Optional[str] = None
    submitter_first_name: Optional[str] = None
    submitter_last_name: Optional[str] = None
    act_name: Optional[str] = None
    act_type: Optional[str] = None

    class Config:
        from_attributes = True


class ActPartReviewRequest(BaseModel):
    pdf_document_id: int
    part_type: PartType
    action: Literal["approved", "rejected"]
    comments: Optional[str] = None


AllActPartsResponse.model_rebuild()
