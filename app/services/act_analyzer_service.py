import json
import re
from typing import Optional

import ollama

from app.core.config import settings

_ROMAN = r"(?=[MDCLXVI])M{0,4}(?:CM|CD|D?C{0,3})(?:XC|XL|L?X{0,3})(?:IX|IV|V?I{0,3})"
_CHAPTER_RE = re.compile(r"^CHAPTER\s+(" + _ROMAN + r")\s*$", re.IGNORECASE)
_SECTION_RE = re.compile(r"^\s{0,6}(\d+[A-Z]?)\.\s{1,4}(.{3,})")
_SCHEDULE_HEAD_RE = re.compile(
    r"^\s*(?:THE\s+)?(?:FIRST|SECOND|THIRD|FOURTH|FIFTH|SIXTH|SEVENTH|EIGHTH|NINTH|TENTH|SCHEDULE)\s*(" + _ROMAN + r")?",
    re.IGNORECASE,
)
_ACT_NUMBER_RE = re.compile(r"No\.\s*(\d+)\s+of\s+(\d{4})", re.IGNORECASE)
_YEAR_RE = re.compile(r"\b(19|20)\d{2}\b")


class ActAnalyzerService:

    def extract(self, pages: list[tuple[int, str]]) -> dict:
        full_text = "\n".join(text for _, text in pages)
        lines = full_text.splitlines()

        act_title, act_number, act_year = self._extract_act_meta(pages)
        toc_lines = self._find_toc(lines)
        chapters = self._parse_toc(toc_lines)
        chapters = self._enrich_section_content(chapters, lines)
        schedules = self._find_schedules(lines)

        return {
            "act_title": act_title,
            "act_number": act_number,
            "act_year": act_year,
            "chapters": chapters,
            "schedules": schedules,
        }

    # ------------------------------------------------------------------
    # Metadata extraction (Ollama on first 3 pages)
    # ------------------------------------------------------------------

    def _extract_act_meta(
        self, pages: list[tuple[int, str]]
    ) -> tuple[str, Optional[str], Optional[int]]:
        first_text = "\n".join(t for _, t in pages[:3])[:3000]

        # Regex fast-path for act number and year
        act_number: Optional[str] = None
        act_year: Optional[int] = None
        m = _ACT_NUMBER_RE.search(first_text)
        if m:
            act_number = f"No. {m.group(1)} of {m.group(2)}"
            act_year = int(m.group(2))

        # Fallback year from any 4-digit year
        if act_year is None:
            ym = _YEAR_RE.search(first_text)
            if ym:
                act_year = int(ym.group(0))

        # Try Ollama for title extraction
        act_title = "Unknown Act"
        try:
            prompt = (
                "Extract the full official title of this legal Act document. "
                'Respond with only a JSON object like: {"act_title": "The Companies Act, 2013"}\n\n'
                f"Text:\n{first_text}"
            )
            client = ollama.Client(host=settings.OLLAMA_HOST)
            resp = client.chat(
                model=settings.OLLAMA_MODEL,
                messages=[{"role": "user", "content": prompt}],
            )
            raw = resp["message"]["content"].strip()
            # Strip markdown code fences if present
            raw = re.sub(r"```(?:json)?", "", raw).strip().rstrip("```").strip()
            data = json.loads(raw)
            if data.get("act_title"):
                act_title = data["act_title"].strip()
                # Also grab number/year from Ollama response if regex missed
                if act_number is None and data.get("act_number"):
                    act_number = data["act_number"]
                if act_year is None and data.get("act_year"):
                    try:
                        act_year = int(str(data["act_year"]))
                    except ValueError:
                        pass
        except Exception:
            # Fallback: take the first non-blank line from page 1 as title
            for line in (pages[0][1] if pages else "").splitlines():
                line = line.strip()
                if len(line) > 10:
                    act_title = line
                    break

        return act_title, act_number, act_year

    # ------------------------------------------------------------------
    # TOC discovery
    # ------------------------------------------------------------------

    def _find_toc(self, lines: list[str]) -> list[str]:
        toc_start = -1
        for i, line in enumerate(lines):
            upper = line.strip().upper()
            if "ARRANGEMENT OF SECTIONS" in upper or upper == "CONTENTS":
                toc_start = i
                break

        if toc_start == -1:
            # No explicit TOC — return first 300 lines as a best-effort source
            return lines[:300]

        # Collect from toc_start until we hit a real chapter/section body
        toc_lines: list[str] = []
        body_start_patterns = [
            re.compile(r"^Be it enacted", re.IGNORECASE),
            re.compile(r"^PART\s+[IVX]+", re.IGNORECASE),
        ]
        for line in lines[toc_start:toc_start + 500]:
            toc_lines.append(line)
            if len(toc_lines) > 5 and any(p.match(line.strip()) for p in body_start_patterns):
                break

        return toc_lines

    # ------------------------------------------------------------------
    # TOC parsing → chapters list
    # ------------------------------------------------------------------

    def _parse_toc(self, toc_lines: list[str]) -> list[dict]:
        chapters: list[dict] = []
        current_chapter: Optional[dict] = None
        expect_title = False

        for line in toc_lines:
            stripped = line.strip()
            if not stripped:
                continue

            ch_match = _CHAPTER_RE.match(stripped)
            if ch_match:
                current_chapter = {
                    "chapter_number": ch_match.group(1).upper(),
                    "chapter_title": None,
                    "sections": [],
                }
                chapters.append(current_chapter)
                expect_title = True
                continue

            if expect_title and current_chapter is not None:
                if not _SECTION_RE.match(line):
                    current_chapter["chapter_title"] = stripped
                    expect_title = False
                    continue
                expect_title = False

            sec_match = _SECTION_RE.match(line)
            if sec_match:
                sec_num = sec_match.group(1)
                sec_title = sec_match.group(2).strip().rstrip(".")
                section = {
                    "section_number": sec_num,
                    "section_title": sec_title,
                    "content": None,
                }
                if current_chapter is not None:
                    current_chapter["sections"].append(section)
                else:
                    # Sections before any chapter — put in a placeholder chapter
                    placeholder = {
                        "chapter_number": None,
                        "chapter_title": "General",
                        "sections": [section],
                    }
                    if not chapters or chapters[-1]["chapter_number"] is not None:
                        chapters.append(placeholder)
                        current_chapter = placeholder
                    else:
                        chapters[-1]["sections"].append(section)

        return chapters

    # ------------------------------------------------------------------
    # Section content enrichment (scan full body text)
    # ------------------------------------------------------------------

    def _enrich_section_content(
        self, chapters: list[dict], all_lines: list[str]
    ) -> list[dict]:
        for chapter in chapters:
            for section in chapter["sections"]:
                sec_num = section["section_number"]
                content = self._extract_section_body(sec_num, all_lines)
                if content:
                    section["content"] = content
        return chapters

    def _extract_section_body(self, sec_num: str, lines: list[str]) -> Optional[str]:
        # Match a line that starts with "N." or "N. Title"
        heading_re = re.compile(
            r"^\s{0,4}" + re.escape(sec_num) + r"\.\s+\S"
        )
        next_sec_re = re.compile(r"^\s{0,4}\d+[A-Z]?\.\s+\S")

        start_idx = -1
        for i, line in enumerate(lines):
            if heading_re.match(line):
                start_idx = i
                break

        if start_idx == -1:
            return None

        body_lines: list[str] = []
        for line in lines[start_idx:start_idx + 150]:
            # Stop at next section heading (but not the first line itself)
            if body_lines and next_sec_re.match(line):
                break
            body_lines.append(line)

        content = "\n".join(body_lines).strip()
        return content[:2000] if content else None

    # ------------------------------------------------------------------
    # Schedule detection
    # ------------------------------------------------------------------

    def _find_schedules(self, lines: list[str]) -> list[dict]:
        schedules: list[dict] = []
        current: Optional[dict] = None

        ordinal_map = {
            "FIRST": "I", "SECOND": "II", "THIRD": "III", "FOURTH": "IV",
            "FIFTH": "V", "SIXTH": "VI", "SEVENTH": "VII", "EIGHTH": "VIII",
            "NINTH": "IX", "TENTH": "X",
        }

        for i, line in enumerate(lines):
            stripped = line.strip().upper()
            m = _SCHEDULE_HEAD_RE.match(stripped)
            if m:
                # Determine schedule number
                roman = m.group(1) if m and m.lastindex and m.group(1) else None
                if roman is None:
                    # Try ordinal word at start of line
                    for word, num in ordinal_map.items():
                        if stripped.startswith(word):
                            roman = num
                            break

                # Save previous schedule content
                if current is not None:
                    current["schedule_content"] = current["schedule_content"].strip()[:3000]
                    schedules.append(current)

                current = {
                    "schedule_number": roman or str(len(schedules) + 1),
                    "schedule_title": line.strip(),
                    "schedule_content": "",
                }
                continue

            if current is not None:
                current["schedule_content"] = (current["schedule_content"] + "\n" + line)

        if current is not None:
            current["schedule_content"] = current["schedule_content"].strip()[:3000]
            schedules.append(current)

        return schedules
