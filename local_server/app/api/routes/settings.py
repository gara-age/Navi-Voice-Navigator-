from fastapi import APIRouter

from local_server.app.models.requests import SettingsUpdateRequest
from local_server.app.models.responses import SettingsResponse, SettingsUpdateResponse
from local_server.app.services.settings_service import SettingsService

router = APIRouter(tags=["settings"])
settings_service = SettingsService()


@router.get("/settings/current", response_model=SettingsResponse)
async def get_settings() -> SettingsResponse:
    return SettingsResponse(settings=settings_service.load())


@router.post("/settings/update", response_model=SettingsUpdateResponse)
async def update_settings(payload: SettingsUpdateRequest) -> SettingsUpdateResponse:
    saved = settings_service.save(payload.settings)
    return SettingsUpdateResponse(status="saved", applied_settings=saved)
