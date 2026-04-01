from __future__ import annotations

import ctypes
from ctypes import wintypes


class WindowController:
    def __init__(self) -> None:
        self.user32 = ctypes.windll.user32

    def restore_or_show(self) -> bool:
        hwnd = self._find_window(
            ["Navi: Voice Navigator", "Voice Navigator", "voice_navigator"]
        )
        if hwnd is None:
            return False

        self.user32.ShowWindow(hwnd, 9)
        self.user32.SetForegroundWindow(hwnd)
        return True

    def send_function_key(self, key_name: str) -> bool:
        hwnd = self._find_window(
            ["Navi: Voice Navigator", "Voice Navigator", "voice_navigator"]
        )
        if hwnd is None:
            return False

        virtual_key = {
            "F2": 0x71,
            "F3": 0x72,
            "F5": 0x74,
        }.get(key_name.upper())
        if virtual_key is None:
            return False

        self.user32.SetForegroundWindow(hwnd)
        self.user32.keybd_event(virtual_key, 0, 0, 0)
        self.user32.keybd_event(virtual_key, 0, 0x0002, 0)
        return True

    def _find_window(self, title_candidates: list[str]) -> int | None:
        matches: list[int] = []
        needles = [title.lower() for title in title_candidates]

        enum_windows = self.user32.EnumWindows
        enum_windows.argtypes = [
            ctypes.WINFUNCTYPE(ctypes.c_bool, wintypes.HWND, wintypes.LPARAM),
            wintypes.LPARAM,
        ]

        def callback(hwnd: int, _: int) -> bool:
            if not self.user32.IsWindowVisible(hwnd):
                return True

            length = self.user32.GetWindowTextLengthW(hwnd)
            if length <= 0:
                return True

            buffer = ctypes.create_unicode_buffer(length + 1)
            self.user32.GetWindowTextW(hwnd, buffer, length + 1)
            title = buffer.value.lower()
            if any(needle in title for needle in needles):
                matches.append(hwnd)
                return False
            return True

        proc = ctypes.WINFUNCTYPE(ctypes.c_bool, wintypes.HWND, wintypes.LPARAM)(callback)
        self.user32.EnumWindows(proc, 0)
        return matches[0] if matches else None
