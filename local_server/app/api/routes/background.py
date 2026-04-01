from fastapi import APIRouter

from local_server.app.api.routes.session import session_manager
from local_server.app.models.background import BackgroundEventRequest
from local_server.app.services.websocket_broker import broker

router = APIRouter(tags=["background"])


@router.post("/background/event")
async def receive_background_event(payload: BackgroundEventRequest) -> dict[str, str]:
    session_id = payload.session_hint or "background"
    if payload.session_hint and session_manager.get(payload.session_hint) is None:
        session_manager.create_with_id(payload.session_hint, mode="general")

    await broker.publish(
        session_id,
        {
            "type": "background_event",
            "session_id": session_id,
            "event": payload.event,
            "timestamp": payload.timestamp,
            "source": payload.source,
        },
    )
    return {"status": "accepted"}
