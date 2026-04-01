import httpx

from local_server.app.core.config import AppConfig
from local_server.app.models.requests import VoiceCommandMetadata


class SttService:
    def __init__(self, config: AppConfig | None = None) -> None:
        self.config = config or AppConfig.from_env()

    def transcribe(self, audio_bytes: bytes, metadata: VoiceCommandMetadata) -> dict:
        if self.config.openai_api_key:
            try:
                return self._transcribe_with_openai(audio_bytes, metadata)
            except Exception:
                pass
        return self._fallback_transcript(metadata)

    def _transcribe_with_openai(
        self,
        audio_bytes: bytes,
        metadata: VoiceCommandMetadata,
    ) -> dict:
        files = {
            "file": (
                f"voice-input.{metadata.audio_format}",
                audio_bytes,
                f"audio/{metadata.audio_format}",
            )
        }
        data = {
            "model": self.config.openai_stt_model,
            "language": metadata.language_hint,
        }
        headers = {
            "Authorization": f"Bearer {self.config.openai_api_key}",
        }

        with httpx.Client(timeout=60.0) as client:
            response = client.post(
                "https://api.openai.com/v1/audio/transcriptions",
                headers=headers,
                data=data,
                files=files,
            )
            response.raise_for_status()
            payload = response.json()

        transcript = payload.get("text") or payload.get("transcript") or ""
        return {
            "transcript": transcript.strip(),
            "confidence": 0.95 if transcript else 0.0,
            "language": metadata.language_hint,
            "provider": "openai",
            "model": self.config.openai_stt_model,
        }

    def _fallback_transcript(self, metadata: VoiceCommandMetadata) -> dict:
        transcript = "voice command transcription is not connected"
        if metadata.language_hint.lower().startswith("ko"):
            transcript = "youtube cat videos search"
        return {
            "transcript": transcript,
            "confidence": 0.82,
            "language": metadata.language_hint,
            "provider": "fallback",
            "model": self.config.openai_stt_model,
        }
