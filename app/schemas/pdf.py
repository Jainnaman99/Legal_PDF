from datetime import datetime
from typing import Optional
from pydantic import BaseModel


class PDFUploadResponse(BaseModel):
    id: int
    filename: str
    original_filename: str
    file_size: int
    description: Optional[str] = None
    uploaded_by: int
    created_at: datetime

    model_config = {"from_attributes": True}


class PDFListItem(BaseModel):
    id: int
    original_filename: str
    file_size: int
    description: Optional[str] = None
    uploaded_by: int
    created_at: datetime

    model_config = {"from_attributes": True}
