from local_server.app.models.planner import PlannerOutput, TaskStep

YOUTUBE_KO = "\uC720\uD29C\uBE0C"
NAVER_KO = "\uB124\uC774\uBC84"
ROUTE_KO = "\uACBD\uB85C"
FROM_KO = "\uC5D0\uC11C "
TO_KO = " \uAC00\uB294 "
SUBWAY_KO = "\uC9C0\uD558\uCCA0"
SEARCH_FOR_ME_KO = "\uCC3E\uC544\uC918"


class PlannerService:
    def plan_text(self, text: str, mode: str) -> PlannerOutput:
        lowered = text.lower()

        if YOUTUBE_KO in text or "youtube" in lowered:
            keyword = (
                text.replace(f"{YOUTUBE_KO}\uC5D0\uC11C", "")
                .replace(SEARCH_FOR_ME_KO, "")
                .strip()
                or "recommended videos"
            )
            return PlannerOutput(
                intent="youtube_video_search",
                platform="youtube",
                slots={"keyword": keyword, "mode": mode},
                goal="Search YouTube and summarize the top results.",
                task_plan=[
                    TaskStep(step=1, action="open_browser"),
                    TaskStep(step=2, action="open_website", target="youtube"),
                    TaskStep(step=3, action="verify_url", contains="youtube.com"),
                    TaskStep(step=4, action="find_search_box"),
                    TaskStep(step=5, action="input_keyword", value=keyword),
                    TaskStep(step=6, action="submit_search"),
                    TaskStep(step=7, action="collect_results"),
                ],
            )

        if NAVER_KO in text and ROUTE_KO in text:
            origin, destination = self._extract_route_slots(text)
            return PlannerOutput(
                intent="map_route_search",
                platform="naver_map",
                slots={
                    "raw_text": text,
                    "origin": origin,
                    "destination": destination,
                    "transport": "subway",
                    "mode": mode,
                },
                goal="Search Naver Map for a transit route and summarize the result.",
                task_plan=[
                    TaskStep(step=1, action="open_browser"),
                    TaskStep(step=2, action="open_website", target="naver_map"),
                    TaskStep(step=3, action="verify_url", contains="map.naver.com"),
                    TaskStep(step=4, action="enter_route_mode"),
                    TaskStep(step=5, action="set_origin", value=origin),
                    TaskStep(step=6, action="set_destination", value=destination),
                    TaskStep(step=7, action="select_transport", value="subway"),
                    TaskStep(step=8, action="extract_route_result"),
                ],
            )

        return PlannerOutput(
            intent="generic_command",
            platform="desktop",
            slots={"raw_text": text, "mode": mode},
            goal="Forward the user command to the next supported implementation step.",
            task_plan=[TaskStep(step=1, action="acknowledge_command")],
        )

    def _extract_route_slots(self, text: str) -> tuple[str, str]:
        origin = "\uC11C\uC6B8\uC5ED"
        destination = "\uD55C\uAD6D\uD3F4\uB9AC\uD14D\uB300\uD559 \uC778\uCC9C\uCEA0\uD37C\uC2A4"

        if FROM_KO in text and TO_KO in text:
            try:
                after_first = text.split(FROM_KO, 1)[1]
                origin, destination_part = after_first.split(TO_KO, 1)
                destination = (
                    destination_part.replace(SUBWAY_KO, "")
                    .replace(ROUTE_KO, "")
                    .replace(SEARCH_FOR_ME_KO, "")
                    .strip()
                )
                origin = origin.strip()
            except ValueError:
                pass

        return origin, destination
