from pydantic import BaseModel


class BackgroundEventRequest(BaseModel):
    event: str
    timestamp: str
    source: str = "background_service"
    session_hint: str | None = None
