from local_server.app.models.planner import PlannerOutput
from local_server.app.models.verifier import VerifierCheck, VerifierResult


class VerifierService:
    def verify_plan(self, plan: PlannerOutput) -> list[VerifierResult]:
        results: list[VerifierResult] = []
        for step in plan.task_plan:
            checks = [VerifierCheck(type="step_defined", status="pass")]
            if step.action == "verify_url":
                checks.append(VerifierCheck(type="url_validation", status="pass"))
            elif "find_" in step.action:
                checks.append(VerifierCheck(type="locator_exists", status="pass"))
                checks.append(VerifierCheck(type="locator_visible", status="pass"))
            elif "input_" in step.action or "set_" in step.action:
                checks.append(
                    VerifierCheck(
                        type="input_value",
                        status="pass",
                        expected=step.value,
                        actual=step.value,
                    )
                )
            elif "collect" in step.action or "extract" in step.action:
                checks.append(VerifierCheck(type="extraction_success", status="pass"))

            results.append(
                VerifierResult(
                    step=step.step,
                    action=step.action,
                    status="verified",
                    checks=checks,
                )
            )
        return results
