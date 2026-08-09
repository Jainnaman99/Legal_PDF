import json
import os
import uuid
from typing import Optional

from app.core.config import settings
from app.interfaces.act_parts_repository import IActPartsRepository
from app.schemas.act_parts import (
    ActPartApprovalOut,
    ActPartFileUploadResponse,
    ActPartPendingItem,
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


def _fp_basename(file_path: str) -> Optional[str]:
    """Extract the filename from a stored file_path, normalising both Windows (\\)
    and Unix (/) separators so it works regardless of which OS wrote the path."""
    return os.path.basename((file_path or "").replace("\\", "/")) or None

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
        """Return (file_path, file_size, original_filename) for a file_ref, or (None,None,None).
        Checks the act_parts sub-directory first, then falls back to the main uploads dir so that
        files uploaded before the sub-directory was introduced are still found."""
        if not file_ref:
            return None, None, None
        # file_ref may arrive as a full stored path (e.g. "uploads\\filename") — extract basename
        # and normalise separators so it works on both Windows and Linux hosts.
        basename = os.path.basename(file_ref.replace("\\", "/"))
        if not basename:
            return None, None, None
        # Primary: act_parts sub-directory (current storage location)
        full_path = os.path.join(settings.UPLOAD_DIR, _ACT_PARTS_SUBDIR, basename)
        if not os.path.exists(full_path):
            # Fallback: main uploads directory (legacy storage location)
            full_path = os.path.join(settings.UPLOAD_DIR, basename)
        if not os.path.exists(full_path):
            return None, None, None
        size = os.path.getsize(full_path)
        original = "_".join(basename.split("_")[1:]) if "_" in basename else basename
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
                        "id":               sec.id,
                        "section_number":   sec.section_number or "",
                        "section_title":    sec.section_title or "",
                        "section_content":  sec.section_content or "",
                        "file_path":        fp or "",
                        "file_size":        fs,
                        "original_filename": fn or "",
                        "is_deleted":       1 if sec.is_deleted else 0,
                    })
                chapters_list.append({
                    "id":             ch.id,
                    "chapter_number": ch.chapter_number or "",
                    "chapter_title":  ch.chapter_title or "",
                    "is_deleted":     1 if ch.is_deleted else 0,
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
                    "id":              sec.id,
                    "section_number":  sec.section_number or "",
                    "section_title":   sec.section_title or "",
                    "section_content": sec.section_content or "",
                    "file_path":       fp or "",
                    "file_size":       fs,
                    "original_filename": fn or "",
                    "is_deleted":      1 if sec.is_deleted else 0,
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
                    status=row.get("status"),
                )
            if ch_id and row.get("section_id"):
                fp = row.get("file_path") or ""
                chapters_map[ch_id].sections.append(SectionOut(
                    id=row["section_id"],
                    section_number=row.get("section_number"),
                    section_title=row.get("section_title"),
                    section_content=row.get("section_content"),
                    file_path=fp,
                    file_size=row.get("file_size"),
                    original_filename=row.get("original_filename"),
                    file_ref=_fp_basename(fp),
                    display_order=row.get("section_order", 0),
                    status=row.get("status"),
                ))

        chapters = sorted(chapters_map.values(), key=lambda c: c.display_order)

        flat_sections = [
            SectionOut(
                id=r["section_id"],
                section_number=r.get("section_number"),
                section_title=r.get("section_title"),
                section_content=r.get("section_content"),
                file_path=r.get("file_path") or "",
                file_size=r.get("file_size"),
                original_filename=r.get("original_filename"),
                file_ref=_fp_basename(r.get("file_path") or ""),
                display_order=r.get("section_order", r.get("display_order", 0)),
                status=r.get("status"),
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
                "id":              entry.id,
                "entry_number":    entry.entry_number or "",
                "title":           entry.title or "",
                "description":     entry.description or "",
                "file_path":       fp or "",
                "file_size":       fs,
                "original_filename": fn or "",
                "is_deleted":      1 if entry.is_deleted else 0,
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
                file_path=r.get("file_path") or "",
                file_size=r.get("file_size"),
                original_filename=r.get("original_filename"),
                file_ref=_fp_basename(r.get("file_path") or ""),
                display_order=r.get("display_order", 0),
                created_at=r.get("created_at"),
                status=r.get("status"),
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
                status=row.get("status"),
            )
        for row in data.get("sections", []):
            ch_id = row.get("chapter_id")
            fp = row.get("file_path") or ""
            sec_out = SectionOut(
                id=row["id"],
                section_number=row.get("section_number"),
                section_title=row.get("section_title"),
                section_content=row.get("section_content"),
                file_path=fp,
                file_size=row.get("file_size"),
                original_filename=row.get("original_filename"),
                file_ref=_fp_basename(fp),
                display_order=row.get("display_order", 0),
                status=row.get("status"),
            )
            if ch_id and ch_id in chapters_map:
                chapters_map[ch_id].sections.append(sec_out)

        flat_sections = [
            SectionOut(
                id=r["id"],
                section_number=r.get("section_number"),
                section_title=r.get("section_title"),
                section_content=r.get("section_content"),
                file_path=r.get("file_path") or "",
                file_size=r.get("file_size"),
                original_filename=r.get("original_filename"),
                file_ref=_fp_basename(r.get("file_path") or ""),
                display_order=r.get("display_order", 0),
                status=r.get("status"),
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
                    file_path=r.get("file_path") or "",
                    file_size=r.get("file_size"),
                    original_filename=r.get("original_filename"),
                    file_ref=_fp_basename(r.get("file_path") or ""),
                    display_order=r.get("display_order", 0),
                    status=r.get("status"),
                )
                for r in rows
            ]

        chapters = sorted(chapters_map.values(), key=lambda c: c.display_order)
        approvals = [ActPartApprovalOut(**r) for r in self._repo.get_approvals(pdf_document_id)]
        return AllActPartsResponse(
            pdf_document_id=pdf_document_id,
            has_chapters=len(chapters) > 0,
            chapters=chapters,
            flat_sections=flat_sections,
            schedules=_to_entry_out(data.get("schedules", [])),
            annexures=_to_entry_out(data.get("annexures", [])),
            appendices=_to_entry_out(data.get("appendices", [])),
            forms=_to_entry_out(data.get("forms", [])),
            approvals=approvals,
        )

    # ── Approval ──────────────────────────────────────────────────────────────

    def submit_for_approval(self, pdf_document_id: int, part_type: str, user_id: int) -> ActPartApprovalOut:
        row = self._repo.submit_for_approval(pdf_document_id, part_type, user_id)
        return ActPartApprovalOut(**row)

    def review_act_parts(
        self, pdf_document_id: int, part_type: str,
        reviewer_id: int, action: str, comments,
    ) -> ActPartApprovalOut:
        if action not in ("approved", "rejected"):
            raise ValueError("action must be 'approved' or 'rejected'")
        row = self._repo.review_act_parts(pdf_document_id, part_type, reviewer_id, action, comments)
        return ActPartApprovalOut(**row)

    def get_approvals(self, pdf_document_id: int) -> list[ActPartApprovalOut]:
        return [ActPartApprovalOut(**r) for r in self._repo.get_approvals(pdf_document_id)]

    def list_pending(self, approver_id: Optional[int] = None, department_id: Optional[int] = None) -> list[ActPartPendingItem]:
        return [ActPartPendingItem(**r) for r in self._repo.list_pending(approver_id=approver_id, department_id=department_id)]

    def list_my_submissions(self, user_id: int) -> list[ActPartPendingItem]:
        return [ActPartPendingItem(**r) for r in self._repo.list_my_submissions(user_id)]

    def list_all_submissions(self, approver_id: Optional[int] = None, department_id: Optional[int] = None) -> list[ActPartPendingItem]:
        return [ActPartPendingItem(**r) for r in self._repo.list_all_submissions(approver_id=approver_id, department_id=department_id)]
