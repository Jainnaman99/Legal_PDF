import ollama

from app.core.config import settings


class EmbeddingService:
    def embed(self, text: str) -> list[float]:
        client = ollama.Client(host=settings.OLLAMA_HOST)
        resp = client.embeddings(model=settings.EMBED_MODEL, prompt=text[:8000])
        return resp["embedding"]
