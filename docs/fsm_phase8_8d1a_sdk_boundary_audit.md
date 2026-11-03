# Potok 8D1-A — Auditoría del límite SDK/runtime y contrato para capacidad FSM

**Fecha:** 2026-11-02. **Rama:** `feature/fsm-runtime-flow-flusso`. **Baseline:** `d0b20b38cb487987ad94492e4c60ab0fe7321642`, con CI funcional 8C2 [41550131409](https://github.com/mercurysama/Flujo/actions/runs/41550131409) **SUCCESS 80/80**. **Tipo:** revisión de rutas reales y diseño de un contrato mínimo; **no se afirma implementación** de un servicio nuevo.

## Inspección de ejecución y brecha verificada

1. `FlowFSMRuntime._execute_phase` utiliza un `FlowBlockContainer` transitorio y llama al ejecutor compartido `FlowReadyExecutor._execute_blocks`, con `entry_point` `StateEnter`/`StateUpdate`/`StateExit` y `entry_id` igual al ID de máquina. El camino existe para bloques oficiales y paquetes externos sin ejecutores paralelos.
2. `FlowReadyExecutor._execute_blocks` crea `FlowNavigationContext.new(controller, graph, container, block_id, entry_point, resolution_context)` y llama a `block.get_navigation_decision(context)` para bloques integrados o externos. **El ID de máquina de `entry_id` no se incorpora al contexto de navegación.**
3. `FlowNavigationContext` hace públicas las referencias `controller`, `graph`, `container`, `current_block_id`, `entry_point` y `value_resolution_context`. `FlowValueResolutionContext` también ofrece `graph` y `controller`. `PVController.get_fsm_runtime()` es público. Por tanto, **existe un camino técnico para acceder al runtime, pero no una capacidad acotada por máquina**; tampoco se puede afirmar que el grafo sea inaccesible para un script de paquete. No presentar el SDK actual como un sandbox.
4. `FlowFSMRuntime` ya implementa `register_state`, `has_state`, `change_state`, `remove_state` y accesores de datos; han pasado 8B1, 8B2, 8C1 y 8C2. Implementar otra registry sería duplicación y supondría una fuente adicional de verdad.
5. `docs/manual_block_sdk_contract.md` permite un `FlowBlock` externo sin una clase `class_name` global; la fixture `manual_output:output` es solo salida de texto, no prueba autorización FSM. No convertir esta fixture en un bloque que muta estados para satisfacer 8D1.

## Contrato propuesto para 8D1-B (requiere prueba antes de certificar)

- **Capacidad por invocación:** durante cada fase FSM, el ejecutor puede suministrar una fachada de operaciones a un bloque ejecutado. El contexto debe identificar la instancia de `PVController`, el `FlowFSMRuntime` vigente y **el ID de la máquina dueña de esa fase**, sin entregar la colección de estados dinámica ni el `FlowGraph` como parte de la fachada.
- **API mínima prevista:** `register_state(template_state_id, runtime_id, lifetime, data)`, `has_state(state_id)`, `change_state(state_id)`, `remove_state(state_id, fallback_id)`, `get_state_data(state_id)`, `set_state_data(state_id, data)`. La fachada fija el `machine_id` internamente y delega en la API existente con sus validaciones. Los nombres definitivos se estabilizan con el test de contrato.
- **No escalada accidental:** no permitir seleccionar otra máquina mediante los argumentos de la fachada. La habilitación solo existe para una invocación real `StateEnter`/`StateUpdate`/`StateExit`; Ready, Timer, Constructor y métodos no heredan permisos FSM por accidente.
- **Vigencia:** si la instancia se detiene, cambia el grafo o el contexto queda obsoleto, las operaciones deben rechazar sin mutar. **Rechazar uso tardío** de una referencia guardada fuera del callback, y distinguir consultas de operaciones mutadoras. Si en la implementación es necesario proteger también contextos obsoletos dentro de una transición anidada, usar un token/época de ejecución que se invalide tras cada callback.
- **No seguridad fuerte de scripts hostiles:** scripts GDScript del proyecto siguen teniendo acceso a clases Godot, al controlador y al grafo mediante otras interfaces. Una fachada funcional no constituye aislamiento criptográfico o sandbox; un rediseño de todo el SDK para retirar accesos directos sería un contrato separado, con compatibilidad y migración.
- **No alteración de modelos:** los estados se agregan y retiran **solo en la registry por instancia**. No añadir archivos al `FlowGraph`, no alterar schema v3/v4, no modificar snapshots existentes ni el contrato Flusso.
- **Compatibilidad:** preservar `get_navigation_decision`, el ejecutor genérico, salida de texto, métodos y salto de navegación, y la API pública FSM actual. Los bloques sin necesidad de Potok deben funcionar exactamente igual.

## Descomposición recuperable

| Microbloque | Acción | Gate |
| --- | --- | --- |
| **8D1-A (actual)** | Auditar el camino completo y congelar contrato de capacidad mínima | Documento versionado; cero cambios productivos |
| **8D1-B1** | Test de integración que prueba el acceso de un bloque externo/official en fase FSM, el ID correcto y rechazo desde Ready/Timer; caracterizar estado previo | RED previsto para una capacidad que aún no existe; no desactivar el test |
| **8D1-B2** | Implementar fachada mínima por contexto/instancia y su paso por ejecutor compartido, con control de época si el test lo exige | GREEN focal + regresiones previas; sin acceso mutable al grafo a través de la fachada |
| **8D1-C** | Prueba de obsolescencia de contexto, aislamiento entre controladores y operación real add→change→remove desde bloque externo | GREEN transversal, compatibilidad SDK y runtime; no crear nueva registry |

**Próximo paso:** **8D1-B1** caracterización de la API pública futura y de su conectividad con fases. Antes de codificar producción, leer `AGENTS.md`, `docs/development_workflow.md`, `docs/behavior_catalog.json` y los checklists `$flujo-baseline`/`$flujo-prove`; no declarar dichos procedimientos ejecutados por leer solamente sus archivos. Las 25 pruebas físicas de fase 7 permanecen diferidas. `main` intacta.

*Todo es Flujo; todo fluye.* 🌊
