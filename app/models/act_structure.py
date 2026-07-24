from datetime import datetime
from typing import Optional, List

from sqlalchemy import String, Integer, Text, DateTime, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db.base import Base


class ActStructure(Base):
    __tablename__ = "act_structures"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    pdf_document_id: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    act_title: Mapped[str] = mapped_column(String(500), nullable=False)
    act_number: Mapped[Optional[str]] = mapped_column(String(100), nullable=True)
    act_year: Mapped[Optional[int]] = mapped_column(Integer, nullable=True)
    total_chapters: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    total_sections: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    total_schedules: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    extraction_status: Mapped[str] = mapped_column(String(20), nullable=False, default="pending")
    error_message: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime, default=datetime.utcnow, onupdate=datetime.utcnow, nullable=False
    )

    chapters: Mapped[List["ActChapter"]] = relationship(
        "ActChapter",
        back_populates="structure",
        cascade="all, delete-orphan",
        order_by="ActChapter.display_order",
    )
    schedules: Mapped[List["ActSchedule"]] = relationship(
        "ActSchedule",
        back_populates="structure",
        cascade="all, delete-orphan",
        order_by="ActSchedule.display_order",
    )


class ActChapter(Base):
    __tablename__ = "act_chapters"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    act_structure_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("act_structures.id", ondelete="CASCADE"), nullable=False
    )
    chapter_number: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    chapter_title: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    chapter_description: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    display_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)

    structure: Mapped["ActStructure"] = relationship("ActStructure", back_populates="chapters")
    sections: Mapped[List["ActSection"]] = relationship(
        "ActSection",
        back_populates="chapter",
        cascade="all, delete-orphan",
        order_by="ActSection.display_order",
    )


class ActSection(Base):
    __tablename__ = "act_sections"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    act_structure_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("act_structures.id", ondelete="CASCADE"), nullable=False
    )
    act_chapter_id: Mapped[Optional[int]] = mapped_column(
        Integer, ForeignKey("act_chapters.id", ondelete="SET NULL"), nullable=True
    )
    section_number: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    section_title: Mapped[Optional[str]] = mapped_column(String(1000), nullable=True)
    section_content: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    display_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)

    chapter: Mapped[Optional["ActChapter"]] = relationship("ActChapter", back_populates="sections")


class ActSchedule(Base):
    __tablename__ = "act_schedules"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    act_structure_id: Mapped[int] = mapped_column(
        Integer, ForeignKey("act_structures.id", ondelete="CASCADE"), nullable=False
    )
    schedule_number: Mapped[Optional[str]] = mapped_column(String(50), nullable=True)
    schedule_title: Mapped[Optional[str]] = mapped_column(String(500), nullable=True)
    schedule_content: Mapped[Optional[str]] = mapped_column(Text, nullable=True)
    display_order: Mapped[int] = mapped_column(Integer, nullable=False, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, nullable=False)

    structure: Mapped["ActStructure"] = relationship("ActStructure", back_populates="schedules")
