import os
from dataclasses import dataclass


@dataclass(slots=True)
class AppConfig:
    host: str = "127.0.0.1"
    port: int = 18400
    openai_model: str = "gpt-4.1-mini"
    openai_api_key: str = ""
    openai_stt_model: str = "gpt-4o-mini-transcribe"
    google_tts_api_key: str = ""
    tts_voice: str = "ko-KR-Neural2-A"
    browser_headless: bool = True

    @classmethod
    def from_env(cls) -> "AppConfig":
        return cls(
            host=os.getenv("VOICE_NAVIGATOR_HOST", "127.0.0.1"),
            port=int(os.getenv("VOICE_NAVIGATOR_PORT", "18400")),
            openai_model=os.getenv("OPENAI_LLM_MODEL", "gpt-4.1-mini"),
            openai_api_key=os.getenv("OPENAI_API_KEY", ""),
            openai_stt_model=os.getenv("OPENAI_STT_MODEL", "gpt-4o-mini-transcribe"),
            google_tts_api_key=os.getenv("GOOGLE_CLOUD_API_KEY", ""),
            tts_voice=os.getenv("GOOGLE_TTS_VOICE", "ko-KR-Neural2-A"),
            browser_headless=os.getenv("PLAYWRIGHT_HEADLESS", "true").lower() != "false",
        )
