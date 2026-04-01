from __future__ import annotations

import os
import re
import subprocess
import time
from dataclasses import replace
from pathlib import Path
from typing import Callable
from urllib.error import URLError
from urllib.request import urlopen

from local_server.app.automation.windows.ui_automation_helper import UiAutomationHelper
from local_server.app.core.config import AppConfig

ProgressCallback = Callable[[dict], None]


class PlaywrightRunner:
    def __init__(self, config: AppConfig | None = None) -> None:
        self.config = config or AppConfig.from_env()

    def run_youtube_search(self, keyword: str, locators: dict[str, list[str]]) -> dict:
        try:
            from playwright.sync_api import TimeoutError as PlaywrightTimeoutError
            from playwright.sync_api import sync_playwright
        except Exception:
            return self._fallback(keyword, "playwright_not_installed")

        try:
            with sync_playwright() as playwright:
                browser = playwright.chromium.launch(headless=self.config.browser_headless)
                page = browser.new_page()
                page.goto("https://www.youtube.com", wait_until="domcontentloaded")
                page.wait_for_load_state("networkidle", timeout=10000)

                search_box = self._find_first_visible(page, locators["search_box"])
                if search_box is None:
                    browser.close()
                    return self._fallback(keyword, "search_box_not_found")

                search_box.fill(keyword)
                search_box.press("Enter")
                page.wait_for_load_state("domcontentloaded", timeout=10000)
                page.wait_for_timeout(1500)

                results = self._collect_results(page, locators["result_cards"])
                current_url = page.url
                browser.close()

                return {
                    "status": "success",
                    "engine": "playwright",
                    "url": current_url,
                    "keyword": keyword,
                    "results": results or self._fallback_results(keyword),
                }
        except PlaywrightTimeoutError:
            return self._fallback(keyword, "timeout")
        except Exception as exc:
            return self._fallback(keyword, f"playwright_error:{type(exc).__name__}")

    def run_naver_map_route_search(
        self,
        origin: str,
        destination: str,
        transport: str,
        locators: dict[str, list[str]],
    ) -> dict:
        try:
            from playwright.sync_api import TimeoutError as PlaywrightTimeoutError
            from playwright.sync_api import sync_playwright
        except Exception:
            return self._fallback_route(origin, destination, transport, "playwright_not_installed")

        try:
            with sync_playwright() as playwright:
                browser = playwright.chromium.launch(headless=self.config.browser_headless)
                page = browser.new_page()
                page.goto("https://map.naver.com", wait_until="domcontentloaded")
                page.wait_for_load_state("networkidle", timeout=12000)

                route_button = self._find_first_visible(page, locators["route_tab"])
                if route_button is not None:
                    route_button.click()
                    page.wait_for_timeout(1000)

                input_boxes = self._find_input_boxes(page, locators)
                if len(input_boxes) >= 2:
                    input_boxes[0].fill(origin)
                    page.wait_for_timeout(300)
                    input_boxes[0].press("Enter")
                    page.wait_for_timeout(800)
                    input_boxes[1].fill(destination)
                    page.wait_for_timeout(300)
                    input_boxes[1].press("Enter")
                    page.wait_for_timeout(1800)

                results = self._collect_route_results(page, locators["route_items"])
                current_url = page.url
                browser.close()

                return {
                    "status": "success",
                    "engine": "playwright",
                    "url": current_url,
                    "origin": origin,
                    "destination": destination,
                    "transport": transport,
                    "results": results or self._fallback_route_results(origin, destination),
                }
        except PlaywrightTimeoutError:
            return self._fallback_route(origin, destination, transport, "timeout")
        except Exception as exc:
            return self._fallback_route(
                origin,
                destination,
                transport,
                f"playwright_error:{type(exc).__name__}",
            )

    def run_naver_map_subway_simulation(
        self,
        origin: str,
        destination: str,
        progress_callback: ProgressCallback | None = None,
    ) -> dict:
        try:
            from playwright.sync_api import TimeoutError as PlaywrightTimeoutError
            from playwright.sync_api import sync_playwright
        except Exception:
            return self._simulation_failure("playwright_not_installed", [], progress_callback)

        helper = UiAutomationHelper()
        config = replace(self.config, browser_headless=False)
        steps: list[dict] = []
        browser = None
        last_step: dict | None = None

        def emit(step: int, action: str, status: str, detail: str, popup_state: str = "processing") -> None:
            nonlocal last_step
            payload = {
                "step": step,
                "action": action,
                "status": status,
                "detail": detail,
                "popup_state": popup_state,
            }
            last_step = {
                "step": step,
                "action": action,
                "status": status,
                "detail": detail,
            }
            if progress_callback is not None:
                progress_callback(payload)

        def record(step: int, action: str, status: str, detail: str, popup_state: str = "success") -> None:
            nonlocal last_step
            step_payload = {
                "step": step,
                "action": action,
                "status": status,
                "detail": detail,
            }
            steps.append(step_payload)
            last_step = step_payload
            emit(step, action, status, detail, popup_state)

        try:
            with sync_playwright() as playwright:
                emit(1, "open_chrome_browser", "processing", "크롬 브라우저 세션을 준비하는 중입니다.")
                browser, page, reused_browser = self._connect_or_launch_chrome(playwright)
                page.wait_for_timeout(1800)
                record(
                    1,
                    "open_chrome_browser",
                    "success",
                    "기존 크롬 브라우저에 새 탭을 열었습니다."
                    if reused_browser
                    else "크롬 브라우저를 실행하고 새 탭을 열었습니다.",
                )

                emit(2, "open_naver_map", "processing", "네이버 지도에 접속하고 화면 로딩을 기다리는 중입니다.")
                page.goto("https://map.naver.com/", wait_until="domcontentloaded")
                try:
                    page.wait_for_load_state("load", timeout=15000)
                except Exception:
                    pass
                self._wait_for_map_bootstrap(page, timeout_ms=30000)
                page.wait_for_timeout(3500)
                window_info = helper.wait_for_window_title_contains(
                    ["Chrome", "NAVER Map", "Naver Map"],
                    timeout_ms=8000,
                )
                record(2, "open_naver_map", "success", f"네이버 지도 로딩 완료: {page.url}")
                steps.append(
                    {
                        "step": 2,
                        "action": "verify_browser_window",
                        "status": window_info["status"],
                        "detail": str(window_info.get("window") or "browser window not detected"),
                    }
                )

                emit(
                    3,
                    "click_route_button",
                    "processing",
                    "길찾기 버튼을 찾고 있습니다. 프레임과 텍스트 구조를 함께 확인하는 중입니다.",
                )
                route_button = self._find_route_button(page, timeout_ms=25000)
                route_button.click()
                page.wait_for_timeout(4000)
                record(3, "click_route_button", "success", "길찾기 버튼을 클릭했습니다.")

                emit(4, "click_origin_combobox", "processing", "출발지 입력 상자를 여는 중입니다.")
                origin_combobox = self._find_origin_input(page, timeout_ms=25000)
                origin_combobox.click()
                page.wait_for_timeout(3000)
                record(4, "click_origin_combobox", "success", "출발지 입력 상자를 열었습니다.")

                emit(5, "input_origin", "processing", f"출발지 {origin}을 입력하는 중입니다.")
                origin_combobox.fill(origin)
                page.wait_for_timeout(3000)
                record(5, "input_origin", "success", origin)

                emit(6, "select_origin_place", "processing", "출발지 자동완성 첫 항목을 선택하는 중입니다.")
                self._click_first_place_item(page, timeout_ms=25000)
                page.wait_for_timeout(4000)
                record(6, "select_origin_place", "success", "출발지 자동완성 첫 항목을 선택했습니다.")

                emit(7, "click_destination_combobox", "processing", "도착지 입력 상자를 여는 중입니다.")
                destination_combobox = self._find_destination_input(page, timeout_ms=25000)
                destination_combobox.click()
                page.wait_for_timeout(3000)
                record(7, "click_destination_combobox", "success", "도착지 입력 상자를 열었습니다.")

                emit(8, "input_destination", "processing", f"도착지 {destination}을 입력하는 중입니다.")
                destination_combobox.fill(destination)
                page.wait_for_timeout(3000)
                record(8, "input_destination", "success", destination)

                emit(9, "select_destination_place", "processing", "도착지 자동완성 첫 항목을 선택하는 중입니다.")
                self._click_first_place_item(page, timeout_ms=25000)
                page.wait_for_timeout(4000)
                record(9, "select_destination_place", "success", "도착지 자동완성 첫 항목을 선택했습니다.")

                emit(10, "select_subway_tab", "processing", "지하철 탭 버튼을 선택하는 중입니다.")
                subway_button = self._find_subway_tab_button(page, timeout_ms=25000)
                result_count = self._extract_result_count_from_button(subway_button)
                subway_button.click()
                record(10, "select_subway_tab", "success", "지하철 탭을 선택했습니다.")

                emit(11, "wait_for_route_results", "processing", "조회 결과가 나타나는지 확인하는 중입니다.")
                results_ready = self._wait_for_route_results(page, timeout_ms=4000)
                if not results_ready:
                    page.wait_for_timeout(1200)
                record(
                    11,
                    "wait_for_route_results",
                    "success",
                    "경로 결과 영역을 확인했습니다." if results_ready else "경로 결과를 추가 대기 후 확인했습니다.",
                )

                emit(12, "extract_route_summary", "processing", "첫 번째 경로 정보를 읽는 중입니다.")
                route_summary = self._extract_first_route_text(page)
                duration_text = self._extract_route_duration_text(page)
                record(12, "extract_route_summary", "success", route_summary)
                foreground = helper.get_foreground_window()
                current_url = page.url

                return {
                    "status": "success",
                    "scenario": "naver_map_subway_route",
                    "origin": origin,
                    "destination": destination,
                    "url": current_url,
                    "foreground_window": foreground,
                    "steps": steps,
                    "route_summary": route_summary,
                    "result_count": result_count,
                    "duration_text": duration_text,
                    "engine": {
                        "browser": "chrome",
                        "headless": config.browser_headless,
                        "ui_automation": "windows",
                    },
                }
        except PlaywrightTimeoutError as exc:
            self._append_failure_step(
                steps,
                last_step,
                f"timeout:{type(exc).__name__}",
            )
            return self._simulation_failure(f"timeout:{type(exc).__name__}", steps, progress_callback)
        except Exception as exc:
            self._append_failure_step(
                steps,
                last_step,
                f"playwright_error:{type(exc).__name__}: {exc}",
            )
            return self._simulation_failure(
                f"playwright_error:{type(exc).__name__}: {exc}",
                steps,
                progress_callback,
            )

    def _connect_or_launch_chrome(self, playwright):
        endpoint = "http://127.0.0.1:9222"
        reused_browser = self._is_debug_browser_ready(endpoint)

        if not reused_browser:
            chrome_path = self._resolve_chrome_path()
            if chrome_path is None:
                raise RuntimeError("chrome_executable_not_found")

            user_data_dir = self._resolve_debug_profile_dir()
            user_data_dir.mkdir(parents=True, exist_ok=True)
            subprocess.Popen(
                [
                    chrome_path,
                    "--remote-debugging-port=9222",
                    f"--user-data-dir={user_data_dir}",
                    "--new-window",
                ],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                stdin=subprocess.DEVNULL,
                creationflags=getattr(subprocess, "DETACHED_PROCESS", 0)
                | getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0),
            )
            self._wait_for_debug_browser(endpoint, timeout_ms=12000)

        browser = playwright.chromium.connect_over_cdp(endpoint)
        context = browser.contexts[0] if browser.contexts else browser.new_context()
        page = self._resolve_page_for_simulation(context, reused_browser)
        return browser, page, reused_browser

    def _resolve_page_for_simulation(self, context, reused_browser: bool):
        pages = context.pages
        if not reused_browser and pages:
            for page in pages:
                try:
                    url = (page.url or "").strip().lower()
                    if url in ("", "about:blank", "chrome://newtab/"):
                        return page
                except Exception:
                    continue
            return pages[0]
        return context.new_page()

    def _resolve_debug_profile_dir(self) -> Path:
        env_root = os.getenv("VOICE_NAVIGATOR_ROOT")
        if env_root:
            return Path(env_root) / "runtime" / "chrome_debug_profile"
        return Path.cwd() / "runtime" / "chrome_debug_profile"

    def _resolve_chrome_path(self) -> str | None:
        candidates = [
            os.getenv("PROGRAMFILES", "") + r"\Google\Chrome\Application\chrome.exe",
            os.getenv("PROGRAMFILES(X86)", "") + r"\Google\Chrome\Application\chrome.exe",
            os.getenv("LOCALAPPDATA", "") + r"\Google\Chrome\Application\chrome.exe",
        ]
        for candidate in candidates:
            if candidate and Path(candidate).exists():
                return candidate
        return None

    def _is_debug_browser_ready(self, endpoint: str) -> bool:
        try:
            with urlopen(f"{endpoint}/json/version", timeout=1.2) as response:
                return response.status == 200
        except (URLError, TimeoutError, OSError):
            return False

    def _wait_for_debug_browser(self, endpoint: str, timeout_ms: int) -> None:
        deadline = time.time() + (timeout_ms / 1000)
        while time.time() < deadline:
            if self._is_debug_browser_ready(endpoint):
                return
            time.sleep(0.25)
        raise RuntimeError("chrome_debug_endpoint_not_ready")

    def _find_first_visible(self, page, selectors: list[str]):
        for selector in selectors:
            locator = page.locator(selector).first
            try:
                locator.wait_for(state="visible", timeout=3000)
                return locator
            except Exception:
                continue
        return None

    def _find_route_button(self, page, timeout_ms: int):
        candidates = [
            lambda frame: frame.get_by_role("button", name="\uAE38\uCC3E\uAE30").first,
            lambda frame: frame.get_by_role("link", name="\uAE38\uCC3E\uAE30").first,
            lambda frame: frame.get_by_text("\uAE38\uCC3E\uAE30", exact=False).first,
            lambda frame: frame.locator("text=/\uAE38\uCC3E\uAE30/").first,
            lambda frame: frame.locator("*:has-text('\uAE38\uCC3E\uAE30')").first,
            lambda frame: frame.locator("button:has-text('\uAE38\uCC3E\uAE30')").first,
            lambda frame: frame.locator("a:has-text('\uAE38\uCC3E\uAE30')").first,
            lambda frame: frame.locator("[role='button']:has-text('\uAE38\uCC3E\uAE30')").first,
            lambda frame: frame.locator("[aria-label*='\uAE38\uCC3E\uAE30']").first,
            lambda frame: frame.locator("[title*='\uAE38\uCC3E\uAE30']").first,
        ]
        return self._find_from_frames(page, candidates, timeout_ms, "route button")

    def _find_origin_input(self, page, timeout_ms: int):
        candidates = [
            lambda frame: frame.get_by_role("combobox", name="\uCD9C\uBC1C\uC9C0 \uC785\uB825").first,
            lambda frame: frame.locator("input[placeholder*='\uCD9C\uBC1C']").first,
            lambda frame: frame.locator("input[aria-label*='\uCD9C\uBC1C']").first,
            lambda frame: frame.locator("input[name*='\uCD9C\uBC1C']").first,
        ]
        return self._find_from_frames(page, candidates, timeout_ms, "origin input")

    def _find_destination_input(self, page, timeout_ms: int):
        candidates = [
            lambda frame: frame.get_by_role("combobox", name="\uB3C4\uCC29\uC9C0 \uC785\uB825").first,
            lambda frame: frame.locator("input[placeholder*='\uB3C4\uCC29']").first,
            lambda frame: frame.locator("input[aria-label*='\uB3C4\uCC29']").first,
            lambda frame: frame.locator("input[name*='\uB3C4\uCC29']").first,
        ]
        return self._find_from_frames(page, candidates, timeout_ms, "destination input")

    def _find_from_frames(self, page, candidates: list[Callable], timeout_ms: int, label: str):
        deadline = time.time() + (timeout_ms / 1000)
        last_error = ""
        while time.time() < deadline:
            for frame in page.frames:
                for builder in candidates:
                    locator = builder(frame)
                    try:
                        locator.wait_for(state="visible", timeout=1200)
                        return locator
                    except Exception as exc:
                        last_error = str(exc)
                        continue
            page.wait_for_timeout(700)
        debug = self._collect_frame_debug_snapshot(page)
        raise RuntimeError(
            f"{label} not found | last_error={last_error or 'n/a'} | debug={debug}"
        )

    def _click_first_place_item(self, page, timeout_ms: int) -> None:
        selectors = [
            "ul.list_place li[role='none']",
            "ul[class*='list_place'] li[role='none']",
            "li[role='none']",
        ]
        for frame in page.frames:
            for selector in selectors:
                locator = frame.locator(selector).first
                try:
                    locator.wait_for(state="visible", timeout=timeout_ms)
                    locator.click()
                    return
                except Exception:
                    continue
        raise RuntimeError("list_place first li not found")

    def _find_subway_tab_button(self, page, timeout_ms: int):
        candidates = [
            lambda frame: frame.locator("ul[role='tablist'] button:has-text('\uC9C0\uD558\uCCA0')").first,
            lambda frame: frame.get_by_role("button", name=re.compile(r"^\uC9C0\uD558\uCCA0")).first,
            lambda frame: frame.locator("button:has-text('\uC9C0\uD558\uCCA0')").first,
        ]
        return self._find_from_frames(page, candidates, timeout_ms, "subway tab button")

    def _extract_result_count_from_button(self, button) -> int | None:
        try:
            text = re.sub(r"\s+", " ", button.inner_text(timeout=2000)).strip()
            match = re.search(r"\d+", text)
            if match is None:
                return None
            return int(match.group())
        except Exception:
            return None

    def _extract_first_route_text(self, page) -> str:
        locator = self._find_first_route_locator(page)
        if locator is not None:
            try:
                text = locator.inner_text(timeout=700).strip()
                if text:
                    return re.sub(r"\s+", " ", text)
            except Exception:
                pass
        return "No route summary collected."

    def _extract_route_duration_text(self, page) -> str | None:
        global_selectors = [
            ("span.time_taken", "span.time_unit"),
            (".time_info .time_taken", ".time_info .time_unit"),
            ("[class*='time_taken']", "[class*='time_unit']"),
        ]
        for frame in page.frames:
            for taken_selector, unit_selector in global_selectors:
                try:
                    taken_values = frame.locator(taken_selector).all_inner_texts()
                    unit_values = frame.locator(unit_selector).all_inner_texts()
                    duration = self._compose_first_duration(taken_values, unit_values)
                    if duration:
                        return duration
                except Exception:
                    continue

        locator = self._find_first_route_locator(page)
        if locator is not None:
            try:
                time_tokens = locator.locator(
                    "span.time_taken, span.time_unit, [class*='time_taken'], [class*='time_unit']"
                ).all_inner_texts()
                normalized_tokens = [
                    re.sub(r"\s+", " ", token).strip()
                    for token in time_tokens
                    if re.sub(r"\s+", " ", token).strip()
                ]
                if normalized_tokens:
                    chunks: list[str] = []
                    index = 0
                    while index + 1 < len(normalized_tokens):
                        taken = normalized_tokens[index]
                        unit = normalized_tokens[index + 1]
                        if not re.search(r"\d", taken):
                            break
                        if unit not in ("시간", "분"):
                            break
                        chunks.append(f"{taken}{unit}")
                        index += 2
                        if unit == "분":
                            break
                    if chunks:
                        return " ".join(chunks)
            except Exception:
                pass

            try:
                route_text = re.sub(r"\s+", " ", locator.inner_text(timeout=700)).strip()
                matches = re.findall(r"\d+\s*시간|\d+\s*분", route_text)
                if matches:
                    if len(matches) >= 2 and "시간" in matches[0] and "분" in matches[1]:
                        return f"{matches[0]} {matches[1]}".strip()
                    return matches[0].strip()
            except Exception:
                pass
        return None

    def _compose_first_duration(self, taken_values: list[str], unit_values: list[str]) -> str | None:
        normalized_taken = [
            re.sub(r"\s+", " ", value).strip()
            for value in taken_values
            if re.sub(r"\s+", " ", value).strip()
        ]
        normalized_unit = [
            re.sub(r"\s+", " ", value).strip()
            for value in unit_values
            if re.sub(r"\s+", " ", value).strip()
        ]

        if not normalized_taken or not normalized_unit:
            return None

        chunks: list[str] = []
        for taken, unit in zip(normalized_taken, normalized_unit):
            if not re.search(r"\d", taken):
                continue
            if unit not in ("시간", "분"):
                continue
            chunks.append(f"{taken}{unit}")
            if unit == "분":
                break

        if not chunks:
            return None
        return " ".join(chunks)

    def _find_first_route_locator(self, page):
        selectors = [
            ".route_result_item",
            ".section_direction .item",
            "[role='listitem']",
        ]
        for frame in page.frames:
            for selector in selectors:
                try:
                    locator = frame.locator(selector)
                    if locator.count() > 0:
                        return locator.first
                except Exception:
                    continue
        return None

    def _wait_for_route_results(self, page, timeout_ms: int) -> bool:
        selectors = [
            "span.time_taken",
            ".route_result_item",
            ".section_direction .item",
            "[role='listitem']",
            "[class*='time_taken']",
        ]
        deadline = time.time() + (timeout_ms / 1000)
        while time.time() < deadline:
            for frame in page.frames:
                for selector in selectors:
                    try:
                        locator = frame.locator(selector).first
                        locator.wait_for(state="visible", timeout=500)
                        return True
                    except Exception:
                        continue
            page.wait_for_timeout(250)
        return False

    def _wait_for_map_bootstrap(self, page, timeout_ms: int) -> None:
        candidates = [
            "iframe",
            "button",
            "input",
            "div",
        ]
        page.wait_for_timeout(2000)
        for selector in candidates:
            try:
                page.locator(selector).first.wait_for(state="attached", timeout=timeout_ms)
                return
            except Exception:
                continue
        raise RuntimeError("map bootstrap not detected")

    def _collect_frame_debug_snapshot(self, page) -> str:
        snapshots: list[str] = []
        for index, frame in enumerate(page.frames):
            frame_name = frame.name or f"frame_{index}"
            frame_url = frame.url or "about:blank"
            try:
                texts = frame.locator(
                    "button, a, [role='button'], [role='tab'], span, strong"
                ).all_inner_texts()
                normalized = [
                    re.sub(r"\s+", " ", text).strip()
                    for text in texts
                    if re.sub(r"\s+", " ", text).strip()
                ]
                sample = ", ".join(normalized[:8]) if normalized else "no visible button text"
            except Exception:
                sample = "text enumeration failed"
            snapshots.append(f"{frame_name}@{frame_url} => {sample}")
        return " | ".join(snapshots[:6]) if snapshots else "no frames"

    def _append_failure_step(self, steps: list[dict], last_step: dict | None, reason: str) -> None:
        if last_step is None:
            return
        failed_step = {
            "step": last_step["step"],
            "action": last_step["action"],
            "status": "error",
            "detail": reason,
        }
        if steps and steps[-1]["step"] == failed_step["step"]:
            steps[-1] = failed_step
            return
        steps.append(failed_step)

    def _safe_close_browser(self, browser) -> None:
        try:
            browser.close()
        except Exception:
            pass

    def _collect_results(self, page, selectors: list[str]) -> list[dict]:
        for selector in selectors:
            locator = page.locator(selector)
            try:
                if locator.count() == 0:
                    continue
                items = []
                for index in range(min(locator.count(), 3)):
                    card = locator.nth(index)
                    title = ""
                    duration = ""
                    try:
                        title = card.locator("#video-title").first.inner_text(timeout=2000).strip()
                    except Exception:
                        title = "Unable to read title"
                    try:
                        duration = card.locator(
                            "span.ytd-thumbnail-overlay-time-status-renderer"
                        ).first.inner_text(timeout=1500).strip()
                    except Exception:
                        duration = "Duration unavailable"
                    items.append({"title": title, "duration": duration})
                if items:
                    return items
            except Exception:
                continue
        return []

    def _find_input_boxes(self, page, locators: dict[str, list[str]]) -> list:
        candidates = []
        for selector in locators["origin_input"]:
            locator = page.locator(selector)
            try:
                count = locator.count()
                if count > 0:
                    for index in range(min(count, 2)):
                        candidates.append(locator.nth(index))
                    if candidates:
                        return candidates
            except Exception:
                continue
        return candidates

    def _collect_route_results(self, page, selectors: list[str]) -> list[dict]:
        for selector in selectors:
            locator = page.locator(selector)
            try:
                count = locator.count()
                if count == 0:
                    continue
                items = []
                for index in range(min(count, 3)):
                    text = locator.nth(index).inner_text(timeout=1500).strip()
                    if text:
                        items.append(
                            {
                                "route_name": f"Route {index + 1}",
                                "duration": text.splitlines()[0],
                                "transfers": 0,
                            }
                        )
                if items:
                    return items
            except Exception:
                continue
        return []

    def _fallback(self, keyword: str, reason: str) -> dict:
        return {
            "status": "fallback",
            "engine": "playwright",
            "reason": reason,
            "keyword": keyword,
            "results": self._fallback_results(keyword),
        }

    def _fallback_results(self, keyword: str) -> list[dict]:
        return [
            {"title": f"{keyword} search result", "duration": "Duration unavailable"},
        ]

    def _fallback_route(
        self,
        origin: str,
        destination: str,
        transport: str,
        reason: str,
    ) -> dict:
        return {
            "status": "fallback",
            "engine": "playwright",
            "reason": reason,
            "origin": origin,
            "destination": destination,
            "transport": transport,
            "results": self._fallback_route_results(origin, destination),
        }

    def _fallback_route_results(self, origin: str, destination: str) -> list[dict]:
        return [
            {
                "route_name": f"{origin} to {destination}",
                "duration": "1h 32m",
                "transfers": 2,
            }
        ]

    def _simulation_failure(
        self,
        reason: str,
        steps: list[dict],
        progress_callback: ProgressCallback | None = None,
    ) -> dict:
        if progress_callback is not None:
            progress_callback(
                {
                    "step": steps[-1]["step"] if steps else 0,
                    "action": steps[-1]["action"] if steps else "simulation",
                    "status": "error",
                    "detail": f"시뮬레이션 실패: {reason}",
                    "popup_state": "appError",
                }
            )
        return {
            "status": "error",
            "scenario": "naver_map_subway_route",
            "reason": reason,
            "steps": steps,
        }

