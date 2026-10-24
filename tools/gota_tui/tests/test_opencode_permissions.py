from __future__ import annotations

import json
import os
import re
import shutil
import subprocess
import unittest
from pathlib import Path
from typing import Any


def _wildcard_matches(pattern: str, value: str) -> bool:
    """Match the simple whole-value wildcards used by OpenCode V2."""

    expression = "".join(
        ".*" if character == "*" else "." if character == "?" else re.escape(character)
        for character in pattern
    )
    return re.fullmatch(expression, value) is not None


class OpenCodeV2PermissionTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.repository = Path(__file__).resolve().parents[3]
        cls.config_directory = cls.repository / ".opencode"
        cls.config_file = cls.config_directory / "opencode.jsonc"
        executable = shutil.which("opencode")
        if executable is None:
            raise AssertionError("OpenCode 2.0.32 is required for permission resolution tests")
        cls.environment = os.environ.copy()
        cls.environment["OPENCODE_CONFIG_DIR"] = str(cls.config_directory)
        if cls.environment.get("OPENCODE_DISABLE_PROJECT_CONFIG") == "1":
            raise AssertionError("OPENCODE_DISABLE_PROJECT_CONFIG=1 disables this project smoke")
        version = subprocess.run(
            ["opencode", "--version"],
            cwd=cls.repository,
            env=cls.environment,
            capture_output=True,
            text=True,
            check=True,
        )
        if "v2.0.32" not in version.stdout:
            raise AssertionError(f"OpenCode 2.0.32 required, got {version.stdout.strip()!r}")

        config = cls._run_json_command("debug", "config")
        sources = config if isinstance(config, list) else []
        source_paths = {source.get("path") for source in sources if isinstance(source, dict)}
        if str(cls.config_file) not in source_paths:
            raise AssertionError(
                "OpenCode did not resolve the project config file "
                f"{cls.config_file}"
            )
        resolved_agents = cls._run_json_command("debug", "agents")
        if not isinstance(resolved_agents, list):
            raise AssertionError("OpenCode debug agents did not return a list")
        cls.agents = {
            agent["id"]: agent
            for agent in resolved_agents
            if isinstance(agent, dict) and isinstance(agent.get("id"), str)
        }

    @classmethod
    def _run_json_command(cls, *arguments: str) -> Any:
        result = subprocess.run(
            ["opencode", *arguments],
            cwd=cls.repository,
            env=cls.environment,
            capture_output=True,
            text=True,
            check=False,
        )
        if result.returncode != 0:
            raise AssertionError(
                f"OpenCode {' '.join(arguments)} failed with exit {result.returncode}"
            )
        try:
            return json.loads(result.stdout)
        except json.JSONDecodeError as error:
            raise AssertionError(
                f"OpenCode {' '.join(arguments)} returned non-JSON output"
            ) from error

    @classmethod
    def _rules(cls, agent_id: str) -> list[dict[str, str]]:
        agent = cls.agents.get(agent_id)
        if agent is None:
            raise AssertionError(f"resolved agent {agent_id!r} is missing")
        permissions = agent.get("permissions")
        if not isinstance(permissions, list):
            raise AssertionError(f"resolved agent {agent_id!r} has no permissions")
        return [rule for rule in permissions if isinstance(rule, dict)]

    @classmethod
    def _effect(cls, agent_id: str, action: str, resource: str) -> str:
        matches = [
            rule
            for rule in cls._rules(agent_id)
            if isinstance(rule.get("action"), str)
            and isinstance(rule.get("resource"), str)
            and _wildcard_matches(rule["action"], action)
            and _wildcard_matches(rule["resource"], resource)
        ]
        if not matches:
            raise AssertionError(f"no resolved rule for {agent_id}: {action} {resource}")
        effect = matches[-1].get("effect")
        if not isinstance(effect, str):
            raise AssertionError(f"resolved rule has no effect for {agent_id}: {action} {resource}")
        return effect

    def test_project_config_and_effective_agents_are_resolved(self) -> None:
        self.assertTrue(self.config_file.is_file())
        for agent_id in ("build", "gota-worker", "gota-auditor", "gota-reviewer"):
            with self.subTest(agent=agent_id):
                self.assertIn(agent_id, self.agents)

    def test_build_preserves_authorized_development_and_denies_git_mutation(self) -> None:
        allowed = (
            ("read", "README.md"),
            ("glob", "**/*.py"),
            ("grep", "permission"),
            ("edit", "docs/example.md"),
            ("shell", "python -m unittest"),
            ("shell", "git status --short"),
            ("shell", "git diff --check"),
            ("shell", "git add -- docs/example.md"),
            ("shell", "git commit -m authorized"),
        )
        for action, resource in allowed:
            with self.subTest(action=action, resource=resource):
                self.assertEqual(self._effect("build", action, resource), "allow")

        destructive = (
            "git push --dry-run origin HEAD",
            "git reset --hard HEAD",
            "git clean -fdx",
            "git rebase main",
            "git merge main",
            "git checkout -- docs/example.md",
            "git switch main",
            "git restore docs/example.md",
            "git commit --amend --no-edit",
        )
        for command in destructive:
            with self.subTest(command=command):
                self.assertEqual(self._effect("build", "shell", command), "deny")

    def test_worker_removes_auto_ask_risk_and_preserves_authorized_operations(self) -> None:
        allowed = (
            ("edit", "src/example.py"),
            ("shell", "python -m unittest"),
            ("shell", "git status --short"),
            ("shell", "git diff --check"),
            ("shell", "git add -- src/example.py"),
            ("shell", "git commit -m authorized"),
        )
        for action, resource in allowed:
            with self.subTest(action=action, resource=resource):
                self.assertEqual(self._effect("gota-worker", action, resource), "allow")

        denied = (
            "git push origin HEAD",
            "git pull --ff-only",
            "git fetch origin",
            "git reset --hard HEAD",
            "git clean -fdx",
            "git rebase main",
            "git merge main",
            "git checkout -- src/example.py",
            "git switch main",
            "git restore src/example.py",
            "git commit --amend --no-edit",
        )
        for command in denied:
            with self.subTest(command=command):
                self.assertEqual(self._effect("gota-worker", "shell", command), "deny")

    def test_external_directory_and_service_json_are_denied_for_mutating_agents(self) -> None:
        for agent_id in ("build", "gota-worker", "gota-auditor", "gota-reviewer"):
            with self.subTest(agent=agent_id):
                self.assertEqual(
                    self._effect(agent_id, "external_directory", "/tmp/outside"),
                    "deny",
                )
                self.assertEqual(
                    self._effect(agent_id, "read", ".opencode/service.json"),
                    "deny",
                )
                self.assertEqual(
                    self._effect(agent_id, "read", "nested/.opencode/service.json"),
                    "deny",
                )

    def test_auditor_and_reviewer_remain_read_only(self) -> None:
        self.assertEqual(self._effect("gota-auditor", "read", "README.md"), "allow")
        self.assertEqual(self._effect("gota-auditor", "shell", "git status --short"), "allow")
        for action in ("edit", "subagent", "skill", "external_directory"):
            with self.subTest(agent="gota-auditor", action=action):
                self.assertEqual(self._effect("gota-auditor", action, "*"), "deny")
        self.assertEqual(self._effect("gota-auditor", "shell", "git push origin HEAD"), "deny")

        self.assertEqual(self._effect("gota-reviewer", "read", "README.md"), "allow")
        self.assertEqual(self._effect("gota-reviewer", "glob", "**/*.py"), "allow")
        self.assertEqual(self._effect("gota-reviewer", "grep", "permission"), "allow")
        for action in ("edit", "shell", "subagent", "skill", "external_directory"):
            with self.subTest(agent="gota-reviewer", action=action):
                self.assertEqual(self._effect("gota-reviewer", action, "*"), "deny")
