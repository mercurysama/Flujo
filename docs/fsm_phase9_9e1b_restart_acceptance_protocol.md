# Potok 9E1-B — Protocolo de aceptación pendiente: reinicio real y errores de respaldo

**Fecha:** 2026-11-03. **Rama:** `feature/fsm-runtime-flow-flusso`. **Base:** [dictamen 9E1-A](fsm_phase9_9e1a_conditional_verdict.md). **Estado:** plan de verificación documentado, **NO RUN**; sin scripts ni cambios del runtime. La siguiente implementación deberá mantenerse en microbloques independientes.

## R1 — Reinicio real de proceso (requisito del plan fase 9)

**Objetivo:** demostrar que el archivo de `user://` sobrevive a terminar Godot y que una nueva ejecución **lo restaura mediante una llamada explícita**. Es diferente de [9C2-A](fsm_phase9_9c2a_instance_reconstruction_result.md), que destruye y recrea un PVController dentro del mismo proceso.

**Especificación de prueba futura en CI, separable en R1-A/B/C:**
1. Preparar una **fixture authored determinista** (misma definición `FlowGraph` e IDs estables en ambas ejecuciones); no regenerar IDs de `FlowStateMachineDefinition` o `FlowStateDefinition` entre arranque y reinicio. La fixture puede guardarse como recurso de prueba `res://tests/fixtures/...` o cargarse desde una escena estática inspeccionada. No alterar el formato v1 ni serializar nodos ejecutables como snapshot.
2. **Proceso A**: lanzar Godot 4.7.2 headless en un directorio `user://` de pruebas aislado; arrancar una FSM con alias PERSISTENT y datos no triviales; guardar snapshot `format_version=1` en ruta de test exclusiva; verificar el contenido JSON, identidad de grafo, alias y datos; salir con código 0. Un guardado de recurso del motor no sustituye al snapshot de usuario.
3. **Proceso B**: lanzar *otro proceso* Godot contra el mismo proyecto y carpeta `user://`, sin limpiar los archivos creados por el proceso A. Comprobar que no existe autoload y que SESSION/EPHEMERAL no vuelven; llamar `restore_from_file` explícitamente. Confirmar misma identidad PERSISTENT, payload y snapshot portable. Rechazar cualquier intento de migrar IDs o usar equivalencia por nombres.
4. **Aislamiento y limpieza**: usar entorno de runner/datos dedicado, ruta `user://flujo_fsm_tests/phase9_restart/` que no colisione con archivos existentes, garantizar cleanup aunque B falle en la acción de CI. No borrar `user://` ajeno ni manipular repositorios/dispositivos personales.
5. **Criterio de PASS:** dos invocaciones diferenciadas en log, ambos exit=0, prueba A produce S1 válido y B lo recupera solo al invocar restore; prueba B prueba sesión transitoria ausente. Registrar nueva entrada en catálogo `not_run` y gate CI **obligatorio** antes de ejecutar; actualizar a `passing` solo después de SUCCESS integral, separando prueba y cierre.

**Riesgo técnico que debe atender R1-A:** algunos proyectos Godot configuran su ruta `user://` según nombre de proyecto o `application/config/use_custom_user_dir`; comprobar la ruta efectiva en el runner y aislar directorio temporal real antes de implementar. Ningún resultado previo demuestra este caso.

## R2 — Fallos exactos de reemplazo y backup (F5–F7)

- [Matriz 9B3-C2](fsm_phase9_9b3c2_failure_matrix_and_gate.md) describe C-F5/C-F6/C-F7/C-F7R. **No hay focal que los haya inducido**. Conservar el registro en `NO RUN`.
- Para pasar a implementación se necesita **aprobación explícita** de política F5/F7 y destino corrupto F9; las reglas deseadas de conservar último backup validado no son garantía actual.
- Si se autoriza un seam de I/O, formalizar su contrato, baseline/prove del proyecto, construir focal RED controlada, implementar mínima corrección por commits separados y comprobar suite integral y resultado de archivo real. No agregar flags públicos de falla ni debilitar pruebas que ya aprobaron.
- Si la aprobación no llega, se puede continuar con R1 sin bloquearse: no etiquetar F5–F7 como `passing` ni cerrar fase 9 incondicionalmente.

## R3 — Revisión humana y plataforma

Se aplazan exactamente **25 verificaciones** (15 Fedora, 10 Android). Una prueba Godot headless Linux no equivale a aceptación de UI/almacenamiento Android; cuando el mantenedor retome pruebas, registrar versión de Godot, dispositivo, flujo de recuperación, resultados de filesystem y fallos. Hasta entonces: **0/25**, sin inventar PASS.

## Minihoja de ruta

- **9E1-C:** checkpoint documental y traspaso, después de comprobar estado de Actions de A y B.
- **9R1-A:** fixture de IDs estables y prueba split-process **sin cambio al runtime**, con behavior `not_run` y gate obligatorio.
- **9R1-B:** investigar CI, preservar evidencia, reparar test-only solo con diagnóstico; marcar passing únicamente después de éxito integral.
- **9R2:** ruta F5–F7 **condicionada** a autorización específica; no deducirla de autorización general de continuar.
- **Fase 10:** no abrir ni declarar integrada sin revisar dependencias y decisión humana; la fase 9 conserva sus pendientes.

**Métricas:** CI final de la última implementación [41711670098](https://github.com/mercurysama/Flujo/actions/runs/41711670098) **SUCCESS 109/109**; R1 invocaciones de dos procesos **0**, F5–F7 pruebas **0**, manuales **0/25**. Disponibilidad/durabilidad ante apagado: no medida.

*Todo es Flujo; todo fluye.* 🌊
