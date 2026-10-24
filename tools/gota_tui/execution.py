"""Registered action execution and report lifecycle."""

from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import sys
import threading
from dataclasses import asdict, dataclass
from datetime import UTC, datetime
from pathlib import Path
from threading import Event
from typing import Any, Callable, Mapping

from flow_coordinator import OpenCodeRunResult, OpenCodeRunStatus, SQLiteCoordinatorStore
from flow_coordinator.git_adapter import GitReadError, ReadOnlyGitAdapter
from flow_coordinator.sensitive_output import (
    SensitiveOutputRedactor,
    redact_sensitive_data,
)

from .actions import ActionDefinition
from .clipboard import ClipboardWriter
from .coordinator_facade import (
    CoordinatorGotaFacade,
    CoordinatorOutcome,
    OpenCodePromptFacade,
)
from .durable import DurableRunStore, RunPaths, default_coordinator_database
from .embedded_report import (
    EmbeddedReportParse,
    conflict_diagnostic,
    parse_embedded_report,
    result_consistency,
)
from .envelope import PromptEnvelope
from .prompt_library import PromptComposition, PromptLibrary
from .read_only_agent import ReadOnlyAgentError, validate_read_only_agent
from .reporting import ReportData, ReportManager, PersistedReport


class ExecutionError(RuntimeError):
    """A registered action could not be prepared or executed."""


_DENIAL_PATTERN = re.compile(
    r"\b(?:permission\s+denied|access\s+denied|forbidden|not\s+allowed|blocked|denied)\b",
    re.IGNORECASE,
)
_MUTATION_DENIAL_PATTERN = re.compile(
    r"(?:\b(?:edit|write|patch|mkdir|touch|rm|mv|cp|install)\b|"
    r"\bgit\s+(?:add|commit|push|reset|clean|checkout|restore|pull|merge|rebase|"
    r"cherry-pick|revert|tag|worktree|update-ref)\b|"
    r"\b(?:python(?:3)?\s+-m\s+)?(?:pip|uv|poetry)\s+install\b|"
    r"\b(?:npm\s+install|cargo\s+add|go\s+get)\b)",
    re.IGNORECASE,
)
_SENSITIVE_AUDIT_PATH_PATTERN = re.compile(
    r"(?<![A-Za-z0-9_])\.opencode[/\\]service\.json(?![A-Za-z0-9_])",
    re.IGNORECASE,
)
_DENIAL_DESCRIPTIONS = {
    "MUTATION_DETECTED": "Observable Git or file state changed during the audit",
    "MUTATION_ATTEMPT_DENIED": "An explicit mutation-capable tool or command was denied",
    "READONLY_COMMAND_DENIED": "A non-mutating command was denied by the read-only shell policy",
    "SENSITIVE_PATH_BLOCKED": "A protected local credential path was denied before model access",
}


@dataclass(frozen=True, slots=True)
class TUIConfig:
    repository: Path
    database: Path
    opencode_executable: str = "opencode"
    model_override: str | None = None
    variant_override: str | None = None
    timeout: float = 1800.0


@dataclass(frozen=True, slots=True)
class PreparedAction:
    action: ActionDefinition
    envelope: PromptEnvelope
    composition: PromptComposition | None
    paths: RunPaths


@dataclass(slots=True)
class ActionExecutionResult:
    run_id: str
    paths: RunPaths
    report: str
    report_path: str
    log_path: str
    clipboard_status: str
    clipboard_error: str | None
    verdict: str
    coordinator_state: str | None
    task_id: str | None
    coordinator_run_id: str | None
    diagnostic: str
    process_status: str | None
    process_exit_code: int | None
    embedded_report_id: str | None
    embedded_status: str | None
    embedded_verdict: str | None
    result_consistency: str


class ActionExecutor:
    """Prepare durable UI state, dispatch only registered backends, and report."""

    def __init__(
        self,
        *,
        config: TUIConfig,
        runs: DurableRunStore,
        prompts: PromptLibrary,
        clipboard_writer: ClipboardWriter,
        output_sink: Callable[[str], None] | None = None,
    ) -> None:
        self.config = config
        self.runs = runs
        self.prompts = prompts
        self.clipboard_writer = clipboard_writer
        self.output_sink = output_sink

    def _model(self, action: ActionDefinition) -> str:
        return self.config.model_override or action.model or ""

    def _variant(self, action: ActionDefinition) -> str:
        return self.config.variant_override or action.variant or ""

    def _validate_opencode_audit_configuration(self, action: ActionDefinition) -> None:
        if action.backend != "opencode-readonly":
            return
        if action.mutable:
            raise ExecutionError("OpenCode audit action is mutable")
        model = self._model(action)
        variant = self._variant(action)
        if re.fullmatch(r"[^\s/#]+/[^\s#]+", model) is None:
            raise ExecutionError(f"Invalid OpenCode model: {model!r}")
        if re.fullmatch(r"[^\s#]+", variant) is None:
            raise ExecutionError(f"Invalid OpenCode variant: {variant!r}")
        try:
            validate_read_only_agent(action.agent)
        except ReadOnlyAgentError as error:
            raise ExecutionError(str(error)) from error

    def prepare(
        self,
        action: ActionDefinition,
        envelope: PromptEnvelope,
        *,
        run_id: str | None = None,
    ) -> PreparedAction:
        if action.requires_prompt and not envelope.original.strip():
            raise ExecutionError(f"Action {action.id} requires a non-empty prompt")
        if action.mutable:
            envelope.require_mutable_fields()
        self._validate_opencode_audit_configuration(action)
        composition: PromptComposition | None = None
        if action.template:
            composition = self.prompts.compose(action.template, envelope.assignment)
        original_sha = hashlib.sha256(envelope.original.encode("utf-8")).hexdigest()
        template_payload: dict[str, Any] = {}
        if composition is not None:
            template_payload = {
                "id": composition.template_id,
                "version": composition.template_version,
                "composition_sha256": composition.sha256,
            }
        paths = self.runs.prepare(
            action_id=action.id,
            model=self._model(action),
            variant=self._variant(action),
            agent=action.agent,
            repository=str(self.config.repository),
            prompt=envelope.original,
            prompt_sha256=original_sha,
            template=template_payload,
            envelope=envelope.metadata,
            run_id=run_id,
            allow_empty_prompt=not action.requires_prompt,
            timeout=self.config.timeout,
            opencode_output=action.backend in {"opencode-direct", "opencode-readonly"},
        )
        return PreparedAction(action, envelope, composition, paths)

    def execute(
        self,
        prepared: PreparedAction,
        *,
        cancel_event: Event | None = None,
    ) -> ActionExecutionResult:
        cancel = cancel_event or Event()
        action = prepared.action
        if cancel.is_set():
            return self._finish(
                prepared,
                CoordinatorOutcome(
                    verdict="UI_CANCELLED",
                    cancelled=True,
                    diagnostic="Cancelled before the registered backend started",
                ),
                cancel_status="UI_CANCELLED",
            )
        self.runs.update_request(prepared.paths.run_id, ui_state="RUNNING")
        try:
            if action.backend == "gota-task":
                if prepared.composition is None:
                    raise ExecutionError("Gota task action has no prompt composition")
                outcome = CoordinatorGotaFacade(
                    database=self.config.database,
                    opencode_executable=self.config.opencode_executable,
                    model=self._model(action),
                    variant=self._variant(action),
                    timeout=self.config.timeout,
                    owner_id=f"gota-tui:{os.getpid()}:{prepared.paths.run_id}",
                    output=self._open_code_output(prepared.paths.run_id),
                    cancel_event=cancel,
                ).execute_new_task(prepared.envelope, prepared.composition)
                return self._finish(prepared, outcome)

            if action.backend == "gota-review":
                outcome = CoordinatorGotaFacade(
                    database=self.config.database,
                    opencode_executable=self.config.opencode_executable,
                    model=self._model(action),
                    variant=self._variant(action),
                    timeout=self.config.timeout,
                    owner_id=f"gota-tui:{os.getpid()}:{prepared.paths.run_id}",
                    output=self._open_code_output(prepared.paths.run_id),
                    cancel_event=cancel,
                ).review_existing(prepared.envelope)
                return self._finish(prepared, outcome)

            if action.backend == "opencode-direct":
                outcome = self._execute_direct_prompt(prepared, cancel)
                return self._finish(prepared, outcome)

            if action.backend == "opencode-readonly":
                outcome = self._execute_opencode_audit(prepared, cancel)
                return self._finish(prepared, outcome)

            outcome = self._execute_registered_read_only(prepared, cancel)
            return self._finish(prepared, outcome)
        except Exception as error:
            return self._finish(
                prepared,
                CoordinatorOutcome(
                    verdict=(
                        "FAIL"
                        if action.backend in {"opencode-direct", "opencode-readonly"}
                        else "CYCLE_FAILED"
                    ),
                    coordinator_state=(
                        "READ_ONLY"
                        if action.backend in {"git-audit", "opencode-readonly"}
                        else None
                    ),
                    diagnostic=f"Registered backend failed: {type(error).__name__}: {error}",
                ),
            )

    def _execute_direct_prompt(
        self,
        prepared: PreparedAction,
        cancel: Event,
    ) -> CoordinatorOutcome:
        """Execute raw clipboard text without creating Coordinator state."""
        run_id = prepared.paths.run_id
        base_sha = self._git_head()
        result = OpenCodePromptFacade(
            opencode_executable=self.config.opencode_executable,
            model=self._model(prepared.action),
            variant=self._variant(prepared.action),
            timeout=self.config.timeout,
            output=self._open_code_output(run_id),
            cancel_event=cancel,
        ).execute(
            agent=prepared.action.agent,
            prompt=prepared.envelope.original,
            cwd=self.config.repository,
        )
        commit_sha = self._git_head()
        redactor = self._output_redactor()
        output_path = self.runs.persist_opencode_output(
            run_id,
            redactor.redact(result.stdout),
            redactor.redact(result.stderr),
        )
        metadata = self._process_report_metadata(result, output_path)
        self.runs.update_request(
            run_id,
            output_path=str(output_path),
            process_status=metadata["process_status"],
            process_exit_code=metadata["process_exit_code"],
            result_consistency=metadata["result_consistency"],
            embedded_report_id=metadata.get("embedded_report_id"),
            embedded_status=metadata.get("embedded_status"),
            embedded_verdict=metadata.get("embedded_verdict"),
        )
        diagnostic = redactor.redact(result.error or "Direct OpenCode prompt completed")
        if result.status is OpenCodeRunStatus.INVALID_PAYLOAD and result.exit_code == 0:
            diagnostic = (
                "Direct OpenCode prompt completed without a Coordinator payload; "
                "raw output is available in live.log and opencode-output.txt"
            )
        consistency_diagnostic = metadata.get("result_conflict_diagnostic")
        if type(consistency_diagnostic) is str:
            diagnostic = f"{diagnostic} {consistency_diagnostic}"
        if result.status in {OpenCodeRunStatus.SUCCEEDED, OpenCodeRunStatus.INVALID_PAYLOAD}:
            verdict = "SUCCEEDED" if result.exit_code == 0 else "FAIL"
        elif result.status is OpenCodeRunStatus.TIMEOUT:
            verdict = "FAIL/TIMEOUT"
        elif result.status is OpenCodeRunStatus.CANCELLED:
            verdict = "FAIL/CANCELLED"
        else:
            verdict = "FAIL"
        self._log(
            run_id,
            f"Direct OpenCode status={result.status.value} exit={result.exit_code}"
            f" diagnostic={diagnostic}",
        )
        return CoordinatorOutcome(
            base_sha=base_sha,
            commit_sha=commit_sha,
            verdict=verdict,
            diagnostic=diagnostic,
            cancelled=result.status is OpenCodeRunStatus.CANCELLED,
            metadata=metadata,
        )

    def _process_report_metadata(
        self, result: OpenCodeRunResult, output_path: Path
    ) -> dict[str, Any]:
        """Record process facts and stdout-only embedded evidence.

        The parser receives only the captured agent stdout. The prompt and
        request files never enter this path, and stderr remains diagnostics.
        """

        parsed: EmbeddedReportParse = parse_embedded_report(result.stdout)
        report = parsed.report
        consistency = result_consistency(
            process_status=result.status.value,
            process_exit_code=result.exit_code,
            parsed=parsed,
        )
        metadata: dict[str, Any] = {
            "process_status": result.status.value,
            "process_exit_code": result.exit_code,
            "output_path": str(output_path),
            "result_consistency": consistency,
        }
        if report is not None:
            redactor = self._output_redactor()
            metadata.update(
                {
                    "embedded_report_id": redactor.redact(report.report_id),
                    "embedded_status": (
                        redactor.redact(report.status) if report.status is not None else None
                    ),
                    "embedded_verdict": (
                        redactor.redact(report.verdict) if report.verdict is not None else None
                    ),
                    "embedded_report_classification": report.classification,
                    # The full source block is retained in result.json after
                    # the normal repository/credential redaction boundary.
                    "embedded_report_text": redactor.redact(report.raw_text),
                }
            )
        diagnostic = conflict_diagnostic(consistency)
        if diagnostic is not None:
            metadata["result_conflict_diagnostic"] = diagnostic
        return metadata

    def _read_durable_audit_prompt(
        self, prepared: PreparedAction
    ) -> tuple[str, Mapping[str, Any]]:
        """Read and verify the prompt that was persisted before confirmation."""

        request = self.runs.request(prepared.paths.run_id)
        if request.get("action_id") != prepared.action.id:
            raise ExecutionError("Durable request action does not match audit action")
        try:
            prompt = self.runs.read_prompt(prepared.paths.run_id)
        except Exception as error:
            raise ExecutionError(f"Durable audit prompt is unavailable: {error}") from error
        if not prompt.strip():
            raise ExecutionError("Durable audit prompt is empty")
        prompt_sha256 = hashlib.sha256(prompt.encode("utf-8")).hexdigest()
        if request.get("prompt_sha256") != prompt_sha256:
            raise ExecutionError("Durable audit prompt SHA-256 does not match request metadata")
        return prompt, request

    @staticmethod
    def _snapshot_payload(snapshot: Any) -> dict[str, Any]:
        return {
            "repository": snapshot.repository,
            "head": snapshot.head,
            "branch": snapshot.branch,
            "status": snapshot.status,
            "refs": [list(ref) for ref in snapshot.refs],
        }

    @staticmethod
    def _denial_classifications(stdout: str, stderr: str) -> tuple[str, ...]:
        """Classify policy denials without treating generic shell denial as mutation.

        OpenCode's diagnostic for a denied shell call is intentionally broad. A
        mutation classification therefore requires an explicit mutation-capable
        command or tool in the same denial line. This keeps read-only command
        syntax failures and denied test execution as warnings.
        """

        classifications: list[str] = []
        for line in f"{stdout}\n{stderr}".splitlines():
            if _DENIAL_PATTERN.search(line) is None:
                continue
            if _SENSITIVE_AUDIT_PATH_PATTERN.search(line) is not None:
                classification = "SENSITIVE_PATH_BLOCKED"
            elif _MUTATION_DENIAL_PATTERN.search(line) is not None:
                classification = "MUTATION_ATTEMPT_DENIED"
            else:
                classification = "READONLY_COMMAND_DENIED"
            if classification not in classifications:
                classifications.append(classification)
        return tuple(classifications)

    @classmethod
    def _mutation_attempt_detected(cls, stdout: str, stderr: str) -> bool:
        return "MUTATION_ATTEMPT_DENIED" in cls._denial_classifications(stdout, stderr)

    @staticmethod
    def _requested_delimited_blocks(prompt: str, output: str) -> tuple[str, ...]:
        """Find complete marker blocks requested by a generic prompt.

        No output schema is imposed. A prompt that names ``FOO_BEGIN`` causes
        the matching ``FOO_END`` block to be identified and the complete model
        output remains in the associated artifact.
        """

        markers = re.findall(
            r"(?<![A-Za-z0-9_.-])([A-Za-z0-9][A-Za-z0-9_.-]*_BEGIN)(?![A-Za-z0-9_.-])",
            prompt,
        )
        blocks: list[str] = []
        for begin in dict.fromkeys(markers):
            end = begin[: -len("_BEGIN")] + "_END"
            start_index = output.find(begin)
            if start_index < 0:
                continue
            end_index = output.find(end, start_index + len(begin))
            if end_index < 0:
                continue
            blocks.append(output[start_index : end_index + len(end)])
        return tuple(blocks)

    def _audit_findings(
        self,
        *,
        prompt: str,
        stdout: str,
        stderr: str,
        output_path: str,
        failed: bool,
        classifications: tuple[str, ...] = (),
        mutation_reasons: tuple[str, ...] = (),
    ) -> list[Mapping[str, Any]]:
        combined = stdout if stdout.strip() else stderr
        first_line = next((line.strip() for line in combined.splitlines() if line.strip()), "")
        findings: list[Mapping[str, Any]] = []
        for classification in classifications:
            if classification not in _DENIAL_DESCRIPTIONS:
                continue
            description = _DENIAL_DESCRIPTIONS[classification]
            if classification == "MUTATION_DETECTED" and mutation_reasons:
                description += ": " + "; ".join(mutation_reasons)
            findings.append(
                {
                    "id": classification,
                    "severity": (
                        "error"
                        if classification in {"MUTATION_DETECTED", "MUTATION_ATTEMPT_DENIED"}
                        else "warning"
                    ),
                    "description": description,
                    "path": output_path,
                }
            )
        if first_line:
            findings.append(
                {
                    "id": "OPENCODE_OUTPUT",
                    "severity": "error" if failed else "info",
                    "description": first_line,
                    "path": output_path,
                }
            )
        blocks = self._requested_delimited_blocks(prompt, stdout + "\n" + stderr)
        for index, block in enumerate(blocks, start=1):
            marker = block.splitlines()[0] if block.splitlines() else f"BLOCK_{index}"
            findings.append(
                {
                    "id": f"DELIMITED_BLOCK_{index}",
                    "severity": "error" if failed else "info",
                    "description": f"{marker} preserved in the complete OpenCode output artifact",
                    "path": output_path,
                }
            )
        if not findings:
            findings.append(
                {
                    "id": "OPENCODE_OUTPUT",
                    "severity": "error" if failed else "info",
                    "description": "OpenCode produced no textual findings; complete channels are preserved",
                    "path": output_path,
                }
            )
        return findings

    def _execute_opencode_audit(
        self,
        prepared: PreparedAction,
        cancel: Event,
    ) -> CoordinatorOutcome:
        """Run the generic prompt through the canonical read-only boundary."""

        action = prepared.action
        if action.backend != "opencode-readonly" or action.mutable:
            raise ExecutionError("OpenCode audit backend is not read-only")
        self._validate_opencode_audit_configuration(action)
        prompt, request = self._read_durable_audit_prompt(prepared)
        policy = validate_read_only_agent(action.agent)
        repository = self.config.repository
        try:
            before = ReadOnlyGitAdapter(repository).snapshot()
        except GitReadError as error:
            raise ExecutionError(f"OpenCode audit repository preflight failed: {error}") from error

        version = self._opencode_version()
        timestamp = str(request.get("timestamp") or datetime.now(UTC).isoformat())
        started_at = datetime.now(UTC).isoformat()
        metadata: dict[str, Any] = {
            "run_id": prepared.paths.run_id,
            "action_id": action.id,
            "prompt_sha256": request.get("prompt_sha256"),
            "model": self._model(action),
            "variant": self._variant(action),
            "opencode_version": version,
            "agent": action.agent,
            "repository": str(repository.resolve()),
            "timestamp": timestamp,
            "started_at": started_at,
            "timeout": self.config.timeout,
            "readonly_policy": "deny-all; read, glob, grep, and read-only Git shell patterns only",
            "readonly_policy_sha256": policy.sha256,
            "base_sha": before.head,
            "branch_before": before.branch,
            "git_status_before": before.status,
            "refs_before": [list(ref) for ref in before.refs],
        }
        self.runs.update_request(
            prepared.paths.run_id,
            opencode_version=version,
            readonly_agent=policy.agent_id,
            readonly_policy_sha256=policy.sha256,
            started_at=started_at,
            base_sha=before.head,
            branch_before=before.branch,
            git_status_before=before.status,
            refs_before=metadata["refs_before"],
        )

        result: Any = None
        runner_error: str | None = None
        if version.startswith("unavailable"):
            runner_error = f"OpenCode version preflight failed: {version}"
        else:
            try:
                result = OpenCodePromptFacade(
                    opencode_executable=self.config.opencode_executable,
                    model=self._model(action),
                    variant=self._variant(action),
                    timeout=self.config.timeout,
                    output=self._open_code_output(prepared.paths.run_id),
                    cancel_event=cancel,
                ).execute(
                    agent=action.agent,
                    prompt=prompt,
                    cwd=repository,
                )
            except Exception as error:
                runner_error = f"OpenCode runner failed: {type(error).__name__}: {error}"

        raw_stdout = "" if result is None else result.stdout
        raw_stderr = "" if result is None else result.stderr
        redactor = self._output_redactor()
        stdout = redactor.redact(raw_stdout)
        stderr = redactor.redact(raw_stderr)
        if runner_error:
            safe_runner_error = redactor.redact(runner_error)
            stderr = f"{stderr}\n{safe_runner_error}" if stderr else safe_runner_error
        output_path = self.runs.persist_opencode_output(
            prepared.paths.run_id, stdout, stderr
        )
        if result is not None:
            metadata.update(self._process_report_metadata(result, output_path))
        try:
            after = ReadOnlyGitAdapter(repository).snapshot()
        except GitReadError as error:
            after = None
            runner_error = f"OpenCode audit repository postflight failed: {error}"

        mutation_reasons: list[str] = []
        snapshot_mutation_reasons: list[str] = []
        if after is not None:
            if before.head != after.head:
                snapshot_mutation_reasons.append("HEAD changed")
            if before.branch != after.branch:
                snapshot_mutation_reasons.append("branch changed")
            if before.status != after.status:
                snapshot_mutation_reasons.append("git status changed")
            if before.refs != after.refs:
                snapshot_mutation_reasons.append("Git refs changed")
        mutation_reasons.extend(snapshot_mutation_reasons)
        denied_classifications = list(self._denial_classifications(raw_stdout, raw_stderr))
        if "MUTATION_ATTEMPT_DENIED" in denied_classifications:
            mutation_reasons.append("MUTATION_ATTEMPT_DENIED")
        classifications: list[str] = []
        if snapshot_mutation_reasons:
            classifications.append("MUTATION_DETECTED")
        classifications.extend(
            classification
            for classification in denied_classifications
            if classification not in classifications
        )

        if after is not None:
            metadata.update(
                {
                    "commit_sha": after.head,
                    "branch_after": after.branch,
                    "git_status_after": after.status,
                    "refs_after": [list(ref) for ref in after.refs],
                }
            )
        else:
            metadata["commit_sha"] = None
        metadata.update(
            {
                "output_path": str(output_path),
                "mutation_guard": "PASS" if not mutation_reasons and after is not None else "FAIL",
                "mutation_reasons": mutation_reasons,
                "audit_classifications": classifications,
                "finished_at": datetime.now(UTC).isoformat(),
            }
        )
        self.runs.update_request(
            prepared.paths.run_id,
            finished_at=metadata["finished_at"],
            commit_sha=metadata["commit_sha"],
            branch_after=metadata.get("branch_after"),
            git_status_after=metadata.get("git_status_after"),
            refs_after=metadata.get("refs_after"),
            output_path=str(output_path),
            mutation_guard=metadata["mutation_guard"],
        )

        failed = bool(runner_error or mutation_reasons or after is None)
        if not failed and result is not None:
            accepted_status = result.status in {
                OpenCodeRunStatus.SUCCEEDED,
                OpenCodeRunStatus.INVALID_PAYLOAD,
            }
            failed = result.exit_code != 0 or not accepted_status
        if failed:
            if result is not None and result.status is OpenCodeRunStatus.TIMEOUT:
                verdict = "FAIL/TIMEOUT"
            elif result is not None and result.status is OpenCodeRunStatus.CANCELLED:
                verdict = "FAIL/CANCELLED"
            else:
                verdict = "FAIL"
        else:
            verdict = "READ_ONLY_OK"

        diagnostic_parts = []
        if runner_error:
            diagnostic_parts.append(runner_error)
        elif result is not None:
            diagnostic_parts.append(
                f"OpenCode status={result.status.value} exit={result.exit_code}"
            )
            if result.status is OpenCodeRunStatus.INVALID_PAYLOAD:
                diagnostic_parts.append("generic raw output accepted; no Gota payload required")
            elif result.error and failed:
                diagnostic_parts.append(redactor.redact(result.error))
        if mutation_reasons:
            diagnostic_parts.append("; ".join(mutation_reasons))
        if classifications:
            diagnostic_parts.append("classifications=" + ",".join(classifications))
        consistency_diagnostic = metadata.get("result_conflict_diagnostic")
        if type(consistency_diagnostic) is str:
            diagnostic_parts.append(consistency_diagnostic)
        if not diagnostic_parts:
            diagnostic_parts.append("Read-only OpenCode audit completed")
        self._log(prepared.paths.run_id, "Read-only OpenCode audit: " + " | ".join(diagnostic_parts))
        metadata["verdict"] = verdict
        return CoordinatorOutcome(
            base_sha=before.head,
            commit_sha=after.head if after is not None else None,
            coordinator_state="READ_ONLY",
            findings=self._audit_findings(
                prompt=prompt,
                stdout=stdout,
                stderr=stderr,
                output_path=str(output_path),
                failed=failed,
                classifications=tuple(classifications),
                mutation_reasons=tuple(mutation_reasons),
            ),
            verdict=verdict,
            diagnostic=" | ".join(diagnostic_parts),
            cancelled=(
                result is not None and result.status is OpenCodeRunStatus.CANCELLED
            ),
            metadata=metadata,
        )

    def _git_head(self) -> str | None:
        try:
            return ReadOnlyGitAdapter(self.config.repository).head()
        except GitReadError:
            return None

    def _open_code_output(self, run_id: str) -> Callable[[str, str], None]:
        redactor = self._output_redactor()

        def receive(source: str, text: str) -> None:
            stamp = datetime.now(UTC).isoformat()
            entry = redactor.redact(f"{stamp} [{source.upper()}] {text}")
            self.runs.append_log(run_id, entry)
            if self.output_sink is not None:
                self.output_sink(entry)

        return receive

    def _log(self, run_id: str, text: str) -> None:
        entry = self._output_redactor().redact(
            f"{datetime.now(UTC).isoformat()} [GOTA] {text}\n"
        )
        self.runs.append_log(run_id, entry)
        if self.output_sink is not None:
            self.output_sink(entry)

    def _output_redactor(self) -> SensitiveOutputRedactor:
        config_dir = Path(__file__).resolve().parents[2] / ".opencode"
        return SensitiveOutputRedactor((self.config.repository, config_dir))

    def _execute_registered_read_only(
        self,
        prepared: PreparedAction,
        cancel: Event,
    ) -> CoordinatorOutcome:
        action = prepared.action
        run_id = prepared.paths.run_id
        if action.backend == "git-audit":
            return self._git_audit(prepared)
        if action.backend == "opencode-readonly":
            return self._execute_opencode_audit(prepared, cancel)
        if action.backend == "coordinator-status":
            return self._coordinator_status(prepared)
        if action.backend == "diagnostics":
            return self._diagnostics(prepared)
        if action.backend == "recovery-readonly":
            interrupted = self.runs.recover_interrupted()
            self._log(run_id, f"Recovered UI records: {len(interrupted)}")
            return CoordinatorOutcome(
                verdict="READ_ONLY_OK",
                diagnostic=f"UI recovery inspection found {len(interrupted)} interrupted run(s)",
            )
        if action.backend == "coordinator-tests":
            return self._fixed_command(
                prepared,
                cancel,
                [
                    sys.executable,
                    "-B",
                    "-m",
                    "unittest",
                    "discover",
                    "-s",
                    "tools/coordinator/tests",
                    "-v",
                ],
                tests=True,
            )
        if action.backend == "production-validation":
            resolver = self.config.repository / "tools/godot/resolve_godot.py"
            return self._fixed_command(
                prepared,
                cancel,
                [
                    sys.executable,
                    "-B",
                    str(resolver),
                    "--",
                    "--headless",
                    "--editor",
                    "--path",
                    str(self.config.repository),
                    "--quit-after",
                    "5",
                ],
                tests=True,
            )
        if action.backend == "history":
            return CoordinatorOutcome(verdict="PREVIEW_ONLY", diagnostic="History is a UI view")
        raise ExecutionError(f"No executor exists for registered backend {action.backend!r}")

    def _git_audit(self, prepared: PreparedAction) -> CoordinatorOutcome:
        try:
            snapshot = ReadOnlyGitAdapter(self.config.repository).snapshot()
        except GitReadError as error:
            return CoordinatorOutcome(verdict="READ_ONLY_FAILED", diagnostic=str(error))
        self._log(
            prepared.paths.run_id,
            f"Read-only Git snapshot: HEAD={snapshot.head} branch={snapshot.branch} status={snapshot.status or 'clean'}",
        )
        return CoordinatorOutcome(
            base_sha=snapshot.head,
            commit_sha=snapshot.head,
            coordinator_state="READ_ONLY",
            verdict="READ_ONLY_OK" if not snapshot.status else "READ_ONLY_FAILED",
            diff_check="NOT_REQUESTED",
            diagnostic="Read-only Git audit completed" if not snapshot.status else snapshot.status,
        )

    def _coordinator_status(self, prepared: PreparedAction) -> CoordinatorOutcome:
        if not self.config.database.exists():
            return CoordinatorOutcome(
                coordinator_state="UNINITIALIZED",
                verdict="READ_ONLY_OK",
                diagnostic=f"Coordinator database does not exist: {self.config.database}",
            )
        try:
            store = SQLiteCoordinatorStore(self.config.database)
            runs = store.list_runs()
            lock = CoordinatorServiceForStatus(store).inspect_lock()
            self._log(
                prepared.paths.run_id,
                f"Coordinator status: tasks={len(store.list_task_specs())} runs={len(runs)} lock={lock}",
            )
            return CoordinatorOutcome(
                coordinator_state="AVAILABLE",
                verdict="READ_ONLY_OK",
                diagnostic=f"Coordinator has {len(runs)} run(s); lock={lock}",
            )
        except Exception as error:
            return CoordinatorOutcome(
                coordinator_state="UNAVAILABLE",
                verdict="READ_ONLY_FAILED",
                diagnostic=f"Coordinator status failed: {type(error).__name__}: {error}",
            )

    def _diagnostics(self, prepared: PreparedAction) -> CoordinatorOutcome:
        version = self._opencode_version()
        self._log(prepared.paths.run_id, f"OpenCode: {version}")
        self._log(prepared.paths.run_id, f"Repository: {self.config.repository}")
        self._log(prepared.paths.run_id, f"Coordinator DB: {self.config.database}")
        return CoordinatorOutcome(
            verdict="READ_ONLY_OK" if not version.startswith("unavailable") else "READ_ONLY_FAILED",
            diagnostic=f"OpenCode={version}; state_root={self.runs.root}",
        )

    def _opencode_version(self) -> str:
        try:
            result = subprocess.run(
                [self.config.opencode_executable, "--version"],
                cwd=self.config.repository,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=5,
                check=False,
                shell=False,
            )
        except (OSError, subprocess.SubprocessError) as error:
            return f"unavailable ({type(error).__name__}: {error})"
        output = self._output_redactor().redact((result.stdout or result.stderr).strip())
        return output or f"unavailable (exit={result.returncode})"

    def _fixed_command(
        self,
        prepared: PreparedAction,
        cancel: Event,
        argv: list[str],
        *,
        tests: bool,
    ) -> CoordinatorOutcome:
        redactor = self._output_redactor()
        self._log(prepared.paths.run_id, "Executing fixed read-only argv: " + json.dumps(argv))
        environment = os.environ.copy()
        environment["PYTHONDONTWRITEBYTECODE"] = "1"
        if argv[2:5] == ["-m", "unittest", "discover"]:
            coordinator_source = self.config.repository / "tools/coordinator/src"
            inherited_pythonpath = environment.get("PYTHONPATH")
            environment["PYTHONPATH"] = os.pathsep.join(
                path
                for path in (str(coordinator_source), inherited_pythonpath)
                if path
            )
        try:
            process = subprocess.Popen(
                argv,
                cwd=self.config.repository,
                env=environment,
                stdin=subprocess.DEVNULL,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                encoding="utf-8",
                errors="replace",
                shell=False,
            )
        except OSError as error:
            return CoordinatorOutcome(verdict="READ_ONLY_FAILED", diagnostic=str(error))

        assert process.stdout is not None and process.stderr is not None
        output_lock = threading.Lock()

        def pump(stream: Any, source: str) -> None:
            for line in iter(stream.readline, ""):
                with output_lock:
                    stamp = datetime.now(UTC).isoformat()
                    entry = redactor.redact(f"{stamp} [{source}] {line}")
                    self.runs.append_log(prepared.paths.run_id, entry)
                    if self.output_sink is not None:
                        self.output_sink(entry)

        threads = [
            threading.Thread(target=pump, args=(process.stdout, "OUT"), daemon=True),
            threading.Thread(target=pump, args=(process.stderr, "ERR"), daemon=True),
        ]
        for thread in threads:
            thread.start()
        while process.poll() is None:
            if cancel.is_set():
                process.terminate()
                try:
                    process.wait(timeout=1.0)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=1.0)
                return CoordinatorOutcome(
                    verdict="UI_CANCELLED",
                    cancelled=True,
                    diagnostic="Fixed read-only process terminated by UI request",
                )
            try:
                process.wait(timeout=0.05)
            except subprocess.TimeoutExpired:
                pass
        for thread in threads:
            thread.join(timeout=1.0)
        status = f"exit={process.returncode}"
        return CoordinatorOutcome(
            verdict="READ_ONLY_OK" if process.returncode == 0 else "READ_ONLY_FAILED",
            tests=status if tests else None,
            diagnostic=f"Fixed read-only command {status}",
        )

    def _finish(
        self,
        prepared: PreparedAction,
        outcome: CoordinatorOutcome,
        *,
        cancel_status: str | None = None,
    ) -> ActionExecutionResult:
        action = prepared.action
        redactor = self._output_redactor()
        request = self.runs.request(prepared.paths.run_id)
        coordinator_run_id = outcome.coordinator_run_id
        task_id = outcome.task_id
        coordinator_state = outcome.coordinator_state
        verdict = cancel_status or outcome.verdict
        metadata = dict(outcome.metadata)
        output_path_value = metadata.get("output_path")
        if type(output_path_value) is not str:
            if action.backend in {"opencode-direct", "opencode-readonly"} and prepared.paths.opencode_output.exists():
                output_path_value = str(prepared.paths.opencode_output)
            else:
                output_path_value = None
        if output_path_value is not None:
            metadata["output_path"] = output_path_value
        process_status = metadata.get("process_status")
        if type(process_status) is not str:
            process_status = None
        process_exit_code = metadata.get("process_exit_code")
        if type(process_exit_code) is not int:
            process_exit_code = None
        embedded_report_id = metadata.get("embedded_report_id")
        if type(embedded_report_id) is not str:
            embedded_report_id = None
        embedded_status = metadata.get("embedded_status")
        if type(embedded_status) is not str:
            embedded_status = None
        embedded_verdict = metadata.get("embedded_verdict")
        if type(embedded_verdict) is not str:
            embedded_verdict = None
        result_consistency_value = metadata.get("result_consistency")
        if type(result_consistency_value) is not str:
            result_consistency_value = "NO_EMBEDDED_REPORT"
            metadata["result_consistency"] = result_consistency_value
        opencode_version = metadata.get("opencode_version")
        if type(opencode_version) is not str:
            if action.backend in {"gota-task", "gota-review", "opencode-direct"}:
                opencode_version = self._opencode_version()
            elif action.backend == "audit-readonly" or action.backend == "git-audit":
                opencode_version = "NOT_APPLICABLE"
            elif action.backend == "opencode-readonly":
                opencode_version = "NOT_APPLICABLE"
            else:
                opencode_version = None
        result_payload = asdict(outcome)
        result_payload["ui_run_id"] = prepared.paths.run_id
        result_payload.update(
            {
                "run_id": prepared.paths.run_id,
                "action_id": action.id,
                "action": action.id,
                "prompt_sha256": request.get("prompt_sha256"),
                "model": metadata.get("model", self._model(action) or "NOT_APPLICABLE"),
                "variant": metadata.get("variant", self._variant(action) or "NOT_APPLICABLE"),
                "opencode_version": opencode_version,
                "agent": metadata.get("agent", action.agent or "NOT_APPLICABLE"),
                "repository": metadata.get("repository", str(self.config.repository)),
                "timestamp": metadata.get("timestamp", request.get("timestamp")),
                "timeout": metadata.get("timeout", request.get("timeout")),
                "report_path": str(prepared.paths.report),
                "log_path": str(prepared.paths.live_log),
                "output_path": output_path_value,
            }
        )
        result_payload.update(metadata)
        result_payload = dict(
            redact_sensitive_data(
                result_payload,
                roots=(self.config.repository,),
            )
        )
        self.runs.persist_result(prepared.paths.run_id, result_payload)

        non_coordinator = action.backend in {
            "opencode-direct",
            "opencode-readonly",
            "git-audit",
        }
        direct_prompt = action.backend == "opencode-direct"
        report_task_id = "NOT_APPLICABLE" if non_coordinator else task_id
        report_context_id = (
            "NOT_APPLICABLE"
            if non_coordinator
            else (
                prepared.envelope.metadata.get("context_id")
                if type(prepared.envelope.metadata.get("context_id")) is str
                else None
            )
        )
        report_coordinator_state = (
            "NOT_APPLICABLE"
            if direct_prompt
            else (coordinator_state or "READ_ONLY" if non_coordinator else coordinator_state)
        )
        report_worker_result = "NOT_APPLICABLE" if non_coordinator else outcome.worker_result
        report_review_result = "NOT_APPLICABLE" if non_coordinator else outcome.review_result
        report_model = (
            "NOT_APPLICABLE"
            if action.backend == "git-audit"
            else self._model(action) or "NOT_APPLICABLE"
        )
        report_variant = (
            "NOT_APPLICABLE"
            if action.backend == "git-audit"
            else self._variant(action) or "NOT_APPLICABLE"
        )
        report_agent = (
            "NOT_APPLICABLE" if action.backend == "git-audit" else action.agent or "NOT_APPLICABLE"
        )

        safe_findings = redact_sensitive_data(
            list(outcome.findings),
            roots=(self.config.repository,),
        )
        if not isinstance(safe_findings, list):
            raise ExecutionError("Redacted audit findings are not a list")
        report_data = ReportData(
            run_id=prepared.paths.run_id,
            action=action.id,
            task_id=report_task_id,
            context_id=report_context_id,
            model=report_model,
            variant=report_variant,
            opencode_version=opencode_version,
            agent=report_agent,
            repository=str(metadata.get("repository", self.config.repository)),
            base_sha=outcome.base_sha,
            commit_sha=outcome.commit_sha,
            coordinator_state=report_coordinator_state,
            worker_result=report_worker_result,
            review_result=report_review_result,
            tests=outcome.tests or ("NOT_APPLICABLE" if non_coordinator else None),
            diff_check=outcome.diff_check or ("NOT_REQUESTED" if non_coordinator else None),
            prompt_sha256=request.get("prompt_sha256"),
            report_path=str(prepared.paths.report),
            log_path=str(prepared.paths.live_log),
            output_path=metadata.get("output_path"),
            timestamp=metadata.get("timestamp", request.get("timestamp")),
            timeout=metadata.get("timeout", request.get("timeout")),
            readonly_policy=metadata.get("readonly_policy"),
            mutation_guard=metadata.get("mutation_guard"),
            process_status=process_status,
            process_exit_code=process_exit_code,
            embedded_report_id=embedded_report_id,
            embedded_status=embedded_status,
            embedded_verdict=embedded_verdict,
            result_consistency=result_consistency_value,
            findings=safe_findings,
            verdict=verdict,
            diagnostic=redactor.redact(outcome.diagnostic),
        )
        persisted: PersistedReport = ReportManager(
            self.runs, self.clipboard_writer
        ).persist_before_copy(report_data)
        result_payload.update(
            {
                "clipboard_copy": persisted.clipboard_status,
                "report_path": persisted.path,
            }
        )
        self.runs.persist_result(prepared.paths.run_id, result_payload)
        ui_state = "UI_CANCELLED" if outcome.cancelled or cancel_status else "COMPLETED"
        self.runs.finalize(
            prepared.paths.run_id,
            ui_state=ui_state,
            verdict=verdict,
            coordinator_state=report_coordinator_state,
            task_id=report_task_id,
            coordinator_run_id=coordinator_run_id,
        )
        return ActionExecutionResult(
            run_id=prepared.paths.run_id,
            paths=prepared.paths,
            report=persisted.text,
            report_path=persisted.path,
            log_path=str(prepared.paths.live_log),
            clipboard_status=persisted.clipboard_status,
            clipboard_error=persisted.clipboard_error,
            verdict=verdict,
            coordinator_state=report_coordinator_state,
            task_id=report_task_id,
            coordinator_run_id=coordinator_run_id,
            diagnostic=redactor.redact(outcome.diagnostic),
            process_status=process_status,
            process_exit_code=process_exit_code,
            embedded_report_id=embedded_report_id,
            embedded_status=embedded_status,
            embedded_verdict=embedded_verdict,
            result_consistency=result_consistency_value,
        )


class CoordinatorServiceForStatus:
    """Tiny read-only adapter kept separate from mutable service methods."""

    def __init__(self, store: SQLiteCoordinatorStore) -> None:
        self.store = store

    def inspect_lock(self) -> Mapping[str, Any]:
        from flow_coordinator.lock import GlobalLockManager

        return GlobalLockManager(self.store).inspect()


def default_config(state_root: str | Path | None = None) -> TUIConfig:
    root = Path(state_root) if state_root is not None else None
    return TUIConfig(
        repository=Path.cwd().resolve(),
        database=default_coordinator_database(root),
        opencode_executable=os.environ.get("GOTA_OPENCODE", "opencode"),
        model_override=os.environ.get("GOTA_TUI_MODEL") or None,
        variant_override=os.environ.get("GOTA_TUI_VARIANT") or None,
    )
