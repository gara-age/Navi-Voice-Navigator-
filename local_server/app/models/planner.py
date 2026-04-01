from typing import Any

from pydantic import BaseModel, Field


class TaskStep(BaseModel):
    step: int
    action: str
    target: str | None = None
    value: str | None = None
    contains: str | None = None


class PlannerOutput(BaseModel):
    intent: str
    platform: str
    slots: dict[str, Any] = Field(default_factory=dict)
    goal: str
    task_plan: list[TaskStep]
    risk_flags: list[str] = Field(default_factory=list)
    requires_confirmation: bool = False
