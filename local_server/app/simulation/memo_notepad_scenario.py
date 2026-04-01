from __future__ import annotations

import json
import subprocess
import time
from ctypes import windll
from datetime import datetime
from pathlib import Path

import uiautomation as automation


MEMO_TEXT = (
    "오늘은 평소보다 조금 일찍 눈을 떴다. 창문 사이로 들어오는 햇빛이 생각보다 따뜻해서, "
    "괜히 하루가 괜찮을 것 같은 기분이 들었다. 별다른 계획은 없었지만, 오히려 그래서 더 "
    "여유롭게 시간을 보낼 수 있었다. 커피를 천천히 마시면서 그동안 미뤄두었던 생각들을 "
    "정리해봤다. 요즘 나는 어디로 가고 있는지, 무엇을 원하는지에 대해 스스로에게 질문을 "
    "던져봤다. 명확한 답은 나오지 않았지만, 그 과정 자체가 조금은 의미 있게 느껴졌다. "
    "오후에는 가볍게 산책을 나갔다. 바람이 적당히 불고, 사람들의 표정도 나쁘지 않아 보여서 "
    "괜히 마음이 편해졌다. 특별한 일이 있었던 하루는 아니었지만, 이렇게 조용히 흘러가는 시간도 "
    "나쁘지 않다고 느꼈다. 오늘의 나는 조금은 괜찮았던 것 같다."
)


def emit_progress(payload: dict) -> None:
    print(
        json.dumps(
            {
                "kind": "progress",
                "payload": payload,
            },
            ensure_ascii=False,
        ),
        flush=True,
    )


def _set_clipboard_text(text: str) -> None:
    CF_UNICODETEXT = 13
    GMEM_MOVEABLE = 0x0002

    user32 = windll.user32
    kernel32 = windll.kernel32

    if not user32.OpenClipboard(0):
        raise RuntimeError("clipboard_open_failed")
    try:
        user32.EmptyClipboard()
        data = text.encode("utf-16-le") + b"\x00\x00"
        handle = kernel32.GlobalAlloc(GMEM_MOVEABLE, len(data))
        pointer = kernel32.GlobalLock(handle)
        try:
            windll.msvcrt.memcpy(pointer, data, len(data))
        finally:
            kernel32.GlobalUnlock(handle)
        user32.SetClipboardData(CF_UNICODETEXT, handle)
    finally:
        user32.CloseClipboard()


def _wait_for_notepad_window(process_id: int, timeout_seconds: float = 10.0):
    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        window = automation.WindowControl(searchDepth=1, ProcessId=process_id)
        if window.Exists(maxSearchSeconds=0.2):
            return window
        time.sleep(0.2)
    raise RuntimeError("notepad_window_not_found")


def _focus_notepad(window) -> None:
    window.SetActive()
    time.sleep(0.6)


def _send_shortcut(keys: str) -> None:
    automation.SendKeys(keys, waitTime=0.1)
    time.sleep(0.4)


def run() -> dict:
    steps: list[dict] = []
    current_date = datetime.now().strftime("%Y-%m-%d")
    file_name = f"{current_date}일기.txt"
    save_path = Path.home() / "Documents" / file_name
    save_path.parent.mkdir(parents=True, exist_ok=True)
    save_path.write_text("", encoding="utf-8")

    def emit(step: int, action: str, status: str, detail: str, popup_state: str = "processing") -> None:
        emit_progress(
            {
                "step": step,
                "action": action,
                "status": status,
                "detail": detail,
                "popup_state": popup_state,
            }
        )

    def record(step: int, action: str, detail: str) -> None:
        payload = {
            "step": step,
            "action": action,
            "status": "success",
            "detail": detail,
        }
        steps.append(payload)
        emit_progress(
            {
                "step": step,
                "action": action,
                "status": "success",
                "detail": detail,
                "popup_state": "success",
            }
        )

    emit(1, "open_notepad", "processing", "메모장을 실행하는 중입니다.")
    process = subprocess.Popen(["notepad.exe", str(save_path)])
    window = _wait_for_notepad_window(process.pid)
    _focus_notepad(window)
    record(1, "open_notepad", "메모장을 열었습니다.")

    emit(2, "prepare_editor", "processing", "메모장 편집 영역을 준비하는 중입니다.")
    _focus_notepad(window)
    _send_shortcut("{Ctrl}a")
    _send_shortcut("{DEL}")
    record(2, "prepare_editor", "기존 내용을 비우고 편집 영역을 준비했습니다.")

    emit(3, "paste_content", "processing", "일기 내용을 입력하는 중입니다.")
    _set_clipboard_text(MEMO_TEXT)
    _focus_notepad(window)
    _send_shortcut("{Ctrl}v")
    time.sleep(0.8)
    record(3, "paste_content", "일기 내용을 입력했습니다.")

    emit(4, "save_file", "processing", f"{file_name} 이름으로 저장하는 중입니다.")
    _focus_notepad(window)
    _send_shortcut("{Ctrl}s")
    time.sleep(1.0)
    record(4, "save_file", f"{file_name} 이름으로 저장했습니다.")

    emit(5, "verify_saved_file", "processing", "저장된 파일 내용을 확인하는 중입니다.")
    saved_text = save_path.read_text(encoding="utf-8")
    if MEMO_TEXT[:40] not in saved_text:
        raise RuntimeError("saved_file_content_mismatch")
    record(5, "verify_saved_file", str(save_path))

    return {
        "status": "success",
        "scenario": "memo_notepad",
        "steps": steps,
        "file_name": file_name,
        "saved_path": str(save_path),
        "route_summary": f"{file_name} 파일로 저장했습니다.",
    }


def main() -> None:
    result = run()
    print(
        json.dumps(
            {
                "kind": "result",
                "payload": result,
            },
            ensure_ascii=False,
        ),
        flush=True,
    )


if __name__ == "__main__":
    main()
