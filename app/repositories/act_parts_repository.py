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
                    "SELECT id AS chapter_id, chapter_number, chapter_title, display_order AS chapter_order, status "
                    "FROM act_part_chapters WHERE pdf_document_id = :doc_id AND is_deleted = 0 ORDER BY display_order"
                ),
                {"doc_id": pdf_document_id},
            ).mappings().fetchall()
        ]

        sections = [
            dict(r)
            for r in self._db.execute(
                text(
                    "SELECT id AS section_id, chapter_id, section_number, section_title, "
                    "section_content, file_path, file_size, original_filename, display_order AS section_order, status "
                    "FROM act_part_sections WHERE pdf_document_id = :doc_id AND is_deleted = 0 ORDER BY display_order"
                ),
                {"doc_id": pdf_document_id},
            ).mappings().fetchall()
        ]

        # Build chapter_rows: one row per (chapter, section) pair.
        # Chapters with zero sections still need a row so the service can create the ChapterOut object.
        chapter_map = {c["chapter_id"]: c for c in chapters}
        sections_by_chapter: dict[int, list[dict]] = {}
        for sec in sections:
            ch_id = sec.get("chapter_id")
            if ch_id:
                sections_by_chapter.setdefault(ch_id, []).append(sec)

        chapter_rows: list[dict] = []
        for ch in chapters:
            ch_id = ch["chapter_id"]
            ch_secs = sections_by_chapter.get(ch_id, [])
            if ch_secs:
                for sec in ch_secs:
                    chapter_rows.append({**ch, **sec})
            else:
                # Chapter with no sections — include it with null section fields
                chapter_rows.append({**ch, "section_id": None})

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
                    f"original_filename, display_order, created_at, status "
                    f"FROM {tbl} WHERE pdf_document_id = :doc_id AND is_deleted = 0 ORDER BY display_order"
                ),
                {"doc_id": pdf_document_id},
            ).mappings().fetchall()
        ]

    def submit_for_approval(self, pdf_document_id: int, part_type: str, submitted_by: int) -> dict:
        result = self._db.execute(
            text("CALL sp_submit_act_parts(:doc_id, :ptype, :uid)"),
            {"doc_id": pdf_document_id, "ptype": part_type, "uid": submitted_by},
        ).mappings().fetchone()
        self._db.commit()
        return dict(result) if result else {}

    def review_act_parts(
        self, pdf_document_id: int, part_type: str,
        reviewed_by: int, action: str, comments,
    ) -> dict:
        result = self._db.execute(
            text("CALL sp_review_act_parts(:doc_id, :ptype, :uid, :action, :comments)"),
            {"doc_id": pdf_document_id, "ptype": part_type, "uid": reviewed_by, "action": action, "comments": comments},
        ).mappings().fetchone()
        self._db.commit()
        return dict(result) if result else {}

    def get_approvals(self, pdf_document_id: int) -> list[dict]:
        rows = self._db.execute(
            text(
                "SELECT a.id, a.pdf_document_id, a.part_type, a.status, a.submitted_by, "
                "a.submitted_at, a.reviewed_by, a.reviewed_at, a.comments, "
                "u.username AS submitter_username, u.first_name AS submitter_first_name, "
                "u.last_name AS submitter_last_name, "
                "r.username AS reviewer_username, r.first_name AS reviewer_first_name, "
                "r.last_name AS reviewer_last_name "
                "FROM act_part_approvals a "
                "JOIN users u ON u.id = a.submitted_by "
                "LEFT JOIN users r ON r.id = a.reviewed_by "
                "WHERE a.pdf_document_id = :doc_id "
                "ORDER BY FIELD(a.part_type,'sections','schedule','annexure','appendix','forms')"
            ),
            {"doc_id": pdf_document_id},
        ).mappings().fetchall()
        return [dict(r) for r in rows]

    def list_pending(self) -> list[dict]:
        rows = self._db.execute(
            text(
                "SELECT a.id, a.pdf_document_id, a.part_type, a.status, a.submitted_by, "
                "a.submitted_at, a.reviewed_by, a.reviewed_at, a.comments, "
                "u.username AS submitter_username, u.first_name AS submitter_first_name, "
                "u.last_name AS submitter_last_name, "
                "d.document_name AS act_name, dt.name AS act_type "
                "FROM act_part_approvals a "
                "JOIN users u ON u.id = a.submitted_by "
                "JOIN pdf_documents d ON d.id = a.pdf_document_id "
                "LEFT JOIN document_types dt ON dt.id = d.document_type_id "
                "WHERE a.status = 'pending' ORDER BY a.submitted_at ASC"
            )
        ).mappings().fetchall()
        return [dict(r) for r in rows]

    def list_my_submissions(self, submitted_by: int) -> list[dict]:
        rows = self._db.execute(
            text(
                "SELECT a.id, a.pdf_document_id, a.part_type, a.status, a.submitted_by, "
                "a.submitted_at, a.reviewed_by, a.reviewed_at, a.comments, "
                "r.username AS reviewer_username, r.first_name AS reviewer_first_name, "
                "r.last_name AS reviewer_last_name, "
                "d.document_name AS act_name, dt.name AS act_type "
                "FROM act_part_approvals a "
                "LEFT JOIN users r ON r.id = a.reviewed_by "
                "JOIN pdf_documents d ON d.id = a.pdf_document_id "
                "LEFT JOIN document_types dt ON dt.id = d.document_type_id "
                "WHERE a.submitted_by = :uid ORDER BY a.submitted_at DESC"
            ),
            {"uid": submitted_by},
        ).mappings().fetchall()
        return [dict(r) for r in rows]

    def list_all_submissions(self) -> list[dict]:
        rows = self._db.execute(
            text(
                "SELECT a.id, a.pdf_document_id, a.part_type, a.status, a.submitted_by, "
                "a.submitted_at, a.reviewed_by, a.reviewed_at, a.comments, "
                "u.username AS submitter_username, u.first_name AS submitter_first_name, "
                "u.last_name AS submitter_last_name, "
                "r.username AS reviewer_username, r.first_name AS reviewer_first_name, "
                "r.last_name AS reviewer_last_name, "
                "d.document_name AS act_name, dt.name AS act_type "
                "FROM act_part_approvals a "
                "JOIN users u ON u.id = a.submitted_by "
                "JOIN pdf_documents d ON d.id = a.pdf_document_id "
                "LEFT JOIN document_types dt ON dt.id = d.document_type_id "
                "LEFT JOIN users r ON r.id = a.reviewed_by "
                "ORDER BY a.submitted_at DESC"
            )
        ).mappings().fetchall()
        return [dict(r) for r in rows]

    def get_all_parts(self, pdf_document_id: int) -> dict:
        def _q(sql: str) -> list[dict]:
            return [
                dict(r)
                for r in self._db.execute(text(sql), {"doc_id": pdf_document_id}).mappings().fetchall()
            ]

        chapters = _q(
            "SELECT id, chapter_number, chapter_title, display_order, status "
            "FROM act_part_chapters WHERE pdf_document_id = :doc_id AND is_deleted = 0 ORDER BY display_order"
        )
        sections = _q(
            "SELECT id, chapter_id, section_number, section_title, section_content, "
            "file_path, file_size, original_filename, display_order, status "
            "FROM act_part_sections WHERE pdf_document_id = :doc_id AND is_deleted = 0 ORDER BY display_order"
        )
        schedules  = _q("SELECT id, entry_number, title, description, file_path, file_size, original_filename, display_order, status FROM act_part_schedules  WHERE pdf_document_id = :doc_id AND is_deleted = 0 ORDER BY display_order")
        annexures  = _q("SELECT id, entry_number, title, description, file_path, file_size, original_filename, display_order, status FROM act_part_annexures  WHERE pdf_document_id = :doc_id AND is_deleted = 0 ORDER BY display_order")
        appendices = _q("SELECT id, entry_number, title, description, file_path, file_size, original_filename, display_order, status FROM act_part_appendices WHERE pdf_document_id = :doc_id AND is_deleted = 0 ORDER BY display_order")
        forms      = _q("SELECT id, entry_number, title, description, file_path, file_size, original_filename, display_order, status FROM act_part_forms      WHERE pdf_document_id = :doc_id AND is_deleted = 0 ORDER BY display_order")

        return {
            "chapters":   chapters,
            "sections":   sections,
            "schedules":  schedules,
            "annexures":  annexures,
            "appendices": appendices,
            "forms":      forms,
        }
