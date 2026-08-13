from typing import Optional


def convert_docx_to_pdf_bytes(docx_path: str) -> Optional[bytes]:
    """
    Convert a DOCX file to PDF bytes in memory using mammoth + weasyprint.
    Returns PDF bytes on success, None on any failure (caller falls back to serving DOCX).

    Thread-safe — pure Python, no subprocesses, no shared state.
    Requires: pip install mammoth weasyprint
    """
    try:
        import mammoth
        from weasyprint import HTML

        with open(docx_path, "rb") as f:
            result = mammoth.convert_to_html(f)

        return HTML(string=result.value).write_pdf()
    except Exception:
        return None
