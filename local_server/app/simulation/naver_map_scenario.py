from __future__ import annotations

import json
from dataclasses import replace

from local_server.app.automation.browser.playwright_runner import PlaywrightRunner
from local_server.app.core.config import AppConfig


def emit_progress(payload: dict) -> None:
    print(
        json.dumps(
            {
                "kind": "progress",
                "payload": payload,
            },
            ensure_ascii=False,
        ),
        flush=True,
    )


def run() -> dict:
    config = replace(AppConfig.from_env(), browser_headless=False)
    runner = PlaywrightRunner(config=config)
    return runner.run_naver_map_subway_simulation(
        origin="\uC11C\uC6B8\uC5ED 1\uD638\uC120",
        destination="\uD55C\uAD6D\uD3F4\uB9AC\uD14D\uB300\uD559 \uC778\uCC9C\uCEA0\uD37C\uC2A4",
        progress_callback=emit_progress,
    )


def main() -> None:
    result = run()
    print(
        json.dumps(
            {
                "kind": "result",
                "payload": result,
            },
            ensure_ascii=False,
        ),
        flush=True,
    )


if __name__ == "__main__":
    main()
