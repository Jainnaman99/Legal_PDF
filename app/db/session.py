from typing import Generator
from urllib.parse import quote_plus

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import settings


def _build_connection_url() -> str:
    return (
        f"mysql+pymysql://{quote_plus(settings.DB_USER)}:{quote_plus(settings.DB_PASSWORD)}"
        f"@{settings.DB_SERVER}:{settings.DB_PORT}/{settings.DB_NAME}?charset=utf8mb4"
    )


engine = create_engine(_build_connection_url(), pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
