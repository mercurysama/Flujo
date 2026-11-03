# Potok 9B3-C1 — Evaluación de prueba aislada de fallos F5–F7

**Fecha:** 2026-11-03 (America/Mexico_City). **Rama:** `feature/fsm-runtime-flow-flusso`. **Baseline:** checkpoint 9B3-B3 [Actions 41674464784](https://github.com/mercurysama/Flujo/actions/runs/41674464784) **completed SUCCESS**; focal F3 [41670135010](https://github.com/mercurysama/Flujo/actions/runs/41670135010) **SUCCESS**. **Tipo de cambio:** documentación de diseño; no se ejecutan pruebas adicionales.

## Análisis del flujo existente

En `addons/vp_flujo/runtime/flow_fsm_runtime.gd`, `save_to_file` verifica escritura de `.tmp`, borra un `.bak` anterior antes de copiar el destino sobre `.bak`, luego intenta `rename_absolute(tmp,destino)`. Si falla y había destino, elimina el destino previo para un segundo intento; si falla, intenta recuperarlo copiando backup. Esta secuencia genera **riesgos observables en código**, no defectos reproducidos. El contrato [FLU-FSM-004](fsm_snapshot_contract_v1.md) exige temporal verificado, backup y ruta de recuperación, pero no especifica tolerancia eléctrica ni recuperación automática.

## Alternativas examinadas

| Alternativa | Ventajas | Riesgos y decisión |
| --- | --- | --- |
| Permisos de directorio / chmod | Potencialmente induce fallo de I/O real | No portable a Android, runner puede tener permisos especiales; **no usar como prueba contractual** |
| Colocar archivos/direcciones centinela en los nombres destino, .bak o .tmp | No modifica runtime y usa `user://` aislado | Puede inducir error diferente del punto F5–F7 pretendido; se requiere verificar tramo alcanzado y asegurar limpieza; **solo aceptar como prueba de una rama específica, nunca equivalente a inyección controlada** |
| Hacer fallar `DirAccess.copy_absolute` o `rename_absolute` reemplazando primitivas globales | Teóricamente permite probar cada punto | Interfiere con el motor/producción, no hay seam existente; **rechazar** |
| Separar coordinación de operaciones de archivo en helper testable con backend inyectable | Permite fallos deterministas en copy/rename con registros exactos y sin efectos reales | Refactor de código productivo y diseño API, requiere `$flujo-baseline` / `$flujo-prove` formales, revisión de invariantes y aprobación; **no autorizado en C1** |
| Algoritmo alternativo de respaldo staged y renombrado | Puede reducir ventana de pérdida | Cambia semántica y orden de publicación; requiere contrato/benchmark/prueba de compatibilidad; **no implementar sin autorización explícita** |

## Semántica exacta que conviene caracterizar

- **F5:** con A como destino y B como `.bak`, fallo al copiar A a backup después de eliminar B. Observar separadamente preservación de A, B y temporal, retorno y ausencia de cambios de FSM. No confundir «copia fallida» con «eliminación previa de backup fallida»: el código actualmente no comprueba el resultado de eliminación del backup.
- **F6:** falla primer rename de `.tmp` sobre destino existente. El resultado de la segunda ruta depende de plataforma; probar si el destino A sigue disponible hasta sustitución verificada y si backup representa A.
- **F7:** falla segundo rename tras eliminar destino A. El fallback intenta copiar backup al destino. Medir si los bytes restaurados coinciden con A, si se conserva `.bak` y el retorno es `false`. Si también falla la restauración, considerar esto **RED real** sin ocultar sus efectos.
- **Limitación:** pruebas sintéticas del coordinador no prueban `fsync`, power loss, ni atomicidad del kernel. Para cobertura real harían falta pruebas separadas por plataforma.

## Recomendación de diseño acotado

**Primero una prueba de límites no destructiva**, fuera de `FlowFSMRuntime` y usando una carpeta dedicada `user://flujo_fsm_tests/phase9_9b3_faults/`; no tocar `main` ni archivos ajenos. Una prueba que fuerce un fallo *antes* de la sustitución puede caracterizar únicamente su rama, pero no demostrar F6/F7. Para cubrir F5–F7 plenamente, requerir aprobación de un **helper de operaciones de archivo con interfaz mínima** separado de la lógica de snapshots. El runtime usaría un backend real y el test un backend simulado exclusivamente en prueba; no exponer flags de fault injection en API pública ni introducir scripts de editor.

**Decisión de C1:** no alterar runtime ni montar un test que simule garantizar F5–F7 sin ejecutar realmente esas ramas. Elevar a C2 una especificación de matriz determinista, criterios de aprobación y ruta de implementación. C1 se cierra como **auditoría de diseño**, no como verificación de fallos.

**Gobernanza:** contrato v1 y datos PERSISTENT, orden de callbacks y rechazo in-tick siguen intactos. El catálogo existente no se modifica; no corresponde `passing` nuevo. 25 pruebas manuales pendientes. No Godot local, sin Skills formales. Métricas de falla de copy/rename y consumo temporal: **no medidos**.

*Todo es Flujo; todo fluye.* 🌊
