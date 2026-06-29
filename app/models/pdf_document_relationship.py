from datetime import datetime, timezone
from sqlalchemy import String, DateTime, ForeignKey, Integer
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class PDFDocumentRelationship(Base):
    __tablename__ = "pdf_document_relationships"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    source_pdf_id: Mapped[int] = mapped_column(Integer, ForeignKey("pdf_documents.id"), nullable=False)
    target_pdf_id: Mapped[int] = mapped_column(Integer, ForeignKey("pdf_documents.id"), nullable=False)
    relationship_type: Mapped[str] = mapped_column(String(50), nullable=False, default="related")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
