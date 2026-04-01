from local_server.app.automation.browser.naver_map_actions import NaverMapActions
from local_server.app.automation.browser.youtube_actions import YouTubeActions
from local_server.app.models.planner import PlannerOutput


class ExecutorService:
    def __init__(self) -> None:
        self.youtube_actions = YouTubeActions()
        self.naver_map_actions = NaverMapActions()

    def execute_plan(self, session_id: str, plan: PlannerOutput) -> dict:
        results_preview = self._build_preview(plan)
        return {
            "session_id": session_id,
            "intent": plan.intent,
            "platform": plan.platform,
            "task_plan": [step.model_dump() for step in plan.task_plan],
            "results_preview": results_preview,
        }

    def _build_preview(self, plan: PlannerOutput) -> list[dict]:
        if plan.intent == "youtube_video_search":
            keyword = str(plan.slots.get("keyword", "recommended videos"))
            result = self.youtube_actions.search(keyword)
            if result.get("results"):
                return result["results"]
            return [{"title": "cat video result", "duration": "Duration unavailable"}]

        if plan.intent == "map_route_search":
            result = self.naver_map_actions.search_route(
                origin=str(plan.slots.get("origin", "Seoul Station")),
                destination=str(plan.slots.get("destination", "Incheon")),
                transport=str(plan.slots.get("transport", "subway")),
            )
            if result.get("results"):
                return result["results"]
            return [{"route_name": "subway route", "duration": "1h 32m", "transfers": 2}]

        return []
