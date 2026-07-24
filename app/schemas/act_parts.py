from datetime import datetime
from typing import Optional, List

from pydantic import BaseModel


# ── File upload ────────────────────────────────────────────────────────────────

class ActPartFileUploadResponse(BaseModel):
    file_ref: str
    original_filename: str
    file_size: int


# ── Sections ───────────────────────────────────────────────────────────────────

class SectionInput(BaseModel):
    section_number: Optional[str] = None
    section_title: Optional[str] = None
    section_content: Optional[str] = None
    file_ref: Optional[str] = None          # from /upload-file step


class ChapterInput(BaseModel):
    chapter_number: Optional[str] = None
    chapter_title: Optional[str] = None
    sections: List[SectionInput] = []


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
    entry_number: Optional[str] = None
    title: Optional[str] = None
    description: Optional[str] = None
    file_ref: Optional[str] = None          # from /upload-file step


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
