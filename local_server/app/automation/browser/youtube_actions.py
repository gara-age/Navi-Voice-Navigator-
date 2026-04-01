from local_server.app.automation.browser.locators.youtube_locators import (
    YOUTUBE_LOCATORS,
)
from local_server.app.automation.browser.playwright_runner import PlaywrightRunner


class YouTubeActions:
    def __init__(self) -> None:
        self.runner = PlaywrightRunner()

    def search(self, keyword: str) -> dict:
        return self.runner.run_youtube_search(keyword, YOUTUBE_LOCATORS)
