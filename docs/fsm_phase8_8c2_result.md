# Potok 8C2 — Purga selectiva de solicitudes pendientes y aislamiento entre máquinas

**Fecha:** 2026-11-02. **Rama:** `feature/fsm-runtime-flow-flusso`. **Baseline:** `bfbbb020029f7a7094f729a6484669395b997d28`. **Alcance:** validar la integridad de las colas tras retirar un alias dinámico inactivo. La fase 7 mantiene 25 pruebas manuales diferidas.

## Artefactos

- `35b573c935f8983ba9b4c1d8076a2bccc7d3a0fb` — `tests/runtime/flow_fsm_dynamic_pending_multimachine_test.gd`.
- `03df48438487328bfbe84295c73efabcd6587408` — `tests/runtime/flow_fsm_dynamic_pending_multimachine_test.tscn`.
- `2604a3a252dfff256dd4735b9bbeb26408e942fd` — paso `Potok-8C2 selective pending requests and multi-machine focal` en workflow de GitHub Actions.
- [CI 41550131409](https://github.com/mercurysama/Flujo/actions/runs/41550131409): focal 8C2 SUCCESS; la conclusión de toda la suite debe verificarse por separado.

## Escenario y resultados

Con dos máquinas de estados en un mismo `FlowGraph` y dos `PVController` independientes, la prueba prepara una cola de cinco peticiones mezcladas: dos `direct` hacia un alias de la máquina A, dos eventos no relacionados (uno por máquina) y una transición `direct` válida de la máquina B. Al borrar el alias **inactivo**, la cola pasa de cinco a tres entradas: desaparecen exclusivamente las dos peticiones `direct` dirigidas al alias eliminado.

Se verifica que `change_state` ya no acepta el destino eliminado, y que volver a registrar el mismo ID **no resucita** las peticiones anteriores. Tras un tick manual, ambos eventos son consumidos, la máquina A permanece en su estado original y solo la transición válida de B confirma el cambio. El segundo controlador no recibe alias ni solicitudes; los arrays authored y el grafo permanecen intactos.

## Alcance y siguientes bloques

El test caracteriza la ruta de borrado de alias **inactivos**, el caso con peticiones directas y eventos mezclados, y la independencia entre máquinas/controladores. Las referencias authored de transiciones a estados dinámicos siguen fuera de este contrato, pues no debe mutarse el `FlowGraph` en runtime. No se cambió código productivo, snapshots ni esquema.

**Siguiente:** **8D1**, auditoría del acceso seguro a las operaciones dinámicas mediante servicios de contexto para bloques oficiales y SDK; verificar API real y autoridad del controlador antes de exponer operaciones. Después **8D2** aislamiento y políticas de vida, y **8E** cierre técnico FSM-003. No se autoriza merge ni release; `main` intacta.

*Todo es Flujo; todo fluye.* 🌊
