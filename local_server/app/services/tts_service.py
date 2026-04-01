import base64
from pathlib import Path

import httpx

from local_server.app.core.config import AppConfig


class TtsService:
    def __init__(self, config: AppConfig | None = None) -> None:
        self.config = config or AppConfig.from_env()

    def synthesize(self, session_id: str, summary: str) -> dict:
        output_dir = Path("runtime") / "tts" / session_id
        output_dir.mkdir(parents=True, exist_ok=True)
        output_path = output_dir / "final.mp3"

        if self.config.google_tts_api_key:
            try:
                self._synthesize_with_google(summary, output_path)
                return {
                    "audio_url": f"/tts/{session_id}/final.mp3",
                    "voice": self.config.tts_voice,
                    "speaking_rate": 1.0,
                    "duration_ms": max(2200, len(summary) * 90),
                    "state": "ready",
                    "provider": "google_cloud_tts",
                }
            except Exception:
                pass

        output_path.write_bytes(b"")
        return {
            "audio_url": f"/tts/{session_id}/final.mp3",
            "voice": self.config.tts_voice,
            "speaking_rate": 1.0,
            "duration_ms": max(2200, len(summary) * 90),
            "state": "ready",
            "provider": "fallback",
        }

    def _synthesize_with_google(self, summary: str, output_path: Path) -> None:
        payload = {
            "input": {"text": summary},
            "voice": {"languageCode": "ko-KR", "name": self.config.tts_voice},
            "audioConfig": {
                "audioEncoding": "MP3",
                "speakingRate": 1.0,
            },
        }
        with httpx.Client(timeout=60.0) as client:
            response = client.post(
                "https://texttospeech.googleapis.com/v1/text:synthesize",
                params={"key": self.config.google_tts_api_key},
                json=payload,
            )
            response.raise_for_status()
            audio_content = response.json().get("audioContent", "")
        output_path.write_bytes(base64.b64decode(audio_content))
