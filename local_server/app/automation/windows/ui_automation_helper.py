from __future__ import annotations

import ctypes
import time
from dataclasses import dataclass
from typing import Iterable


@dataclass(slots=True)
class WindowInfo:
    handle: int
    title: str
    visible: bool

    def to_dict(self) -> dict:
        return {
            "handle": self.handle,
            "title": self.title,
            "visible": self.visible,
        }


class UiAutomationHelper:
    def __init__(self) -> None:
        self.user32 = ctypes.windll.user32
        self._uiautomation = self._try_import_uiautomation()

    def get_foreground_window(self) -> dict:
        hwnd = self.user32.GetForegroundWindow()
        if not hwnd:
          return {"handle": 0, "title": "", "visible": False}
        return self._build_window_info(hwnd).to_dict()

    def detect_sensitive_context(self) -> bool:
        foreground = self.get_foreground_window()
        title = str(foreground.get("title", "")).lower()
        return any(token in title for token in ("login", "otp", "password", "sign in"))

    def wait_for_window_title_contains(
        self,
        keywords: Iterable[str],
        timeout_ms: int = 10000,
    ) -> dict:
        normalized = [keyword.lower() for keyword in keywords if keyword]
        deadline = time.time() + (timeout_ms / 1000)

        while time.time() < deadline:
            for window in self._enumerate_windows():
                title = window.title.lower()
                if any(keyword in title for keyword in normalized):
                    return {
                        "status": "success",
                        "window": window.to_dict(),
                        "source": "uiautomation" if self._uiautomation else "user32",
                    }
            time.sleep(0.2)

        return {
            "status": "timeout",
            "window": None,
            "source": "uiautomation" if self._uiautomation else "user32",
        }

    def bring_window_to_front(self, keywords: Iterable[str]) -> bool:
        normalized = [keyword.lower() for keyword in keywords if keyword]
        for window in self._enumerate_windows():
            if any(keyword in window.title.lower() for keyword in normalized):
                self.user32.ShowWindow(window.handle, 9)
                self.user32.SetForegroundWindow(window.handle)
                return True
        return False

    def _try_import_uiautomation(self):
        try:
            import uiautomation as automation  # type: ignore

            return automation
        except Exception:
            return None

    def _enumerate_windows(self) -> list[WindowInfo]:
        windows: list[WindowInfo] = []

        if self._uiautomation is not None:
            try:
                root = self._uiautomation.GetRootControl()
                for child in root.GetChildren():
                    name = str(getattr(child, "Name", "") or "").strip()
                    if name:
                        windows.append(
                            WindowInfo(
                                handle=int(getattr(child, "NativeWindowHandle", 0) or 0),
                                title=name,
                                visible=True,
                            )
                        )
                if windows:
                    return windows
            except Exception:
                windows.clear()

        enum_proc = ctypes.WINFUNCTYPE(ctypes.c_bool, ctypes.c_int, ctypes.c_int)

        def callback(hwnd, _lparam):
            if not self.user32.IsWindowVisible(hwnd):
                return True
            length = self.user32.GetWindowTextLengthW(hwnd)
            if length == 0:
                return True
            buffer = ctypes.create_unicode_buffer(length + 1)
            self.user32.GetWindowTextW(hwnd, buffer, length + 1)
            title = buffer.value.strip()
            if title:
                windows.append(
                    WindowInfo(
                        handle=int(hwnd),
                        title=title,
                        visible=True,
                    )
                )
            return True

        self.user32.EnumWindows(enum_proc(callback), 0)
        return windows

    def _build_window_info(self, hwnd: int) -> WindowInfo:
        length = self.user32.GetWindowTextLengthW(hwnd)
        buffer = ctypes.create_unicode_buffer(length + 1)
        self.user32.GetWindowTextW(hwnd, buffer, length + 1)
        return WindowInfo(
            handle=int(hwnd),
            title=buffer.value.strip(),
            visible=bool(self.user32.IsWindowVisible(hwnd)),
        )
