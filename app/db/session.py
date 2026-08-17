from contextvars import ContextVar
from typing import Generator
from urllib.parse import quote_plus

from sqlalchemy import create_engine, event
from sqlalchemy.orm import Session, sessionmaker

from app.core.config import settings

_audit_user_id: ContextVar[int | None] = ContextVar("_audit_user_id", default=None)
_SENTINEL = object()


def set_audit_user_id(user_id: int | None) -> None:
    _audit_user_id.set(user_id)


def _build_connection_url() -> str:
    return (
        f"mysql+pymysql://{quote_plus(settings.DB_USER)}:{quote_plus(settings.DB_PASSWORD)}"
        f"@{settings.DB_SERVER}:{settings.DB_PORT}/{settings.DB_NAME}?charset=utf8mb4"
    )


engine = create_engine(_build_connection_url(), pool_pre_ping=True)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@event.listens_for(engine, "before_cursor_execute")
def _inject_audit_user(conn, cursor, statement, parameters, context, executemany):
    user_id = _audit_user_id.get()
    last = getattr(conn, "_audit_uid", _SENTINEL)
    if last is _SENTINEL or last != user_id:
        if user_id is not None:
            cursor.execute("SET @app_user_id = %s", (user_id,))
        else:
            cursor.execute("SET @app_user_id = NULL")
        conn._audit_uid = user_id


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
