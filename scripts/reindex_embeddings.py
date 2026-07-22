"""
One-time script to embed all existing documents into ChromaDB.
Run from the project root:
    python scripts/reindex_embeddings.py
"""
import sys

sys.path.insert(0, ".")

from app.db.session import SessionLocal
from app.repositories.pdf_page_repository import PDFPageRepository
from app.repositories.pdf_repository import PDFRepository
from app.services.vector_store_service import VectorStoreService

db = SessionLocal()
pdf_repo = PDFRepository(db)
page_repo = PDFPageRepository(db)
vs = VectorStoreService()

_, docs = pdf_repo.list_all(skip=0, limit=10000)
print(f"Found {len(docs)} documents to index.")

for doc in docs:
    pages = page_repo.get_pages_by_document(doc.id)
    if not pages:
        print(f"  Skipping doc {doc.id} — no pages stored.")
        continue
    try:
        vs.index_pages(
            pdf_id=doc.id,
            document_name=doc.document_name or doc.original_filename or "",
            document_type_name=getattr(doc, "document_type_name", "") or "",
            department_name=getattr(doc, "department_name", "") or "",
            pages=pages,
        )
        print(f"  Indexed doc {doc.id}: {doc.document_name} ({len(pages)} pages)")
    except Exception as exc:
        print(f"  ERROR indexing doc {doc.id}: {exc}")

db.close()
print("Done.")
