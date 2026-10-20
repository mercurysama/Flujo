from __future__ import annotations

import json
import os
import signal
import stat
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path
from typing import Any
from unittest.mock import patch

from flow_coordinator import (
    GOTA_RESULT_BEGIN,
    GOTA_RESULT_END,
    GotaReviewResult,
    GotaWorkerResult,
    GotaProtocolErrorCode,
    OpenCodeRunStatus,
    OpenCodeStartFailure,
    OpenCodeRunner,
)
from flow_coordinator.domain import TaskSpec
from flow_coordinator.service import CoordinatorService
from flow_coordinator.store import SQLiteCoordinatorStore


class OpenCodeRunnerTest(unittest.TestCase):
    commit_sha = "0123456789abcdef0123456789abcdef01234567"

    def setUp(self) -> None:
        self.temporary_directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary_directory.cleanup)
        self.root = Path(self.temporary_directory.name)
        self.cwd = self.root / "workspace"
        self.cwd.mkdir()

    def _fake_executable(
        self,
        *,
        stdout: str = "",
        stderr: str = "",
        exit_code: int = 0,
        sleep_seconds: float = 0.0,
        marker: Path | None = None,
    ) -> tuple[Path, Path]:
        executable = self.root / "fake opencode"
        record = self.root / "invocation.json"
        marker_literal = "None" if marker is None else repr(str(marker))
        executable.write_text(
            "\n".join(
                (
                    f"#!{sys.executable}",
                    "import json",
                    "import os",
                    "from pathlib import Path",
                    "import sys",
                    "import time",
                    f"record = Path({json.dumps(str(record), ensure_ascii=False)})",
                    "record.write_text(json.dumps({",
                    "    'argv': sys.argv[1:],",
                    "    'cwd': os.getcwd(),",
                    "    'git_pager': os.environ.get('GIT_PAGER'),",
                    "    'pager': os.environ.get('PAGER'),",
                    "    'probe_env': os.environ.get('FLOW_RUNNER_PROBE'),",
                    "    'config_dir': os.environ.get('OPENCODE_CONFIG_DIR'),",
                    "}, ensure_ascii=False), encoding='utf-8')",
                    f"sys.stdout.write({json.dumps(stdout, ensure_ascii=False)})",
                    "sys.stdout.flush()",
                    f"sys.stderr.write({json.dumps(stderr, ensure_ascii=False)})",
                    "sys.stderr.flush()",
                    f"time.sleep({sleep_seconds!r})",
                    f"marker = {marker_literal}",
                    "if marker is not None:",
                    "    Path(marker).write_text('completed', encoding='utf-8')",
                    f"raise SystemExit({exit_code})",
                )
            ),
            encoding="utf-8",
        )
        executable.chmod(executable.stat().st_mode | stat.S_IXUSR)
        return executable, record

    def _sigterm_ignoring_executable(self, *, marker: Path, pid_file: Path) -> Path:
        executable = self.root / "fake opencode ignoring SIGTERM"
        executable.write_text(
            "\n".join(
                (
                    f"#!{sys.executable}",
                    "import os",
                    "import signal",
                    "import time",
                    "from pathlib import Path",
                    f"pid_file = Path({str(pid_file)!r})",
                    f"marker = Path({str(marker)!r})",
                    "pid_file.write_text(str(os.getpid()), encoding='utf-8')",
                    "signal.signal(signal.SIGTERM, signal.SIG_IGN)",
                    "time.sleep(10)",
                    "marker.write_text('completed', encoding='utf-8')",
                )
            ),
            encoding="utf-8",
        )
        executable.chmod(executable.stat().st_mode | stat.S_IXUSR)
        return executable

    def _worker_payload(self) -> dict[str, Any]:
        return {
            "protocol": "flujo.gota/v1",
            "message": "worker.result",
            "request_id": "run-42:1:worker",
            "task_id": "task-42",
            "run_id": "run-42",
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

    def _review_payload(self) -> dict[str, Any]:
        return {
            "protocol": "flujo.gota/v1",
            "message": "review.result",
            "request_id": "run-42:1:review",
            "task_id": "task-42",
            "run_id": "run-42",
            "attempt": 1,
            "reviewed_commit_sha": self.commit_sha,
            "decision": "PASSED",
            "findings": [],
            "evidence": [{"kind": "audit", "passed": True}],
        }

    @staticmethod
    def _frame(payload: dict[str, Any], *, prefix: str = "", suffix: str = "") -> str:
        return (
            f"{prefix}{GOTA_RESULT_BEGIN}\n"
            f"{json.dumps(payload, sort_keys=True, ensure_ascii=False)}\n"
            f"{GOTA_RESULT_END}{suffix}"
        )

    def _record(self, path: Path) -> dict[str, Any]:
        return json.loads(path.read_text(encoding="utf-8"))

    def _escaped_descendant_executable(
        self,
        *,
        marker: Path,
        pid_file: Path,
        session_file: Path,
        cgroup_file: Path,
    ) -> Path:
        executable = self.root / "fake opencode with escaped child"
        child_code = "\n".join(
            (
                "import os",
                "import time",
                "from pathlib import Path",
                "os.setsid()",
                f"Path({str(session_file)!r}).write_text(str(os.getsid(0)), encoding='utf-8')",
                f"Path({str(cgroup_file)!r}).write_text(Path('/proc/self/cgroup').read_text(encoding='utf-8'), encoding='utf-8')",
                "time.sleep(0.6)",
                f"Path({str(marker)!r}).write_text('escaped', encoding='utf-8')",
                "time.sleep(0.1)",
            )
        )
        executable.write_text(
            "\n".join(
                (
                    f"#!{sys.executable}",
                    "import subprocess",
                    "import time",
                    "from pathlib import Path",
                    f"child = subprocess.Popen([{sys.executable!r}, '-c', {child_code!r}])",
                    f"Path({str(pid_file)!r}).write_text(str(child.pid), encoding='utf-8')",
                    "for _ in range(100):",
                    f"    if Path({str(session_file)!r}).exists():",
                    "        break",
                    "    time.sleep(0.01)",
                    "print('helper started', flush=True)",
                    "time.sleep(10)",
                )
            ),
            encoding="utf-8",
        )
        executable.chmod(executable.stat().st_mode | stat.S_IXUSR)
        return executable

    def _double_fork_descendant_executable(
        self,
        *,
        marker: Path,
        pid_file: Path,
        parent_file: Path,
        wrapper_file: Path,
        first_pid_file: Path,
        root_pid_file: Path,
        cgroup_file: Path,
    ) -> Path:
        executable = self.root / "fake opencode with double fork"
        executable.write_text(
            "\n".join(
                (
                    f"#!{sys.executable}",
                    "import os",
                    "import time",
                    "from pathlib import Path",
                    f"marker = Path({str(marker)!r})",
                    f"pid_file = Path({str(pid_file)!r})",
                    f"parent_file = Path({str(parent_file)!r})",
                    f"wrapper_file = Path({str(wrapper_file)!r})",
                    f"first_pid_file = Path({str(first_pid_file)!r})",
                    f"root_pid_file = Path({str(root_pid_file)!r})",
                    f"cgroup_file = Path({str(cgroup_file)!r})",
                    "root_pid_file.write_text(str(os.getpid()), encoding='utf-8')",
                    "first_pid = os.fork()",
                    "if first_pid == 0:",
                    "    first_child_pid = os.getpid()",
                    "    second_pid = os.fork()",
                    "    if second_pid == 0:",
                    "        os.setsid()",
                    "        pid_file.write_text(str(os.getpid()), encoding='utf-8')",
                    "        for _ in range(200):",
                    "            if os.getppid() != first_child_pid:",
                    "                break",
                    "            time.sleep(0.005)",
                    "        parent_file.write_text(str(os.getppid()), encoding='utf-8')",
                    "        cgroup_file.write_text(Path('/proc/self/cgroup').read_text(encoding='utf-8'), encoding='utf-8')",
                    "        os.write(1, b'double-fork stdout\\n')",
                    "        os.write(2, b'double-fork stderr\\n')",
                    "        time.sleep(0.8)",
                    "        marker.write_text('late', encoding='utf-8')",
                    "        time.sleep(0.1)",
                    "        os._exit(0)",
                    "    os._exit(0)",
                    "first_pid_file.write_text(str(first_pid), encoding='utf-8')",
                    "wrapper_file.write_text(str(os.getppid()), encoding='utf-8')",
                    "for _ in range(200):",
                    "    if parent_file.exists():",
                    "        break",
                    "    time.sleep(0.005)",
                    "print('double-fork root exiting', flush=True)",
                    "time.sleep(10)",
                )
            ),
            encoding="utf-8",
        )
        executable.chmod(executable.stat().st_mode | stat.S_IXUSR)
        return executable

    @staticmethod
    def _linux_process_is_executing(pid: int) -> bool:
        try:
            stat_text = Path(f"/proc/{pid}/stat").read_text(encoding="ascii")
        except (OSError, UnicodeError):
            return False
        closing_parenthesis = stat_text.rfind(")")
        if closing_parenthesis < 0:
            return False
        fields = stat_text[closing_parenthesis + 2 :].split()
        return bool(fields) and fields[0] not in {"Z", "X"}

    @staticmethod
    def _linux_process_state(pid: int) -> str | None:
        try:
            stat_text = Path(f"/proc/{pid}/stat").read_text(encoding="ascii")
        except (OSError, UnicodeError):
            return None
        closing_parenthesis = stat_text.rfind(")")
        if closing_parenthesis < 0:
            return None
        fields = stat_text[closing_parenthesis + 2 :].split()
        return fields[0] if fields else None

    @classmethod
    def _wait_for_process_gone(cls, pid: int, timeout: float = 1.0) -> None:
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if cls._linux_process_state(pid) is None:
                return
            time.sleep(0.01)

    def _assert_no_flow_units(self) -> None:
        result = subprocess.run(
            [
                "systemctl",
                "--user",
                "list-units",
                "--all",
                "flow-gota-*.service",
                "--no-legend",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=1.0,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "")

    def _assert_user_manager_healthy(self) -> None:
        result = subprocess.run(
            ["systemctl", "--user", "is-system-running"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=1.0,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), "running")

    def _assert_cgroup_empty(self, cgroup_file: Path) -> None:
        content = cgroup_file.read_text(encoding="utf-8")
        self.assertIn("flow-gota-", content)
        relative_path = content.split(":", 2)[-1].strip()
        cgroup_directory = Path("/sys/fs/cgroup") / relative_path.lstrip("/")
        if cgroup_directory.exists():
            self.assertEqual(
                (cgroup_directory / "cgroup.procs")
                .read_text(encoding="ascii")
                .strip(),
                "",
            )

    @staticmethod
    def _cleanup_process(process: subprocess.Popen[str]) -> None:
        if process.poll() is None:
            process.terminate()
        try:
            process.wait(timeout=1.0)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=1.0)

    def _sigstop_parent_executable(
        self,
        *,
        marker: Path,
        helper_pid_file: Path,
        wrapper_pid_file: Path,
        wrapper_cmdline_file: Path,
        descendant_pid_file: Path,
        cgroup_file: Path,
    ) -> Path:
        executable = self.root / "fake opencode with stopped parent"
        descendant_code = "import time; time.sleep(10)"
        executable.write_text(
            "\n".join(
                (
                    f"#!{sys.executable}",
                    "import os",
                    "import signal",
                    "import subprocess",
                    "import time",
                    "from pathlib import Path",
                    f"marker = Path({str(marker)!r})",
                    f"helper_pid_file = Path({str(helper_pid_file)!r})",
                    f"wrapper_pid_file = Path({str(wrapper_pid_file)!r})",
                    f"wrapper_cmdline_file = Path({str(wrapper_cmdline_file)!r})",
                    f"descendant_pid_file = Path({str(descendant_pid_file)!r})",
                    f"cgroup_file = Path({str(cgroup_file)!r})",
                    "helper_pid_file.write_text(str(os.getpid()), encoding='utf-8')",
                    "wrapper_pid = os.getppid()",
                    "wrapper_pid_file.write_text(str(wrapper_pid), encoding='utf-8')",
                    "wrapper_cmdline_file.write_bytes(Path(f'/proc/{wrapper_pid}/cmdline').read_bytes())",
                    "cgroup_file.write_text(Path('/proc/self/cgroup').read_text(encoding='utf-8'), encoding='utf-8')",
                    f"descendant = subprocess.Popen([{sys.executable!r}, '-c', {descendant_code!r}])",
                    "descendant_pid_file.write_text(str(descendant.pid), encoding='utf-8')",
                    "os.kill(wrapper_pid, signal.SIGSTOP)",
                    "time.sleep(2)",
                    "marker.write_text('late', encoding='utf-8')",
                    "time.sleep(0.1)",
                )
            ),
            encoding="utf-8",
        )
        executable.chmod(executable.stat().st_mode | stat.S_IXUSR)
        return executable

    def test_builds_exact_argv_and_keeps_shell_text_as_data(self) -> None:
        marker = self.root / "must-not-exist"
        executable, record = self._fake_executable()
        agent = "worker agent 🌧️"
        prompt = (
            f"texto con espacios y Unicode 🌧️ $(touch {marker}) $ ${{HOME}} "
            '"comillas" ; &\nsegunda línea'
        )
        before_cwd = Path.cwd()

        result = OpenCodeRunner(model="model/test", variant="fast", executable=executable).run(
            agent=agent,
            prompt=prompt,
            cwd=self.cwd,
            timeout=2,
        )

        self.assertEqual(
            result.argv,
            (
                str(executable),
                "run",
                "--standalone",
                "--model",
                "model/test#fast",
                "--agent",
                agent,
                "--auto",
                prompt,
            ),
        )
        invocation = self._record(record)
        self.assertEqual(invocation["argv"], list(result.argv[1:]))
        self.assertNotIn("--variant", invocation["argv"])
        self.assertEqual(invocation["cwd"], str(self.cwd))
        self.assertEqual(Path.cwd(), before_cwd)
        self.assertFalse(marker.exists())
        self.assertEqual(result.status, OpenCodeRunStatus.INVALID_PAYLOAD)

    def test_defaults_and_pagers_are_explicit_in_child_environment(self) -> None:
        executable, record = self._fake_executable()

        with patch.dict(
            os.environ,
            {
                "GIT_PAGER": "less",
                "PAGER": "more",
                "FLOW_RUNNER_PROBE": "$literal ${HOME} & Unicode 🌧️",
            },
        ):
            result = OpenCodeRunner(executable=executable).run(
                agent="worker",
                prompt="default configuration",
                cwd=self.cwd,
                timeout=2,
            )
            self.assertEqual(os.environ["GIT_PAGER"], "less")
            self.assertEqual(os.environ["PAGER"], "more")

        invocation = self._record(record)
        self.assertEqual(
            result.argv[1:],
            (
                "run",
                "--standalone",
                "--model",
                "openai/gpt-5.6-luna#max",
                "--agent",
                "worker",
                "--auto",
                "default configuration",
            ),
        )
        self.assertEqual(invocation["argv"], list(result.argv[1:]))
        self.assertEqual(invocation["git_pager"], "cat")
        self.assertEqual(invocation["pager"], "cat")
        self.assertEqual(invocation["probe_env"], "$literal ${HOME} & Unicode 🌧️")

    def test_canonical_config_dir_overrides_inherited_value_only_in_child(self) -> None:
        executable, record = self._fake_executable()
        canonical_config = Path(__file__).resolve().parents[3] / ".opencode"
        inherited_config = str(self.root / "other-config")

        with patch.dict(os.environ, {"OPENCODE_CONFIG_DIR": inherited_config}):
            OpenCodeRunner(executable=executable).run(
                agent="gota-reviewer",
                prompt="canonical configuration",
                cwd=self.cwd,
                timeout=2,
            )
            self.assertEqual(os.environ["OPENCODE_CONFIG_DIR"], inherited_config)

        invocation = self._record(record)
        self.assertEqual(invocation["config_dir"], str(canonical_config))
        self.assertNotEqual(canonical_config, self.cwd / ".opencode")
        self.assertEqual(invocation["cwd"], str(self.cwd))

    def test_standalone_preserves_requested_canonical_agent(self) -> None:
        executable, record = self._fake_executable()
        for agent in ("gota-worker", "gota-reviewer"):
            with self.subTest(agent=agent):
                result = OpenCodeRunner(executable=executable).run(
                    agent=agent,
                    prompt="agent selection",
                    cwd=self.cwd,
                    timeout=2,
                )
                self.assertEqual(result.argv[:3], (str(executable), "run", "--standalone"))
                self.assertEqual(result.argv.count("--standalone"), 1)
                invocation = self._record(record)
                self.assertEqual(invocation["argv"], list(result.argv[1:]))
                self.assertEqual(invocation["argv"][invocation["argv"].index("--agent") + 1], agent)

    def test_model_without_variant_keeps_exact_argv(self) -> None:
        executable, record = self._fake_executable()

        result = OpenCodeRunner(
            model="model/test", variant=None, executable=executable
        ).run(
            agent="worker",
            prompt="model without variant",
            cwd=self.cwd,
            timeout=2,
        )

        self.assertEqual(
            result.argv,
            (
                str(executable),
                "run",
                "--standalone",
                "--model",
                "model/test",
                "--agent",
                "worker",
                "--auto",
                "model without variant",
            ),
        )
        invocation = self._record(record)
        self.assertEqual(invocation["argv"], list(result.argv[1:]))
        self.assertNotIn("--variant", invocation["argv"])

    def test_blank_variant_remains_invalid(self) -> None:
        for variant in ("", " \t\n"):
            with self.subTest(variant=variant):
                with self.assertRaisesRegex(ValueError, "variant must be a non-empty string"):
                    OpenCodeRunner(variant=variant)

    def test_captures_output_and_validates_worker_payload(self) -> None:
        stdout = self._frame(self._worker_payload())
        executable, record = self._fake_executable(
            stdout=stdout,
            stderr="diagnostic 🌧️\n",
        )

        result = OpenCodeRunner(executable=executable).run(
            agent="worker",
            prompt="produce worker result",
            cwd=self.cwd,
            timeout=2,
        )

        self.assertEqual(result.status, OpenCodeRunStatus.SUCCEEDED)
        self.assertEqual(result.stdout, stdout)
        self.assertEqual(result.stderr, "diagnostic 🌧️\n")
        self.assertEqual(result.exit_code, 0)
        self.assertFalse(result.timed_out)
        self.assertIsInstance(result.payload, GotaWorkerResult)
        self.assertEqual(result.payload.commit_sha, self.commit_sha)
        self.assertTrue(record.exists())

    def test_validates_reviewer_payload(self) -> None:
        stdout = self._frame(self._review_payload())
        executable, _ = self._fake_executable(stdout=stdout)

        result = OpenCodeRunner(executable=executable).run(
            agent="reviewer",
            prompt="review the change",
            cwd=self.cwd,
            timeout=2,
        )

        self.assertEqual(result.status, OpenCodeRunStatus.SUCCEEDED)
        self.assertIsInstance(result.payload, GotaReviewResult)
        self.assertEqual(result.payload.request_id, "run-42:1:review")

    def test_invalid_framing_or_payload_is_not_accepted(self) -> None:
        executable, _ = self._fake_executable(
            stdout=f"{GOTA_RESULT_BEGIN}\n{{}}\n{GOTA_RESULT_END}"
        )

        result = OpenCodeRunner(executable=executable).run(
            agent="worker",
            prompt="invalid result",
            cwd=self.cwd,
            timeout=2,
        )

        self.assertEqual(result.status, OpenCodeRunStatus.INVALID_PAYLOAD)
        self.assertEqual(result.exit_code, 0)
        self.assertIsNone(result.payload)
        self.assertEqual(result.protocol_error_code, GotaProtocolErrorCode.MISSING_FIELD)
        self.assertIn("MISSING_FIELD", result.error or "")

    def test_output_without_gota_result_is_not_accepted(self) -> None:
        executable, _ = self._fake_executable(stdout="ordinary OpenCode log\n")

        result = OpenCodeRunner(executable=executable).run(
            agent="worker",
            prompt="no result",
            cwd=self.cwd,
            timeout=2,
        )

        self.assertEqual(result.status, OpenCodeRunStatus.INVALID_PAYLOAD)
        self.assertEqual(result.protocol_error_code, GotaProtocolErrorCode.START_DELIMITER_MISSING)
        self.assertIsNone(result.payload)

    def test_parser_accepts_free_text_around_a_valid_frame(self) -> None:
        stdout = self._frame(
            self._worker_payload(),
            prefix="operational preface\n",
            suffix="\noperational suffix",
        )
        executable, _ = self._fake_executable(stdout=stdout)

        result = OpenCodeRunner(executable=executable).run(
            agent="worker",
            prompt="valid result with logs",
            cwd=self.cwd,
            timeout=2,
        )

        self.assertEqual(result.status, OpenCodeRunStatus.SUCCEEDED)
        self.assertIsInstance(result.payload, GotaWorkerResult)

    def test_non_zero_exit_is_distinct_even_when_stdout_is_captured(self) -> None:
        stdout = self._frame(self._worker_payload())
        executable, _ = self._fake_executable(
            stdout=stdout,
            stderr="OpenCode failed\n",
            exit_code=7,
        )

        result = OpenCodeRunner(executable=executable).run(
            agent="worker",
            prompt="failed process",
            cwd=self.cwd,
            timeout=2,
        )

        self.assertEqual(result.status, OpenCodeRunStatus.NON_ZERO_EXIT)
        self.assertEqual(result.exit_code, 7)
        self.assertEqual(result.stdout, stdout)
        self.assertEqual(result.stderr, "OpenCode failed\n")
        self.assertIsNone(result.payload)
        self.assertFalse(result.timed_out)

    def test_timeout_terminates_process_and_captures_partial_output(self) -> None:
        marker = self.root / "completed-after-timeout"
        executable, _ = self._fake_executable(
            stdout="before timeout\n",
            stderr="still running\n",
            sleep_seconds=10,
            marker=marker,
        )

        result = OpenCodeRunner(executable=executable).run(
            agent="worker",
            prompt="slow process",
            cwd=self.cwd,
            timeout=0.2,
        )

        self.assertEqual(result.status, OpenCodeRunStatus.TIMEOUT)
        self.assertTrue(result.timed_out)
        self.assertIsNotNone(result.exit_code)
        self.assertIn("before timeout", result.stdout)
        self.assertIn("still running", result.stderr)
        time.sleep(0.1)
        self.assertFalse(marker.exists())

    @unittest.skipUnless(sys.platform == "linux", "requires Linux systemd")
    def test_timeout_does_not_report_cleanup_for_collected_unit(self) -> None:
        marker = self.root / "collected-unit-completed-after-timeout"
        executable, record = self._fake_executable(
            sleep_seconds=10,
            marker=marker,
        )
        started = time.monotonic()

        result = OpenCodeRunner(executable=executable).run(
            agent="worker",
            prompt="timeout with asynchronous unit collection",
            cwd=self.cwd,
            timeout=0.2,
        )
        elapsed = time.monotonic() - started

        self.assertEqual(result.status, OpenCodeRunStatus.TIMEOUT)
        self.assertNotIn("was not collected within the cleanup bound", result.error or "")
        self.assertLess(elapsed, 1.5)
        self.assertTrue(record.exists())
        self.assertFalse(marker.exists())
        self._assert_no_flow_units()
        self._assert_user_manager_healthy()

    @unittest.skipUnless(sys.platform == "linux", "requires Linux system supervision")
    def test_timeout_terminates_target_that_ignores_sigterm(self) -> None:
        marker = self.root / "sigterm-ignored-completed-after-timeout"
        pid_file = self.root / "sigterm-ignored.pid"
        executable = self._sigterm_ignoring_executable(marker=marker, pid_file=pid_file)

        result = OpenCodeRunner(executable=executable).run(
            agent="worker",
            prompt="terminate a target that ignores SIGTERM",
            cwd=self.cwd,
            timeout=0.2,
        )

        self.assertEqual(result.status, OpenCodeRunStatus.TIMEOUT)
        self.assertNotIn("was not collected within the cleanup bound", result.error or "")
        target_pid = int(pid_file.read_text(encoding="utf-8"))
        self._wait_for_process_gone(target_pid)
        self.assertIsNone(self._linux_process_state(target_pid))
        self.assertFalse(marker.exists())
        self._assert_no_flow_units()
        self._assert_user_manager_healthy()

    def test_unit_collection_keeps_diagnostic_when_load_state_stays_loaded(self) -> None:
        with (
            patch("flow_coordinator.opencode_runner._SYSTEMD_COLLECTION_GRACE_SECONDS", 0.03),
            patch.object(OpenCodeRunner, "_run_systemctl") as run_systemctl,
        ):
            run_systemctl.return_value = subprocess.CompletedProcess(
                ["systemctl"],
                0,
                stdout="loaded\n",
                stderr="",
            )
            started = time.monotonic()
            collected = OpenCodeRunner._wait_for_unit_collected(
                "systemctl", "flow-gota-still-loaded.service"
            )
            elapsed = time.monotonic() - started

        self.assertFalse(collected)
        self.assertGreater(run_systemctl.call_count, 1)
        self.assertLess(elapsed, 0.5)

    @unittest.skipUnless(sys.platform == "linux", "requires Linux process metadata")
    def test_timeout_terminates_setsid_descendant_and_bounds_pipe_collection(self) -> None:
        marker = self.root / "escaped-descendant-marker"
        pid_file = self.root / "escaped-descendant.pid"
        session_file = self.root / "escaped-descendant.session"
        cgroup_file = self.root / "escaped-descendant.cgroup"
        executable = self._escaped_descendant_executable(
            marker=marker,
            pid_file=pid_file,
            session_file=session_file,
            cgroup_file=cgroup_file,
        )
        unrelated_signal_file = self.root / "setsid-unrelated-signal"
        unrelated_code = (
            "import signal,time; "
            f"signal.signal(signal.SIGTERM, lambda *_: open({str(unrelated_signal_file)!r}, 'w').write('term')); "
            "time.sleep(5)"
        )
        unrelated = subprocess.Popen([sys.executable, "-c", unrelated_code])
        self.addCleanup(self._cleanup_process, unrelated)
        started = time.monotonic()

        result = OpenCodeRunner(executable=executable).run(
            agent="worker",
            prompt="terminate the complete process tree",
            cwd=self.cwd,
            timeout=0.2,
        )
        elapsed = time.monotonic() - started

        self.assertEqual(result.status, OpenCodeRunStatus.TIMEOUT)
        self.assertLess(elapsed, 1.0)
        child_pid = int(pid_file.read_text(encoding="utf-8"))
        self.assertEqual(session_file.read_text(encoding="utf-8"), str(child_pid))
        self.assertFalse(self._linux_process_is_executing(child_pid))
        self.assertFalse(marker.exists())
        self.assertFalse(unrelated_signal_file.exists())
        self._assert_cgroup_empty(cgroup_file)
        self._assert_no_flow_units()
        self._assert_user_manager_healthy()
        time.sleep(0.3)
        self.assertFalse(marker.exists())
        self._cleanup_process(unrelated)

    @unittest.skipUnless(sys.platform == "linux", "requires Linux process supervision")
    def test_timeout_terminates_double_fork_reparented_descendant(self) -> None:
        marker = self.root / "double-fork-marker"
        pid_file = self.root / "double-fork.pid"
        parent_file = self.root / "double-fork.parent"
        wrapper_file = self.root / "double-fork.wrapper"
        first_pid_file = self.root / "double-fork.first-pid"
        root_pid_file = self.root / "double-fork.root-pid"
        cgroup_file = self.root / "double-fork.cgroup"
        executable = self._double_fork_descendant_executable(
            marker=marker,
            pid_file=pid_file,
            parent_file=parent_file,
            wrapper_file=wrapper_file,
            first_pid_file=first_pid_file,
            root_pid_file=root_pid_file,
            cgroup_file=cgroup_file,
        )
        unrelated_signal_file = self.root / "double-fork-unrelated-signal"
        unrelated_code = (
            "import signal,time; "
            f"signal.signal(signal.SIGTERM, lambda *_: open({str(unrelated_signal_file)!r}, 'w').write('term')); "
            "time.sleep(5)"
        )
        unrelated = subprocess.Popen([sys.executable, "-c", unrelated_code])
        coordinator_pid = os.getpid()
        child_pid: int | None = None
        first_pid: int | None = None
        root_pid: int | None = None
        wrapper_pid: int | None = None
        started = time.monotonic()
        try:
            result = OpenCodeRunner(executable=executable).run(
                agent="worker",
                prompt="terminate a reparented double-fork descendant",
                cwd=self.cwd,
                timeout=0.2,
            )
            elapsed = time.monotonic() - started

            self.assertEqual(result.status, OpenCodeRunStatus.TIMEOUT)
            self.assertLess(elapsed, 1.5)
            child_pid = int(pid_file.read_text(encoding="utf-8"))
            first_pid = int(first_pid_file.read_text(encoding="utf-8"))
            root_pid = int(root_pid_file.read_text(encoding="utf-8"))
            wrapper_pid = int(wrapper_file.read_text(encoding="utf-8"))
            self.assertNotEqual(int(parent_file.read_text(encoding="utf-8")), wrapper_pid)
            self.assertNotEqual(int(parent_file.read_text(encoding="utf-8")), first_pid)
            self.assertNotEqual(wrapper_pid, coordinator_pid)
            for process_pid in (root_pid, first_pid, child_pid, wrapper_pid):
                self._wait_for_process_gone(process_pid)
                self.assertIsNone(self._linux_process_state(process_pid))
            self.assertIsNone(unrelated.poll())
            self.assertFalse(unrelated_signal_file.exists())
            self.assertTrue(self._linux_process_is_executing(coordinator_pid))
            self.assertFalse(marker.exists())
            self._assert_cgroup_empty(cgroup_file)
            self._assert_no_flow_units()
            self._assert_user_manager_healthy()
            time.sleep(1.0)
            self.assertFalse(marker.exists())
            self.assertIsNone(self._linux_process_state(child_pid))
        finally:
            for orphan_pid in (child_pid, first_pid, root_pid, wrapper_pid):
                if (
                    orphan_pid is None
                    or self._linux_process_state(orphan_pid) in {None, "Z", "X"}
                ):
                    continue
                try:
                    os.kill(orphan_pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
            if unrelated.poll() is None:
                self._cleanup_process(unrelated)

    @unittest.skipUnless(sys.platform == "linux", "requires Linux process supervision")
    def test_timeout_terminates_sigstop_parent_and_complete_cgroup(self) -> None:
        marker = self.root / "sigstop-parent-marker"
        helper_pid_file = self.root / "sigstop-parent.helper-pid"
        wrapper_pid_file = self.root / "sigstop-parent.wrapper-pid"
        wrapper_cmdline_file = self.root / "sigstop-parent.wrapper-cmdline"
        descendant_pid_file = self.root / "sigstop-parent.descendant-pid"
        cgroup_file = self.root / "sigstop-parent.cgroup"
        executable = self._sigstop_parent_executable(
            marker=marker,
            helper_pid_file=helper_pid_file,
            wrapper_pid_file=wrapper_pid_file,
            wrapper_cmdline_file=wrapper_cmdline_file,
            descendant_pid_file=descendant_pid_file,
            cgroup_file=cgroup_file,
        )
        unrelated_signal_file = self.root / "sigstop-unrelated-signal"
        unrelated_code = (
            "import signal,time; "
            f"signal.signal(signal.SIGTERM, lambda *_: open({str(unrelated_signal_file)!r}, 'w').write('term')); "
            "time.sleep(5)"
        )
        unrelated = subprocess.Popen([sys.executable, "-c", unrelated_code])
        coordinator_pid = os.getpid()
        helper_pid: int | None = None
        wrapper_pid: int | None = None
        descendant_pid: int | None = None
        try:
            started = time.monotonic()
            result = OpenCodeRunner(executable=executable).run(
                agent="worker",
                prompt="stop the wrapper parent, then contain every descendant",
                cwd=self.cwd,
                timeout=0.2,
            )
            elapsed = time.monotonic() - started

            self.assertEqual(result.status, OpenCodeRunStatus.TIMEOUT)
            self.assertLess(elapsed, 1.5)
            helper_pid = int(helper_pid_file.read_text(encoding="utf-8"))
            wrapper_pid = int(wrapper_pid_file.read_text(encoding="utf-8"))
            descendant_pid = int(descendant_pid_file.read_text(encoding="utf-8"))
            self.assertNotEqual(wrapper_pid, coordinator_pid)
            self.assertIn(b"opencode_wrapper.py", wrapper_cmdline_file.read_bytes())
            self._wait_for_process_gone(wrapper_pid)
            self.assertIsNone(self._linux_process_state(wrapper_pid))
            for process_pid in (helper_pid, descendant_pid):
                self._wait_for_process_gone(process_pid)
                self.assertIsNone(self._linux_process_state(process_pid))
            self.assertFalse(marker.exists())
            self._assert_cgroup_empty(cgroup_file)
            self._assert_no_flow_units()
            self.assertIsNone(unrelated.poll())
            self.assertFalse(unrelated_signal_file.exists())
            self.assertTrue(self._linux_process_is_executing(coordinator_pid))
            self._assert_user_manager_healthy()
            time.sleep(0.3)
            self.assertFalse(marker.exists())
        finally:
            for orphan_pid in (helper_pid, descendant_pid, wrapper_pid):
                if (
                    orphan_pid is None
                    or self._linux_process_state(orphan_pid) in {None, "Z", "X"}
                ):
                    continue
                try:
                    os.kill(orphan_pid, signal.SIGKILL)
                except ProcessLookupError:
                    pass
            if unrelated.poll() is None:
                self._cleanup_process(unrelated)

    def test_start_failure_and_invalid_cwd_are_distinct_from_process_results(self) -> None:
        missing_executable = self.root / "does-not-exist"
        start_failure = OpenCodeRunner(executable=missing_executable).run(
            agent="worker",
            prompt="cannot start",
            cwd=self.cwd,
            timeout=2,
        )
        invalid_cwd = OpenCodeRunner(executable=missing_executable).run(
            agent="worker",
            prompt="invalid cwd",
            cwd=self.root / "missing-directory",
            timeout=2,
        )

        for result in (start_failure, invalid_cwd):
            with self.subTest(result=result):
                self.assertEqual(result.status, OpenCodeRunStatus.START_FAILED)
                self.assertIsNone(result.exit_code)
                self.assertFalse(result.timed_out)
                self.assertIsNone(result.payload)
                self.assertTrue(result.error)
        self.assertEqual(
            start_failure.start_failure,
            OpenCodeStartFailure.TARGET_EXECUTABLE,
        )
        self.assertEqual(invalid_cwd.start_failure, OpenCodeStartFailure.INVALID_CWD)

    @unittest.skipUnless(sys.platform == "linux", "requires Linux systemd")
    def test_linux_without_systemd_fails_without_an_uncontained_fallback(self) -> None:
        executable, _ = self._fake_executable()

        with patch("flow_coordinator.opencode_runner.shutil.which", return_value=None):
            result = OpenCodeRunner(executable=executable).run(
                agent="worker",
                prompt="containment is required",
                cwd=self.cwd,
                timeout=2,
            )

        self.assertEqual(result.status, OpenCodeRunStatus.START_FAILED)
        self.assertEqual(
            result.start_failure,
            OpenCodeStartFailure.CONTAINMENT_UNAVAILABLE,
        )
        self.assertIn("containment unavailable", result.error or "")
        self.assertFalse((self.root / "invocation.json").exists())

    def test_runner_does_not_change_sqlite_or_task_state(self) -> None:
        database = self.root / "coordinator.sqlite3"
        store = SQLiteCoordinatorStore(database)
        service = CoordinatorService(store)
        spec = TaskSpec(
            task_id="runner-task",
            title="Runner task",
            objective="Verify the runner boundary",
            project_id="project-a",
            repository_id="repo-a",
            branch="feature/runner-task",
            base_sha="a" * 40,
            context_id="context-runner-task",
            allowed_paths=("src/change.py",),
            protected_paths=("demo/main.tscn",),
            required_resources=(),
            acceptance_criteria=("Runner remains state-free",),
            commit_message="test: runner boundary",
        )
        task_run = service.create_task(spec, {"workspace": str(self.cwd)})
        before_runs = store.list_runs()
        before_events = store.list_events(task_run.run_id)
        before_evidence = store.list_evidence(task_run.run_id)
        before_checkpoints = store.list_checkpoints(task_run.run_id)
        executable, _ = self._fake_executable(stdout="not a gota result")

        result = OpenCodeRunner(executable=executable).run(
            agent="worker",
            prompt="state-free invocation",
            cwd=self.cwd,
            timeout=2,
        )

        self.assertEqual(result.status, OpenCodeRunStatus.INVALID_PAYLOAD)
        self.assertEqual(store.list_runs(), before_runs)
        self.assertEqual(store.list_events(task_run.run_id), before_events)
        self.assertEqual(store.list_evidence(task_run.run_id), before_evidence)
        self.assertEqual(store.list_checkpoints(task_run.run_id), before_checkpoints)


if __name__ == "__main__":
    unittest.main()
