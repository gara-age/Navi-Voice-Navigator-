from pathlib import Path

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from local_server.app.api.routes import (
    background,
    command,
    health,
    screen,
    session,
    settings,
    websocket,
)


def create_app() -> FastAPI:
    runtime_dir = Path("runtime")
    tts_dir = runtime_dir / "tts"
    tts_dir.mkdir(parents=True, exist_ok=True)

    app = FastAPI(title="Voice Navigator Local Server", version="0.1.0")
    app.include_router(background.router)
    app.include_router(session.router)
    app.include_router(command.router)
    app.include_router(screen.router)
    app.include_router(settings.router)
    app.include_router(health.router)
    app.include_router(websocket.router)
    app.mount("/tts", StaticFiles(directory=tts_dir), name="tts")
    return app


app = create_app()
