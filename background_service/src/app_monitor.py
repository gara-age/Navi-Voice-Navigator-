from __future__ import annotations

import subprocess
from pathlib import Path

from path_utils import resolve_project_root


class AppMonitor:
    def __init__(self) -> None:
        self.root = resolve_project_root()
        self.launcher = self.root / "start_flutter_connected.ps1"
        self.demo_launcher = self.root / "start_flutter_demo.ps1"
        self.connected_exe = self.root / "dist" / "connected" / "voice_navigator.exe"
        self.demo_exe = self.root / "dist" / "demo" / "voice_navigator.exe"
        self.creationflags = getattr(subprocess, "CREATE_NO_WINDOW", 0)

    def is_main_app_running(self) -> bool:
        try:
            result = subprocess.run(
                ["tasklist", "/FO", "CSV", "/NH"],
                capture_output=True,
                text=True,
                check=False,
                encoding="utf-8",
                errors="ignore",
                creationflags=self.creationflags,
            )
        except Exception:
            return False

        lowered = result.stdout.lower()
        return "voice_navigator.exe" in lowered or "flutter_tester.exe" in lowered

    def ensure_running(self, demo_mode: bool = False) -> bool:
        if self.is_main_app_running():
            return True

        executable = self.demo_exe if demo_mode else self.connected_exe
        launcher = self.demo_launcher if demo_mode else self.launcher
        if not launcher.exists():
            if not executable.exists():
                return False

        try:
            if executable.exists():
                subprocess.Popen(
                    [str(executable)],
                    cwd=str(executable.parent),
                    creationflags=self.creationflags,
                )
                return True

            subprocess.Popen(
                [
                    "powershell",
                    "-WindowStyle",
                    "Hidden",
                    "-ExecutionPolicy",
                    "Bypass",
                    "-File",
                    str(launcher),
                ],
                cwd=str(self.root),
                creationflags=self.creationflags,
            )
            return True
        except Exception:
            return False
