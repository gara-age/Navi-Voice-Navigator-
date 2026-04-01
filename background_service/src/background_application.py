from __future__ import annotations

import atexit
import json
import subprocess
import threading
import time
from ctypes import WinDLL, c_void_p, get_last_error
from ctypes.wintypes import BOOL, LPCWSTR
from pathlib import Path

import events
import pystray
from PIL import Image

from app_monitor import AppMonitor
from config import BackgroundConfig
from event_dispatcher import EventDispatcher
from hotkey_manager import HotkeyManager
from path_utils import resolve_project_root
from server_probe import ServerProbe
from settings_reader import SettingsReader
from window_controller import WindowController

ERROR_ALREADY_EXISTS = 183


class BackgroundApplication:
    def __init__(self, config: BackgroundConfig) -> None:
        self.config = config
        self.settings_reader = SettingsReader()
        self.dispatcher = EventDispatcher(config)
        self.server_probe = ServerProbe(config.server_base_url)
        self.window_controller = WindowController()
        self.app_monitor = AppMonitor()
        self.hotkeys = HotkeyManager(
            config,
            self.dispatcher,
            server_probe=self.server_probe,
        )
        self.root = resolve_project_root()
        self.runtime_dir = self.root / "runtime"
        self.event_file = self.runtime_dir / "background_event.json"
        self.stop_event = threading.Event()
        self.hotkey_thread: threading.Thread | None = None
        self.icon: pystray.Icon | None = None
        self._mutex_handle: c_void_p | None = None

    def run(self) -> None:
        if not self._acquire_single_instance():
            return

        self.hotkey_thread = threading.Thread(
            target=self.hotkeys.run_forever,
            kwargs={"stop_event": self.stop_event},
            name="navi-background-hotkeys",
            daemon=True,
        )
        self.hotkey_thread.start()

        self.icon = pystray.Icon(
            "navi_background",
            self._load_icon(),
            "Navi Background",
            menu=pystray.Menu(
                pystray.MenuItem("모두 종료하기", self._on_exit_all_clicked),
            ),
        )
        self.icon.run()

    def _load_icon(self) -> Image.Image:
        executable_dir = Path(__file__).resolve().parent
        bundled_icon = executable_dir / "app_icon.ico"
        repo_icon = (
            self.root
            / "app_flutter"
            / "windows"
            / "runner"
            / "resources"
            / "app_icon.ico"
        )
        icon_path = bundled_icon if bundled_icon.exists() else repo_icon
        return Image.open(icon_path)

    def _on_exit_all_clicked(
        self,
        icon: pystray.Icon,
        item: pystray.MenuItem,
    ) -> None:
        del item
        self._stop_main_processes()
        self.stop()
        icon.stop()

    def stop(self) -> None:
        self.stop_event.set()
        self.hotkeys.stop()
        if self.hotkey_thread is not None and self.hotkey_thread.is_alive():
            self.hotkey_thread.join(timeout=1.5)
        self._release_single_instance()

    def _show_app(self) -> None:
        if self.window_controller.restore_or_show():
            return

        self.app_monitor.ensure_running(demo_mode=False)
        time.sleep(0.6)
        self.window_controller.restore_or_show()

    def _write_local_event(self, event_name: str) -> None:
        self.runtime_dir.mkdir(parents=True, exist_ok=True)
        payload = {
            "event": event_name,
            "timestamp_ms": int(time.time() * 1000),
        }
        self.event_file.write_text(
            json.dumps(payload, ensure_ascii=False),
            encoding="utf-8",
        )

    def _stop_main_processes(self) -> None:
        commands = (
            ["taskkill", "/IM", "voice_navigator.exe", "/F"],
            ["taskkill", "/IM", "flutter_tester.exe", "/F"],
        )

        for command in commands:
            try:
                subprocess.run(
                    command,
                    check=False,
                    capture_output=True,
                    creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0),
                )
            except Exception:
                pass

    def _acquire_single_instance(self) -> bool:
        kernel32 = WinDLL("kernel32", use_last_error=True)
        kernel32.CreateMutexW.argtypes = [c_void_p, BOOL, LPCWSTR]
        kernel32.CreateMutexW.restype = c_void_p

        handle = kernel32.CreateMutexW(None, False, "Local\\NaviBackgroundSingleton")
        if not handle:
            return False

        self._mutex_handle = handle
        atexit.register(self._release_single_instance)
        return get_last_error() != ERROR_ALREADY_EXISTS

    def _release_single_instance(self) -> None:
        if self._mutex_handle is None:
            return

        kernel32 = WinDLL("kernel32", use_last_error=True)
        kernel32.CloseHandle.argtypes = [c_void_p]
        kernel32.CloseHandle.restype = BOOL
        kernel32.CloseHandle(self._mutex_handle)
        self._mutex_handle = None
