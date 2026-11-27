from __future__ import annotations

import unittest
import tempfile
from pathlib import Path
from unittest.mock import patch

from flow_coordinator import OpenCodeRunResult, OpenCodeRunStatus
from gota_tui.actions import ActionRegistry
from gota_tui.durable import DurableRunStore
from gota_tui.envelope import PromptEnvelope
from gota_tui.execution import ActionExecutor, TUIConfig
from gota_tui.prompt_library import PromptLibrary
from gota_tui.routing import (
    GotaRoutingError,
    inject_role,
    parse_gota_prompt,
    resolve_execution_routing,
)


class GotaRoutingTest(unittest.TestCase):
    def test_complete_initial_header_is_removed_and_values_are_preserved(self) -> None:
        parsed = parse_gota_prompt(
            "GOTA_MODEL=openai/gpt-5.6-sol\n"
            "GOTA_VARIANT=low\n"
            "GOTA_ROLE=Arquitecto\n"
            "GOTA_AGENT=build\n"
            "\n"
            "Hola"
        )

        self.assertEqual(parsed.header.model, "openai/gpt-5.6-sol")
        self.assertEqual(parsed.header.variant, "low")
        self.assertEqual(parsed.header.role, "Arquitecto")
        self.assertEqual(parsed.header.agent, "build")
        self.assertEqual(parsed.body, "Hola")
        self.assertEqual(
            parsed.effective_prompt,
            "ROLE:\nArquitecto\n\nTASK:\nHola",
        )

    def test_prompt_without_header_is_legacy_and_unchanged(self) -> None:
        prompt = "Hola\nGOTA_MODEL=openai/gpt-5.6-sol\n\ntexto"
        parsed = parse_gota_prompt(prompt)

        self.assertFalse(parsed.header.present)
        self.assertEqual(parsed.body, prompt)
        self.assertEqual(parsed.effective_prompt, prompt)

    def test_partial_header_uses_fallback_for_missing_values(self) -> None:
        parsed = parse_gota_prompt("GOTA_MODEL=openai/gpt-5.6-sol\n\nHola")
        routing = resolve_execution_routing(
            parsed,
            action_model="openai/gpt-5.6-luna",
            action_variant="max",
            action_agent="build",
            config_variant="high",
        )

        self.assertEqual(routing.model, "openai/gpt-5.6-sol")
        self.assertEqual(routing.model_source, "prompt")
        self.assertEqual(routing.variant, "high")
        self.assertEqual(routing.variant_source, "config")
        self.assertEqual(routing.agent, "build")
        self.assertEqual(routing.agent_source, "action")

    def test_header_looking_text_in_body_is_not_reinterpreted(self) -> None:
        prompt = "GOTA_ROLE=Inicial\n\nHola\nGOTA_ROLE=No cambiar\nfinal"
        parsed = parse_gota_prompt(prompt)

        self.assertEqual(parsed.header.role, "Inicial")
        self.assertIn("GOTA_ROLE=No cambiar", parsed.body)
        self.assertEqual(parsed.body, "Hola\nGOTA_ROLE=No cambiar\nfinal")

    def test_unicode_role_survives_role_injection(self) -> None:
        role = "Ingeniero de herramientas 🌊 / revisión — 中文"
        parsed = parse_gota_prompt(f"GOTA_ROLE={role}\n\nTarea\n```\n🌧️\n```")

        self.assertEqual(parsed.header.role, role)
        self.assertIn(role, parsed.effective_prompt)
        self.assertIn("Tarea\n```\n🌧️\n```", parsed.effective_prompt)

    def test_invalid_initial_values_fail_before_routing(self) -> None:
        for prompt in (
            "GOTA_MODEL=\n\nHola",
            "GOTA_MODEL=invalid\n\nHola",
            "GOTA_VARIANT=\n\nHola",
            "GOTA_AGENT=\n\nHola",
        ):
            with self.subTest(prompt=prompt):
                with self.assertRaises(GotaRoutingError):
                    resolve_execution_routing(
                        parse_gota_prompt(prompt),
                        action_model="openai/gpt-5.6-luna",
                        action_variant="max",
                        action_agent="build",
                    )

    def test_role_injection_without_role_preserves_body_byte_for_byte(self) -> None:
        body = "# Markdown 🌊\n\n```python\nprint('x')\n```\n"
        self.assertEqual(inject_role(body, None), body)

    def test_direct_execution_uses_header_values_and_reports_effective_selection(self) -> None:
        prompt = (
            "GOTA_MODEL=openai/gpt-5.6-sol\n"
            "GOTA_VARIANT=low\n"
            "GOTA_ROLE=Verificador Unicode 🌊\n"
            "GOTA_AGENT=build\n"
            "\n"
            "Responde únicamente: CONFIG_OK\n"
        )
        observations: list[dict[str, object]] = []

        class Writer:
            def copy(self, text: str) -> str:
                observations.append({"report_copy": text})
                return "test"

        class Runner:
            def __init__(self, **kwargs: object) -> None:
                observations.append(dict(kwargs))

            def run(self, **kwargs: object) -> OpenCodeRunResult:
                observations.append(dict(kwargs))
                callback = kwargs["output_callback"]
                assert callable(callback)
                callback("stdout", "CONFIG_OK\n")
                argv = (
                    "opencode",
                    "run",
                    "--model",
                    "openai/gpt-5.6-sol#low",
                    "--agent",
                    "build",
                    "--auto",
                    str(kwargs["prompt"]),
                )
                observations.append({"argv": argv})
                return OpenCodeRunResult(
                    status=OpenCodeRunStatus.SUCCEEDED,
                    argv=argv,
                    cwd=str(kwargs["cwd"]),
                    stdout="CONFIG_OK\n",
                    stderr="",
                    exit_code=0,
                    timed_out=False,
                )

        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            state = DurableRunStore(root / "state")
            executor = ActionExecutor(
                config=TUIConfig(
                    repository=root,
                    database=root / "coordinator.sqlite3",
                    opencode_executable="fake-opencode",
                    model_override="openai/gpt-5.6-luna",
                    variant_override="max",
                ),
                runs=state,
                prompts=PromptLibrary.default(),
                clipboard_writer=Writer(),  # type: ignore[arg-type]
            )
            prepared = executor.prepare(
                ActionRegistry.default().get("clipboard-prompt"),
                PromptEnvelope.parse(prompt),
                run_id="header-route",
            )
            with patch("gota_tui.coordinator_facade.OpenCodeRunner", Runner), patch.object(
                executor, "_opencode_version", return_value="test-opencode"
            ):
                result = executor.execute(prepared)

            runner_init = observations[0]
            runner_call = observations[1]
            self.assertEqual(runner_init["model"], "openai/gpt-5.6-sol")
            self.assertEqual(runner_init["variant"], "low")
            self.assertEqual(runner_call["agent"], "build")
            self.assertNotIn("--variant", observations[2]["argv"])
            self.assertEqual(
                runner_call["prompt"],
                "ROLE:\nVerificador Unicode 🌊\n\nTASK:\nResponde únicamente: CONFIG_OK\n",
            )
            report = state.read_report(result.run_id)
            self.assertIn("MODEL=openai/gpt-5.6-sol", report)
            self.assertIn("VARIANT=low", report)
            self.assertIn("ROLE=Verificador Unicode 🌊", report)
            self.assertIn("AGENT=build", report)
            self.assertIn("MODEL_SOURCE=prompt", report)
            self.assertIn("VARIANT_SOURCE=prompt", report)
            self.assertEqual(state.read_prompt(result.run_id), prompt)


if __name__ == "__main__":
    unittest.main()
