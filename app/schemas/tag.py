from datetime import datetime
from typing import Optional
from pydantic import BaseModel


class TagOut(BaseModel):
    id: int
    name: str
    parent_id: Optional[int] = None
    parent_name: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class TagCreate(BaseModel):
    name: str
    parent_id: Optional[int] = None


class TagRef(BaseModel):
    id: int
    name: str
