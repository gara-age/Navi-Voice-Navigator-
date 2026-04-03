from __future__ import annotations

import json
import time

from local_server.app.automation.windows.ui_automation_helper import UiAutomationHelper


KAKAOTALK_KEYWORDS = [
    "\uCE74\uCE74\uC624\uD1A1",
    "kakaotalk",
    "kakao",
]
KAKAOTALK_PROCESS_NAMES = ["KakaoTalk.exe"]
RECIPIENT_NAME = "\uB098\uC640\uC758 \uCC44\uD305"
MESSAGE_TEXT = (
    "\uce74\uce74\uc624\ud1a1 \uc790\ub3d9\ud654 \ud14c\uc2a4\ud2b8 \uba54\uc2dc\uc9c0\uc785\ub2c8\ub2e4"
)


def emit_progress(payload: dict) -> None:
    print(
        json.dumps(
            {
                "kind": "progress",
                "payload": payload,
            },
            ensure_ascii=True,
        ),
        flush=True,
    )


def run() -> dict:
    helper = UiAutomationHelper()
    automation = helper.require_uiautomation()
    steps: list[dict] = []
    window = None
    native_handle = 0

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

    def find_search_box():
        search_name_candidates = [
            "\uac80\uc0c9",
            "\uce5c\uad6c \uac80\uc0c9",
            "\ub300\ud654\ubc29 \uac80\uc0c9",
            "\ucc44\ud305\ubc29 \uac80\uc0c9",
            "search",
        ]
        search_type_candidates = [
            "EditControl",
            "DocumentControl",
            "PaneControl",
        ]

        for control_type in search_type_candidates:
            try:
                return helper.find_descendant(
                    window,
                    names=search_name_candidates,
                    control_types=[control_type],
                    timeout_ms=1600,
                    max_depth=12,
                )
            except Exception:
                continue

        # Some KakaoTalk builds expose a magnifier button first.
        for control_type in ("ButtonControl", "CustomControl", "TextControl"):
            try:
                search_trigger = helper.find_descendant(
                    window,
                    names=["\uac80\uc0c9", "\ub3cb\ubcf4\uae30", "search"],
                    control_types=[control_type],
                    timeout_ms=1200,
                    max_depth=12,
                )
                helper.click_control(search_trigger)
                time.sleep(0.5)
                for edit_type in search_type_candidates:
                    try:
                        return helper.find_descendant(
                            window,
                            names=search_name_candidates,
                            control_types=[edit_type],
                            timeout_ms=1200,
                            max_depth=12,
                        )
                    except Exception:
                        continue
            except Exception:
                continue

        # Keyboard fallback: focus search UI first, then find the nearest edit box.
        window.SetFocus()
        helper.send_keys("{Ctrl}f")
        time.sleep(0.7)
        for control_type in search_type_candidates:
            try:
                return helper.find_descendant(
                    window,
                    control_types=[control_type],
                    timeout_ms=1200,
                    max_depth=12,
                )
            except Exception:
                continue

        raise RuntimeError("search_box_not_found")

    def get_control_bounds(control) -> tuple[int, int]:
        try:
            rect = getattr(control, "BoundingRectangle", None)
            if rect is None:
                return (999999, 999999)
            left = int(getattr(rect, "left", 999999))
            top = int(getattr(rect, "top", 999999))
            return (top, left)
        except Exception:
            return (999999, 999999)

    def find_topmost_profile_candidate():
        blacklist_tokens = [
            "\uce5c\uad6c \ucd94\uac00",
            "\uac80\uc0c9",
            "\ub3cb\ubcf4\uae30",
            "\uc124\uc815",
            "\ucc44\ud305",
            "\uc624\ud508\ucc44\ud305",
            "\ucc44\ub110",
            "\ub354\ubcf4\uae30",
        ]
        prioritized_tokens = [
            "\ub098\uc640\uc758 \ucc44\ud305",
            "\ub0b4 \ud504\ub85c\ud544",
            "\ud504\ub85c\ud544",
            "\ub098",
        ]

        candidates = []
        for control in helper.collect_descendants(window, max_depth=14, limit=250):
            control_type = str(getattr(control, "ControlTypeName", "") or "").strip()
            if control_type not in (
                "ListItemControl",
                "ButtonControl",
                "CustomControl",
                "TextControl",
                "PaneControl",
            ):
                continue

            name = str(getattr(control, "Name", "") or "").strip()
            lowered = name.lower()
            if any(token in lowered for token in blacklist_tokens):
                continue

            top, left = get_control_bounds(control)
            if top >= 999999:
                continue

            priority = 0
            for index, token in enumerate(prioritized_tokens):
                if token in lowered:
                    priority = len(prioritized_tokens) - index
                    break

            candidates.append((priority, top, left, name, control))

        if not candidates:
            raise RuntimeError("self_profile_not_found")

        candidates.sort(key=lambda item: (-item[0], item[1], item[2]))
        return candidates[0][4], candidates[:8]

    def find_left_sidebar_friends_tab():
        blacklist_tokens = [
            "\uce5c\uad6c \ucd94\uac00",
            "\uac80\uc0c9",
            "\ub3cb\ubcf4\uae30",
            "\uc124\uc815",
            "\ub354\ubcf4\uae30",
        ]
        prioritized_tokens = [
            "\uce5c\uad6c",
            "friends",
        ]

        candidates = []
        for control in helper.collect_descendants(window, max_depth=12, limit=220):
            control_type = str(getattr(control, "ControlTypeName", "") or "").strip()
            if control_type not in (
                "ButtonControl",
                "TabItemControl",
                "ListItemControl",
                "CustomControl",
                "TextControl",
                "PaneControl",
            ):
                continue

            name = str(getattr(control, "Name", "") or "").strip()
            lowered = name.lower()
            if any(token in lowered for token in blacklist_tokens):
                continue

            top, left = get_control_bounds(control)
            if top >= 999999:
                continue

            if left > 140:
                continue
            if top < 40 or top > 420:
                continue

            priority = 0
            for index, token in enumerate(prioritized_tokens):
                if token in lowered:
                    priority = len(prioritized_tokens) - index + 5
                    break

            # If there is no reliable name, prefer the topmost icon-like control
            # in the left sidebar.
            candidates.append((priority, top, left, name, control))

        if not candidates:
            raise RuntimeError("friends_tab_sidebar_candidate_not_found")

        candidates.sort(key=lambda item: (-item[0], item[1], item[2]))
        return candidates[0][4], candidates[:8]

    def click_friends_tab_by_layout() -> tuple[int, int]:
        # KakaoTalk PC often exposes only custom EVA panes without accessible tab names.
        # Use a conservative click point near the top item of the left vertical sidebar.
        return helper.click_relative_point(window, rel_x=0.055, rel_y=0.20)

    def find_friends_tab_by_hover():
        bounds = helper.get_bounds(window)
        probe_rel_x_values = [0.035, 0.05, 0.065, 0.08, 0.095]
        probe_rel_y_values = [0.07, 0.10, 0.13, 0.16, 0.20, 0.24, 0.28, 0.32, 0.36]
        debug_hits = []

        def tooltip_contains_friend_keyword() -> tuple[bool, str]:
            tooltip_candidates = []
            try:
                root = helper.get_root_control()
                for control in helper.collect_descendants(root, max_depth=3, limit=120):
                    name = str(getattr(control, "Name", "") or "").strip()
                    control_type = str(getattr(control, "ControlTypeName", "") or "").strip()
                    class_name = str(getattr(control, "ClassName", "") or "").strip()
                    if not name:
                        continue
                    lowered = name.lower()
                    tooltip_candidates.append(
                        f"{name}/{control_type or '<empty>'}/{class_name or '<empty>'}"
                    )
                    if "\uce5c\uad6c" in lowered or "friends" in lowered:
                        return True, f"{name}/{control_type or '<empty>'}/{class_name or '<empty>'}"
            except Exception:
                pass
            return False, "; ".join(tooltip_candidates[:12])

        for rel_x in probe_rel_x_values:
            probe_x = bounds["left"] + int(bounds["width"] * rel_x)
            for rel_y in probe_rel_y_values:
                probe_y = bounds["top"] + int(bounds["height"] * rel_y)
                helper.hover_point(probe_x, probe_y, pause_ms=520)

                control = helper.get_control_from_point(probe_x, probe_y)
                lineage = helper.get_control_lineage(control, max_depth=5) if control is not None else []
                lineage_summary = " > ".join(
                    (
                        f"{item['name'] or '<empty>'}/{item['type'] or '<empty>'}"
                    )
                    for item in lineage
                )
                tooltip_hit, tooltip_debug = tooltip_contains_friend_keyword()
                debug_hits.append(
                    f"{lineage_summary or '<none>'}@({probe_x},{probe_y}) tooltip={tooltip_debug or '<none>'}"
                )

                if any(
                    ("\uce5c\uad6c" in item["name"].lower()) or ("friends" in item["name"].lower())
                    for item in lineage
                ):
                    return (probe_x, probe_y), debug_hits
                if tooltip_hit:
                    return (probe_x, probe_y), debug_hits

        raise RuntimeError(f"friends_tab_hover_probe_not_found: {'; '.join(debug_hits)}")

    def open_self_profile_by_layout() -> tuple[int, int]:
        # After switching to the friends view, the user's own profile is usually the
        # first row near the top of the main content pane. Click slightly to the
        # right of the profile thumbnail so the row body opens reliably.
        if native_handle:
            return helper.click_window_relative_point(native_handle, rel_x=0.29, rel_y=0.18, double=True)
        return helper.click_relative_point(window, rel_x=0.29, rel_y=0.18, double=True)

    def focus_message_input_by_layout() -> tuple[int, int]:
        # KakaoTalk chat input usually sits in the bottom pane; click into the
        # middle-left area of that pane rather than relying on tab order.
        if native_handle:
            return helper.click_window_relative_point(native_handle, rel_x=0.43, rel_y=0.93)
        return helper.click_relative_point(window, rel_x=0.43, rel_y=0.93)

    def open_self_chat_room() -> None:
        emit(2, "open_friends_tab", "processing", "\uce5c\uad6c \ubaa9\ub85d \ud0ed\uc73c\ub85c \uc774\ub3d9\ud558\ub294 \uc911\uc785\ub2c8\ub2e4.")

        friends_tab = None
        for control_type in ("ButtonControl", "TabItemControl", "ListItemControl", "TextControl"):
            try:
                friends_tab = helper.find_descendant(
                    window,
                    names=["\uce5c\uad6c", "friends"],
                    control_types=[control_type],
                    timeout_ms=1500,
                    max_depth=12,
                )
                break
            except Exception:
                continue

        if friends_tab is None:
            try:
                friends_tab, tab_candidates = find_left_sidebar_friends_tab()
            except Exception as exc:
                try:
                    (x, y), hover_debug = find_friends_tab_by_hover()
                    helper.click_point(x, y)
                    fallback_detail = (
                        "\ud638\ubc84\ub85c \uce5c\uad6c \ud234\ud301\uc744 \ud655\uc778\ud55c \ub4a4 \uce74\uce74\uc624\ud1a1 "
                        f"\uce5c\uad6c \ud0ed\uc744 \ub20c\ub800\uc2b5\ub2c8\ub2e4. point=({x},{y}) probes={'; '.join(hover_debug)}"
                    )
                except Exception:
                    x, y = click_friends_tab_by_layout()
                    fallback_detail = (
                        "\ud638\ubc84 \ud655\uc778\uc774 \uc5b4\ub824\uc6cc \uc88c\uce21 \uc0ac\uc774\ub4dc\ubc14 \uae30\uc900 "
                        f"\uc88c\ud45c fallback\uc73c\ub85c \uce5c\uad6c \ud0ed\uc744 \ub20c\ub800\uc2b5\ub2c8\ub2e4. point=({x},{y})"
                    )
                time.sleep(0.8)
                record(
                    2,
                    "open_friends_tab",
                    fallback_detail,
                )
                emit(3, "open_self_profile", "processing", "\ucd5c\uc0c1\ub2e8 \ub098\uc758 \ud504\ub85c\ud544\uc744 \uc5ec\ub294 \uc911\uc785\ub2c8\ub2e4.")
                x, y = open_self_profile_by_layout()
                time.sleep(0.9)
                record(
                    3,
                    "open_self_profile",
                    f"\ud654\uba74 \ub808\uc774\uc544\uc6c3 \uae30\uc900 \uc88c\ud45c fallback\uc73c\ub85c \ub0b4 \ud504\ub85c\ud544\uc744 \ub354\ube14 \ud074\ub9ad\ud588\uc2b5\ub2c8\ub2e4. point=({x},{y})",
                )
                return
        else:
            tab_candidates = []

        helper.click_control(friends_tab)
        time.sleep(0.6)
        chosen_name = str(getattr(friends_tab, "Name", "") or "").strip() or "\uce5c\uad6c \ud0ed"
        candidate_summary = ", ".join(
            f"{name or '<empty>'}@({top},{left})"
            for _priority, top, left, name, _control in tab_candidates[:4]
        )
        detail = f"{chosen_name}\uc744(\ub97c) \ub20c\ub7ec \uce5c\uad6c \ubaa9\ub85d \ud0ed\uc73c\ub85c \uc774\ub3d9\ud588\uc2b5\ub2c8\ub2e4."
        if candidate_summary:
            detail += f" candidates={candidate_summary}"
        record(2, "open_friends_tab", detail)

        emit(3, "open_self_profile", "processing", "\ucd5c\uc0c1\ub2e8 \ub098\uc758 \ud504\ub85c\ud544\uc744 \uc5ec\ub294 \uc911\uc785\ub2c8\ub2e4.")
        time.sleep(0.8)
        try:
            profile_item, debug_candidates = find_topmost_profile_candidate()
        except Exception as exc:
            debug_lines = helper.describe_descendants(window, max_depth=5, limit=40)
            raise RuntimeError(
                f"self_profile_not_found: {exc} | visible_controls={'; '.join(debug_lines)}"
            ) from exc
        helper.double_click_control(profile_item)
        time.sleep(0.9)
        chosen_name = str(getattr(profile_item, "Name", "") or "").strip() or "\ucd5c\uc0c1\ub2e8 \ud504\ub85c\ud544"
        candidate_summary = ", ".join(
            f"{name or '<empty>'}@({top},{left})"
            for _priority, top, left, name, _control in debug_candidates[:4]
        )
        record(
            3,
            "open_self_profile",
            f"{chosen_name}\uc744(\ub97c) \ub354\ube14 \ud074\ub9ad\ud574 \ub098\uc640\uc758 \ucc44\ud305\uc73c\ub85c \uc9c4\uc785\ud588\uc2b5\ub2c8\ub2e4. candidates={candidate_summary}",
        )

    emit(1, "open_kakaotalk", "processing", "\uce74\uce74\uc624\ud1a1 \ucc3d\uc744 \uc900\ube44\ud558\ub294 \uc911\uc785\ub2c8\ub2e4.")
    try:
        helper.bring_window_to_front(KAKAOTALK_KEYWORDS, process_names=KAKAOTALK_PROCESS_NAMES)
        window_info = helper.wait_for_window_title_contains(
            KAKAOTALK_KEYWORDS,
            process_names=KAKAOTALK_PROCESS_NAMES,
            timeout_ms=4000,
        )
        if window_info.get("status") != "success" or not window_info.get("window"):
            raise RuntimeError("kakaotalk_window_not_found")
        native_handle = int(window_info["window"]["handle"])
        helper.bring_window_to_front(KAKAOTALK_KEYWORDS, process_names=KAKAOTALK_PROCESS_NAMES)
        window = helper.get_automation_window_from_handle(native_handle, timeout_ms=4000)
    except Exception:
        helper.launch_process(["KakaoTalk.exe"])
        window_info = helper.wait_for_window_title_contains(
            KAKAOTALK_KEYWORDS,
            process_names=KAKAOTALK_PROCESS_NAMES,
            timeout_ms=15000,
        )
        if window_info.get("status") != "success" or not window_info.get("window"):
            raise RuntimeError("kakaotalk_window_not_found_after_launch")
        native_handle = int(window_info["window"]["handle"])
        helper.bring_window_to_front(KAKAOTALK_KEYWORDS, process_names=KAKAOTALK_PROCESS_NAMES)
        window = helper.get_automation_window_from_handle(native_handle, timeout_ms=5000)
    window.SetActive()
    time.sleep(0.8)
    record(1, "open_kakaotalk", "\uce74\uce74\uc624\ud1a1 \ucc3d\uc744 \ud655\uc778\ud588\uc2b5\ub2c8\ub2e4.")

    if RECIPIENT_NAME == "\uB098\uC640\uC758 \uCC44\uD305":
        open_self_chat_room()
        message_input_step = 4
        type_message_step = 5
        send_message_step = 6
    else:
        emit(2, "find_search_box", "processing", "\uac80\uc0c9 \uc785\ub825 \uc0c1\uc790\ub97c \ucc3e\ub294 \uc911\uc785\ub2c8\ub2e4.")
        try:
            search_box = find_search_box()
        except Exception as exc:
            debug_lines = helper.describe_descendants(window, max_depth=4, limit=30)
            raise RuntimeError(
                f"search_box_not_found: {exc} | visible_controls={'; '.join(debug_lines)}"
            ) from exc
        helper.click_control(search_box)
        record(2, "find_search_box", "\uac80\uc0c9 \uc785\ub825 \uc0c1\uc790\ub97c \ud655\uc778\ud588\uc2b5\ub2c8\ub2e4.")

        emit(3, "search_recipient", "processing", f"{RECIPIENT_NAME} \ub300\ud654\ubc29\uc744 \uac80\uc0c9\ud558\ub294 \uc911\uc785\ub2c8\ub2e4.")
        helper.enter_text(search_box, RECIPIENT_NAME)
        time.sleep(1.1)
        record(3, "search_recipient", f"{RECIPIENT_NAME} \uac80\uc0c9\uc5b4\ub97c \uc785\ub825\ud588\uc2b5\ub2c8\ub2e4.")

        emit(4, "select_chat_room", "processing", "\uac80\uc0c9 \uacb0\uacfc\uc5d0\uc11c \ub300\ud654\ubc29\uc744 \uc120\ud0dd\ud558\ub294 \uc911\uc785\ub2c8\ub2e4.")
        chat_item = helper.find_descendant(
            window,
            names=[RECIPIENT_NAME],
            control_types=["ListItemControl", "ButtonControl", "TextControl"],
            timeout_ms=7000,
        )
        helper.click_control(chat_item)
        time.sleep(0.9)
        record(4, "select_chat_room", f"{RECIPIENT_NAME} \ub300\ud654\ubc29\uc744 \uc120\ud0dd\ud588\uc2b5\ub2c8\ub2e4.")
        message_input_step = 5
        type_message_step = 6
        send_message_step = 7

    emit(message_input_step, "find_message_input", "processing", "\uba54\uc2dc\uc9c0 \uc785\ub825 \uc900\ube44 \uc0c1\ud0dc\ub97c \ud655\uc778\ud558\ub294 \uc911\uc785\ub2c8\ub2e4.")
    message_box = None
    for control_type in ("EditControl", "DocumentControl", "PaneControl"):
        try:
            message_box = helper.find_descendant(
                window,
                names=["\uba54\uc2dc\uc9c0", "\ub300\ud654 \uc785\ub825", "input"],
                control_types=[control_type],
                timeout_ms=900,
            )
            break
        except Exception:
            continue
    if message_box is None:
        record(
            message_input_step,
            "find_message_input",
            "\ucc44\ud305\ubc29 \uc9c4\uc785 \ud6c4 \uae30\ubcf8 \uc785\ub825 \ub300\uae30 \uc0c1\ud0dc\ub85c \uac04\uc8fc\ud558\uace0 \uba54\uc2dc\uc9c0 \uc785\ub825\uc744 \uc9c4\ud589\ud569\ub2c8\ub2e4.",
        )
    else:
        record(message_input_step, "find_message_input", "\uba54\uc2dc\uc9c0 \uc785\ub825 \uc601\uc5ed\uc744 \ud655\uc778\ud588\uc2b5\ub2c8\ub2e4.")

    emit(type_message_step, "type_message", "processing", "\uba54\uc2dc\uc9c0 \ub0b4\uc6a9\uc744 \uc785\ub825\ud558\ub294 \uc911\uc785\ub2c8\ub2e4.")
    helper.bring_window_to_front(KAKAOTALK_KEYWORDS, process_names=KAKAOTALK_PROCESS_NAMES)
    if message_box is not None:
        try:
            helper.enter_text(message_box, MESSAGE_TEXT, clear_first=False)
        except Exception:
            helper.set_clipboard_text(MESSAGE_TEXT)
            helper.send_keys("{Ctrl}v")
    else:
        helper.set_clipboard_text(MESSAGE_TEXT)
        helper.send_keys("{Ctrl}v")
    time.sleep(0.45)
    record(type_message_step, "type_message", MESSAGE_TEXT)

    emit(send_message_step, "send_message", "processing", "\uba54\uc2dc\uc9c0\ub97c \uc804\uc1a1\ud558\ub294 \uc911\uc785\ub2c8\ub2e4.")
    helper.send_keys("{Enter}")
    time.sleep(0.8)
    record(send_message_step, "send_message", "\uba54\uc2dc\uc9c0 \uc804\uc1a1\uc744 \uc644\ub8cc\ud588\uc2b5\ub2c8\ub2e4.")

    return {
        "status": "success",
        "scenario": "kakaotalk_message",
        "steps": steps,
        "recipient_name": RECIPIENT_NAME,
        "message_text": MESSAGE_TEXT,
        "route_summary": f"{RECIPIENT_NAME} \ub300\ud654\ubc29\uc5d0 \uba54\uc2dc\uc9c0\ub97c \uc804\uc1a1\ud588\uc2b5\ub2c8\ub2e4.",
    }


def main() -> None:
    result = run()
    print(
        json.dumps(
            {
                "kind": "result",
                "payload": result,
            },
            ensure_ascii=True,
        ),
        flush=True,
    )


if __name__ == "__main__":
    main()
