from pydantic import BaseModel, Field


class VerifierCheck(BaseModel):
    type: str
    status: str
    expected: str | None = None
    actual: str | None = None


class VerifierResult(BaseModel):
    step: int
    action: str
    status: str
    checks: list[VerifierCheck] = Field(default_factory=list)
    fallback_used: bool = False
    error_code: str | None = None
