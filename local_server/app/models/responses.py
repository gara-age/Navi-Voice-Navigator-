from typing import Any

from pydantic import BaseModel, Field

from local_server.app.models.session import SessionState


class SessionStartResponse(BaseModel):
    session_id: str
    status: str
    websocket_channel: str


class CommandResponse(BaseModel):
    session_id: str
    status: str
    transcript: str
    summary: str
    follow_up: str | None = None
    results_preview: list[dict[str, Any]] = Field(default_factory=list)
    tts: dict[str, Any] = Field(default_factory=dict)


class ScreenReadResponse(BaseModel):
    session_id: str
    status: str
    summary: str


class SettingsUpdateResponse(BaseModel):
    status: str
    applied_settings: dict[str, Any]


class SettingsResponse(BaseModel):
    settings: dict[str, Any]


class SessionStateResponse(BaseModel):
    session: SessionState
