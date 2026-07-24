import json
import os
import uuid
from typing import Optional

from app.core.config import settings
from app.interfaces.act_parts_repository import IActPartsRepository
from app.schemas.act_parts import (
    ActPartFileUploadResponse,
    AllActPartsResponse,
    ChapterOut,
    EntryOut,
    SaveEntriesRequest,
    SaveSectionsRequest,
    SectionOut,
    SectionsResponse,
)

# Sub-directory inside UPLOAD_DIR for act-part files
_ACT_PARTS_SUBDIR = "act_parts"

# Maps tab key (from frontend) to SP part_type argument
PART_TYPE_MAP = {
    "schedule":  "schedule",
    "annexure":  "annexure",
    "appendix":  "appendix",
    "forms":     "form",
}


class ActPartsService:

    def __init__(self, repo: IActPartsRepository):
        self._repo = repo

    # ── File upload ────────────────────────────────────────────────────────────

    def store_file(self, filename: str, content: bytes) -> ActPartFileUploadResponse:
        upload_dir = os.path.join(settings.UPLOAD_DIR, _ACT_PARTS_SUBDIR)
        os.makedirs(upload_dir, exist_ok=True)
        unique_name = f"{uuid.uuid4().hex}_{filename}"
        file_path = os.path.join(upload_dir, unique_name)
        with open(file_path, "wb") as f:
            f.write(content)
        return ActPartFileUploadResponse(
            file_ref=unique_name,
            original_filename=filename,
            file_size=len(content),
        )

    def _resolve_file_ref(self, file_ref: Optional[str]) -> tuple[Optional[str], Optional[int], Optional[str]]:
        """Return (file_path, file_size, original_filename) for a file_ref, or (None,None,None)."""
        if not file_ref:
            return None, None, None
        full_path = os.path.join(settings.UPLOAD_DIR, _ACT_PARTS_SUBDIR, file_ref)
        if not os.path.exists(full_path):
            return None, None, None
        size = os.path.getsize(full_path)
        original = "_".join(file_ref.split("_")[1:]) if "_" in file_ref else file_ref
        return full_path, size, original

    # ── Sections ───────────────────────────────────────────────────────────────

    def save_sections(self, pdf_document_id: int, user_id: int, body: SaveSectionsRequest) -> SectionsResponse:
        if body.has_chapters:
            chapters_list = []
            for ch in (body.chapters or []):
                sections_list = []
                for sec in ch.sections:
                    fp, fs, fn = self._resolve_file_ref(sec.file_ref)
                    sections_list.append({
                        "section_number":   sec.section_number or "",
                        "section_title":    sec.section_title or "",
                        "section_content":  sec.section_content or "",
                        "file_path":        fp or "",
                        "file_size":        fs,
                        "original_filename": fn or "",
                    })
                chapters_list.append({
                    "chapter_number": ch.chapter_number or "",
                    "chapter_title":  ch.chapter_title or "",
                    "sections":       sections_list,
                })
            self._repo.save_sections(
                pdf_document_id, user_id, True,
                json.dumps(chapters_list, ensure_ascii=False), None
            )
        else:
            flat_list = []
            for sec in (body.flat_sections or []):
                fp, fs, fn = self._resolve_file_ref(sec.file_ref)
                flat_list.append({
                    "section_number":    sec.section_number or "",
                    "section_title":     sec.section_title or "",
                    "section_content":   sec.section_content or "",
                    "file_path":         fp or "",
                    "file_size":         fs,
                    "original_filename": fn or "",
                })
            self._repo.save_sections(
                pdf_document_id, user_id, False,
                None, json.dumps(flat_list, ensure_ascii=False)
            )

        return self.get_sections(pdf_document_id)

    def get_sections(self, pdf_document_id: int) -> SectionsResponse:
        data = self._repo.get_sections(pdf_document_id)
        chapter_rows: list[dict] = data["chapter_rows"]
        flat_rows: list[dict] = data["flat_rows"]

        # Reconstruct nested chapters
        chapters_map: dict[int, ChapterOut] = {}
        for row in chapter_rows:
            ch_id = row["chapter_id"]
            if ch_id and ch_id not in chapters_map:
                chapters_map[ch_id] = ChapterOut(
                    id=ch_id,
                    chapter_number=row.get("chapter_number"),
                    chapter_title=row.get("chapter_title"),
                    display_order=row.get("chapter_order", 0),
                    sections=[],
                )
            if ch_id and row.get("section_id"):
                chapters_map[ch_id].sections.append(SectionOut(
                    id=row["section_id"],
                    section_number=row.get("section_number"),
                    section_title=row.get("section_title"),
                    section_content=row.get("section_content"),
                    file_path=row.get("file_path"),
                    file_size=row.get("file_size"),
                    original_filename=row.get("original_filename"),
                    display_order=row.get("section_order", 0),
                ))

        chapters = sorted(chapters_map.values(), key=lambda c: c.display_order)

        flat_sections = [
            SectionOut(
                id=r["section_id"],
                section_number=r.get("section_number"),
                section_title=r.get("section_title"),
                section_content=r.get("section_content"),
                file_path=r.get("file_path"),
                file_size=r.get("file_size"),
                original_filename=r.get("original_filename"),
                display_order=r.get("section_order", r.get("display_order", 0)),
            )
            for r in flat_rows
        ]

        return SectionsResponse(
            has_chapters=len(chapters) > 0,
            chapters=chapters,
            flat_sections=flat_sections,
        )

    # ── Generic entries (schedule/annexure/appendix/forms) ────────────────────

    def save_entries(self, part_type: str, pdf_document_id: int, user_id: int, body: SaveEntriesRequest) -> list[EntryOut]:
        sp_type = PART_TYPE_MAP.get(part_type)
        if not sp_type:
            raise ValueError(f"Unknown part type: {part_type}")

        entries_list = []
        for entry in body.entries:
            fp, fs, fn = self._resolve_file_ref(entry.file_ref)
            entries_list.append({
                "entry_number":     entry.entry_number or "",
                "title":            entry.title or "",
                "description":      entry.description or "",
                "file_path":        fp or "",
                "file_size":        fs,
                "original_filename": fn or "",
            })

        self._repo.save_entries(sp_type, pdf_document_id, user_id, json.dumps(entries_list, ensure_ascii=False))
        return self.get_entries(part_type, pdf_document_id)

    def get_entries(self, part_type: str, pdf_document_id: int) -> list[EntryOut]:
        sp_type = PART_TYPE_MAP.get(part_type)
        if not sp_type:
            raise ValueError(f"Unknown part type: {part_type}")
        rows = self._repo.get_entries(sp_type, pdf_document_id)
        return [
            EntryOut(
                id=r["id"],
                entry_number=r.get("entry_number"),
                title=r.get("title"),
                description=r.get("description"),
                file_path=r.get("file_path"),
                file_size=r.get("file_size"),
                original_filename=r.get("original_filename"),
                display_order=r.get("display_order", 0),
                created_at=r.get("created_at"),
            )
            for r in rows
        ]

    # ── All parts ─────────────────────────────────────────────────────────────

    def get_all_parts(self, pdf_document_id: int) -> AllActPartsResponse:
        data = self._repo.get_all_parts(pdf_document_id)

        # Rebuild chapters + sections (same logic as get_sections)
        chapters_map: dict[int, ChapterOut] = {}
        for row in data.get("chapters", []):
            chapters_map[row["id"]] = ChapterOut(
                id=row["id"],
                chapter_number=row.get("chapter_number"),
                chapter_title=row.get("chapter_title"),
                display_order=row.get("display_order", 0),
                sections=[],
            )
        for row in data.get("sections", []):
            ch_id = row.get("chapter_id")
            sec_out = SectionOut(
                id=row["id"],
                section_number=row.get("section_number"),
                section_title=row.get("section_title"),
                section_content=row.get("section_content"),
                file_path=row.get("file_path"),
                file_size=row.get("file_size"),
                original_filename=row.get("original_filename"),
                display_order=row.get("display_order", 0),
            )
            if ch_id and ch_id in chapters_map:
                chapters_map[ch_id].sections.append(sec_out)

        flat_sections = [
            SectionOut(
                id=r["id"],
                section_number=r.get("section_number"),
                section_title=r.get("section_title"),
                section_content=r.get("section_content"),
                file_path=r.get("file_path"),
                file_size=r.get("file_size"),
                original_filename=r.get("original_filename"),
                display_order=r.get("display_order", 0),
            )
            for r in data.get("sections", [])
            if not r.get("chapter_id")
        ]

        def _to_entry_out(rows: list[dict]) -> list[EntryOut]:
            return [
                EntryOut(
                    id=r["id"],
                    entry_number=r.get("entry_number"),
                    title=r.get("title"),
                    description=r.get("description"),
                    file_path=r.get("file_path"),
                    file_size=r.get("file_size"),
                    original_filename=r.get("original_filename"),
                    display_order=r.get("display_order", 0),
                )
                for r in rows
            ]

        chapters = sorted(chapters_map.values(), key=lambda c: c.display_order)
        return AllActPartsResponse(
            pdf_document_id=pdf_document_id,
            has_chapters=len(chapters) > 0,
            chapters=chapters,
            flat_sections=flat_sections,
            schedules=_to_entry_out(data.get("schedules", [])),
            annexures=_to_entry_out(data.get("annexures", [])),
            appendices=_to_entry_out(data.get("appendices", [])),
            forms=_to_entry_out(data.get("forms", [])),
        )
