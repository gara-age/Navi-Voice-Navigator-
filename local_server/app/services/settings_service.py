import json
from pathlib import Path
from typing import Any


class SettingsService:
    def __init__(self) -> None:
        self._path = Path("runtime") / "settings.json"

    def save(self, settings: dict[str, Any]) -> dict[str, Any]:
        self._path.parent.mkdir(parents=True, exist_ok=True)
        self._path.write_text(
            json.dumps(settings, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )
        return settings

    def load(self) -> dict[str, Any]:
        if not self._path.exists():
            return {}
        return json.loads(self._path.read_text(encoding="utf-8"))
