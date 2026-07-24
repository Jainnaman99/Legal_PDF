import ollama

from app.core.config import settings
from app.services.vector_store_service import VectorStoreService

_SYSTEM_PROMPT = (
    "You are a legal document assistant for Indian government documents. "
    "Answer the user's question using ONLY the provided document excerpts. "
    "Be concise (2-4 sentences). Mention the document name if relevant. "
    "If the excerpts do not contain enough information, say so clearly."
)


class RAGService:
    def __init__(self, vector_store: "VectorStoreService | None"):
        self._vs = vector_store

    def answer(self, question: str, top_k: int = 5) -> dict:
        if self._vs is None:
            return {
                "answer": "Semantic search is temporarily unavailable (vector store not initialized).",
                "sources": [],
            }
        chunks = self._vs.search(question, top_k)
        if not chunks:
            return {
                "answer": "No relevant documents found in the database for your question.",
                "sources": [],
            }

        context = "\n\n---\n\n".join(
            f"[{c['metadata']['document_name']} | Page {c['metadata']['page_number']}]\n"
            f"{c['text'][:1500]}"
            for c in chunks
        )
        user_msg = f"Context:\n{context}\n\nQuestion: {question}"

        client = ollama.Client(host=settings.OLLAMA_HOST)
        resp = client.chat(
            model=settings.OLLAMA_MODEL,
            messages=[
                {"role": "system", "content": _SYSTEM_PROMPT},
                {"role": "user",   "content": user_msg},
            ],
        )
        answer_text = resp["message"]["content"].strip()

        sources = [
            {
                "pdf_id":          int(c["metadata"]["pdf_id"]),
                "document_name":   c["metadata"]["document_name"],
                "document_type":   c["metadata"]["document_type_name"],
                "department":      c["metadata"]["department_name"],
                "page_number":     int(c["metadata"]["page_number"]),
                "relevance_score": c["relevance_score"],
                "snippet":         c["text"][:300],
            }
            for c in chunks
        ]
        return {"answer": answer_text, "sources": sources}
