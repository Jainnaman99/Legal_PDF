import chromadb

from app.core.config import settings
from app.services.embedding_service import EmbeddingService

_COLLECTION = "legal_pdf_pages"


class VectorStoreService:
    def __init__(self):
        self._client = self._make_client()
        self._col = self._client.get_or_create_collection(
            _COLLECTION,
            metadata={"hnsw:space": "cosine"},
        )
        self._embedder = EmbeddingService()

    @staticmethod
    def _make_client():
        try:
            return chromadb.PersistentClient(path=settings.CHROMA_DIR)
        except AttributeError:
            # chromadb 0.6.x Rust backend bug: stale SharedSystemClient from a prior
            # hot-reload holds a broken RustBindingsAPI with no 'bindings' attr.
            # Clear the registry so the next call starts clean.
            try:
                from chromadb.api.shared_system_client import SharedSystemClient
                if hasattr(SharedSystemClient, "_identifier_to_system"):
                    SharedSystemClient._identifier_to_system.clear()
            except Exception:
                pass
            return chromadb.PersistentClient(path=settings.CHROMA_DIR)

    def index_pages(
        self,
        pdf_id: int,
        document_name: str,
        document_type_name: str,
        department_name: str,
        pages: list[tuple[int, str]],
    ) -> None:
        for page_num, text in pages:
            if not text.strip():
                continue
            embedding = self._embedder.embed(text)
            self._col.upsert(
                ids=[f"{pdf_id}_p{page_num}"],
                embeddings=[embedding],
                documents=[text],
                metadatas=[{
                    "pdf_id": pdf_id,
                    "page_number": page_num,
                    "document_name": document_name or "",
                    "document_type_name": document_type_name or "",
                    "department_name": department_name or "",
                }],
            )

    def search(self, question: str, top_k: int = 5) -> list[dict]:
        count = self._col.count()
        if count == 0:
            return []
        n = min(top_k, count)
        embedding = self._embedder.embed(question)
        results = self._col.query(
            query_embeddings=[embedding],
            n_results=n,
            include=["documents", "metadatas", "distances"],
        )
        out = []
        for doc, meta, dist in zip(
            results["documents"][0],
            results["metadatas"][0],
            results["distances"][0],
        ):
            out.append({
                "text": doc,
                "metadata": meta,
                "relevance_score": round(1 - dist, 4),  # cosine distance → similarity
            })
        return out
