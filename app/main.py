import os

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from starlette.types import ASGIApp, Receive, Scope, Send

from app.api.v1.router import router
from app.core.config import settings
from app.core.security import decode_access_token
from app.db.session import set_audit_user_id


class _AuditUserMiddleware:
    """
    Decodes the Bearer token on every request and stores the user_id in a
    ContextVar before any route handler or dependency runs.
    Because this is async (runs in the event loop), asyncio copies the
    ContextVar value into every thread-pool call for the same request, so
    the SQLAlchemy before_cursor_execute listener can read it reliably.
    """

    def __init__(self, app: ASGIApp) -> None:
        self.app = app

    async def __call__(self, scope: Scope, receive: Receive, send: Send) -> None:
        if scope["type"] == "http":
            headers = dict(scope.get("headers", []))
            auth = headers.get(b"authorization", b"").decode("latin-1")
            if auth.startswith("Bearer "):
                payload = decode_access_token(auth[7:])
                if payload and payload.get("sub"):
                    set_audit_user_id(int(payload["sub"]))
        await self.app(scope, receive, send)


app = FastAPI(title=settings.APP_NAME, version="1.0.0")
app.add_middleware(_AuditUserMiddleware)

app.include_router(router)

os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
app.mount("/uploads", StaticFiles(directory=settings.UPLOAD_DIR), name="uploads")


@app.get("/health", tags=["Health"])
def health_check():
    return {"status": "ok"}
