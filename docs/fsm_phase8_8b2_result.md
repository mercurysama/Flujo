# Potok 8B2 — Plantillas válidas y datos JSON-safe

**Fecha:** 2026-11-02. **Rama:** `feature/fsm-runtime-flow-flusso`. **Baseline:** `cd6fbe5c1415ae1aa245db3f420c7285051ea43f` y [CI 41548045003](https://github.com/mercurysama/Flujo/actions/runs/41548045003) SUCCESS. **Alcance:** caracterización test-first sobre las APIs FSM-003 ya existentes; no cambiar esquema ni runtime.

## Artefactos y prueba

- `727459addf18861f900e225a1cf1f39dfd01cdd4`: `tests/runtime/flow_fsm_dynamic_template_data_test.gd`.
- `7e12fd611a223a73f0774e0c2a55c91f622ccd3a`: escena `tests/runtime/flow_fsm_dynamic_template_data_test.tscn`.
- `5a1528dc995039560aacd66b8c27f63618da819c`: paso `Potok-8B2 dynamic state templates and structured data focal` en `.github/workflows/flujo-fsm.yml`.
- **GREEN global confirmado:** [Actions 41548395878](https://github.com/mercurysama/Flujo/actions/runs/41548395878), **completed SUCCESS 78/78 pasos**, cero fallos, sobre `5a1528dc995039560aacd66b8c27f63618da819c`; incluye focales 8B2 y 8B1 y las regresiones previas.

## Cobertura focal verificada

- Acepta `template_state_id` del mismo machine habilitado; rechaza plantilla deshabilitada, plantilla de otra máquina y máquina desconocida, sin agregar entradas.
- Registra datos JSON-safe anidados con Array, Dictionary, int, bool, float finito, String y null; las modificaciones posteriores a la entrada no cambian el registro.
- `get_dynamic_state_data` entrega copia profunda desacoplada; `set_dynamic_state_data` reemplaza con una copia y no retiene referencias del llamante.
- Rechaza Array con más de 256 entradas, claves Dictionary no String, float no finito, cadena que excede el límite JSON de 65536 caracteres, profundidad superior a 8, Callable, Vector2 y Node. Todos los rechazos deben preservar el valor anterior y el inventario de aliases.
- Comprueba aislamiento de otro `PVController`, integridad de los arrays authored y validez de `FlowGraph`. No ensaya Dictionary/Array cíclicos porque el validador recursivo existente no cuenta con protección explícita contra ciclos; ello queda como riesgo a caracterizar y tratar en un microbloque posterior de seguridad.

## Decisión, riesgos y siguiente

Las rutas positivas y los límites anteriores funcionan en la implementación existente: **no se modificó código productivo**. Se ha preservado la versión del esquema, la semántica de los snapshots de fase 9 y la distinción de datos del estado runtime frente a los recursos authored. Los escenarios cíclicos requieren una prueba controlada y un contrato de rechazo antes de inyectarse directamente en un proceso de Godot, para evitar recursion/hang.

**Siguiente: 8C1**, lifecycle de un alias activo: fallback inválido, disabled, válido, durante tick y señalización Exit/Enter, con garantías de no mutación ante rechazo. Las 25 pruebas visuales diferidas de fase 7 continúan PENDING. `main` no se modifica.

*Todo es Flujo; todo fluye.* 🌊
