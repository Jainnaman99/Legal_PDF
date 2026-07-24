from typing import Optional

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.interfaces.act_structure_repository import IActStructureRepository
from app.models.act_structure import ActChapter, ActSchedule, ActSection, ActStructure


class ActStructureRepository(IActStructureRepository):
    def __init__(self, db: Session):
        self._db = db

    def create_structure(
        self,
        pdf_document_id: Optional[int],
        act_title: str,
        act_number: Optional[str],
        act_year: Optional[int],
    ) -> ActStructure:
        obj = ActStructure(
            pdf_document_id=pdf_document_id,
            act_title=act_title,
            act_number=act_number,
            act_year=act_year,
            extraction_status="processing",
        )
        self._db.add(obj)
        self._db.commit()
        self._db.refresh(obj)
        return obj

    def update_status(
        self, structure_id: int, status: str, error_message: Optional[str] = None
    ) -> None:
        obj = self._db.get(ActStructure, structure_id)
        if obj:
            obj.extraction_status = status
            if error_message is not None:
                obj.error_message = error_message
            self._db.commit()

    def update_totals(
        self, structure_id: int, chapters: int, sections: int, schedules: int
    ) -> None:
        obj = self._db.get(ActStructure, structure_id)
        if obj:
            obj.total_chapters = chapters
            obj.total_sections = sections
            obj.total_schedules = schedules
            self._db.commit()

    def add_chapter(
        self,
        structure_id: int,
        chapter_number: Optional[str],
        chapter_title: Optional[str],
        display_order: int,
    ) -> int:
        obj = ActChapter(
            act_structure_id=structure_id,
            chapter_number=chapter_number,
            chapter_title=chapter_title,
            display_order=display_order,
        )
        self._db.add(obj)
        self._db.flush()
        return obj.id

    def add_section(
        self,
        structure_id: int,
        chapter_id: Optional[int],
        section_number: Optional[str],
        section_title: Optional[str],
        section_content: Optional[str],
        display_order: int,
    ) -> None:
        obj = ActSection(
            act_structure_id=structure_id,
            act_chapter_id=chapter_id,
            section_number=section_number,
            section_title=section_title,
            section_content=section_content,
            display_order=display_order,
        )
        self._db.add(obj)
        self._db.flush()

    def add_schedule(
        self,
        structure_id: int,
        schedule_number: Optional[str],
        schedule_title: Optional[str],
        schedule_content: Optional[str],
        display_order: int,
    ) -> None:
        obj = ActSchedule(
            act_structure_id=structure_id,
            schedule_number=schedule_number,
            schedule_title=schedule_title,
            schedule_content=schedule_content,
            display_order=display_order,
        )
        self._db.add(obj)
        self._db.flush()

    def get_by_id(self, structure_id: int) -> Optional[ActStructure]:
        return self._db.get(ActStructure, structure_id)

    def get_by_pdf_document_id(self, pdf_document_id: int) -> Optional[ActStructure]:
        return (
            self._db.query(ActStructure)
            .filter(ActStructure.pdf_document_id == pdf_document_id)
            .first()
        )

    def list_all(self) -> list[ActStructure]:
        return self._db.query(ActStructure).order_by(ActStructure.created_at.desc()).all()

    def list_available_acts(self, query: str) -> list[dict]:
        sql = """
            SELECT p.id, p.document_name, p.act_year
            FROM pdf_documents p
            WHERE p.status = 'approved'
              AND (:q = '' OR p.document_name LIKE :q_like)
            ORDER BY p.document_name
            LIMIT 100
        """
        result = self._db.execute(text(sql), {"q": query, "q_like": f"%{query}%"})
        return [dict(r) for r in result.mappings().fetchall()]
