from typing import Optional

from sqlalchemy import text
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.interfaces.tag_repository import ITagRepository
from app.models.tag import Tag


class TagRepository(ITagRepository):

    def __init__(self, db: Session):
        self._db = db

    def list_all(self) -> list[Tag]:
        result = self._db.execute(text("EXEC sp_list_tags"))
        return [self._map_row(row) for row in result.mappings().fetchall()]

    def get_by_id(self, tag_id: int) -> Optional[Tag]:
        result = self._db.execute(
            text("EXEC sp_get_tag_by_id @tag_id = :tag_id"),
            {"tag_id": tag_id},
        )
        row = result.mappings().fetchone()
        return self._map_row(row) if row else None

    def create(self, name: str, parent_id: Optional[int] = None) -> Tag:
        try:
            result = self._db.execute(
                text("EXEC sp_create_tag @name = :name, @parent_id = :parent_id"),
                {"name": name, "parent_id": parent_id},
            )
            row = result.mappings().fetchone()
            self._db.commit()
            return self._map_row(row)
        except IntegrityError:
            self._db.rollback()
            raise ValueError("A tag with this name already exists")

    def save_document_tags(self, pdf_id: int, tag_ids: list[int]) -> None:
        if not tag_ids:
            return
        tag_ids_str = ",".join(str(i) for i in tag_ids)
        self._db.execute(
            text("EXEC sp_save_pdf_document_tags @pdf_id = :pdf_id, @tag_ids = :tag_ids"),
            {"pdf_id": pdf_id, "tag_ids": tag_ids_str},
        )
        self._db.commit()

    @staticmethod
    def _map_row(row) -> Tag:
        d = dict(row)
        tag = Tag(
            id=d["id"],
            name=d["name"],
            parent_id=d.get("parent_id"),
            created_at=d["created_at"],
        )
        tag.parent_name = d.get("parent_name")
        return tag
