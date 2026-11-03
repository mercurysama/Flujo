# Potok 8C1 — Eliminación segura de alias dinámico activo

**Fecha:** 2026-11-02. **Rama:** `feature/fsm-runtime-flow-flusso`. **Baseline:** `459913a3514ef3239ad32f2b189e637af7abfdae`. **Objetivo:** verificar la política de rechazo y recuperación al retirar un alias dinámico que es el estado activo de una máquina.

## Cambios y evidencias

- `f1a669b601680408671a8492b32fdd3bd10eab9c`: nuevo test `tests/runtime/flow_fsm_dynamic_active_removal_test.gd`.
- `9a6ccf64b4e8f21375b784a4d5f31dd4bd40bd37`: escena ejecutable `tests/runtime/flow_fsm_dynamic_active_removal_test.tscn`.
- `f1922e8de2e6a6ad513c49bde200b22b3c6f2539`: paso `Potok-8C1 active dynamic alias fallback lifecycle focal` en `.github/workflows/flujo-fsm.yml`.
- **GREEN global confirmado:** [GitHub Actions 41549228081](https://github.com/mercurysama/Flujo/actions/runs/41549228081), **completed SUCCESS, 79/79 pasos**, cero fallos, para el commit `f1922e8de2e6a6ad513c49bde200b22b3c6f2539`. Incluye focal 8C1, 8B2, 8B1 y las regresiones históricas.

## Pruebas realizadas

1. Dos máquinas, con estado inicial authored, plantilla dinámica habilitada, respaldo dinámico habilitado y estado authored deshabilitado.
2. Activa un alias dinámico mediante `change_state` y un tick manual.
3. Intentos de `remove_state` sin fallback, con fallback al mismo alias, destino inexistente, estado authored deshabilitado y destino perteneciente a otra máquina: deben retornar `false` y conservar activo, inventario y señales sin alteración.
4. Desde el callback real de `state_updated` (dentro del tick), intenta remover el alias activo con fallback válido: se rechaza sin alterar inventario ni emitir señales de transición.
5. Fuera del tick, retira el alias activo con fallback a otro alias dinámico válido: se verifica nuevo activo, invalidación del ID eliminado y orden **state_exited → state_entered → transition_committed**, con trigger `dynamic-removal`.
6. Retira posteriormente el segundo alias activo mediante fallback al estado authored inicial; verifica mismo orden y registro dinámico vacío.
7. Rechaza eliminación repetida de un ID desaparecido; conserva recursos authored, segundo machine y validación del grafo.

## Decisión

La implementación previa satisface este contrato; no se modificó el código de producción ni el esquema. El contrato aún necesita pruebas independientes sobre mezcla de solicitudes y eventos pendientes, y múltiples máquinas (**8C2**). Los casos físicos de Fase 7 siguen pospuestos (0/25) y no se autoriza `main` ni release.

**Siguiente:** 8C2: purga selectiva de solicitudes al retirar alias, sin perder solicitudes de otras máquinas ni eventos y sin producir destinos colgantes.

*Todo es Flujo; todo fluye.* 🌊
