from __future__ import annotations

import copy
import json
import unittest
from typing import Any

from flow_coordinator.gota_protocol import (
    GOTA_PROTOCOL,
    GOTA_RESULT_BEGIN,
    GOTA_RESULT_END,
    GotaPhase,
    GotaProtocolError,
    GotaProtocolErrorCode,
    GotaReviewResult,
    GotaWorkerResult,
    ReviewDecision,
    WorkerResultStatus,
    parse_gota_output,
)


class GotaProtocolTest(unittest.TestCase):
    run_id = "run-42"
    commit_sha = "a" * 40

    def _request(self, *, phase: str = "worker") -> dict[str, Any]:
        return {
            "protocol": GOTA_PROTOCOL,
            "request_id": f"{self.run_id}:1:{phase}",
            "task_id": "task-42",
            "run_id": self.run_id,
            "attempt": 1,
            "phase": phase,
            "objective": "Implement the approved drop",
            "acceptance_criteria": ["The focal checks pass"],
            "workspace": "/workspace/project",
            "branch": "feature/drop",
            "base_sha": self.commit_sha,
            "allowed_paths": ["tools/coordinator/src/flow_coordinator"],
            "protected_paths": ["demo/main.tscn", "export_presets.cfg"],
        }

    def _worker_result(self) -> dict[str, Any]:
        return {
            "protocol": GOTA_PROTOCOL,
            "message": "worker.result",
            "request_id": f"{self.run_id}:1:worker",
            "task_id": "task-42",
            "run_id": self.run_id,
            "attempt": 1,
            "result": "READY_FOR_REVIEW",
            "commit_sha": self.commit_sha,
            "changed_paths": ["tools/coordinator/src/flow_coordinator"],
            "evidence": [{"kind": "test", "passed": True}],
            "checkpoint": {
                "completed_steps": ["implementation"],
                "remaining_phase": "review",
            },
        }

    def _review_result(
        self,
        *,
        decision: str = "PASSED",
        findings: list[dict[str, str]] | None = None,
    ) -> dict[str, Any]:
        return {
            "protocol": GOTA_PROTOCOL,
            "message": "review.result",
            "request_id": f"{self.run_id}:1:review",
            "task_id": "task-42",
            "run_id": self.run_id,
            "attempt": 1,
            "reviewed_commit_sha": self.commit_sha,
            "decision": decision,
            "findings": findings or [],
            "evidence": [{"kind": "audit", "passed": True}],
        }

    def _output(self, payload: dict[str, Any]) -> str:
        return (
            "operational preface\n"
            f"{GOTA_RESULT_BEGIN}\n"
            f"{json.dumps(payload, sort_keys=True)}\n"
            f"{GOTA_RESULT_END}\n"
            "operational suffix"
        )

    def _assert_code(
        self,
        code: GotaProtocolErrorCode,
        callable_object: Any,
    ) -> None:
        with self.assertRaises(GotaProtocolError) as raised:
            callable_object()
        self.assertEqual(raised.exception.code, code)

    def test_worker_request_is_valid_and_round_trips(self) -> None:
        from flow_coordinator import GotaRequest

        request = GotaRequest.from_payload(self._request())

        self.assertEqual(request.phase, GotaPhase.WORKER)
        self.assertEqual(request.to_payload(), self._request())

    def test_review_request_preserves_previous_findings(self) -> None:
        from flow_coordinator import GotaRequest

        payload = self._request(phase="review")
        payload["previous_findings"] = [
            {
                "id": "finding-1",
                "severity": "high",
                "path": "src/file.py",
                "description": "The focal evidence is incomplete",
                "required_change": "Add the missing evidence",
            }
        ]

        request = GotaRequest.from_payload(payload)

        self.assertEqual(request.phase, GotaPhase.REVIEW)
        self.assertEqual(request.to_payload(), payload)

    def test_worker_result_is_valid(self) -> None:
        result = parse_gota_output(self._output(self._worker_result()))

        self.assertIsInstance(result, GotaWorkerResult)
        self.assertEqual(result.result, WorkerResultStatus.READY_FOR_REVIEW)
        self.assertEqual(result.checkpoint.remaining_phase, "review")

    def test_review_passed_is_valid(self) -> None:
        result = parse_gota_output(self._output(self._review_result()))

        self.assertIsInstance(result, GotaReviewResult)
        self.assertEqual(result.decision, ReviewDecision.PASSED)
        self.assertEqual(result.findings, ())

    def test_review_correction_required_preserves_findings(self) -> None:
        finding = {
            "id": "finding-1",
            "severity": "high",
            "description": "A required check is missing",
            "required_change": "Run the check",
        }
        result = parse_gota_output(
            self._output(
                self._review_result(
                    decision="CORRECTION_REQUIRED", findings=[finding]
                )
            )
        )

        self.assertIsInstance(result, GotaReviewResult)
        self.assertEqual(result.decision, ReviewDecision.CORRECTION_REQUIRED)
        self.assertEqual(result.findings[0].id, "finding-1")

    def test_review_human_review_required_is_valid(self) -> None:
        result = parse_gota_output(
            self._output(self._review_result(decision="HUMAN_REVIEW_REQUIRED"))
        )

        self.assertEqual(result.decision, ReviewDecision.HUMAN_REVIEW_REQUIRED)

    def test_review_blocked_is_valid(self) -> None:
        result = parse_gota_output(
            self._output(self._review_result(decision="BLOCKED"))
        )

        self.assertEqual(result.decision, ReviewDecision.BLOCKED)

    def test_invalid_json_is_rejected(self) -> None:
        output = f"{GOTA_RESULT_BEGIN}\n{{not-json}}\n{GOTA_RESULT_END}"

        self._assert_code(
            GotaProtocolErrorCode.INVALID_JSON,
            lambda: parse_gota_output(output),
        )

    def test_missing_start_delimiter_is_rejected(self) -> None:
        output = f"{{}}\n{GOTA_RESULT_END}"

        self._assert_code(
            GotaProtocolErrorCode.START_DELIMITER_MISSING,
            lambda: parse_gota_output(output),
        )

    def test_missing_end_delimiter_is_rejected(self) -> None:
        output = f"{GOTA_RESULT_BEGIN}\n{{}}"

        self._assert_code(
            GotaProtocolErrorCode.END_DELIMITER_MISSING,
            lambda: parse_gota_output(output),
        )

    def test_two_payloads_are_rejected(self) -> None:
        output = f"{self._output(self._worker_result())}\n{self._output(self._worker_result())}"

        self._assert_code(
            GotaProtocolErrorCode.MULTIPLE_PAYLOADS,
            lambda: parse_gota_output(output),
        )

    def test_protocol_is_checked(self) -> None:
        payload = self._worker_result()
        payload["protocol"] = "unknown/v1"

        self._assert_code(
            GotaProtocolErrorCode.UNKNOWN_PROTOCOL,
            lambda: parse_gota_output(self._output(payload)),
        )

    def test_request_id_coherence_is_checked(self) -> None:
        payload = self._request()
        payload["request_id"] = "run-42:1:review"

        from flow_coordinator import GotaRequest

        self._assert_code(
            GotaProtocolErrorCode.INVALID_REQUEST_ID,
            lambda: GotaRequest.from_payload(payload),
        )

    def test_attempt_must_be_positive_integer(self) -> None:
        from flow_coordinator import GotaRequest

        for attempt in (0, -1, True):
            with self.subTest(attempt=attempt):
                payload = self._request()
                payload["attempt"] = attempt
                self._assert_code(
                    GotaProtocolErrorCode.INVALID_ATTEMPT,
                    lambda payload=payload: GotaRequest.from_payload(payload),
                )

    def test_phase_is_checked(self) -> None:
        from flow_coordinator import GotaRequest

        payload = self._request(phase="worker")
        payload["phase"] = "execution"

        self._assert_code(
            GotaProtocolErrorCode.INVALID_PHASE,
            lambda: GotaRequest.from_payload(payload),
        )

    def test_sha_format_is_checked(self) -> None:
        payload = self._worker_result()
        payload["commit_sha"] = "not-a-sha"

        self._assert_code(
            GotaProtocolErrorCode.INVALID_SHA,
            lambda: parse_gota_output(self._output(payload)),
        )

    def test_unknown_decision_is_rejected(self) -> None:
        payload = self._review_result(decision="RETRY_LATER")

        self._assert_code(
            GotaProtocolErrorCode.UNKNOWN_DECISION,
            lambda: parse_gota_output(self._output(payload)),
        )

    def test_unknown_result_is_rejected(self) -> None:
        payload = self._worker_result()
        payload["result"] = "COMPLETED"

        self._assert_code(
            GotaProtocolErrorCode.UNKNOWN_RESULT,
            lambda: parse_gota_output(self._output(payload)),
        )

    def test_unknown_message_is_rejected(self) -> None:
        payload = self._worker_result()
        payload["message"] = "worker.log"

        self._assert_code(
            GotaProtocolErrorCode.UNKNOWN_MESSAGE,
            lambda: parse_gota_output(self._output(payload)),
        )

    def test_missing_required_field_is_rejected(self) -> None:
        payload = copy.deepcopy(self._worker_result())
        del payload["commit_sha"]

        self._assert_code(
            GotaProtocolErrorCode.MISSING_FIELD,
            lambda: parse_gota_output(self._output(payload)),
        )

    def test_free_text_around_payload_does_not_change_result(self) -> None:
        payload = self._worker_result()

        result = parse_gota_output(
            "log before\n" + self._output(payload) + "\nlog after"
        )

        self.assertIsInstance(result, GotaWorkerResult)
        self.assertEqual(result.commit_sha, self.commit_sha)


if __name__ == "__main__":
    unittest.main()
