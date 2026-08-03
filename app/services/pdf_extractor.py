import io
import os
from typing import Generator

import pymupdf as fitz
import pytesseract
from PIL import Image

from app.core.config import settings

if settings.TESSERACT_CMD:
    pytesseract.pytesseract.tesseract_cmd = settings.TESSERACT_CMD


def extract_pages(file_path: str) -> Generator[tuple[int, str], None, None]:
    ext = os.path.splitext(file_path)[1].lower()
    if ext == ".docx":
        yield from _extract_docx(file_path)
    else:
        yield from _extract_pdf(file_path)


def _is_garbled_devanagari(text: str) -> bool:
    """Detect non-standard font encoding where PyMuPDF extracts wrong Unicode glyphs.

    Broken encodings produce an abnormally high frequency of 'ष' (sha) — a rare
    consonant in natural Hindi — because it maps to a common glyph slot in those fonts.
    """
    devanagari = [c for c in text if 'ऀ' <= c <= 'ॿ']
    if len(devanagari) < 50:
        return False
    return text.count('ष') / len(devanagari) > 0.05


def _ocr_page(page) -> str:
    pix = page.get_pixmap(matrix=fitz.Matrix(2, 2))
    img = Image.open(io.BytesIO(pix.tobytes("png")))
    return pytesseract.image_to_string(img, lang=settings.TESSERACT_LANG).strip()


def _extract_pdf(file_path: str) -> Generator[tuple[int, str], None, None]:
    doc = fitz.open(file_path)
    try:
        for index in range(len(doc)):
            page = doc[index]
            text = page.get_text("text").strip()

            if not text or _is_garbled_devanagari(text):
                # Scanned page or broken font encoding — render at 2× and OCR
                text = _ocr_page(page)

            if text:
                yield index + 1, text
    finally:
        doc.close()


def _extract_docx(file_path: str) -> Generator[tuple[int, str], None, None]:
    import docx  # imported lazily — python-docx is optional for PDF-only deployments
    doc = docx.Document(file_path)
    text = "\n".join(p.text for p in doc.paragraphs if p.text.strip())
    if text:
        yield 1, text
