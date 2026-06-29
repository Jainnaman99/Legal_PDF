from datetime import datetime, timezone
from sqlalchemy import String, DateTime, ForeignKey, Integer, Text
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class PDFDocumentApproval(Base):
    __tablename__ = "pdf_document_approvals"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    pdf_id: Mapped[int] = mapped_column(Integer, ForeignKey("pdf_documents.id"), nullable=False)
    approver_id: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
    action: Mapped[str] = mapped_column(String(20), nullable=False)
    comments: Mapped[str | None] = mapped_column(Text, nullable=True)
    acted_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )
