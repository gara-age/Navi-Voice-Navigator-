from local_server.app.models.responses import CommandResponse


class FormatterService:
    def build_summary(self, result: dict) -> tuple[str, str | None]:
        summary = "명령을 처리할 준비가 되었습니다."
        follow_up = None

        if result["intent"] == "youtube_video_search":
            summary = "유튜브 검색 결과를 찾았습니다. 첫 번째 영상은 귀여운 고양이 놀이 모음입니다."
            follow_up = "첫 번째 영상을 재생할까요?"
        elif result["intent"] == "map_route_search":
            summary = "경로를 찾았습니다. 가장 빠른 경로는 약 1시간 32분이 걸립니다."
            follow_up = "경로를 안내할까요?"
        elif result["intent"] == "blocked":
            summary = "보안 보호를 위해 민감한 작업 자동화를 차단했습니다."
            follow_up = "직접 입력 후 다음 단계를 도와드릴까요?"

        return summary, follow_up

    def format_command_response(
        self,
        session_id: str,
        transcript: str,
        result: dict,
        tts_result: dict | None = None,
    ) -> CommandResponse:
        summary, follow_up = self.build_summary(result)

        return CommandResponse(
            session_id=session_id,
            status="success" if result["intent"] != "blocked" else "blocked",
            transcript=transcript,
            summary=summary,
            follow_up=follow_up,
            results_preview=result.get("results_preview", []),
            tts=tts_result or {},
        )
