class TranscriptValidator:
    def validate(self, transcript: str, confidence: float) -> dict:
        cleaned = transcript.strip()
        is_valid = bool(cleaned) and confidence >= 0.6
        return {
            "transcript": cleaned,
            "confidence": confidence,
            "is_valid": is_valid,
            "reason": None if is_valid else "low_confidence_or_empty_transcript",
        }
