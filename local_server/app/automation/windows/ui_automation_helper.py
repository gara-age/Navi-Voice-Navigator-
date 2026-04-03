from __future__ import annotations

import ctypes
import ctypes.wintypes
import os
import subprocess
import time
from dataclasses import dataclass
from typing import Any, Iterable


@dataclass(slots=True)
class WindowInfo:
    handle: int
    title: str
    visible: bool
    process_name: str = ""

    def to_dict(self) -> dict:
        return {
            "handle": self.handle,
            "title": self.title,
            "visible": self.visible,
            "process_name": self.process_name,
        }


class UiAutomationHelper:
    def __init__(self) -> None:
        self.user32 = ctypes.windll.user32
        self.gdi32 = ctypes.windll.gdi32
        self.kernel32 = ctypes.windll.kernel32
        self.kernel32.GlobalAlloc.argtypes = [ctypes.c_uint, ctypes.c_size_t]
        self.kernel32.GlobalAlloc.restype = ctypes.c_void_p
        self.kernel32.GlobalLock.argtypes = [ctypes.c_void_p]
        self.kernel32.GlobalLock.restype = ctypes.c_void_p
        self.kernel32.GlobalUnlock.argtypes = [ctypes.c_void_p]
        self.kernel32.GlobalUnlock.restype = ctypes.c_bool
        self.kernel32.GlobalFree.argtypes = [ctypes.c_void_p]
        self.kernel32.GlobalFree.restype = ctypes.c_void_p
        self.user32.OpenClipboard.argtypes = [ctypes.c_void_p]
        self.user32.OpenClipboard.restype = ctypes.c_bool
        self.user32.EmptyClipboard.argtypes = []
        self.user32.EmptyClipboard.restype = ctypes.c_bool
        self.user32.SetClipboardData.argtypes = [ctypes.c_uint, ctypes.c_void_p]
        self.user32.SetClipboardData.restype = ctypes.c_void_p
        self.user32.CloseClipboard.argtypes = []
        self.user32.CloseClipboard.restype = ctypes.c_bool
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
        process_names: Iterable[str] = (),
        timeout_ms: int = 10000,
    ) -> dict:
        normalized = [keyword.lower() for keyword in keywords if keyword]
        normalized_processes = [value.lower() for value in process_names if value]
        deadline = time.time() + (timeout_ms / 1000)

        while time.time() < deadline:
            for window in self._enumerate_windows():
                title = window.title.lower()
                process_name = window.process_name.lower()
                if normalized_processes and process_name not in normalized_processes:
                    continue
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

    def bring_window_to_front(
        self,
        keywords: Iterable[str],
        process_names: Iterable[str] = (),
    ) -> bool:
        normalized = [keyword.lower() for keyword in keywords if keyword]
        normalized_processes = [value.lower() for value in process_names if value]
        for window in self._enumerate_windows():
            if normalized_processes and window.process_name.lower() not in normalized_processes:
                continue
            if any(keyword in window.title.lower() for keyword in normalized):
                self.user32.ShowWindow(window.handle, 9)
                self.user32.SetForegroundWindow(window.handle)
                return True
        return False

    def require_uiautomation(self):
        if self._uiautomation is None:
            raise RuntimeError("uiautomation_not_available")
        return self._uiautomation

    def launch_process(self, command: list[str]) -> subprocess.Popen:
        resolved_command = self._resolve_launch_command(command)
        return subprocess.Popen(resolved_command)

    def wait_for_automation_window(
        self,
        keywords: Iterable[str],
        process_names: Iterable[str] = (),
        timeout_ms: int = 15000,
    ):
        automation = self.require_uiautomation()
        normalized = [keyword.lower() for keyword in keywords if keyword]
        normalized_processes = [value.lower() for value in process_names if value]
        deadline = time.time() + (timeout_ms / 1000)

        while time.time() < deadline:
            root = automation.GetRootControl()
            for child in root.GetChildren():
                title = self._safe_control_name(child)
                if not title:
                    continue
                lowered = title.lower()
                native_handle = self._safe_int_attr(child, "NativeWindowHandle")
                if normalized_processes:
                    process_name = self._get_process_name(native_handle).lower()
                    if process_name not in normalized_processes:
                        continue
                if any(keyword in lowered for keyword in normalized):
                    return child
            time.sleep(0.25)

        raise RuntimeError("window_not_found")

    def get_automation_window_from_handle(self, hwnd: int, timeout_ms: int = 5000):
        automation = self.require_uiautomation()
        deadline = time.time() + (timeout_ms / 1000)

        while time.time() < deadline:
            root = automation.GetRootControl()
            for child in root.GetChildren():
                native_handle = self._safe_int_attr(child, "NativeWindowHandle")
                if native_handle == hwnd:
                    return child
            time.sleep(0.2)

        raise RuntimeError("automation_window_from_handle_not_found")

    def find_descendant(
        self,
        root: Any,
        *,
        names: Iterable[str] = (),
        control_types: Iterable[str] = (),
        class_names: Iterable[str] = (),
        automation_ids: Iterable[str] = (),
        timeout_ms: int = 5000,
        max_depth: int = 8,
    ):
        names_normalized = [name.lower() for name in names if name]
        control_types_normalized = [value.lower() for value in control_types if value]
        class_names_normalized = [value.lower() for value in class_names if value]
        automation_ids_normalized = [value.lower() for value in automation_ids if value]
        deadline = time.time() + (timeout_ms / 1000)

        while time.time() < deadline:
            for control in self._iter_descendants(root, max_depth=max_depth):
                if self._matches_control(
                    control,
                    names=names_normalized,
                    control_types=control_types_normalized,
                    class_names=class_names_normalized,
                    automation_ids=automation_ids_normalized,
                ):
                    return control
            time.sleep(0.2)

        raise RuntimeError("control_not_found")

    def click_control(self, control: Any) -> None:
        try:
            control.Click(simulateMove=False)
        except Exception:
            control.SetFocus()
            self.require_uiautomation().SendKeys("{Enter}", waitTime=0.1)
        time.sleep(0.35)

    def double_click_control(self, control: Any) -> None:
        try:
            control.DoubleClick(simulateMove=False)
        except Exception:
            try:
                control.Click(simulateMove=False)
                time.sleep(0.12)
                control.Click(simulateMove=False)
            except Exception:
                control.SetFocus()
                self.require_uiautomation().SendKeys("{Enter}", waitTime=0.08)
                time.sleep(0.08)
                self.require_uiautomation().SendKeys("{Enter}", waitTime=0.08)
        time.sleep(0.45)

    def find_first_descendant(
        self,
        root: Any,
        *,
        control_types: Iterable[str] = (),
        class_names: Iterable[str] = (),
        timeout_ms: int = 5000,
        max_depth: int = 8,
    ):
        control_types_normalized = [value.lower() for value in control_types if value]
        class_names_normalized = [value.lower() for value in class_names if value]
        deadline = time.time() + (timeout_ms / 1000)

        while time.time() < deadline:
            for control in self._iter_descendants(root, max_depth=max_depth):
                control_type = str(getattr(control, "ControlTypeName", "") or "").strip().lower()
                class_name = str(getattr(control, "ClassName", "") or "").strip().lower()
                if control_types_normalized and control_type not in control_types_normalized:
                    continue
                if class_names_normalized and class_name not in class_names_normalized:
                    continue
                return control
            time.sleep(0.2)

        raise RuntimeError("first_control_not_found")

    def collect_descendants(
        self,
        root: Any,
        *,
        max_depth: int = 8,
        limit: int = 200,
    ) -> list[Any]:
        collected: list[Any] = []
        for index, control in enumerate(self._iter_descendants(root, max_depth=max_depth)):
            if index >= limit:
                break
            collected.append(control)
        return collected

    def get_root_control(self):
        return self.require_uiautomation().GetRootControl()

    def enter_text(self, control: Any, text: str, *, clear_first: bool = True) -> None:
        control.SetFocus()
        time.sleep(0.2)
        automation = self.require_uiautomation()
        if clear_first:
            automation.SendKeys("{Ctrl}a", waitTime=0.05)
            automation.SendKeys("{Del}", waitTime=0.05)
        automation.SendKeys(text, waitTime=0.02)
        time.sleep(0.45)

    def send_keys(self, keys: str) -> None:
        self.require_uiautomation().SendKeys(keys, waitTime=0.08)
        time.sleep(0.25)

    def set_clipboard_text(self, text: str) -> None:
        CF_UNICODETEXT = 13
        GMEM_MOVEABLE = 0x0002

        data = ctypes.create_unicode_buffer(text)
        data_size = ctypes.sizeof(data)

        h_global = self.kernel32.GlobalAlloc(GMEM_MOVEABLE, data_size)
        if not h_global:
            raise RuntimeError("clipboard_global_alloc_failed")

        locked = self.kernel32.GlobalLock(h_global)
        if not locked:
            self.kernel32.GlobalFree(h_global)
            raise RuntimeError("clipboard_global_lock_failed")

        try:
            ctypes.memmove(locked, ctypes.addressof(data), data_size)
        finally:
            self.kernel32.GlobalUnlock(h_global)

        opened = False
        try:
            for _ in range(10):
                if self.user32.OpenClipboard(0):
                    opened = True
                    break
                time.sleep(0.05)

            if not opened:
                self.kernel32.GlobalFree(h_global)
                raise RuntimeError("clipboard_open_failed")

            self.user32.EmptyClipboard()
            if not self.user32.SetClipboardData(CF_UNICODETEXT, h_global):
                raise RuntimeError("clipboard_set_data_failed")
            h_global = None
        finally:
            if opened:
                self.user32.CloseClipboard()
            if h_global:
                self.kernel32.GlobalFree(h_global)

    def get_bounds(self, control: Any) -> dict[str, int]:
        rect = getattr(control, "BoundingRectangle", None)
        if rect is None:
            raise RuntimeError("bounding_rectangle_not_available")
        left = int(getattr(rect, "left", 0))
        top = int(getattr(rect, "top", 0))
        right = int(getattr(rect, "right", left))
        bottom = int(getattr(rect, "bottom", top))
        return {
            "left": left,
            "top": top,
            "right": right,
            "bottom": bottom,
            "width": max(0, right - left),
            "height": max(0, bottom - top),
        }

    def get_window_rect(self, hwnd: int) -> dict[str, int]:
        rect = ctypes.wintypes.RECT()
        if not self.user32.GetWindowRect(int(hwnd), ctypes.byref(rect)):
            raise RuntimeError("get_window_rect_failed")
        left = int(rect.left)
        top = int(rect.top)
        right = int(rect.right)
        bottom = int(rect.bottom)
        return {
            "left": left,
            "top": top,
            "right": right,
            "bottom": bottom,
            "width": max(0, right - left),
            "height": max(0, bottom - top),
        }

    def click_point(self, x: int, y: int, *, double: bool = False) -> None:
        self.user32.SetCursorPos(int(x), int(y))
        time.sleep(0.06)
        self.user32.mouse_event(0x0002, 0, 0, 0, 0)
        self.user32.mouse_event(0x0004, 0, 0, 0, 0)
        if double:
            time.sleep(0.08)
            self.user32.mouse_event(0x0002, 0, 0, 0, 0)
            self.user32.mouse_event(0x0004, 0, 0, 0, 0)
        time.sleep(0.35 if not double else 0.5)

    def click_relative_point(
        self,
        control: Any,
        *,
        rel_x: float,
        rel_y: float,
        double: bool = False,
    ) -> tuple[int, int]:
        bounds = self.get_bounds(control)
        x = bounds["left"] + int(bounds["width"] * rel_x)
        y = bounds["top"] + int(bounds["height"] * rel_y)
        self.click_point(x, y, double=double)
        return (x, y)

    def click_window_relative_point(
        self,
        hwnd: int,
        *,
        rel_x: float,
        rel_y: float,
        double: bool = False,
    ) -> tuple[int, int]:
        bounds = self.get_window_rect(hwnd)
        x = bounds["left"] + int(bounds["width"] * rel_x)
        y = bounds["top"] + int(bounds["height"] * rel_y)
        self.click_point(x, y, double=double)
        return (x, y)

    def hover_point(self, x: int, y: int, *, pause_ms: int = 350) -> None:
        self.user32.SetCursorPos(int(x), int(y))
        time.sleep(max(0.05, pause_ms / 1000))

    def get_control_from_point(self, x: int, y: int):
        automation = self.require_uiautomation()
        try:
            return automation.ControlFromPoint(x, y)
        except Exception:
            return None

    def get_control_lineage(self, control: Any, *, max_depth: int = 6) -> list[dict[str, str]]:
        lineage: list[dict[str, str]] = []
        current = control
        depth = 0
        while current is not None and depth < max_depth:
            lineage.append(
                {
                    "name": self._safe_control_name(current),
                    "type": self._safe_attr_as_string(current, "ControlTypeName"),
                    "class_name": self._safe_attr_as_string(current, "ClassName"),
                    "automation_id": self._safe_attr_as_string(current, "AutomationId"),
                }
            )
            try:
                current = current.GetParentControl()
            except Exception:
                current = None
            depth += 1
        return lineage

    def describe_descendants(
        self,
        root: Any,
        *,
        max_depth: int = 4,
        limit: int = 40,
    ) -> list[str]:
        lines: list[str] = []
        for index, control in enumerate(self._iter_descendants(root, max_depth=max_depth)):
            if index >= limit:
                break
            name = str(getattr(control, "Name", "") or "").strip()
            control_type = str(getattr(control, "ControlTypeName", "") or "").strip()
            class_name = str(getattr(control, "ClassName", "") or "").strip()
            automation_id = str(getattr(control, "AutomationId", "") or "").strip()
            lines.append(
                f"name={name or '<empty>'} | type={control_type or '<empty>'} | class={class_name or '<empty>'} | id={automation_id or '<empty>'}"
            )
        return lines

    def _try_import_uiautomation(self):
        try:
            import uiautomation as automation  # type: ignore

            return automation
        except Exception:
            return None

    def _matches_control(
        self,
        control: Any,
        *,
        names: list[str],
        control_types: list[str],
        class_names: list[str],
        automation_ids: list[str],
    ) -> bool:
        name = str(getattr(control, "Name", "") or "").strip().lower()
        control_type = str(getattr(control, "ControlTypeName", "") or "").strip().lower()
        class_name = str(getattr(control, "ClassName", "") or "").strip().lower()
        automation_id = str(getattr(control, "AutomationId", "") or "").strip().lower()

        if names and not any(candidate in name for candidate in names):
            return False
        if control_types and control_type not in control_types:
            return False
        if class_names and class_name not in class_names:
            return False
        if automation_ids and automation_id not in automation_ids:
            return False
        return True

    def _iter_descendants(self, root: Any, *, max_depth: int = 8):
        stack: list[tuple[Any, int]] = [(root, 0)]
        while stack:
            control, depth = stack.pop()
            if depth > max_depth:
                continue
            try:
                children = list(control.GetChildren())
            except Exception:
                children = []
            for child in children:
                yield child
                stack.append((child, depth + 1))

    def _enumerate_windows(self) -> list[WindowInfo]:
        windows: list[WindowInfo] = []

        if self._uiautomation is not None:
            try:
                root = self._uiautomation.GetRootControl()
                for child in root.GetChildren():
                    name = self._safe_control_name(child)
                    if name:
                        native_handle = self._safe_int_attr(child, "NativeWindowHandle")
                        windows.append(
                            WindowInfo(
                                handle=native_handle,
                                title=name,
                                visible=True,
                                process_name=self._get_process_name(native_handle),
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
                        process_name=self._get_process_name(int(hwnd)),
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
            process_name=self._get_process_name(int(hwnd)),
        )

    def _resolve_launch_command(self, command: list[str]) -> list[str]:
        if not command:
            raise RuntimeError("empty_launch_command")
        executable = command[0]
        lowered = executable.lower()
        if lowered != "kakaotalk.exe":
            return command

        candidates = [
            executable,
            r"C:\Program Files\Kakao\KakaoTalk\KakaoTalk.exe",
            r"C:\Program Files (x86)\Kakao\KakaoTalk\KakaoTalk.exe",
        ]
        local_app_data = os.environ.get("LOCALAPPDATA", "")
        if local_app_data:
            candidates.append(
                os.path.join(local_app_data, "Kakao", "KakaoTalk", "KakaoTalk.exe")
            )

        for candidate in candidates:
            if os.path.isfile(candidate):
                return [candidate, *command[1:]]

        raise RuntimeError("kakaotalk_executable_not_found")

    def _get_process_name(self, hwnd: int) -> str:
        if not hwnd:
            return ""
        process_id = ctypes.c_ulong(0)
        self.user32.GetWindowThreadProcessId(hwnd, ctypes.byref(process_id))
        pid = int(process_id.value or 0)
        if not pid:
            return ""

        kernel32 = ctypes.windll.kernel32
        process = kernel32.OpenProcess(0x1000, False, pid)
        if not process:
            return ""

        try:
            buffer_length = ctypes.c_ulong(260)
            buffer = ctypes.create_unicode_buffer(buffer_length.value)
            query_full_process_image_name = getattr(kernel32, "QueryFullProcessImageNameW", None)
            if query_full_process_image_name and query_full_process_image_name(
                process,
                0,
                buffer,
                ctypes.byref(buffer_length),
            ):
                full_path = buffer.value
                return full_path.split("\\")[-1]
        finally:
            kernel32.CloseHandle(process)

        return ""

    def _safe_control_name(self, control: Any) -> str:
        return self._safe_attr_as_string(control, "Name")

    def _safe_attr_as_string(self, control: Any, attribute_name: str) -> str:
        try:
            return str(getattr(control, attribute_name, "") or "").strip()
        except Exception:
            return ""

    def _safe_int_attr(self, control: Any, attribute_name: str) -> int:
        try:
            return int(getattr(control, attribute_name, 0) or 0)
        except Exception:
            return 0
