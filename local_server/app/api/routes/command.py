import json

from fastapi import APIRouter, File, Form, HTTPException, UploadFile

from local_server.app.api.routes.session import session_manager
from local_server.app.models.requests import TextCommandRequest, VoiceCommandMetadata
from local_server.app.models.responses import CommandResponse
from local_server.app.services.orchestration_service import OrchestrationService

router = APIRouter(tags=["command"])
orchestrator = OrchestrationService(session_manager)


@router.post("/command/text", response_model=CommandResponse)
async def submit_text_command(payload: TextCommandRequest) -> CommandResponse:
    return await orchestrator.process_text_command(payload.session_id, payload.text, payload.mode)


@router.post("/command/voice", response_model=CommandResponse)
async def submit_voice_command(
    audio: UploadFile = File(...),
    metadata: str = Form(...),
) -> CommandResponse:
    parsed = VoiceCommandMetadata.model_validate(json.loads(metadata))
    try:
        return await orchestrator.process_voice_command(await audio.read(), parsed)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
