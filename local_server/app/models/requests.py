from typing import Any, Literal

from pydantic import BaseModel, Field


class AccessibilityPayload(BaseModel):
    large_text: bool = True
    screen_reader_enabled: bool = True


class SessionStartRequest(BaseModel):
    client: str = "flutter_windows"
    trigger_source: str = "manual"
    mode: Literal["general", "secure"] = "general"
    locale: str = "ko-KR"
    accessibility: AccessibilityPayload = Field(default_factory=AccessibilityPayload)


class TextCommandRequest(BaseModel):
    session_id: str
    text: str
    mode: Literal["general", "secure"] = "general"


class VoiceCommandMetadata(BaseModel):
    session_id: str
    audio_format: str = "wav"
    sample_rate_hz: int = 16000
    channels: int = 1
    duration_ms: int = 0
    language_hint: str = "ko"
    trigger_source: str = "manual"
    mode: Literal["general", "secure"] = "general"


class ScreenReadRequest(BaseModel):
    session_id: str
    foreground_window_only: bool = True
    detail_level: Literal["summary", "detailed"] = "summary"


class SettingsUpdateRequest(BaseModel):
    settings: dict[str, Any]
