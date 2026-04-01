from local_server.app.automation.browser.locators.naver_map_locators import (
    NAVER_MAP_LOCATORS,
)
from local_server.app.automation.browser.playwright_runner import PlaywrightRunner


class NaverMapActions:
    def __init__(self) -> None:
        self.runner = PlaywrightRunner()

    def search_route(self, origin: str, destination: str, transport: str) -> dict:
        return self.runner.run_naver_map_route_search(
            origin=origin,
            destination=destination,
            transport=transport,
            locators=NAVER_MAP_LOCATORS,
        )
