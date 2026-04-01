from fastapi import APIRouter

from local_server.app.api.routes.command import orchestrator
from local_server.app.models.requests import ScreenReadRequest
from local_server.app.models.responses import ScreenReadResponse

router = APIRouter(tags=["screen"])


@router.post("/screen/read", response_model=ScreenReadResponse)
async def read_screen(payload: ScreenReadRequest) -> ScreenReadResponse:
    return await orchestrator.process_screen_read(payload.session_id, payload.detail_level)
