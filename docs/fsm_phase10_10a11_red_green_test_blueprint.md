# Potok 10A-11 — Diseño de pruebas RED/GREEN para DEBUG-FSM 10B (SIN EJECUTAR)

**Fecha:** 2026-11-03. **Base:** `5a2f6589befba5d47b5763b791e6aecb12ccbcb1`. **Estado:** especificación de pruebas **PREPARADA**, no suites ejecutables nuevas, no código productivo ni gate CI cambiado. **No hacer RED obligatorio antes de aprobar contrato 10B-G1..G6.**

**Referencia contractual:** [DEBUG-FSM v1 candidato](fsm_observability_contract_v1_candidate.md), [presupuesto](fsm_phase10_10a6_trace_budget_proposal.md), [auditoría de evidencia](fsm_phase10_10a10_ci_and_contract_audit.md), `docs/fsm_implementation_plan.md` FSM-R27/R28 y contratos FLU-FSM-001/002/003/004.

## 1. Estado y puerta inicial (10B-0)

Antes de escribir tests que supongan APIs nuevas, registrar aceptación explícita del responsable para:
- **G1:** capacidad y límite real de tamaño, política de truncamiento/descarte.
- **G2:** activación, ruta sin captura y comportamiento exportado.
- **G3:** fuente de verdad, modo de consulta (polling/señal) y prevención de reentrancia.
- **G4:** taxonomía exacta de etapas y outcomes; semántica entre solicitudes, paquetes y condiciones.
- **G5:** privacidad, strings y sanitización de datos; objetos prohibidos.
- **G6:** consulta de estado actual al conectar observador tardío, secuencia y epochs.

Los propuestos **128 registros / 1024 bytes UTF-8 y desactivado por defecto** aún no están aprobados. Si cambian, modificar esta matriz **antes** de los RED. G7 (editor/transport) y G8 (pausa/step) requieren autorizaciones aparte.

## 2. Estrategia de fixtures, baseline y gate de pruebas

1. **Baseline formal:** desde el checkout en Fedora/Godot 4.7.2 invocar `$flujo-baseline` conforme a su Skill; capturar HEAD, estado Git, comandos exactos, salida, código y marcadores. Las focales existentes 10A-3/4/5, FSM-4B/4C/5B/5G y regresiones adyacentes preservan el comportamiento actual.
2. **Contrato congelado:** fijar `DEBUG-FSM v1.0 accepted` y entradas de catálogo para el **comportamiento nuevo**, con `not_run` hasta que el test real se ejecute. No registrar `passing` al crear una escena.
3. **RED controlado:** introducir una fixture por capacidad o grupo coherente, que falle por una **única funcionalidad faltante**. Probarla explícitamente fuera del gate obligatorio de CI, registrar código de salida y aserción incumplida con el SHA test-only. No debilitar ni deshabilitar regresiones existentes.
4. **GREEN mínimo:** implementar sólo la capacidad autorizada, sin editar `FlowGraph` ni el snapshot; ejecutar focal y regresiones. Agregar fixture al workflow obligatorio **cuando pase** y registrar estado `passing` sólo después de CI confirmado.
5. **Auditar:** invocar `$flujo-prove` formalmente antes de aprobar commit productivo conforme al proceso de desarrollo, sin convertir CI en revisión humana. Registrar bitácora y handoff. En caso de timeout o falla repetir como máximo conforme a Skill y no improvisar executor.
6. **Independencia:** no crear fixtures que carguen scripts `Editor*` dentro del runtime o sean dependientes del dispositivo de un desarrollador.

## 3. Matriz de escenarios redactados con oráculo observable

| ID | Entrada y estado previo | Oráculo RED → GREEN (una vez aprobada la API) | Invariantes que nunca deben romperse |
|---|---|---|---|
| **OBS-B01** | Captura OFF, dos FSM con MANUAL/PHYSICS, eventos/directos intercalados | API de consulta devuelve historial vacío o código de disabled según contrato; ejecución conserva el mismo orden/resultado que baseline y no crea eventos DEBUG | `request_rejected`, `event_consumed`, Enter/Exit/Commit sin reordenar |
| **OBS-B02** | Captura ON; emitir **N+K** registros con tamaño variable, donde N es la capacidad aprobada | Consulta devuelve sólo los últimos N, secuencia monotónica, gap/overwrite distinguible, límites de bytes/registro respetados | La cola de 256 requests y work budget 32 son independientes del rastro |
| **OBS-B03** | Controladores A/B con el mismo recurso y varias máquinas; intercalar tick y evento | Historiales, epoch, `machine_id`, contador y runtime de A/B separados; lectura en A nunca contiene B | Grafo authored inmutable; no singletons de depuración |
| **OBS-B04** | Payload profundo, `Node`, `Resource`, nombre excesivo, UTF-8 multibyte, strings con control | Ninguna referencia viva ni payload expuesto; aplicar filtrado/truncamiento determinista conforme a G5; mutar el resultado consultado no cambia lecturas posteriores | No I/O, telemetría, fuga de datos, reserialización de objetos |
| **OBS-B05** | Condiciones false/true/self, error tipado y orden authored/prioridad; instrumentar contador de `resolve()` existente si test lo permite | DEBUG explica sólo resultados **realmente evaluados**, con una única evaluación por candidato; ganador y señales iguales a FSM-5B/10A-4 | No evaluación extra, prioridad y FIFO no alterados |
| **OBS-B06** | Iniciar runtime sin observador y conectar después de Enter y transición | Snapshot muestra **estado vigente** y marcador de historial no disponible; registros nuevos posteriores en orden; no fabricar eventos de inicio | Misma identidad runtime, sin replay ficticio |
| **OBS-B07** | Stop durante Update/Exit, reset tras callback, destrucción de A con B vivo | No doble Exit/Stopped ni registros post-teardown; las lecturas invalidadas fallan de manera definida; B sigue ejecutando | Respeta shutdown/reentrancia y `FlowGraph` |
| **OBS-B08** | Esquemas 3 y 4, Ready/Timer, múltiples FSM, Fluo y export de plugin | Suite histórica completa, sin dependencias `Editor*` en runtime | Sin cambio de persistencia/snapshot v1 |
| **OBS-B09** | 0, 1 y muchas máquinas, captura ON/OFF; superar N en ejecución prolongada | Registrar latencias, asignaciones/memoria y crecimiento de rastro con protocolo definido; no afirmar presupuesto cumplido sin medición | Misma secuencia de transiciones; sin comparación fabricada de FPS |
| **OBS-B10** | Snapshot persistente y restore entre procesos, corruptos/backup como fixtures existentes | El historial no aparece en snapshot ni altera preflight/rollback; se conserva la política F9/F10 vigente | No autocarga `.bak`, ni nuevas rutas de escritura |
| **OBS-UI11** | Editar escena durante sesión del editor y desconectar/reconectar debugger | Panel read-only, identificación por sesión+controlador+máquina, sin pérdida de foco ni Undo/Redo/Fluo | Dependencia de editor fuera del runtime |
| **OBS-CTRL12** | Pausa/step durante cola, PHYSICS, Timer y callbacks | **No desarrollar** hasta aprobación separada G8; especificar primero política de relojes y reentrancia | No confundir SceneTree.paused con FSM pausada |

## 4. Desglose de futuros minibloques 10B (NO autorizados)

| Minibloque candidato | Artefacto esperado | Primer criterio de verificación |
|---|---|---|
| **10B-0A** | Acta aprobada G1..G6, contrato v1.0 | Decisiones públicas, sin ambigüedad, SHA base |
| **10B-1A** | Test focal RED para captura OFF + ring N | Fallo esperado documentado, sin gate obligatorio roto |
| **10B-1B** | Activación OFF y buffer mínimo por `FlowFSMRuntime` | OBS-B01/B02 GREEN, sin referencias authored mutables |
| **10B-1C** | Aislamiento y snapshots de lectura | OBS-B03/B04/B06 GREEN |
| **10B-1D** | Captura en admisión y arbitraje sin doble evaluación | OBS-B05 GREEN, callbacks legacy intactos |
| **10B-1E** | Teardown, saturación y compatibilidad | OBS-B07/08/10 GREEN; benchmark OBS-B09 |
| **10B-2A** | Diseño/aprobación G7 para adaptador Godot | Contrato de protocolo por sesión y prueba de ambiente 4.7.2 |
| **10B-2B** | Tab de debugger sólo lectura | OBS-UI11 y revisión visual Fedora |
| **10B-3A** | Diseño/aprobación G8 separado | Ningún código de pausa/step sin decisión nueva |

**Separación de commits:** cada implementación tendrá un test y evidencia focal coherentes; un cambio de comportamiento público se versiona según `docs/development_workflow.md`, sin introducirlo como 'refactor conservador'. No cargar un RED esperado como gate permanente; tampoco clasificar un error del editor o del executor como un resultado esperado de la funcionalidad.

## 5. Formato de evidencia a llenar después de autorizar

```text
Test ID:
Contrato aprobado (URL/SHA):
Rama / HEAD before / HEAD after:
Prueba focal + método de ejecución:
Resultado RED real / código de salida:
Implementación GREEN / commit:
CI focal + completo / URL / conclusion:
Catálogo ID + baseline_status:
Skills baseline/prove: READY|BLOCKED / PASA|NO PASA + logs:
Revisión humana / plataforma:
Riesgos, gaps y rollback:
```

**Estado actual de toda la matriz:** pruebas futuras **NOT RUN**; scripts de estas APIs **NO IMPLEMENTADOS**; benchmark **NOT MEASURED**; **no se añadió ningún nuevo test al workflow ni `docs/behavior_catalog.json`**. Por ahora los tests 10A-3/4/5 siguen siendo sólo caracterizaciones del comportamiento previo.

*Todo es Flujo; todo fluye.* 🌊
