from datetime import datetime

from sqlalchemy import DateTime, ForeignKey, Integer, Text
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    pass


class PDFApprovalDraft(Base):
    __tablename__ = "pdf_approval_drafts"

    id:               Mapped[int]           = mapped_column(Integer, primary_key=True, autoincrement=True)
    pdf_id:           Mapped[int]           = mapped_column(Integer, ForeignKey("pdf_documents.id", ondelete="CASCADE"), nullable=False)
    approver_id:      Mapped[int]           = mapped_column(Integer, ForeignKey("users.id",          ondelete="CASCADE"), nullable=False)
    comments:         Mapped[str | None]    = mapped_column(Text,    nullable=True)
    annotations_json: Mapped[str | None]    = mapped_column(Text,    nullable=True)
    saved_at:         Mapped[datetime]      = mapped_column(DateTime, nullable=False)
