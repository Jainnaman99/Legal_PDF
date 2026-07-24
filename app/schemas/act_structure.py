from datetime import datetime
from typing import Optional

from pydantic import BaseModel


class SectionOut(BaseModel):
    id: int
    section_number: Optional[str] = None
    section_title: Optional[str] = None
    section_content: Optional[str] = None
    display_order: int

    model_config = {"from_attributes": True}


class ChapterOut(BaseModel):
    id: int
    chapter_number: Optional[str] = None
    chapter_title: Optional[str] = None
    display_order: int
    sections: list[SectionOut] = []

    model_config = {"from_attributes": True}


class ScheduleOut(BaseModel):
    id: int
    schedule_number: Optional[str] = None
    schedule_title: Optional[str] = None
    schedule_content: Optional[str] = None
    display_order: int

    model_config = {"from_attributes": True}


class ActStructureOut(BaseModel):
    id: int
    pdf_document_id: Optional[int] = None
    act_title: str
    act_number: Optional[str] = None
    act_year: Optional[int] = None
    total_chapters: int
    total_sections: int
    total_schedules: int
    extraction_status: str
    error_message: Optional[str] = None
    created_at: datetime
    chapters: list[ChapterOut] = []
    schedules: list[ScheduleOut] = []

    model_config = {"from_attributes": True}


class ActStructureSummary(BaseModel):
    id: int
    pdf_document_id: Optional[int] = None
    act_title: str
    act_number: Optional[str] = None
    act_year: Optional[int] = None
    total_chapters: int
    total_sections: int
    total_schedules: int
    extraction_status: str
    created_at: datetime

    model_config = {"from_attributes": True}


class AvailableActItem(BaseModel):
    id: int
    document_name: Optional[str] = None
    act_year: Optional[int] = None
