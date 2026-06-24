from typing import Generator

import pymupdf as fitz  # PyMuPDF >= 1.24 renamed the module from fitz to pymupdf


def extract_pages(file_path: str) -> Generator[tuple[int, str], None, None]:
    """
    Open a PDF and yield (page_number, text) for every page.
    Page numbers are 1-based to match what users see in a PDF viewer.
    Pages with no extractable text (e.g. image-only scans) are skipped.
    """
    doc = fitz.open(file_path)
    try:
        for index in range(len(doc)):
            text = doc[index].get_text("text").strip()
            if text:
                yield index + 1, text
    finally:
        doc.close()
