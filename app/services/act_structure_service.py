import io
from typing import Optional

from app.interfaces.act_structure_repository import IActStructureRepository
from app.models.act_structure import ActStructure
from app.services.act_analyzer_service import ActAnalyzerService


class ActStructureService:

    def __init__(self, repo: IActStructureRepository):
        self._repo = repo
        self._analyzer = ActAnalyzerService()

    # ------------------------------------------------------------------
    # Dropdown support
    # ------------------------------------------------------------------

    def list_available_acts(self, query: str = "") -> list[dict]:
        return self._repo.list_available_acts(query)

    # ------------------------------------------------------------------
    # Main upload-and-analyze flow
    # ------------------------------------------------------------------

    def upload_and_analyze(
        self, pdf_document_id: int, filename: str, file_bytes: bytes
    ) -> ActStructure:
        pages = self._extract_text_from_bytes(filename, file_bytes)
        if not pages:
            raise ValueError("No text could be extracted from the uploaded file")

        structure = self._repo.create_structure(pdf_document_id, "Extracting...", None, None)
        try:
            result = self._analyzer.extract(pages)

            # Update act title/number/year on the master record
            obj = self._repo.get_by_id(structure.id)
            if obj:
                obj.act_title = result["act_title"] or "Unknown Act"
                obj.act_number = result.get("act_number")
                obj.act_year = result.get("act_year")
                self._repo._db.commit()  # type: ignore[attr-defined]

            total_sections = 0
            for i, ch in enumerate(result["chapters"]):
                ch_id = self._repo.add_chapter(
                    structure.id,
                    ch.get("chapter_number"),
                    ch.get("chapter_title"),
                    i,
                )
                for j, sec in enumerate(ch["sections"]):
                    self._repo.add_section(
                        structure.id,
                        ch_id,
                        sec.get("section_number"),
                        sec.get("section_title"),
                        sec.get("content"),
                        j,
                    )
                    total_sections += 1

            for i, sch in enumerate(result["schedules"]):
                self._repo.add_schedule(
                    structure.id,
                    sch.get("schedule_number"),
                    sch.get("schedule_title"),
                    sch.get("schedule_content"),
                    i,
                )

            self._repo.update_totals(
                structure.id,
                len(result["chapters"]),
                total_sections,
                len(result["schedules"]),
            )
            self._repo.update_status(structure.id, "completed")

        except Exception as exc:
            self._repo.update_status(structure.id, "failed", str(exc))
            raise

        return self._repo.get_by_id(structure.id)

    # ------------------------------------------------------------------
    # Text extraction from file bytes
    # ------------------------------------------------------------------

    def _extract_text_from_bytes(
        self, filename: str, content: bytes
    ) -> list[tuple[int, str]]:
        lower = (filename or "").lower()
        if lower.endswith(".docx"):
            return self._extract_docx(content)
        return self._extract_pdf(content)

    @staticmethod
    def _extract_pdf(content: bytes) -> list[tuple[int, str]]:
        try:
            import fitz  # PyMuPDF

            doc = fitz.open(stream=content, filetype="pdf")
            pages: list[tuple[int, str]] = []
            for page_num, page in enumerate(doc, start=1):
                text = page.get_text()
                if text.strip():
                    pages.append((page_num, text))
            return pages
        except Exception:
            pass

        # Fallback: PyPDF2
        try:
            import PyPDF2

            reader = PyPDF2.PdfReader(io.BytesIO(content))
            pages = []
            for page_num, page in enumerate(reader.pages, start=1):
                text = page.extract_text() or ""
                if text.strip():
                    pages.append((page_num, text))
            return pages
        except Exception:
            return []

    @staticmethod
    def _extract_docx(content: bytes) -> list[tuple[int, str]]:
        try:
            from docx import Document

            doc = Document(io.BytesIO(content))
            chunk_size = 50  # paragraphs per "page"
            paras = [p.text for p in doc.paragraphs if p.text.strip()]
            pages: list[tuple[int, str]] = []
            for i in range(0, len(paras), chunk_size):
                chunk = "\n".join(paras[i: i + chunk_size])
                pages.append((len(pages) + 1, chunk))
            return pages
        except Exception:
            return []

    # ------------------------------------------------------------------
    # Read endpoints
    # ------------------------------------------------------------------

    def get_by_id(self, structure_id: int) -> Optional[ActStructure]:
        return self._repo.get_by_id(structure_id)

    def get_by_document(self, pdf_document_id: int) -> Optional[ActStructure]:
        return self._repo.get_by_pdf_document_id(pdf_document_id)

    def list_all(self) -> list[ActStructure]:
        return self._repo.list_all()
