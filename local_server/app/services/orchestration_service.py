from local_server.app.automation.windows.ui_automation_helper import UiAutomationHelper
from local_server.app.core.security import (
    contains_dangerous_automation,
    contains_sensitive_text,
)
from local_server.app.models.planner import PlannerOutput
from local_server.app.models.requests import VoiceCommandMetadata
from local_server.app.models.responses import CommandResponse, ScreenReadResponse
from local_server.app.services.executor_service import ExecutorService
from local_server.app.services.formatter_service import FormatterService
from local_server.app.services.planner_service import PlannerService
from local_server.app.services.session_manager import SessionManager
from local_server.app.services.stt_service import SttService
from local_server.app.services.transcript_validator import TranscriptValidator
from local_server.app.services.tts_service import TtsService
from local_server.app.services.verifier_service import VerifierService
from local_server.app.services.websocket_broker import broker


class OrchestrationService:
    def __init__(self, session_manager: SessionManager) -> None:
        self.session_manager = session_manager
        self.planner = PlannerService()
        self.executor = ExecutorService()
        self.formatter = FormatterService()
        self.stt = SttService()
        self.validator = TranscriptValidator()
        self.verifier = VerifierService()
        self.tts = TtsService()
        self.ui_helper = UiAutomationHelper()

    async def process_text_command(
        self,
        session_id: str,
        text: str,
        mode: str,
    ) -> CommandResponse:
        secure_response = await self._maybe_block_sensitive_command(session_id, text, mode)
        if secure_response is not None:
            return secure_response

        await broker.publish(
            session_id,
            {
                "type": "status",
                "session_id": session_id,
                "state": "processing",
                "stage": "planner",
                "message": "Planning command",
            },
        )
        self.session_manager.update_status(session_id, "processing")
        plan = self.planner.plan_text(text, mode)
        return await self._execute_plan(session_id, text, plan)

    async def process_voice_command(
        self,
        audio_bytes: bytes,
        metadata: VoiceCommandMetadata,
    ) -> CommandResponse:
        await broker.publish(
            metadata.session_id,
            {
                "type": "status",
                "session_id": metadata.session_id,
                "state": "processing",
                "stage": "stt",
                "message": "Transcribing audio",
            },
        )
        self.session_manager.update_status(metadata.session_id, "processing")
        stt_result = self.stt.transcribe(audio_bytes, metadata)
        validation = self.validator.validate(stt_result["transcript"], stt_result["confidence"])
        await broker.publish(
            metadata.session_id,
            {
                "type": "transcript",
                "session_id": metadata.session_id,
                "transcript": validation["transcript"],
                "confidence": validation["confidence"],
            },
        )
        if not validation["is_valid"]:
            self.session_manager.update_status(metadata.session_id, "error")
            raise ValueError(validation["reason"])

        secure_response = await self._maybe_block_sensitive_command(
            metadata.session_id,
            validation["transcript"],
            metadata.mode,
        )
        if secure_response is not None:
            return secure_response

        plan = self.planner.plan_text(validation["transcript"], metadata.mode)
        return await self._execute_plan(metadata.session_id, validation["transcript"], plan)

    async def process_screen_read(
        self,
        session_id: str,
        detail_level: str,
    ) -> ScreenReadResponse:
        await broker.publish(
            session_id,
            {
                "type": "status",
                "session_id": session_id,
                "state": "processing",
                "stage": "screen_read",
                "message": "Reading current screen",
            },
        )

        if self.ui_helper.detect_sensitive_context():
            summary = "민감한 화면이 감지되어 자세한 읽기를 제한했습니다."
        else:
            summary = (
                "현재 화면에는 Voice Navigator 메인 창이 열려 있고, 듣기 시작과 현재 화면 읽기 버튼이 보입니다."
                if detail_level == "summary"
                else "현재 화면의 접근성 요약과 세부 요소 분석은 이후 Windows UI Automation 연동 단계에서 확장됩니다."
            )

        self.session_manager.update_result(session_id, summary=summary, status="success")
        await broker.publish(
            session_id,
            {
                "type": "completed",
                "session_id": session_id,
                "summary": summary,
                "follow_up": "다른 화면도 읽어드릴까요?",
            },
        )
        return ScreenReadResponse(session_id=session_id, status="success", summary=summary)

    async def _execute_plan(
        self,
        session_id: str,
        transcript: str,
        plan: PlannerOutput,
    ) -> CommandResponse:
        result = self.executor.execute_plan(session_id, plan)
        verification = self.verifier.verify_plan(plan)
        for item in verification:
            await broker.publish(
                session_id,
                {
                    "type": "verification",
                    "session_id": session_id,
                    "step": item.step,
                    "action": item.action,
                    "status": item.status,
                },
            )

        summary, follow_up = self.formatter.build_summary(result)
        tts_result = self.tts.synthesize(session_id, summary)
        response = self.formatter.format_command_response(
            session_id,
            transcript,
            result,
            tts_result,
        )
        self.session_manager.update_result(
            session_id,
            transcript=transcript,
            summary=summary,
            follow_up=follow_up,
            results_preview=response.results_preview,
            status="success",
        )
        await broker.publish(
            session_id,
            {
                "type": "completed",
                "session_id": session_id,
                "summary": summary,
                "follow_up": follow_up,
                "tts": response.tts,
            },
        )
        await broker.publish(
            session_id,
            {
                "type": "tts",
                "session_id": session_id,
                "state": "ready",
                "audio_url": response.tts.get("audio_url"),
            },
        )
        return response

    async def _maybe_block_sensitive_command(
        self,
        session_id: str,
        transcript: str,
        mode: str,
    ) -> CommandResponse | None:
        sensitive = contains_sensitive_text(transcript)
        dangerous = contains_dangerous_automation(transcript)
        secure_context = self.ui_helper.detect_sensitive_context()

        if not (dangerous or (mode == "secure" and sensitive) or secure_context):
            return None

        summary = "보안 보호를 위해 민감한 작업 자동화를 차단했습니다."
        follow_up = "직접 입력 후 다음 단계를 도와드릴까요?"
        tts_result = self.tts.synthesize(session_id, summary)
        self.session_manager.update_result(
            session_id,
            transcript=transcript,
            summary=summary,
            follow_up=follow_up,
            status="blocked",
        )
        await broker.publish(
            session_id,
            {
                "type": "secure_warning",
                "session_id": session_id,
                "summary": summary,
                "follow_up": follow_up,
            },
        )
        return self.formatter.format_command_response(
            session_id,
            transcript,
            {"intent": "blocked", "results_preview": []},
            tts_result,
        )
