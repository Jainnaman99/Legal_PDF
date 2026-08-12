import os
import subprocess
from typing import Optional

_SOFFICE_CANDIDATES = [
    "soffice",                                                  # Linux / macOS (in PATH)
    "libreoffice",                                              # Linux alternate alias
    r"C:\Program Files\LibreOffice\program\soffice.exe",       # Windows default install
    r"C:\Program Files (x86)\LibreOffice\program\soffice.exe",
]


def _find_soffice() -> Optional[str]:
    for candidate in _SOFFICE_CANDIDATES:
        try:
            subprocess.run([candidate, "--version"], capture_output=True, timeout=10)
            return candidate
        except Exception:
            continue
    return None


def convert_docx_to_pdf(docx_path: str, timeout: int = 60) -> Optional[str]:
    """
    Convert a DOCX file to PDF using LibreOffice headless.
    Output PDF is written to the same directory as the input.
    Returns the PDF path on success, None on any failure (caller keeps the DOCX).

    Requires LibreOffice:
      Linux  : sudo apt install libreoffice
      Windows: https://www.libreoffice.org/download
    """
    soffice = _find_soffice()
    if not soffice:
        return None
    try:
        out_dir = os.path.dirname(os.path.abspath(docx_path))
        result = subprocess.run(
            [soffice, "--headless", "--convert-to", "pdf", "--outdir", out_dir, docx_path],
            capture_output=True,
            text=True,
            timeout=timeout,
        )
        if result.returncode != 0:
            return None
        pdf_path = os.path.splitext(docx_path)[0] + ".pdf"
        return pdf_path if os.path.exists(pdf_path) else None
    except Exception:
        return None
