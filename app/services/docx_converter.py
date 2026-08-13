import logging
from typing import Optional

logger = logging.getLogger(__name__)


def convert_docx_to_pdf_bytes(docx_path: str) -> Optional[bytes]:
    """
    Convert a DOCX file to PDF bytes in memory using mammoth + weasyprint.
    Returns PDF bytes on success, None on any failure.
    Thread-safe — pure Python, no subprocesses, no shared state.
    """
    try:
        import mammoth
        from weasyprint import HTML

        with open(docx_path, "rb") as f:
            result = mammoth.convert_to_html(f)

        css = """
            @page { margin: 1.5cm; }
            body { font-family: Arial, sans-serif; font-size: 11pt; line-height: 1.6; }
            img { max-width: 100%; height: auto; display: block; }
            table { width: 100%; border-collapse: collapse; table-layout: fixed; word-wrap: break-word; }
            td, th { padding: 4px 8px; overflow-wrap: break-word; }
        """
        html = f"<!DOCTYPE html><html><head><meta charset='utf-8'><style>{css}</style></head><body>{result.value}</body></html>"
        return HTML(string=html).write_pdf()
    except Exception as e:
        logger.error("DOCX→PDF conversion failed for %s: %s", docx_path, e, exc_info=True)
        return None
