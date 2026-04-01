from __future__ import annotations

import os
import sys
from pathlib import Path


def resolve_project_root() -> Path:
    env_root = os.environ.get("VOICE_NAVIGATOR_ROOT", "").strip()
    if env_root:
        candidate = Path(env_root).resolve()
        if candidate.exists():
            return candidate

    candidates: list[Path] = []
    candidates.append(Path.cwd().resolve())

    if getattr(sys, "frozen", False):
        exe_dir = Path(sys.executable).resolve().parent
        candidates.extend([exe_dir, exe_dir.parent, exe_dir.parent.parent])
    else:
        candidates.append(Path(__file__).resolve().parents[2])

    for candidate in candidates:
        if (
            (candidate / "runtime").exists()
            or (candidate / "background_service").exists()
            or (candidate / "start_voice_navigator_launcher.bat").exists()
        ):
            return candidate

    return candidates[0]
