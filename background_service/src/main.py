import ctypes

from background_application import BackgroundApplication
from config import BackgroundConfig
from event_dispatcher import EventDispatcher
from hotkey_manager import HotkeyManager
from server_probe import ServerProbe
from settings_reader import SettingsReader


ERROR_ALREADY_EXISTS = 183


def acquire_single_instance() -> int | None:
    kernel32 = ctypes.windll.kernel32
    mutex = kernel32.CreateMutexW(None, False, "VoiceNavigatorBackgroundService")
    if not mutex:
        return None

    if kernel32.GetLastError() == ERROR_ALREADY_EXISTS:
        return None

    return mutex


def main() -> None:
    mutex = acquire_single_instance()
    if mutex is None:
        print("Voice Navigator background service is already running.")
        return

    config = SettingsReader().load()
    app = BackgroundApplication(config)
    bindings = app.hotkeys.describe_bindings()
    server_ready = app.server_probe.is_server_ready()

    print("Voice Navigator background service starting...")
    print(f"Server target: {config.server_base_url}")
    print(f"Server ready: {server_ready}")
    print(f"Settings file: {SettingsReader().settings_path}")
    print(f"Bindings: {bindings}")
    print("Global hotkeys are now active. Press Ctrl+C to stop.")

    app.run()


if __name__ == "__main__":
    main()
