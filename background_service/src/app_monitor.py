from __future__ import annotations

import subprocess
from pathlib import Path


class AppMonitor:
    def __init__(self) -> None:
        self.root = Path(__file__).resolve().parents[2]
        self.launcher = self.root / "start_flutter_connected.bat"
        self.demo_launcher = self.root / "start_flutter_demo.bat"

    def is_main_app_running(self) -> bool:
        try:
            result = subprocess.run(
                ["tasklist", "/FO", "CSV", "/NH"],
                capture_output=True,
                text=True,
                check=False,
                encoding="utf-8",
                errors="ignore",
            )
        except Exception:
            return False

        lowered = result.stdout.lower()
        return "voice_navigator.exe" in lowered or "flutter_tester.exe" in lowered

    def ensure_running(self, demo_mode: bool = False) -> bool:
        if self.is_main_app_running():
            return True

        launcher = self.demo_launcher if demo_mode else self.launcher
        if not launcher.exists():
            return False

        try:
            subprocess.Popen(
                [str(launcher)],
                cwd=str(self.root),
                shell=True,
            )
            return True
        except Exception:
            return False
