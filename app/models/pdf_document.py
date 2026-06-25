from datetime import datetime, date, timezone
from sqlalchemy import String, DateTime, ForeignKey, Integer, BigInteger, Text, Date
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class PDFDocument(Base):
    __tablename__ = "pdf_documents"

    id: Mapped[int] = mapped_column(primary_key=True, index=True)
    filename: Mapped[str] = mapped_column(String(255), nullable=False)
    original_filename: Mapped[str] = mapped_column(String(255), nullable=False)
    file_path: Mapped[str] = mapped_column(String(500), nullable=False)
    file_size: Mapped[int] = mapped_column(BigInteger, nullable=False)
    act_name: Mapped[str | None] = mapped_column(String(500), nullable=True)
    gazette_reference: Mapped[str | None] = mapped_column(String(500), nullable=True)
    issuing_authority: Mapped[str | None] = mapped_column(String(255), nullable=True)
    enactment_date: Mapped[date | None] = mapped_column(Date, nullable=True)
    version_no: Mapped[str | None] = mapped_column(String(50), nullable=True, default="1.0")
    department_id: Mapped[int | None] = mapped_column(Integer, ForeignKey("departments.id"), nullable=True)
    document_type_id: Mapped[int | None] = mapped_column(Integer, ForeignKey("document_types.id"), nullable=True)
    description: Mapped[str | None] = mapped_column(Text, nullable=True)
    uploaded_by: Mapped[int] = mapped_column(Integer, ForeignKey("users.id"), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), default=lambda: datetime.now(timezone.utc)
    )

    uploaded_by_user: Mapped["User"] = relationship("User", back_populates="pdf_documents")
