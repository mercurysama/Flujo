# Potok 7E-4B — Registro consolidado de evidencias humanas

**Fecha de creación:** 2026-11-02. **Fuente de pasos reproducibles:** [guía 7E-4A](fsm_phase7_7e4a_manual_review.md). **Auditoría técnica:** [7E-4B](fsm_phase7_7e4b_gap_audit.md). **SHA guía:** `cbd68a56c762d1f11a51e62f99b436fc53e91ec9` · [CI 41406599140](https://github.com/mercurysama/Flujo/actions/runs/41406599140) 59/59.

**REGISTRO VACÍO: 0 PASS, 0 FAIL observados, 0 BLOCKED observados, 25 PENDING.** Ningún archivo visual ni informe de dispositivo actual se aportó durante 7E-4B. `BLOCKED técnico previsto` en auditoría de código **no cambia** el resultado humano PENDING: solo una ejecución presencial puede establecer lo observado.

| ID | Plataforma | Requisitos F7 | ¿Gate? | Estado manual | Evidencia | Incidencia |
|---|---|---|---|---|---|---|
| F01 | Fedora | 1/7 | No | **PENDING** | — | — |
| F02 | Fedora | 2 | No | **PENDING** | — | — |
| F03 | Fedora | 2/3/5 | Sí | **PENDING** | — | — |
| F04 | Fedora | 2/3/5 | Sí | **PENDING** | — | — |
| F05 | Fedora | 3/7 | No | **PENDING** | — | — |
| F06 | Fedora | 4 | No | **PENDING** | — | — |
| F07 | Fedora | 4/7 | No | **PENDING** | — | — |
| F08 | Fedora | 7 | No | **PENDING** | — | — |
| F09 | Fedora | 5/7 | No | **PENDING** | — | — |
| F10 | Fedora | 5/6 | No | **PENDING** | — | — |
| F11 | Fedora | 8 | No | **PENDING** | — | — |
| F12 | Fedora | 7/8 | No | **PENDING** | — | — |
| F13 | Fedora | 1/3 | No | **PENDING** | — | — |
| F14 | Fedora | 9 | Sí | **PENDING** | — | — |
| F15 | Fedora | 2/5/9 | Sí | **PENDING** | — | — |
| A01 | Android | 8 | No | **PENDING** | — | — |
| A02 | Android | 1/7/8 | No | **PENDING** | — | — |
| A03 | Android | 8 | No | **PENDING** | — | — |
| A04 | Android | 8 | No | **PENDING** | — | — |
| A05 | Android | 3/7/8 | No | **PENDING** | — | — |
| A06 | Android | 4/6/8 | No | **PENDING** | — | — |
| A07 | Android | 3/5/7/8 | No | **PENDING** | — | — |
| A08 | Android | 7/8 | No | **PENDING** | — | — |
| A09 | Android | 8/9 | No | **PENDING** | — | — |
| A10 | Android | 2/3/5/8 | Sí | **PENDING** | — | — |

## Recepción y evaluación

1. Registrar el **SHA del binario/proyecto probado** (debe corresponder a un commit verificable), versión completa Godot, SO, pantalla/orientación, fecha y zona, ejecutante y ruta o URL de captura/vídeo. Una imagen anterior no prueba el nuevo SHA.
2. Usar la ficha individual de `docs/fsm_phase7_7e4a_manual_review.md`. Un mismo ID puede tener varias corridas documentadas: nunca sobrescribir un FAIL anterior sin conservar la reproducción, evidencia y SHA. Mantener la última decisión con historial.
3. Estados manuales permitidos: `PENDING`, `PASS`, `FAIL`, `BLOCKED`, `N/A` (solo con motivo aprobado). Si hay un fallo/ausencia técnica, abrir incidencia con pasos y vínculo al gate; no convertir automáticamente resultados de código o CI en PASS.
4. `F03` y `A10` tienen una **brecha confirmada en fuente**: Potok no expone Add de bloques Enter/Update/Exit. Si se ejecutan ahora, documentar lo visible sin fabricar el control; las filas permanecen PENDING hasta que una persona efectivamente las ejecute. El cierre integral de fase 7 requiere resolver 7F y repetir esos casos.
5. La tabla es un **registro de llegada**, no un calendario ni una declaración de resultados. El mantenedor realiza aceptación explícita por gate y revisión completa, con evidencia de Fedora y Android independientes.

## Estado verificable al preparar este registro

- **Automatizado:** CI del checkpoint 7E-4A `cbd68a56...` [41406599140](https://github.com/mercurysama/Flujo/actions/runs/41406599140) **SUCCESS, 59/59**. CI del contrato 7E-4B [41407321246](https://github.com/mercurysama/Flujo/actions/runs/41407321246) **SUCCESS, 59/59**. Estos resultados **no** actualizan las 25 filas.
- **Android:** carga/render de Fluo Preview 1 del 2026-10-27 es evidencia de otro alcance, no de este registro.
- **Brecha de software:** falta autoría visual de bloques de fase, separada de las acciones ya disponibles para crear estados/transiciones. Próximo microbloque 7F-1A.
- **Límite:** revisión UI real y Fedora Git worktree local no accesibles mediante el conector GitHub. No se afirma aprobación final, release ni pase formal de Skills.

Todo es Flujo; todo fluye. 🌊
