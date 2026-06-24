from fastapi import FastAPI

from app.api.v1.router import router
from app.core.config import settings

app = FastAPI(title=settings.APP_NAME, version="1.0.0")

app.include_router(router)


@app.get("/health", tags=["Health"])
def health_check():
    return {"status": "ok"}
