from __future__ import annotations

import json
import sys
import time


STEPS = [
    {
        "actor": "LUNA",
        "action": "preparando plan de lectura",
        "file": "tools/coordinator/src/flow_coordinator/coordinator.py",
        "progress": 8,
        "phase": "PLANNING",
    },
    {
        "actor": "QWEN",
        "action": "leyendo implementación",
        "file": "tools/coordinator/src/flow_coordinator/store.py",
        "progress": 24,
        "phase": "EXPLORING",
    },
    {
        "actor": "QWEN",
        "action": "contrastando persistencia",
        "file": "tools/coordinator/tests/test_gota_persistence.py",
        "progress": 41,
        "phase": "EXPLORING",
    },
    {
        "actor": "EXPLORE",
        "action": "localizando frontera de review",
        "file": "tools/coordinator/src/flow_coordinator/gota_review_entry.py",
        "progress": 57,
        "phase": "EXPLORING",
    },
    {
        "actor": "QWEN",
        "action": "revisando decisiones",
        "file": "tools/coordinator/src/flow_coordinator/gota_decision_application.py",
        "progress": 72,
        "phase": "ANALYZING",
    },
    {
        "actor": "LUNA",
        "action": "integrando resultados",
        "file": "tools/coordinator/src/flow_coordinator/decision_policy.py",
        "progress": 88,
        "phase": "INTEGRATING",
    },
    {
        "actor": "REVIEW",
        "action": "verificando evidencia",
        "file": "tools/coordinator/tests/test_gota_decision_application.py",
        "progress": 100,
        "phase": "VERIFYING",
    },
]


def emit_event(step: dict) -> None:
    print("GOTA_EVENT " + json.dumps(step, ensure_ascii=False), flush=True)


def main() -> int:
    print("Proceso de demostración iniciado.", flush=True)
    time.sleep(1)

    for index, step in enumerate(STEPS, start=1):
        emit_event(step)
        print(
            f"Paso {index}/{len(STEPS)}: {step['action']}",
            flush=True,
        )

        if index == 3:
            print(
                "stderr de prueba: canal capturado correctamente; no es un fallo.",
                file=sys.stderr,
                flush=True,
            )

        time.sleep(2)

    print("Proceso de demostración completado.", flush=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
