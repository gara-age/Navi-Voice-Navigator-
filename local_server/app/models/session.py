from datetime import datetime
from typing import Any

from pydantic import BaseModel, Field


class SessionState(BaseModel):
    session_id: str
    mode: str
    status: str = "ready"
    transcript: str | None = None
    summary: str | None = None
    follow_up: str | None = None
    results_preview: list[dict[str, Any]] = Field(default_factory=list)
    created_at: datetime = Field(default_factory=datetime.utcnow)
    updated_at: datetime = Field(default_factory=datetime.utcnow)
