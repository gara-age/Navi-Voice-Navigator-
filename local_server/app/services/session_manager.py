from datetime import datetime

from local_server.app.models.session import SessionState
from local_server.app.models.requests import SessionStartRequest
from local_server.app.models.responses import SessionStartResponse


class SessionManager:
    def __init__(self) -> None:
        self._sessions: dict[str, SessionState] = {}

    def start(self, payload: SessionStartRequest) -> SessionStartResponse:
        stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        session_id = f"sess_{stamp}"
        self._sessions[session_id] = SessionState(session_id=session_id, mode=payload.mode)
        return SessionStartResponse(
            session_id=session_id,
            status="ready",
            websocket_channel=f"ws://127.0.0.1:18400/ws?session_id={session_id}",
        )

    def create_with_id(self, session_id: str, mode: str) -> None:
        if session_id not in self._sessions:
            self._sessions[session_id] = SessionState(session_id=session_id, mode=mode)

    def get(self, session_id: str) -> SessionState | None:
        return self._sessions.get(session_id)

    def update_status(self, session_id: str, status: str) -> None:
        session = self._sessions.get(session_id)
        if session is None:
            return
        session.status = status
        session.updated_at = datetime.utcnow()

    def update_result(
        self,
        session_id: str,
        *,
        transcript: str | None = None,
        summary: str | None = None,
        follow_up: str | None = None,
        results_preview: list[dict] | None = None,
        status: str,
    ) -> None:
        session = self._sessions.get(session_id)
        if session is None:
            return
        session.status = status
        session.transcript = transcript
        session.summary = summary
        session.follow_up = follow_up
        session.results_preview = results_preview or []
        session.updated_at = datetime.utcnow()
