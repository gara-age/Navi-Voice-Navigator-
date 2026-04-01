from fastapi import APIRouter, HTTPException

from local_server.app.models.requests import SessionStartRequest
from local_server.app.models.responses import SessionStartResponse, SessionStateResponse
from local_server.app.services.session_manager import SessionManager

router = APIRouter(tags=["session"])
session_manager = SessionManager()


@router.post("/session/start", response_model=SessionStartResponse)
async def start_session(payload: SessionStartRequest) -> SessionStartResponse:
    return session_manager.start(payload)


@router.get("/session/{session_id}", response_model=SessionStateResponse)
async def get_session(session_id: str) -> SessionStateResponse:
    session = session_manager.get(session_id)
    if session is None:
        raise HTTPException(status_code=404, detail="session_not_found")
    return SessionStateResponse(session=session)
