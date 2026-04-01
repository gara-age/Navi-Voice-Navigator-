from datetime import datetime

import httpx

from config import BackgroundConfig


class EventDispatcher:
    def __init__(self, config: BackgroundConfig) -> None:
        self.config = config

    def build_event(self, name: str, session_hint: str | None = None) -> dict[str, str]:
        payload = {
            "event": name,
            "timestamp": datetime.now().astimezone().isoformat(),
            "source": "background_service",
        }
        if session_hint:
            payload["session_hint"] = session_hint
        return payload

    def send(self, name: str, session_hint: str | None = None) -> dict[str, str]:
        payload = self.build_event(name, session_hint)
        try:
            with httpx.Client(timeout=3.0) as client:
                client.post(f"{self.config.server_base_url}/background/event", json=payload)
        except Exception:
            pass
        return payload
