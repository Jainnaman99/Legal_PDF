from datetime import datetime
from typing import Optional, List

from sqlalchemy import BigInteger, Integer, String, Text, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class ActPartChapter(Base):
    __tablename__ = "act_part_chapters"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    pdf_document_id: Mapped[int] = mapped_column(Integer, nullable=False)
    chapter_number: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    chapter_title: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    display_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_by: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)

    sections: Mapped[List["ActPartSection"]] = relationship(
        "ActPartSection",
        back_populates="chapter",
        cascade="all, delete-orphan",
        order_by="ActPartSection.display_order",
    )


class ActPartSection(Base):
    __tablename__ = "act_part_sections"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    pdf_document_id: Mapped[int] = mapped_column(Integer, nullable=False)
    chapter_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("act_part_chapters.id", ondelete="SET NULL"), nullable=True
    )
    section_number: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    section_title: Mapped[Optional[str]] = mapped_column(String(1000), nullable=True)
    section_content: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    file_path: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    file_size: Mapped[Optional[int]] = mapped_column(BigInteger, nullable=True)
    original_filename: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    display_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_by: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)

    chapter: Mapped[Optional["ActPartChapter"]] = relationship("ActPartChapter", back_populates="sections")


class ActPartSchedule(Base):
    __tablename__ = "act_part_schedules"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    pdf_document_id: Mapped[int] = mapped_column(Integer, nullable=False)
    entry_number: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    title: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    file_path: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    file_size: Mapped[Optional[int]] = mapped_column(BigInteger, nullable=True)
    original_filename: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    display_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_by: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)


class ActPartAnnexure(Base):
    __tablename__ = "act_part_annexures"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    pdf_document_id: Mapped[int] = mapped_column(Integer, nullable=False)
    entry_number: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    title: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    file_path: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    file_size: Mapped[Optional[int]] = mapped_column(BigInteger, nullable=True)
    original_filename: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    display_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_by: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)


class ActPartAppendix(Base):
    __tablename__ = "act_part_appendices"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    pdf_document_id: Mapped[int] = mapped_column(Integer, nullable=False)
    entry_number: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    title: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    file_path: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    file_size: Mapped[Optional[int]] = mapped_column(BigInteger, nullable=True)
    original_filename: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    display_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_by: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)


class ActPartForm(Base):
    __tablename__ = "act_part_forms"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    pdf_document_id: Mapped[int] = mapped_column(Integer, nullable=False)
    entry_number: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    title: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    file_path: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    file_size: Mapped[Optional[int]] = mapped_column(BigInteger, nullable=True)
    original_filename: Mapped[Optional[str]] = mapped_column(String(255), nullable=True)
    display_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_by: Mapped[int] = mapped_column(Integer, nullable=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)
