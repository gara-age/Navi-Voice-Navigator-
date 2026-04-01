from dataclasses import dataclass


@dataclass(slots=True)
class BackgroundConfig:
    host: str = "127.0.0.1"
    port: int = 18400
    shortcuts_enabled: bool = True
    listen_toggle_key: str = "F2"
    screen_read_key: str = "F3"
    open_settings_key: str = ""
    prefer_demo_when_server_unavailable: bool = True

    @property
    def server_base_url(self) -> str:
        return f"http://{self.host}:{self.port}"
