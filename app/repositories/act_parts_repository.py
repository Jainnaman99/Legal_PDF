import json
from typing import Optional

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.interfaces.act_parts_repository import IActPartsRepository

_ENTRY_TABLE = {
    "schedule":  "act_part_schedules",
    "annexure":  "act_part_annexures",
    "appendix":  "act_part_appendices",
    "form":      "act_part_forms",
}


class ActPartsRepository(IActPartsRepository):

    def __init__(self, db: Session):
        self._db = db

    # ── Writes use SPs (single result set — no nextset() needed) ─────────────

    def save_sections(
        self,
        pdf_document_id: int,
        created_by: int,
        has_chapters: bool,
        chapters_json: Optional[str],
        flat_json: Optional[str],
    ) -> None:
        self._db.execute(
            text("CALL sp_save_act_part_sections(:doc_id, :user_id, :has_ch, :ch_json, :flat_json)"),
            {
                "doc_id": pdf_document_id,
                "user_id": created_by,
                "has_ch": 1 if has_chapters else 0,
                "ch_json": chapters_json,
                "flat_json": flat_json,
            },
        )
        self._db.commit()

    def save_entries(
        self,
        part_type: str,
        pdf_document_id: int,
        created_by: int,
        entries_json: str,
    ) -> None:
        self._db.execute(
            text("CALL sp_save_act_part_entries(:ptype, :doc_id, :user_id, :entries)"),
            {
                "ptype": part_type,
                "doc_id": pdf_document_id,
                "user_id": created_by,
                "entries": entries_json,
            },
        )
        self._db.commit()

    # ── Reads use direct SQL (avoids multi-result-set cursor handling) ────────

    def get_sections(self, pdf_document_id: int) -> dict:
        chapters = [
            dict(r)
            for r in self._db.execute(
                text(
                    "SELECT id AS chapter_id, chapter_number, chapter_title, display_order AS chapter_order "
                    "FROM act_part_chapters WHERE pdf_document_id = :doc_id ORDER BY display_order"
                ),
                {"doc_id": pdf_document_id},
            ).mappings().fetchall()
        ]

        sections = [
            dict(r)
            for r in self._db.execute(
                text(
                    "SELECT id AS section_id, chapter_id, section_number, section_title, "
                    "section_content, file_path, file_size, original_filename, display_order AS section_order "
                    "FROM act_part_sections WHERE pdf_document_id = :doc_id ORDER BY display_order"
                ),
                {"doc_id": pdf_document_id},
            ).mappings().fetchall()
        ]

        # Build chapter_rows (joined shape the service expects)
        chapter_map = {c["chapter_id"]: c for c in chapters}
        chapter_rows: list[dict] = []
        for sec in sections:
            ch_id = sec.get("chapter_id")
            if ch_id and ch_id in chapter_map:
                ch = chapter_map[ch_id]
                chapter_rows.append({**ch, **sec})

        flat_rows = [s for s in sections if not s.get("chapter_id")]

        return {"chapter_rows": chapter_rows, "flat_rows": flat_rows}

    def get_entries(self, part_type: str, pdf_document_id: int) -> list[dict]:
        tbl = _ENTRY_TABLE.get(part_type)
        if not tbl:
            raise ValueError(f"Unknown part type: {part_type}")
        return [
            dict(r)
            for r in self._db.execute(
                text(
                    f"SELECT id, entry_number, title, description, file_path, file_size, "
                    f"original_filename, display_order, created_at "
                    f"FROM {tbl} WHERE pdf_document_id = :doc_id ORDER BY display_order"
                ),
                {"doc_id": pdf_document_id},
            ).mappings().fetchall()
        ]

    def get_all_parts(self, pdf_document_id: int) -> dict:
        def _q(sql: str) -> list[dict]:
            return [
                dict(r)
                for r in self._db.execute(text(sql), {"doc_id": pdf_document_id}).mappings().fetchall()
            ]

        chapters = _q(
            "SELECT id, chapter_number, chapter_title, display_order "
            "FROM act_part_chapters WHERE pdf_document_id = :doc_id ORDER BY display_order"
        )
        sections = _q(
            "SELECT id, chapter_id, section_number, section_title, section_content, "
            "file_path, file_size, original_filename, display_order "
            "FROM act_part_sections WHERE pdf_document_id = :doc_id ORDER BY display_order"
        )
        schedules  = _q("SELECT id, entry_number, title, description, file_path, file_size, original_filename, display_order FROM act_part_schedules  WHERE pdf_document_id = :doc_id ORDER BY display_order")
        annexures  = _q("SELECT id, entry_number, title, description, file_path, file_size, original_filename, display_order FROM act_part_annexures  WHERE pdf_document_id = :doc_id ORDER BY display_order")
        appendices = _q("SELECT id, entry_number, title, description, file_path, file_size, original_filename, display_order FROM act_part_appendices WHERE pdf_document_id = :doc_id ORDER BY display_order")
        forms      = _q("SELECT id, entry_number, title, description, file_path, file_size, original_filename, display_order FROM act_part_forms      WHERE pdf_document_id = :doc_id ORDER BY display_order")

        return {
            "chapters":   chapters,
            "sections":   sections,
            "schedules":  schedules,
            "annexures":  annexures,
            "appendices": appendices,
            "forms":      forms,
        }
