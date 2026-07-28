import os

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from app.api.v1.router import router
from app.core.config import settings

app = FastAPI(title=settings.APP_NAME, version="1.0.0")

app.include_router(router)

os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=settings.UPLOAD_DIR), name="uploads")


@app.get("/health", tags=["Health"])
def health_check():
    return {"status": "ok"}
