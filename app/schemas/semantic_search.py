from pydantic import BaseModel


class SemanticSource(BaseModel):
    pdf_id: int
    document_name: str
    document_type: str
    department: str
    page_number: int
    relevance_score: float
    snippet: str
    file_url: str


class SemanticSearchResponse(BaseModel):
    question: str
    answer: str
    sources: list[SemanticSource]
