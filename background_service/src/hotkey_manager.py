from __future__ import annotations

import ctypes
import json
import time
from pathlib import Path
from ctypes import wintypes

import events
from app_monitor import AppMonitor
from config import BackgroundConfig
from event_dispatcher import EventDispatcher
from server_probe import ServerProbe
from settings_reader import SettingsReader


class HotkeyManager:
    MOD_ALT = 0x0001
    MOD_CONTROL = 0x0002
    MOD_SHIFT = 0x0004
    MOD_WIN = 0x0008
    MOD_NOREPEAT = 0x4000
    WM_HOTKEY = 0x0312
    PM_REMOVE = 0x0001

    def __init__(
        self,
        config: BackgroundConfig,
        dispatcher: EventDispatcher,
        server_probe: ServerProbe | None = None,
    ) -> None:
        self.config = config
        self.dispatcher = dispatcher
        self.server_probe = server_probe or ServerProbe(config.server_base_url)
        self.app_monitor = AppMonitor()
        self.settings_reader = SettingsReader()
        self.root = Path(__file__).resolve().parents[2]
        self.runtime_dir = self.root / "runtime"
        self.event_file = self.runtime_dir / "background_event.json"
        self.ui_state_file = self.runtime_dir / "ui_state.json"
        self.settings_file = self.settings_reader.settings_path
        self.kernel32 = ctypes.windll.kernel32
        self.user32 = ctypes.windll.user32
        self._last_reload_check = 0.0
        self._last_app_running_check = 0.0
        self._cached_app_running = False
        self._bindings: dict[str, str] = {}
        self._actions: dict[str, object] = {}
        self._key_specs: dict[str, tuple[int, int]] = {}
        self._pressed: dict[str, bool] = {}
        self._rebuild_bindings()
        self._settings_signature = self._make_settings_signature(self.config)
        self._registered_hotkeys: dict[int, str] = {}
        self._register_supported = False
        self._hotkeys_registered = False

    def describe_bindings(self) -> dict[str, str]:
        return dict(self._bindings)

    def start(self) -> None:
        self._register_supported = self._register_hotkeys()
        self._hotkeys_registered = self._register_supported
        if self._register_supported:
            print("Using RegisterHotKey-based global hotkey detection.")
        else:
            print("Using polling-based global hotkey detection.")

    def run_forever(self) -> None:
        self.start()
        try:
            while True:
                self._reload_settings_if_needed()
                if self._register_supported:
                    suspended = self._are_hotkeys_suspended()
                    self._sync_hotkey_registration(suspended)
                    if self._hotkeys_registered:
                        self._pump_hotkey_messages()
                    time.sleep(0.01)
                else:
                    self._poll_hotkeys()
                    time.sleep(0.02)
        except KeyboardInterrupt:
            self.stop()

    def stop(self) -> None:
        self._pressed = {name: False for name in self._pressed}
        self._unregister_hotkeys()
        self._hotkeys_registered = False

    def _reload_settings_if_needed(self) -> None:
        now = time.monotonic()
        if now - self._last_reload_check < 0.35:
            return

        self._last_reload_check = now
        next_config = self.settings_reader.load()
        next_signature = self._make_settings_signature(next_config)
        if next_signature == self._settings_signature:
            return

        self.config = next_config
        self._settings_signature = next_signature
        self.server_probe = ServerProbe(self.config.server_base_url)
        self._rebuild_bindings()
        if self._register_supported:
            self._unregister_hotkeys()
            self._hotkeys_registered = self._register_hotkeys()
        print(f"Hotkey bindings updated: {self.describe_bindings()}")

    def _make_settings_signature(self, config: BackgroundConfig) -> tuple[object, ...]:
        return (
            config.shortcuts_enabled,
            self._normalize_hotkey(config.listen_toggle_key),
            self._normalize_hotkey(config.screen_read_key),
            self._normalize_hotkey(config.open_settings_key),
            config.server_base_url,
            config.prefer_demo_when_server_unavailable,
        )

    def _rebuild_bindings(self) -> None:
        bindings: dict[str, str] = {}
        actions = {
            "listen_toggle": self._handle_listen_toggle,
            "screen_read": self._handle_screen_read,
            "open_settings": self._handle_open_settings,
        }

        if self.config.shortcuts_enabled:
            listen = self._normalize_hotkey(self.config.listen_toggle_key)
            screen = self._normalize_hotkey(self.config.screen_read_key)
            open_settings = self._normalize_hotkey(self.config.open_settings_key)

            if listen:
                bindings["listen_toggle"] = listen
            if screen:
                bindings["screen_read"] = screen
            if open_settings:
                bindings["open_settings"] = open_settings

        self._bindings = bindings
        self._actions = {
            name: actions[name]
            for name in self._bindings
        }
        self._key_specs = {
            name: self._parse_hotkey(binding)
            for name, binding in self._bindings.items()
        }
        self._pressed = {name: False for name in self._bindings}

    def _poll_hotkeys(self) -> None:
        for action_name, handler in self._actions.items():
            if self._are_hotkeys_suspended():
                self._pressed[action_name] = False
                continue
            is_pressed = self._is_hotkey_pressed(*self._key_specs[action_name])
            if is_pressed and not self._pressed[action_name]:
                self._pressed[action_name] = True
                handler()
            elif not is_pressed:
                self._pressed[action_name] = False

    def _register_hotkeys(self) -> bool:
        self._registered_hotkeys.clear()
        hotkey_ids = {
            "listen_toggle": 1,
            "screen_read": 2,
            "open_settings": 3,
        }

        for action_name, binding in self._bindings.items():
            modifiers, virtual_key = self._parse_hotkey(binding)
            hotkey_id = hotkey_ids[action_name]
            success = self.user32.RegisterHotKey(
                None,
                hotkey_id,
                modifiers | self.MOD_NOREPEAT,
                virtual_key,
            )
            if not success:
                self._unregister_hotkeys()
                return False
            self._registered_hotkeys[hotkey_id] = action_name

        return True

    def _unregister_hotkeys(self) -> None:
        for hotkey_id in list(self._registered_hotkeys.keys()):
            try:
                self.user32.UnregisterHotKey(None, hotkey_id)
            except Exception:
                pass
        self._registered_hotkeys.clear()

    def _sync_hotkey_registration(self, suspended: bool) -> None:
        if suspended and self._hotkeys_registered:
            self._unregister_hotkeys()
            self._hotkeys_registered = False
            return

        if not suspended and not self._hotkeys_registered:
            self._hotkeys_registered = self._register_hotkeys()

    def _pump_hotkey_messages(self) -> None:
        if not self._registered_hotkeys:
            return

        msg = wintypes.MSG()
        while self.user32.PeekMessageW(ctypes.byref(msg), None, 0, 0, self.PM_REMOVE):
            if msg.message != self.WM_HOTKEY:
                continue

            action_name = self._registered_hotkeys.get(int(msg.wParam))
            handler = self._actions.get(action_name)
            if action_name is None or handler is None:
                continue
            if self._are_hotkeys_suspended():
                continue
            handler()

    def _handle_listen_toggle(self) -> None:
        print("Global hotkey pressed: listen_toggle")
        server_ready, demo_mode = self._prepare_app()
        print(f"App prepared. server_ready={server_ready}, demo_mode={demo_mode}")
        if server_ready:
            self.dispatcher.send(events.START_LISTENING)
        self._write_local_event(events.START_LISTENING)
        print("Queued local event: START_LISTENING")

    def _handle_screen_read(self) -> None:
        print("Global hotkey pressed: screen_read")
        server_ready, demo_mode = self._prepare_app()
        print(f"App prepared. server_ready={server_ready}, demo_mode={demo_mode}")
        if server_ready:
            self.dispatcher.send(events.START_SCREEN_READ)
        self._write_local_event(events.START_SCREEN_READ)
        print("Queued local event: START_SCREEN_READ")

    def _handle_open_settings(self) -> None:
        print("Global hotkey pressed: open_settings")
        server_ready, demo_mode = self._prepare_app()
        print(f"App prepared. server_ready={server_ready}, demo_mode={demo_mode}")
        if server_ready:
            self.dispatcher.send(events.OPEN_SETTINGS)
        self._write_local_event(events.OPEN_SETTINGS)
        print("Queued local event: OPEN_SETTINGS")

    def _prepare_app(self) -> tuple[bool, bool]:
        server_ready = self.server_probe.is_server_ready()
        app_running = self.app_monitor.is_main_app_running()
        demo_mode = self.config.prefer_demo_when_server_unavailable and not server_ready and not app_running
        self.app_monitor.ensure_running(demo_mode=demo_mode)
        time.sleep(0.8)
        return server_ready, demo_mode

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

    def _are_hotkeys_suspended(self) -> bool:
        now = time.monotonic()
        if now - self._last_app_running_check >= 0.75:
            self._cached_app_running = self.app_monitor.is_main_app_running()
            self._last_app_running_check = now

        if not self._cached_app_running:
            return False

        if not self.ui_state_file.exists():
            return False

        try:
            payload = json.loads(self.ui_state_file.read_text(encoding="utf-8"))
        except Exception:
            return False

        updated_at_ms = payload.get("updated_at_ms")
        if isinstance(updated_at_ms, (int, float)):
            age_ms = int(time.time() * 1000) - int(updated_at_ms)
            if age_ms > 5000:
                return False

        return bool(payload.get("settings_modal_open", False)) or bool(
            payload.get("app_focused", False)
        )

    def _normalize_hotkey(self, hotkey: str) -> str:
        return hotkey.strip().lower()

    def _parse_hotkey(self, hotkey: str) -> tuple[int, int]:
        modifiers = 0
        parts = [part.strip().lower() for part in hotkey.split("+") if part.strip()]
        key_name = parts[-1] if parts else "f2"

        for part in parts[:-1]:
            if part in {"ctrl", "control"}:
                modifiers |= self.MOD_CONTROL
            elif part == "shift":
                modifiers |= self.MOD_SHIFT
            elif part == "alt":
                modifiers |= self.MOD_ALT
            elif part in {"win", "windows", "meta"}:
                modifiers |= self.MOD_WIN

        return modifiers, self._virtual_key_for(key_name)

    def _is_hotkey_pressed(self, modifiers: int, virtual_key: int) -> bool:
        if not self._is_modifier_state_valid(modifiers):
            return False

        return self._is_key_down(virtual_key)

    def _is_modifier_state_valid(self, modifiers: int) -> bool:
        checks = (
            (self.MOD_CONTROL, 0x11),
            (self.MOD_SHIFT, 0x10),
            (self.MOD_ALT, 0x12),
            (self.MOD_WIN, 0x5B),
        )

        for modifier_flag, virtual_key in checks:
            required = (modifiers & modifier_flag) != 0
            if self._is_key_down(virtual_key) != required:
                return False

        if modifiers & self.MOD_WIN:
            return self._is_key_down(0x5B) or self._is_key_down(0x5C)

        return True

    def _is_key_down(self, virtual_key: int) -> bool:
        return (self.user32.GetAsyncKeyState(virtual_key) & 0x8000) != 0

    def _virtual_key_for(self, key_name: str) -> int:
        function_keys = {f"f{index}": 0x6F + index for index in range(1, 25)}
        if key_name in function_keys:
            return function_keys[key_name]

        if len(key_name) == 1 and key_name.isalpha():
            return ord(key_name.upper())

        if len(key_name) == 1 and key_name.isdigit():
            return ord(key_name)

        named_keys = {
            "space": 0x20,
            "enter": 0x0D,
            "esc": 0x1B,
            "escape": 0x1B,
            "tab": 0x09,
        }
        return named_keys.get(key_name, 0x71)
