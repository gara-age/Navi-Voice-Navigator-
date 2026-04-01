from __future__ import annotations

import json
from pathlib import Path

from config import BackgroundConfig


class SettingsReader:
    def __init__(self) -> None:
        self.root = Path(__file__).resolve().parents[2]
        self.settings_path = self.root / "runtime" / "settings.json"

    def load(self) -> BackgroundConfig:
        config = BackgroundConfig()
        if not self.settings_path.exists():
            return config

        try:
            payload = json.loads(self.settings_path.read_text(encoding="utf-8"))
        except Exception:
            return config

        shortcuts = payload.get("shortcuts", {})
        if isinstance(shortcuts, dict):
            config.shortcuts_enabled = bool(
                shortcuts.get("enabled", config.shortcuts_enabled)
            )
            config.listen_toggle_key = str(shortcuts.get("listen_toggle", config.listen_toggle_key))
            config.screen_read_key = str(shortcuts.get("screen_read", config.screen_read_key))
            config.open_settings_key = str(shortcuts.get("open_settings", config.open_settings_key))

        return config
