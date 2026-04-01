from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from local_server.app.services.websocket_broker import broker

router = APIRouter(tags=["websocket"])


@router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket) -> None:
    session_id = websocket.query_params.get("session_id", "default")
    await websocket.accept()
    queue = broker.subscribe(session_id)
    await websocket.send_json(
        {
            "type": "status",
            "session_id": session_id,
            "state": "ready",
            "message": "Voice Navigator local server connected",
        }
    )
    try:
        while True:
            event = await queue.get()
            await websocket.send_json(event)
    except WebSocketDisconnect:
        broker.unsubscribe(session_id, queue)
