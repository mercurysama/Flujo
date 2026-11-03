## Potok 10A — tanda 1, observabilidad sin cambio productivo (2026-11-03)

- **10A-1**: [auditoría de señales y brechas](fsm_phase10_10a1_diagnostics_audit.md), commit `a3d56ae874da2ee1a9b94d9922191b40bfcda238`. Reutilizar señales actuales antes de agregar historial.
- **10A-2**: [contrato DEBUG-FSM v0](fsm_observability_contract_proposal_v0.md), commit `2dcfca0dc7eb8d114c9ba41fe1659cbf860b865a`. **Propuesta**, no aprobación de API, cuota ni mutaciones en runtime.
- **10A-3**: caracterización de señales en dos controladores, fixture `tests/runtime/flow_fsm_observability_existing_signals_test.tscn`, commit `15da55c216e62afbd8aeb2c2ded40e1107983a39`; comportamiento `FLUJO-BHV-POTOK-OBSERVABILITY-EXISTING-001` **passing** tras [Actions 41734104878](https://github.com/mercurysama/Flujo/actions/runs/41734104878) **completed SUCCESS**, focal obligatoria PASS y suite integral PASS.
- **Tres workflows:** [41733666657](https://github.com/mercurysama/Flujo/actions/runs/41733666657) SUCCESS, [41733785823](https://github.com/mercurysama/Flujo/actions/runs/41733785823) SUCCESS y [41734104878](https://github.com/mercurysama/Flujo/actions/runs/41734104878) SUCCESS. Git whitespace gate, validador, editor/model, Ready y demás pasos obligatorios de los tres runs aprobados. Los procedimientos locales versionados `$flujo-baseline` y `$flujo-prove` fueron **consultados**, no ejecutados formalmente; Godot local **NOT RUN**, pruebas humanas 0/25.
- **Siguiente tanda independiente:** 10A-4 caracterización de condiciones false / no-op con señales presentes; 10A-5 caracterización de ciclo de vida y reloj entre controladores; 10A-6 presupuesto/retención de trazas como diseño y test plan. **10B productivo está bloqueado por decisiones arquitectónicas** enumeradas en 10A-2. Fase 9 continúa condicionada (F5–F7/F7R, F9, F10 sin recovery automático); `main` sin cambios.

## Potok 9R1-A — split process snapshot persistence focal registered (2026-11-03)

- [9R1-A](fsm_phase9_9r1a_two_process_restart_result.md): separate Godot writer/reader scenes with test-only stable graph IDs and shared isolated `XDG_DATA_HOME`, verifying PERSISTENT explicit restore and SESSION/EPHEMERAL omission across a real process boundary. Behavior `FLUJO-BHV-POTOK-SNAPSHOT-TWO-PROCESS-020` **not_run** until full CI. [9E1-C Actions 41718438282](https://github.com/mercurysama/Flujo/actions/runs/41718438282) **SUCCESS**.
- Next **9R1-B** verify both separate processes and full CI, close only on success; unresolved F5–F7 and 25 manual checks remain. No runtime/schema/codec/main changes.

## Potok 9E1-A/B/C — conditional verdict, two-process acceptance plan, recoverable checkpoint (2026-11-03)

- [9E1-A conditional verdict](fsm_phase9_9e1a_conditional_verdict.md) **technical conditional only**; [9E1-B restart protocol](fsm_phase9_9e1b_restart_acceptance_protocol.md) defines **two separate Godot processes** and stable authored IDs as missing verification. [9E1-C handoff](fsm_phase9_9e1c_conditional_handoff.md) records next microsteps. Historical [41712607299](https://github.com/mercurysama/Flujo/actions/runs/41712607299) **SUCCESS** for 9D2 checkpoint; 9E1 commit CIs have separate statuses.
- Snapshot behaviors 012–019: **8/8 passing** with mandatory CI, last implementation suite **109/109 SUCCESS**. Phase 9 **not unconditionally closed**: two-process game restart **NO RUN**, F5–F7 faults **NO RUN**, F9 approval open, human tests **0/25** deferred. No production/codec/schema change or main merge.
- **Next 9R1-A** build stable graph fixture and split-process snapshot test in isolated user:// with `not_run` and mandatory gate, then **9R1-B** verify full CI. **9R2** fault behavior only after explicit maintainer policy authorization. No automatic move to phase 10.

## Potok 9D2-A — phase 9 coverage/risk audit; next 9E1-A conditional acceptance (2026-11-03)

- [9D2-A audit](fsm_phase9_9d2a_coverage_risk_audit.md): all 8 new snapshot behaviors 012–019 catalogued **passing**, each with a mandatory focal in `.github/workflows/flujo-fsm.yml`; [Actions 41711670098](https://github.com/mercurysama/Flujo/actions/runs/41711670098) completed **SUCCESS 109/109**. [9D1-B closeout](fsm_phase9_9d1b_compatibility_closeout.md) records compatibility passing. These automatic results cover S1/S2 backup on success, safe paths, F3 preflight, invalid files, explicit new controller restore, callbacks/reentrancy and v1 strict rejection.
- **Not closed:** F5–F7 copy/rename/recovery exact fault branches, corrupt previous file policy F9, rebooted game process proof, and 25 deferred human checks (15 Fedora, 10 Android); no silent `.bak` auto-recovery. Runtime/codec/format/graph unchanged; no main merge. **Next 9E1-A:** conditional technical assessment, not release; approval for filesystem failure semantics still required.

## Potok 9D1-B — strict v1 compatibility CI PASS; next 9D2-A (2026-11-03)

- [9D1-B closeout](fsm_phase9_9d1b_compatibility_closeout.md): [Actions 41711670098](https://github.com/mercurysama/Flujo/actions/runs/41711670098) completed **SUCCESS 109/109**, mandatory 9D1-A focal PASS. Catalog `FLUJO-BHV-POTOK-SNAPSHOT-COMPATIBILITY-019` updated **not_run → passing** after complete evidence.
- **Next 9D2-A** audit all phase 9 automatic coverage, exact F5–F7 fault gaps and unapproved recovery policy. Phase9 and manual 25 NOT closed; no production change.

## Potok 9D1-A — snapshot strict compatibility matrix focal registered (2026-11-03)

- [9D1-A](fsm_phase9_9d1a_compatibility_matrix_result.md) adds a mandatory `flow_fsm_snapshot_compatibility_matrix_test.tscn` for old/future format, mismatched schema/graph/machine, invalid active/template ID and machine collection. All reject without modifying persistent alias/data or pending request; exact v1 file must restore. Behavior `FLUJO-BHV-POTOK-SNAPSHOT-COMPATIBILITY-019` **not_run** until complete CI. No migration or runtime edits.
- [9C3-D](fsm_phase9_9c3d_disk_reentrant_closeout.md) CI [41706512868](https://github.com/mercurysama/Flujo/actions/runs/41706512868) **SUCCESS 108/108**, reentrancy catalog marked passing. Next **9D1-B** check new CI, then 9D2. F5–F7 unresolved; 25 manual tests deferred.

## Potok 9C3-D — reentrant disk restore CI PASS; next 9D1-A (2026-11-03)

- [9C3-D closeout](fsm_phase9_9c3d_disk_reentrant_closeout.md) confirms [Actions 41706512868](https://github.com/mercurysama/Flujo/actions/runs/41706512868) **SUCCESS 108/108**, mandatory disk restore in-tick focal PASS. Catalog `FLUJO-BHV-POTOK-SNAPSHOT-DISK-REENTRANCY-018` advanced `not_run → passing`. No runtime code changes.
- **Next 9D1-A** contract v1 compatibility rejection matrix for format/schema/graph IDs and machine identity; no silent migration. F5-F7 remain unverified, 25 manual checks deferred.

## Potok 9C3-C — disk restore in-tick reentrancy focal added (2026-11-03)

- [9C3-C](fsm_phase9_9c3c_disk_restore_reentrant_result.md) adds mandatory `flow_fsm_snapshot_disk_restore_reentrant_test.tscn`, behavior `FLUJO-BHV-POTOK-SNAPSHOT-DISK-REENTRANCY-018` **not_run** awaiting CI, testing file restore attempts from StateUpdate/commit, nested-tick rejection, deferred owner event, sibling isolation and outside-tick successful restore. 9C3-B [Actions 41681389535](https://github.com/mercurysama/Flujo/actions/runs/41681389535) **SUCCESS 107/107**; behavior 017 updated passing.
- **Next 9C3-D:** verify full CI and close or investigate RED. Then 9D1. No runtime changes; 25 manual checks deferred.

## Potok 9C3-B — disk callback focal PASS; next 9C3-C (2026-11-03)

- [9C3-B closure](fsm_phase9_9c3b_disk_restore_callbacks_closeout.md), [Actions 41681389535](https://github.com/mercurysama/Flujo/actions/runs/41681389535) **SUCCESS 107/107**, behavior `FLUJO-BHV-POTOK-SNAPSHOT-DISK-CALLBACKS-017` now **passing**. Next 9C3-C focus on file restore in-tick reentrancy without runtime changes. F5–F7 unverified; manual 25 deferred.

## Potok 9C3-A — file restore callbacks and owner/peer queues focal (2026-11-03)

- [9C3-A](fsm_phase9_9c3a_disk_restore_callbacks_result.md) adds mandatory `flow_fsm_snapshot_disk_restore_callbacks_test.tscn`, behavior `FLUJO-BHV-POTOK-SNAPSHOT-DISK-CALLBACKS-017` **not_run** awaiting full CI. Covers disk-backed restore global Exit(A),Exit(B),Enter(A),Enter(B), zero Commit signals and clear only owner pending requests; sibling remains unchanged until tick. No reentrancy tested here, no production changes.
- [9C2-B closeout](fsm_phase9_9c2b_instance_reconstruction_closeout.md) based on [Actions 41679988667](https://github.com/mercurysama/Flujo/actions/runs/41679988667) **SUCCESS**. Next **9C3-B** validate full CI; later restore_from_file in-tick reentrancy. 25 manual checks deferred, main untouched.

## Potok 9C2-B — rebuilt instance explicit disk restore CI PASS; next 9C3-A (2026-11-03)

- [9C2-B closure](fsm_phase9_9c2b_instance_reconstruction_closeout.md): [Actions 41679988667](https://github.com/mercurysama/Flujo/actions/runs/41679988667) **SUCCESS 106/106**, 9C2-A focal SUCCESS. Behavior `FLUJO-BHV-POTOK-SNAPSHOT-RECONSTRUCT-016` changed `not_run → passing` after evidence. New controller lacks prior aliases until explicit file restore, which recovers only PERSISTENT.
- **Next 9C3-A** characterize file-restore callbacks / queue and reentrancy without changing runtime. 25 manual checks deferred.

## Potok 9C2-A — controller teardown + explicit disk recovery focal (2026-11-03)

- [9C2-A](fsm_phase9_9c2a_instance_reconstruction_result.md): new mandatory `flow_fsm_snapshot_instance_reconstruction_test.tscn` and behavior `FLUJO-BHV-POTOK-SNAPSHOT-RECONSTRUCT-016` **not_run** pending CI. Fresh controller after real queue_free of source does not carry SESSION/PERSISTENT alias automatically; explicit `restore_from_file` must restore only PERSISTENT identity and data. No production changes.
- [9C1-B closeout](fsm_phase9_9c1b_invalid_file_restore_closeout.md) recorded **PASS** from [41678522740](https://github.com/mercurysama/Flujo/actions/runs/41678522740). Next **9C2-B** verify CI and close; then 9C3-A callbacks. 25 manual checks deferred.

## Potok 9C1-B — disk restore invalid-file full CI PASS, next 9C2-A (2026-11-03)

- [9C1-B closeout](fsm_phase9_9c1b_invalid_file_restore_closeout.md): [Actions 41678522740](https://github.com/mercurysama/Flujo/actions/runs/41678522740) **completed SUCCESS**, **105/105 steps**, mandatory 9C1-A focal PASS; behavior `FLUJO-BHV-POTOK-SNAPSHOT-INVALID-FILE-015` **not_run → passing**. No production changes.
- **Next 9C2-A:** independent teardown / new controller / explicit `restore_from_file` characterization; no autoload claim. Main untouched; 25 manual checks deferred.

## Potok 9B3-C3 + 9C1-A — authorization boundary and invalid disk restore test (2026-11-03)

- [9B3-C3](fsm_phase9_9b3c3_authorization_boundary.md) leaves F5–F7 and F9 as open contractual choices, **does not interpret permission for grouped microblocks as authorization to change save semantics**.
- [9C1-A](fsm_phase9_9c1a_invalid_file_restore_result.md) adds mandatory invalid-file restore focal, behavior `FLUJO-BHV-POTOK-SNAPSHOT-INVALID-FILE-015` **not_run** pending full CI. Tests absent, malformed, wrong JSON root, >MAX_JSON_LENGTH, version and graph mismatch while retaining active alias, payload and pending queue. No production code changes.
- **Next 9C1-B** close only after full CI success. Then 9C2-A teardown/new-controller explicit file roundtrip. 25 manual checks deferred, no main merge.

## Potok 9B3-C1 + 9B3-C2 — two consecutive microblocks (2026-11-03)

- **9B3-C1** [design audit](fsm_phase9_9b3c1_fault_test_design_audit.md), commit `e6713f5f6639847da3d0ad5b004e9aaa7f6a733d`: investigated direct path blockers, OS permission tricks, real file operations and possible test-only backend seam. No method reliably forces F5–F7 in current runtime across all platforms; a controlled seam requires a separate approved implementation. No claim of reproduced defect.
- **9B3-C2** [fault matrix & authorization gate](fsm_phase9_9b3c2_failure_matrix_and_gate.md), commit `bf1c26f8487081ac6095558c4fa61a588ef493e5`: exact negative cases F5/F6/F7/F7R, F9/F10 decisions, expected outcome, guarded future test-first tasks. **No tests for F5–F7 have run**, no production, catalog or workflow change; no auto-recovery contract change.
- Previous [9B3-B3 checkpoint 41674464784](https://github.com/mercurysama/Flujo/actions/runs/41674464784) **completed SUCCESS**, protecting F3. **Next 9B3-C3** authorization/design decision or independent **9C1-A** file-read reject characterization. Never infer user approval for changed save/backup semantics; 25 manual tests remain deferred, main untouched.

## Potok 9B3-B3 — F3 full CI PASS, next 9B3-C1 (2026-11-03)

- [9B3-B3 closeout](fsm_phase9_9b3b3_save_preflight_closeout.md): [Actions 41670135010](https://github.com/mercurysama/Flujo/actions/runs/41670135010) **completed SUCCESS**, all **104** headless steps, mandatory F3 focal PASS on `9fc4d44`. Catalog `FLUJO-BHV-POTOK-SNAPSHOT-SAVE-PREFLIGHT-014` updated **not_run → passing** only after full evidence. Separate valid S1, sentinel, active PERSISTENT alias and pending request preserved.
- **Next 9B3-C1** audit how to test backup/rename failure branches F5–F7 safely; no live fault hooks or product changes without contract authority. Phase 9 not closed, no main merge; 25 manual Fedora/Android checks deferred.

## Potok 9B3-B2 — safe early-save F3 failure focal added (2026-11-03)

- [9B3-B2 focal](fsm_phase9_9b3b2_save_preflight_failure_result.md) creates `flow_fsm_snapshot_save_preflight_failure_test.tscn` and mandatory GitHub Actions step for early `save_to_file` failure: sentinel file occupies a path component, preserving separate valid S1 bytes, pending transition, persistent alias and avoiding leaked temp. Behavior `FLUJO-BHV-POTOK-SNAPSHOT-SAVE-PREFLIGHT-014` **not_run** until integral CI passes. F5–F7 rename/backup replacement remain unproven.
- **Next 9B3-B3** verify focal and full CI, repair only evidence-backed RED or mark behavior passing after SUCCESS; later **9B3-C1** recovery/fault-test design. No runtime/codec changes, main untouched, 25 manual checks deferred.

## Potok 9B3-B1 — backup failure policy proposal and safe F3 test plan (2026-11-03)

- [9B3-B1 policy proposal](fsm_phase9_9b3b1_backup_failure_policy.md): F5/F7 should prefer preserving previously verified backup and target; F9 corrupt prior target still needs human contract choice; F10 automatic recovery from .bak is NOT authorized and is NOT currently implemented. No claim of universal atomicity, no productive code changes.
- **Next 9B3-B2:** safe early save preflight F3 test: create a file sentinel under isolated `user://flujo_fsm_tests/` and attempt save beneath it as if it were a directory; verify false, unchanged valid snapshot/runtime/queue and no leaked files. Register `not_run` and mandatory focal; close only after full CI in later microblock. 25 visual tests still deferred; main untouched. 9B3-A runs [41668929079](https://github.com/mercurysama/Flujo/actions/runs/41668929079), [41669024313](https://github.com/mercurysama/Flujo/actions/runs/41669024313) were in progress at initial 9B3-B1 check; confirm final status separately.

## Potok 9B3-A — backup failure path audit complete; next 9B3-B1 (2026-11-03)

- [9B3-A failure-path audit](fsm_phase9_9b3a_failure_path_audit.md) inspected `FlowFSMRuntime.save_to_file` sequencing of `.tmp`, `.bak`, `copy_absolute`, `rename_absolute` and fallback. Historical [9B2-B checkpoint 41659742397](https://github.com/mercurysama/Flujo/actions/runs/41659742397) **SUCCESS**. Prior backup can be deleted before a replacement backup copy succeeds; rename fallback can delete target before retry; these are **risks inferred from source, not confirmed failures**. 9B1 assures successful S2 main + S1 bak, not interrupted operations.
- **Next 9B3-B1:** document expected backup preservation/recovery policy for failure branches F5/F7/F9/F10, then 9B3-B2 safe preflight I/O failure focal using only dedicated `user://flujo_fsm_tests/`. No production, codec, workflow or behavior catalog changes in 9B3-A. Godot local/Skills formally not run, no main merge; 25 manual checks deferred.

## Potok 9B2-B — full CI PASS; next 9B3-A safe replacement audit (2026-11-03)

- [9B2-B closeout](fsm_phase9_9b2b_path_matrix_closeout.md): [Actions 41658845225](https://github.com/mercurysama/Flujo/actions/runs/41658845225) completed **SUCCESS 103/103 steps**, mandatory 9B2A focal PASS. Historical [41658231067](https://github.com/mercurysama/Flujo/actions/runs/41658231067) RED was one test-only Dictionary-versus-JSON representation assertion, normalized by `85e5b7f`; full coverage preserved. Behavior `FLUJO-BHV-POTOK-SNAPSHOT-PATH-POLICY-013` becomes **passing** only after full CI.
- **Next 9B3-A** safely audit filesystem replacement/backup failure cases before test or code modifications; do not claim atomicity over crashes. No production changes; 25 visual acceptance checks deferred; main untouched.

## Potok 9B2-B — focal JSON-normalization fix after historical RED (2026-11-03)

- [Actions 41658231067](https://github.com/mercurysama/Flujo/actions/runs/41658231067) **FAIL** only on final direct Dictionary equality after successful JSON restore; preceding checks passed. Test-only normalization compares portable JSON snapshots on both sides, preserving all path / queue / alias assertions. Behavior `FLUJO-BHV-POTOK-SNAPSHOT-PATH-POLICY-013` stays **not_run** pending a new full SUCCESS. No runtime or codec changes.

## Potok 9B2-A — safe user:// snapshot path matrix registered (2026-11-03)

- [9B2-A path matrix](fsm_phase9_9b2a_path_matrix_result.md) creates mandatory `tests/runtime/flow_fsm_snapshot_path_matrix_test.tscn` and behavior `FLUJO-BHV-POTOK-SNAPSHOT-PATH-POLICY-013` **not_run** pending new CI. It checks valid root/nested `user://` paths, rejects relative/res/absolute/traversal/backslash/invalid-extension on save and restore, retains queued direct request on rejected restore, and successfully restores portable persistent alias from allowed nested file. No production changes.
- [9B1-B checkpoint 41655383920](https://github.com/mercurysama/Flujo/actions/runs/41655383920) **completed SUCCESS**. Next **9B2-B** verify new full Actions before marking `passing`, then **9B3** backup replacement failure characterization; 25 visual checks deferred, main untouched.

## Potok 9B1-B — backup S1/S2 full CI PASS; next 9B2-A (2026-11-03)

- [9B1-B closure](fsm_phase9_9b1b_backup_contents_closeout.md): [GitHub Actions 41654276567](https://github.com/mercurysama/Flujo/actions/runs/41654276567) **completed SUCCESS**, 102/102 Godot 4.7.2 steps, including mandatory `Potok-9B1A distinct snapshot backup contents focal`. Source `c0385b6` checks main JSON=S2 and `.bak`=previous S1 with persistent alias identity and differing data. Catalog `FLUJO-BHV-POTOK-SNAPSHOT-BACKUP-CONTENT-012` advanced `not_run → passing` only after full CI.
- **Next 9B2-A:** bounded, safe `user://` write/read path matrix (valid paths versus invalid/traversal) without changing production; register new behavior/focal/gate and close only after CI. No runtime/codec/schema changes, main untouched. 25 manual checks deferred; local Godot/formal repo Skills NOT RUN.

## Potok 9B1-A — distinct S1/S2 snapshot backup focal registered (2026-11-03)

- [9B1-A characterization](fsm_phase9_9b1a_backup_contents_result.md) adds a real-PVController test `flow_fsm_snapshot_backup_contents_test.tscn`, mandatory Godot 4.7.2 CI step and behavior `FLUJO-BHV-POTOK-SNAPSHOT-BACKUP-CONTENT-012` at **not_run** until full CI. Asserts new main JSON=S2 and backup .bak=S1 after two semantically distinct saves.
- [9A2 CI 41624218942](https://github.com/mercurysama/Flujo/actions/runs/41624218942) **SUCCESS** for unconditional historic snapshot test. **Next 9B1-B** verify complete new CI before passing; then 9B2 path matrix. No production/schema/codec changes; 25 manual checks deferred.

## Potok 9A2 — FSM-004 policy frozen; base snapshot CI gate mandatory (2026-11-03)

- [9A2 contract and acceptance criteria](fsm_phase9_9a2_contract_and_gate.md) keeps format v1, SESSION teardown and explicit PERSISTENT restore semantics unchanged. Defines 9B1 test for distinct saved S1/S2 with `.bak=S1` and destination `S2`; replacement failure recovery is still unproven, not declared broken.
- Workflow `FSM snapshot focal (when present)` replaced with unconditional `FSM-004 mandatory snapshot file round-trip focal`, running the existing scene directly. A missing scene now fails CI. [9A1 Actions 41613093728](https://github.com/mercurysama/Flujo/actions/runs/41613093728) and [41613177819](https://github.com/mercurysama/Flujo/actions/runs/41613177819) **SUCCESS**. 9A2 new CI must independently pass. Next **9B1-A** scoped test and catalog/gate, then **9B1-B** full-CI closeout.
- No runtime/codec/schema changes or merge. 25 manual tests deferred, local Godot and formal project Skills not run.

## Potok 9A1 — FSM-004 persistence baseline audited; next 9A2 (2026-11-03)

- [9A1 baseline audit](fsm_phase9_9a1_baseline_audit.md) traces `FLU-FSM-004` to `FlowFSMSnapshotCodec`, `FlowFSMRuntime`, the existing `flow_fsm_snapshot_test.tscn` and 8D2 compatibility coverage. The test proves `.bak` **exists**, not that it contains the prior saved snapshot; code's rename/remove fallback requires bounded characterization, not an unproven bug declaration.
- Base snapshot CI step is currently conditional `FSM snapshot focal (when present)`; assess an unconditional gate during 9A2. **Next 9A2** freeze v1 format / SESSION policy, specify 9B1 saved S1 vs S2 backup acceptance, and decide gate hardening; then 9B1–9E1 microblocks. No production changes or release. 25 Fedora/Android manual checks pending, local Godot/formal repo Skills NOT RUN.

## Potok 8E-4 — FSM-004 inventory and phase 9 handoff (2026-11-03)

- [8E-4 phase 9 handoff](fsm_phase8_8e4_phase9_handoff.md) inventories existing `FlowFSMSnapshotCodec`, `FlowFSMRuntime.export_snapshot/restore_snapshot/save_to_file/restore_from_file`, `FLU-FSM-004`, `tests/runtime/flow_fsm_snapshot_test.tscn` and 8D2 snapshot compatibility focals. Phase 9 is **NOT complete**; no production or snapshot format edits.
- **Next 9A1:** audit snapshot file safety, backup contents, failure recovery, paths, invalid JSON, graph incompatibility and per-controller isolation; phase 9 is subdivided into 9A1–9E1 recoverable microblocks. A conditional snapshot CI gate exists and needs review. Historical 8E-2 CI [41595220445](https://github.com/mercurysama/Flujo/actions/runs/41595220445) SUCCESS; the 8E-3 runs [41612296707](https://github.com/mercurysama/Flujo/actions/runs/41612296707) and [41612358115](https://github.com/mercurysama/Flujo/actions/runs/41612358115) were still running at start of 8E-4; do not assume PASS before checking.
- Phase 8 is **technically validated by CI with human acceptance deferred**. Fedora 15 + Android 10 = **0/25 manual checks done**. No merge or stable release; no local Godot/formally invoked repository Skills.

## Potok 8E-3 — fase 8 technical acceptance conditional, next 8E-4 (2026-11-03)

- [8E-3 conditional technical acceptance](fsm_phase8_8e3_conditional_technical_acceptance.md): **phase 8 automated technical validation complete** on `feature/fsm-runtime-flow-flusso`; **human acceptance NOT complete**. [8E-2 audit Actions 41595172497](https://github.com/mercurysama/Flujo/actions/runs/41595172497) and [checkpoint 41595220445](https://github.com/mercurysama/Flujo/actions/runs/41595220445) both **SUCCESS**. Full Potok automatic subset of 22 entries `passing`, but other catalog statuses retain their own non-PASS values. No production changes, no merge/release.
- 15 Fedora + 10 Android manual checks **0/25 deferred**. **Next 8E-4:** create recoverable FSM-004 phase-9 roadmap and baseline inventory for versioned snapshots, safe `user://` file saves/backups, restore validation and cross-controller isolation. **Do not preemptively close phase 9.** Local Godot and formal repository Skills NOT RUN.

## Potok 8E-2 — governance and mandatory CI gate audit complete (2026-11-03)

- [8E-2 governance audit](fsm_phase8_8e2_governance_gate_audit.md) reviews `AGENTS.md`, constitution, workflow, `FLU-FSM-003`, full 92-entry catalog and mandatory Godot 4.7.2 CI YAML. The 22 automatic `FLUJO-BHV-POTOK-*` entries are all `passing`, their cited test files exist in Git tree and every path occurs in mandatory CI; global catalog statuses include deferred unrelated cases and must not be misrepresented as all passing.
- [8E-1 audit CI 41594476054](https://github.com/mercurysama/Flujo/actions/runs/41594476054) **SUCCESS**; [checkpoint CI 41594515152](https://github.com/mercurysama/Flujo/actions/runs/41594515152) **SUCCESS**. 8E-2 audit is documentation only; its own CI is a separate required confirmation. Next **8E-3** conditional technical phase-8 closure, then **8E-4** phase-9 roadmap. 25 visual checks (15 Fedora, 10 Android) deferred, main untouched; local Godot and formal Skills not invoked.

## Potok — 8E-1 FLU-FSM-003 closure criteria audited; next 8E-2 (2026-11-03)

- [8E-1 closure criteria audit](fsm_phase8_8e1_closure_criteria_audit.md): maps phase 8 original eight tasks to existing 8A–8D technical evidence, with 8B1 [41547536522](https://github.com/mercurysama/Flujo/actions/runs/41547536522), 8B2 [41548395878](https://github.com/mercurysama/Flujo/actions/runs/41548395878), 8C1 [41549228081](https://github.com/mercurysama/Flujo/actions/runs/41549228081), 8C2 [41550131409](https://github.com/mercurysama/Flujo/actions/runs/41550131409), 8D1-C [41574412835](https://github.com/mercurysama/Flujo/actions/runs/41574412835) and 8D2-C2 [41594048021](https://github.com/mercurysama/Flujo/actions/runs/41594048021) confirmed SUCCESS. Current contract retains constant 128-state quota; original plan's 'configurable' wording is a recorded difference, not authorization to alter runtime.
- 8E-1 is documentary only, no production/test changes. **Next 8E-2** check `AGENTS.md`, constitution, workflow, catalog and mandatory test gates then fresh full CI. **Phase 8 not yet formally closed**; Fedora 15 + Android 10 acceptance checks still pending, phase 9 separate. Godot local and formal repository Skills not run.

## Potok 8D2-C2 — technical closeout, handoff to 8E (2026-11-03)

- [C2 technical closeout](fsm_phase8_8d2c2_closeout.md) reconciles [C1 matrix](fsm_phase8_8d2c1_traceability_audit.md), 11 `passing` behavior-catalog entries, 11 mandatory Godot 4.7.2 focal scenes and historic full CI **SUCCESS**, with [Actions 41593493271](https://github.com/mercurysama/Flujo/actions/runs/41593493271) SUCCESS on C1 and [41593197556](https://github.com/mercurysama/Flujo/actions/runs/41593197556) SUCCESS on B3B4. C2 new docs CI awaits independent validation.
- **8D2 technical scope complete; phase 8 not yet closed. Next 8E-1**, audit `FLU-FSM-003` closure criteria, existing 8A–8D evidence, then 8E gates. Do not close phase 9; 25 manual acceptance checks pending (15 Fedora, 10 Android), no local Godot/formal skill invocation, no production changes.

## Potok 8D2-C1 — technical traceability inventory complete (2026-11-03)

- [C1 evidence audit](fsm_phase8_8d2c1_traceability_audit.md) maps all 11 behavior IDs, `tests/runtime/*.tscn` gates, contracts `FLU-FSM-003` and compatibility frontier `FLU-FSM-004`, implementation and historical successful Actions runs. B3B4 checkpoint Actions [41593197556](https://github.com/mercurysama/Flujo/actions/runs/41593197556) was still running when C1 began.
- C1 is a **documentary audit only**; no new test or production change. **Next 8D2-C2** reconcile final CI results, explicitly classify remaining non-goals and determine technical 8D2 closeout/8E entry; phase 8 and phase 9 remain open. 25 human tests pending; no local Godot or formal repo Skills invocation.

## 2026-11-03 — Potok 8D2-B3B3 / B3B4 reentrancy audit closeout

- Mandatory `flow_fsm_reset_restore_reentrant_guard_test.tscn` introduced in `7dd735d`, [Actions 41592345621](https://github.com/mercurysama/Flujo/actions/runs/41592345621) **SUCCESS** full Godot 4.7.2 suite. No runtime edits. Catalog `FLUJO-BHV-POTOK-RESET-RESTORE-REENTRANCY-011` now `passing` based on verified CI.
- [B3B4 audit](fsm_phase8_8d2b3b4_audit.md) records B3B1–B3B3 exact scenes, commits, CI and reset per-machine Exit→Enter vs restore global Exit→Enter distinction. No new test or product code in audit; next 8D2-C1 traceability. 25 human checks pending, local Godot NOT RUN, repository skills not formally invoked.

## 2026-11-03 — Potok 8D2-B3B2 snapshot restore callbacks

- Focal `flow_fsm_restore_callback_queue_test.tscn`, behavior `FLUJO-BHV-POTOK-RESTORE-CALLBACK-QUEUE-010`, source `4bc3f73`; [Actions 41591954025](https://github.com/mercurysama/Flujo/actions/runs/41591954025) **SUCCESS** full Godot 4.7.2 suite. Restore emits global Exit(A), Exit(B), Enter(A), Enter(B) and clears only owner stale queue, sibling independent. Catalog marked passing after CI, production unchanged.
- B3B3 reentrancy characterization registered at `7dd735d` but separately NOT RUN until verified. Local Godot and formal Skills NOT RUN; 25 manual checks remain deferred.

## 2026-11-03 — Potok 8D2-B3B1 guarded reset callbacks

- `74f755e` registered required test `flow_fsm_reset_callback_guard_test.tscn` and behavior `FLUJO-BHV-POTOK-RESET-CALLBACK-GUARD-009`. [Actions 41590902774](https://github.com/mercurysama/Flujo/actions/runs/41590902774) **SUCCESS** full Godot 4.7.2 suite. In-tick reset returns false; outside-tick reset performs bounded per-machine Exit→Enter and clears only owner pending queue. No production changes.
- Catalog marked passing after CI, next B3B2 snapshot restore callbacks. Skills read not formally invoked; local Godot NOT RUN and 25 manual checks deferred.

## 2026-11-03 — Potok 8D2-B3A5 determinism evidence audit

- [B3A5 audit](fsm_phase8_8d2b3a5_audit.md) maps B3A1–A4 to contracts, test scenes, catalog IDs, focal gates, commits, and Actions (all technical PASS). Historical B3A4 RED was a fixture-only reset callback order mistake; runtime untouched. No new test or product code in B3A5; the audit is documentary and not equivalent to a fresh Godot execution.
- B3A is technically complete by recorded CI; B3B reset/restore callback guards next, split into bounded B3B1–B3B4. Other 8D2/8E phases and human 25/25 acceptance remain incomplete.

## 2026-11-03 — Potok 8D2-B3A4 deterministic dynamic reset replay

- `ce2f8b5` added mandatory focal, catalog `FLUJO-BHV-POTOK-DETERMINISM-RESET-008`, two controllers with equal explicit alias IDs. [Actions 41589653144](https://github.com/mercurysama/Flujo/actions/runs/41589653144) FAIL due to test-only reset trace assumption (all Exits then all Enters).
- Existing reset performs Exit→Enter **per machine**, not two global phases. Corrected fixture-only expected trace in `fb6c134` with full assertions intact; [Actions 41589766004](https://github.com/mercurysama/Flujo/actions/runs/41589766004) **SUCCESS** full Godot 4.7.2 suite. Catalog `not_run` → `passing` after CI. No production changes.
- Next B3A5 determinant replay audit; local Godot and formal Skills NOT RUN; 25 manual tests pending. See [B3A4 result](fsm_phase8_8d2b3a4_result.md).

## 2026-11-02 — Potok 8D2-B3A3 event FIFO budget and callback determinism

- Focal and mandatory gate at `4c73329`; [Actions 41588927428](https://github.com/mercurysama/Flujo/actions/runs/41588927428) full **SUCCESS**. Identical 34 FIFO A events, one B event, 32 per-machine budget, single deferred callback and guarded nested tick across two controllers produce equivalent ordered traces.
- Catalog `FLUJO-BHV-POTOK-DETERMINISM-EVENT-BUDGET-007` moved `not_run` → `passing` after remote CI. No production changes; B3A4 next. Local Godot/formal Skills NOT RUN; manual review 0/25.

## 2026-11-02 — Potok 8D2-B3A2 ordered two-wave replay

- `fcc5d1d` introduced focal `flow_fsm_two_wave_order_replay_test.tscn`, mandatory CI and behavior `FLUJO-BHV-POTOK-DETERMINISM-ORDER-006`. [Actions 41584784409](https://github.com/mercurysama/Flujo/actions/runs/41584784409) **SUCCESS** full Godot 4.7.2 suite. Reverse admission B→A over two waves commits A→B each time in both independent runtimes. No production changes.
- Catalog moved `not_run` to `passing` only after CI; B3A3 events/budget is next. Manual tests 0/25 pending; repository Skills documentation read, not formally invoked.

## 2026-11-02 — Potok 8D2-B3A1 deterministic dual-controller replay

- Defined minimal two-MANUAL-machine contract in `3528ac9`; characterization focal and required CI gate in `845f68f`.
- [Actions 41584361713](https://github.com/mercurysama/Flujo/actions/runs/41584361713) **SUCCESS** on Godot 4.7.2, including new focal and existing regressions. Two independent PVControllers sharing authored definitions produce identical ordered A→B direct-commit traces, separate queues, matching targets, no graph mutation.
- `FLUJO-BHV-POTOK-DETERMINISM-005` changed `not_run` → `passing` after evidence. No production changes or schema changes. New B3A2 two-wave ordering focal has its own `not_run` registration; no completion claimed until its CI passes.
- Local Godot and formal skills **NOT RUN**; 25 human checks pending. See [B3A1 result](fsm_phase8_8d2b3a1_result.md).

# Flujo FSM — Iteration journal / Skill learning

## 2026-11-02 — Potok 8D2-B2B rejected snapshot atomicity

- Baseline `8583cbdc0e8bf01e98364d19671bd162b65f488d`, [CI 41579978091](https://github.com/mercurysama/Flujo/actions/runs/41579978091) SUCCESS 93/93. Initial `cb32badb` [CI 41581962872](https://github.com/mercurysama/Flujo/actions/runs/41581962872) FAIL: a malformed-record fixture tried to write string into typed Array[Dictionary], causing errors and cascading false failures; not proof of a runtime bug.
- Test-only fix `32f6ab6a95ccb31c51dac882be578180afbe9dd4` uses an **untyped copy** of arrays to build invalid document records. [CI 41582200667](https://github.com/mercurysama/Flujo/actions/runs/41582200667) **SUCCESS 94/94** including new focal; 23 negative cases rejected with no Exit/Enter, active state, registry, nested data, pending queue, or sibling mutation. Valid restore afterward clears pending and commits ordered callbacks, with deep-copy isolation.
- `FLUJO-BHV-POTOK-SNAPSHOT-ATOMIC-004` marked `passing` only after remote evidence. No production/codec/schema changes; separate FLU-FSM-004 Phase 9 not closed. [Result B2B](fsm_phase8_8d2b2b_result.md).
- Lesson: codec exports typed Array[Dictionary]; to test malformed JSON-shape records, first construct an **untyped Array** copy. Prevent test fixture setup errors from masquerading as failed validator invariants. Next 8D2-B3A deterministic replay, B3B callback guards, C audit; 0/25 manual acceptance.

## 2026-11-02 — Potok 8D2-B2A transient-active snapshots and ordering

- Baseline `50fe20def6c91a3b59ef11d54ff3e701583392cb` / [CI 41578626503](https://github.com/mercurysama/Flujo/actions/runs/41578626503) SUCCESS 92/92. Test commit `78a9a7d265ddad369f2473de661b01bb906d3fe5`, [CI 41579446980](https://github.com/mercurysama/Flujo/actions/runs/41579446980) **SUCCESS 93/93**, mandatory B2A focal passed.
- Three real MANUAL machines: EPHEMERAL and SESSION active recovery IDs export as authored initial state, PERSISTENT active stays alias; nine runtime aliases interleaved, six PERSISTENT exported exactly in machine/registration order. Version 1 portable payload, detached nested metadata, identical repeated exports, restored into second controller, complete ordered reexport and instance data isolation confirmed.
- `FLUJO-BHV-POTOK-SNAPSHOT-TRANSIENT-003` catalog `not_run` → `passing` after CI. No runtime/codec/schema change, no claims of completing existing Phase 9 FSM-004. [Report B2A](fsm_phase8_8d2b2a_result.md).
- Next **8D2-B2B**, characterize preflight rejection atomicity (graph/schema mismatch, duplicate entries, unresolved references, quota, unsafe payload) while live queue and aliases exist; don't weaken existing FSM snapshot test. Godot local NOT RUN, skills not formally invoked, 0/25 human checks deferred.

## 2026-11-02 — Potok 8D2-B1B controller teardown, restart and stale SDK

- Baseline [41577454239](https://github.com/mercurysama/Flujo/actions/runs/41577454239) 91/91 SUCCESS at `f8a4120beb89ee27c276a9645ad045b69fc1e162`. Test commit `2dad13c6815ae4269cbd42ebd07eb79f8fac2854` passed [CI 41578192657](https://github.com/mercurysama/Flujo/actions/runs/41578192657) **92/92 SUCCESS** (mandatory B1B focal + all existing regressions).
- Two real PVControllers share only authored graph. A registers all three lifetimes, activates PERSISTENT and queues two direct + one event requests; B retains independent SESSION alias and pending request. Shutdown A emits Exit and Stopped once, clears registry/queue and disables old runtime. Restart same controller creates new instance with no alias or old requests and exactly one Enter.
- Retained callback-local facades from initial StateEnter and shutdown StateExit cannot mutate either dead or fresh runtime. Stale IDs reject; new alias can register independently. B remains unchanged until own tick. No production or snapshot code changed.
- `FLUJO-BHV-POTOK-LIFETIME-STOP-002` catalog `not_run` → `passing` after remote CI; fixture, .gd/.tscn and required gate preserved. [B1B result](fsm_phase8_8d2b1b_result.md).
- Lesson: **stop/restart is not reset**: SESSION and PERSISTENT survive `reset()`, but no dynamic ID survives runtime teardown without explicit snapshot restore; never claim automatic persistence. Next **8D2-B2A** snapshot of active transient aliases; FLU-FSM-004 unchanged. Godot local NOT RUN, repository Skills not formally invoked, 25 visual checks pending.

## 2026-11-02 — Potok 8D2-B1A active EPHEMERAL reset characterization

- Baseline `a81af3ebb42efa101c5336381a831c5244f7ff07` [CI 41576142513](https://github.com/mercurysama/Flujo/actions/runs/41576142513) SUCCESS 90/90. Focal `7d9f702c1eef19af52d7ba90a600bf153eeb204e`, [CI 41576973539](https://github.com/mercurysama/Flujo/actions/runs/41576973539) **SUCCESS 91/91**; mandatory test passed under Godot 4.7.2 with no product changes.
- Two PVControllers share one schema 3 graph, not registries. On A, active EPHEMERAL alias exits on reset and disappears; SESSION/PERSISTENT alias IDs and detached nested metadata survive in order, and both remain executable. A's two queued packets are cleared; B's queued command/alias remain and advance independently. Exit/Enter exact trace and authored graph invariants verified.
- `FLUJO-BHV-POTOK-LIFETIME-RESET-001` added to catalog, marked passing only after remote CI; `flow_fsm_lifetime_reset_matrix_test.tscn` has required pipeline step. Existing FSM-004 snapshots untouched and not implied to close phase 9.
- Report [B1A](fsm_phase8_8d2b1a_result.md); next **8D2-B1B** teardown/restart all lifetimes and stale capability; no premature 8D2-C/8E or manual acceptance. Local Godot NOT RUN; formal repo Skills not invoked; 15 Fedora + 10 Android PENDING.
- Lesson: reset and teardown are distinct lifecycle boundaries. Test isolation using another controller's **pending packet**, not merely comparing immutable graph or initial state.

## 2026-11-02 — Potok 8D2-A audit: lifetime/reset/snapshot evidence before coding

- Baseline `ad73a4816849556810dd62047d468decdd562a9f`, [CI 41575182608](https://github.com/mercurysama/Flujo/actions/runs/41575182608) SUCCESS **90/90** with actual FSM 003 dynamic and FSM 004 snapshot focal markers; no new runtime verification was run locally.
- Reviewed `FlowFSMRuntime`, `FlowFSMDynamicStateRecord`, `FlowFSMSnapshotCodec`, `PVController`, [FLU-FSM-003](fsm_dynamic_contract_v1.md), [FLU-FSM-004](fsm_snapshot_contract_v1.md), earlier 8A audit, current dynamic/snapshot/SDK tests, and the original roadmap. These APIs exist already; never treat Phase 9 snapshot infrastructure as unimplemented Phase 8 work.
- Relevant gaps are **characterization only**, not known defects: active ephemeral reset lifecycle, full lifetime matrix on restart, transient active snapshot fallback, rejection atomicity against queue, deterministic multi-machine replay and callbacks around reset/restore.
- Created [8D2-A audit](fsm_phase8_8d2a_audit.md) and [small-step 8D2 plan](fsm_phase8_8d2_microblocks.md). Next **8D2-B1A** independent focal on current production, catalog NOT RUN until actual remote Actions.
- Existing SDK is not a sandbox; local Godot NOT RUN, formal repo skills not invoked; human acceptance 0/25. No production/schema modifications or phase 9 redesign.

## 2026-11-02 — Potok 8D1-C5 SDK technical evidence audit

- Nine mandatory SDK focal steps C1A, C1B, C2, C3, C4A, C4B, C4C1 and C4C2A/B confirmed SUCCESS in [Actions 41574412835](https://github.com/mercurysama/Flujo/actions/runs/41574412835), full **90/90** under Godot 4.7.2; catalog nine focal steps across eight behavior IDs all `passing` and test paths exist.
- GitHub compare baseline `85a9ace1aab97dfc6f9248910b7fa05462e2a4d7` → `ae8b4710e9e1da22b12f708a5e0cdbbf6252bffd`: **24 commits, 38 paths**, tests, docs and CI only; production code untouched. Two historic C4C2 failures documented, not erased.
- Finding: positive active removal outside tick was demonstrated through controlled shared executor using real runtime but not from an autonomous public callback trigger. SDK is capability scoping, not a sandbox; limitations remain explicit.
- Local Godot NOT RUN, formal repo Skills not invoked, manual phase 7 0/25 deferred; technical CI closure does not mean human acceptance, merge, or completion of phase 8.
- [8D1-C5 audit](fsm_phase8_8d1c5_audit.md); next **8D2-A** audit lifetimes, stop/restart, snapshots, determinism before adding new code. Reusable lesson: review whole CI job evidence and GitHub compare, not just old statuses; separate API contract, executable seam and actual public workflow.

## 2026-11-02 — Potok 8D1-C4C2 split active SDK fallback and guarded StateEnter reentry

- Baseline `b6f61f9f` / [CI 41571201948](https://github.com/mercurysama/Flujo/actions/runs/41571201948) SUCCESS 88/88. Initial combined test `d7ffa6b0` [CI 41572128593](https://github.com/mercurysama/Flujo/actions/runs/41572128593) FAIL (GDScript parse); syntax fix `b53ee9f5` [CI 41572368984](https://github.com/mercurysama/Flujo/actions/runs/41572368984) FAIL due to incorrect record count when authored fallback legitimately reenters idle StateEnter; stopped after two resource failures.
- Newly authorized split `6650d5c7571887f13e61d18f4c4753c5e59e80eb`: C4C2A dynamic-to-dynamic fallback uses existing scene; C4C2B authored fallback runs independently with separate .gd/.tscn. It explicitly requires the extra StateEnter record but no additional alias registration, queue admission, or changed IDs. [CI 41573978889](https://github.com/mercurysama/Flujo/actions/runs/41573978889) **SUCCESS 90/90**, both focal gates passed.
- SDK real StateUpdate rejects active removal inside tick; controlled shared executor outside tick accepts valid fallback and emits Exit→Enter→Commit without destructive recursion. Other-machine event retained. Positive executor seam is not a normal public lifecycle trigger. Catalog `FLUJO-BHV-POTOK-SDK-ACTIVE-REMOVE-008` moves `not_run`→`passing` only after CI.
- No production changes, persistent-schema changes or `main` edits; local Godot NOT RUN; remote Godot 4.7.2 PASS. Formal skills invocation unavailable; human visual 15 Fedora + 10 Android pending.
- Reusable skill lesson: on return to authored state, callback *must* execute; prevent duplicate *registration*, not callback reentry. Split scenarios with different lifecycle expectations so failed assertions describe a real invariant, not a false assumption.
- [C4C2 result](fsm_phase8_8d1c4c2_result.md), [recoverable C plan](fsm_phase8_8d1c_microblocks.md). Next **8D1-C5** audit SDK evidence, then 8D2 only after review.

## 2026-11-02 — Potok 8D1-C4C1 SDK inactive removal, selective queue purge

- Baseline `bb9b73a0` / [CI 41569317117](https://github.com/mercurysama/Flujo/actions/runs/41569317117), SUCCESS 87/87. Test commit `948c3b9d8a9f4d5df08d31a20e0ad7dba57ba631`; [CI 41570578617](https://github.com/mercurysama/Flujo/actions/runs/41570578617) **SUCCESS 88/88**.
- Actual StateUpdate SDK block in one machine registered two aliases, enqueued two direct requests to a removable alias and one to its survivor, then removed the inactive target; sibling machine had already queued its own direct request. Only targeted requests were purged. Next manual tick committed the two survivors in machine order; model untouched, retained SDK facades expired.
- Added fixture, focused .gd/.tscn, required CI and `FLUJO-BHV-POTOK-SDK-INACTIVE-REMOVE-007` (catalog `passing` after confirmed run); no production code changes.
- Godot local NOT RUN; remote Godot 4.7.2 PASS; project skills consulted but not formally invoked. Human 15 Fedora + 10 Android scenarios remain PENDING.
- [C4C1 result](fsm_phase8_8d1c4c1_result.md), [plan](fsm_phase8_8d1c_microblocks.md); next **8D1-C4C2**: active alias fallback SDK outside tick and Exit→Enter sequence. C4C not complete until this passes.
- Skill learning: enqueue an unrelated sibling command **before** removing a pending alias in the same actual SDK lifecycle tick; the negative property (not purging unrelated requests) is otherwise not proved.

## 2026-11-02 — Potok 8D1-C4B SDK data deep-copy and validation

- Baseline `1b952a4d` / [CI 41568112472](https://github.com/mercurysama/Flujo/actions/runs/41568112472) SUCCESS 86/86; test commit `6dda6c74637170905877cb59ee7c50bc23bb4f07`, [CI 41568809804](https://github.com/mercurysama/Flujo/actions/runs/41568809804) **SUCCESS 87/87**.
- Two PVControllers sharing a schema 3 FlowGraph execute external-style `FlowBlock` SDK callbacks. Registration deep clones nested data; repeated SDK reads are detached; replacement data is deep cloned. Eight invalid input categories reject both registration and writing without changing stored data, queues or graph.
- Added fixture, focal scene, mandatory CI step and catalog `FLUJO-BHV-POTOK-SDK-DATA-DETACH-006` (now **passing** only after CI); zero production changes or schema changes.
- Local Godot NOT RUN; remote Actions Godot 4.7.2 PASS. Versioned baseline/prove Skills instructions consulted, not formally invoked. 15 Fedora + 10 Android manual checks remain PENDING.
- [C4B report](fsm_phase8_8d1c4b_result.md), [plan](fsm_phase8_8d1c_microblocks.md); next **8D1-C4C**, active alias removal from SDK with fallback lifecycle and selective request cleanup.
- Reusable lesson: prove all three copy boundaries—registration input, setter input and readback—and check non-mutation after each rejected invalid payload through actual SDK callbacks.

## 2026-11-02 — Potok 8D1-C4A SDK queued dynamic state activation

- Baseline `0c6b3749`, [CI 41567300158](https://github.com/mercurysama/Flujo/actions/runs/41567300158) SUCCESS 85/85. Test commit `89d9bfb7382f44eaa2b52862a3e8562253db4ca9` passed full [Actions 41567631405](https://github.com/mercurysama/Flujo/actions/runs/41567631405) **SUCCESS 86/86**.
- External-style SDK StateEnter callback registers a templated SESSION alias and queues `change_state`; the alias is visible and data readable inside the callback. Initial state and request count remain unchanged until next manual tick. That tick orders original Update→Exit→template Enter→direct commit; dynamic Update waits until next tick. Retained facade expires and authored graph remains immutable.
- Added focused fixture, .gd/.tscn scene, required CI step and `FLUJO-BHV-POTOK-SDK-REGISTER-CHANGE-005`, now catalog `passing` after confirmed CI. No production code edits, schema/UI changes or `main` merge.
- Godot local NOT RUN, remote Godot Actions PASS; versioned baseline/prove skill instructions were consulted but not formally invoked. Manual 15 Fedora + 10 Android remains PENDING.
- [C4A report](fsm_phase8_8d1c4a_result.md), [C plan](fsm_phase8_8d1c_microblocks.md); next **8D1-C4B** deep-copy data, invalid payload rejection.
- Reusable skill lesson: assert the post-callback pending queue before ticking, then the precise lifecycle trace and delayed template Update; one green registration assertion alone does not prove non-reentrancy.

## 2026-11-02 — Potok 8D1-C3 non-FSM SDK capability boundary

- Baseline `b65b7a48`: [CI 41566270777](https://github.com/mercurysama/Flujo/actions/runs/41566270777) SUCCESS 84/84. Test commit `1989bf6fc52b52903770c8c53ec4207f304cd2af`; [CI 41566863222](https://github.com/mercurysama/Flujo/actions/runs/41566863222) **SUCCESS 85/85**.
- Verified real Constructor/Ready startup, Timer timeout and Method calls; replayed Ready/Constructor after FSM startup. Methods called from StateUpdate keep the phase name but do not inherit the FSM runtime. Synthetic StateEnter without runtime also remains unauthorized. Genuine Enter/Update/Exit callbacks obtain ephemeral facades; FlowGraph unchanged.
- Added fixture, focal .gd/.tscn, required CI step and catalog `FLUJO-BHV-POTOK-SDK-CAPABILITY-EXCLUSION-004`, now passing after verified CI; no production changes.
- Versioned baseline/prove instructions consulted but **not formally invoked**. Local Godot NOT RUN, remote Godot Actions PASS; manual Fedora/Android approval pending 15+10.
- Handoff [C3 result](fsm_phase8_8d1c3_result.md), [C plan](fsm_phase8_8d1c_microblocks.md). Next 8D1-C4A (SDK registration and queued change).
- Skill lesson: test capability boundaries with real executable routes, **including a method called by StateUpdate**, because an inherited phase string alone must never confer runtime authority.

## 2026-11-02 — Potok 8D1-C2 controller/machine SDK isolation

- Baseline: `6b091334` / [CI 41563497465](https://github.com/mercurysama/Flujo/actions/runs/41563497465) SUCCESS 83/83. Test commit `4c867d45d6bc5878eb42cd57bdf6c08279a40049`; [CI 41565743817](https://github.com/mercurysama/Flujo/actions/runs/41565743817) **SUCCESS 84/84**.
- One SDK-style probe, runtime scene and required CI step characterize 2 PVControllers × 2 machines sharing one FlowGraph and the same dynamic ID. Foreign machine operations reject; callback writes, active transitions, alias removal and controller stop remain isolated. Retained facades expire.
- No changes to production runtime, editor, schema or `main`. Catalog `FLUJO-BHV-POTOK-SDK-MULTI-OWNER-003` advanced to `passing` only after CI. Godot local NOT RUN; versioned baseline/prove skills read, not formally invoked.
- Physical acceptance: 15 Fedora + 10 Android PENDING. Detailed evidence and handoff: [8D1-C2 result](fsm_phase8_8d1c2_result.md), [microblocks](fsm_phase8_8d1c_microblocks.md). Next 8D1-C3 (Ready/Timer/Constructor capability exclusion).
- Reusable Skill lesson: use a shared valid runtime alias across machine/controller scopes to catch registry leakage; verify rejected cross-machine operations inside the actual SDK callback and assert no unintended queue/model mutations.

## 2026-11-02 — Potok 8D1-C1B: SDK lifecycle, reset and graph guard

- Added standalone GDScript test and `.tscn` scene, mandatory CI step, and `FLUJO-BHV-POTOK-SDK-CAPABILITY-LIFECYCLE-002`; no production files touched. Commit `1df32fdbb0ccba29eede437bc3f1ae6b33374a33`.
- Real SDK callbacks retain and expire facades in Enter, Update and Exit during reset. SESSION aliases survive reset, not stop/restart; shutdown Exit cannot register while controller disabled. A separately direct-constructed facade tests the graph-identity guard but is not a sandbox proof.
- [CI 41563021661](https://github.com/mercurysama/Flujo/actions/runs/41563021661) **SUCCESS 83/83**; focal SDK lifecycle **PASS**, full regressions **PASS**. Baseline [41562801506](https://github.com/mercurysama/Flujo/actions/runs/41562801506) SUCCESS 82/82.
- Godot local **NOT RUN**; versioned baseline/prove Skills instructions read, not formally invoked. Visual acceptance 15 Fedora + 10 Android **PENDING**.
- [Result and recovery](fsm_phase8_8d1c1b_result.md); next **8D1-C2** tests two controller SDK facade isolation. Lesson: distinguish true executor-supplied callback scope from a direct-constructor guard probe.

## 2026-11-02 — Potok 8D1-C1A: SDK facade expiration

- Verified baseline: `85a9ace1` / [CI 41558938893](https://github.com/mercurysama/Flujo/actions/runs/41558938893) **SUCCESS 81/81**.
- Added one SDK-style fixture, scene and test that retains `FlowFSMOperations`: alias registration works in StateEnter, but all six API operations reject after callback return; runtime and `FlowGraph` remain unchanged.
- No production GDScript changes. Full [CI 41562174607](https://github.com/mercurysama/Flujo/actions/runs/41562174607) and later [CI 41562328203](https://github.com/mercurysama/Flujo/actions/runs/41562328203) completed **SUCCESS 82/82**.
- Keep history: [CI 41562016330](https://github.com/mercurysama/Flujo/actions/runs/41562016330) failed only whitespace of the plan, fixed in `585cbdd2`.
- Versioned `flujo-baseline` and `flujo-prove` read but not formally invoked. Local Godot **NOT RUN**; remote CI **PASS**. Physical review 15 Fedora + 10 Android **PENDING**.
- Recovery: [C1A result](fsm_phase8_8d1c1a_result.md), [C1–C5 plan](fsm_phase8_8d1c_microblocks.md). Next 8D1-C1B; do not redo completed code or claim full 8D1-C closure.
- Skill lesson: distinguish successful in-callback use from rejection of an escaped reference, and check the real runtime/graph for side effects, not only facade return values.

**Iteration:** FSM-01 / remote branch `feature/fsm-runtime-flow-flusso`  
**Start:** 2026-11-01  
**Status:** IN PROGRESS. No FSM runtime/UI test pass is claimed.  
**Origin:** `feature/block-builder-fprint-dogfood` @ `5cf7c4d5a3e1a1e292036ff5da393433c8c54e8c`.

## Objective and scope

Implement the FSM plan in [fsm_implementation_plan.md](fsm_implementation_plan.md) while preserving portable runtime/editor separation, schema compatibility, FlowGraph immutability and per-PVController runtime isolation. Keep user-facing UI in the existing Inspector → Fluo → Flow / Flusso workflow. This journal is the source for later enrichment of the Flujo skill; describe reproducible lessons, not unverified impressions.

## Baseline already inspected (code review, not test execution)

- `FlowStateMachineDefinition`: stable identity, enabled flag, ordered states, `initial_state_id`, lookup and deep duplication.
- `FlowStateDefinition`: inherited block container, legacy `is_initial` (schema 1 only).
- `FlowGraphValidator`: per-machine initial-state integrity and stable identity validation.
- `FlowReadyExecutor`: Ready, Timer and legacy supported constructor paths in schema 3/4, with `FlowNavigationDecision` and per-execution budgets.
- `PVController`: existing per-instance output, context and timer runtime; schema 5 stores have a separate, non-executable contract.
- Fluo: Inspector container activation, Flow selection, Flusso editing, live persistence and Revertir, keyboard navigation, panel-side switching. Do not duplicate Inspector Blocks.

## Engineering decisions to preserve

1. A machine with one state is a complete executable definition; an empty machine can only be edited.
2. Serialized definitions must never store the runtime active state.
3. Dynamic states live in the controller instance and do not mutate `FlowGraph`.
4. Persistent references are stable IDs, not names, array indices, NodePaths or references to live Nodes.
5. Transitions must be queued and non-reentrant with deterministic conflict order and bounded work.
6. A model/schema extension requires explicit migration and round-trip tests before promotion.
7. New blocks use the existing generic SDK/catalog/Fluo path; avoid container-specific duplicate block classes.
8. Changes to existing behavior require `$flujo-baseline` before production edits, `$flujo-prove` before committing and manual approval of visible UI. A missing test is **not** a PASS.

## Achievements and evidence

| Item | Outcome | Evidence |
|---|---|---|
| Isolated development branch | CREATED | `feature/fsm-runtime-flow-flusso` |
| Implementation plan | ADDED | `docs/fsm_implementation_plan.md` |
| UI requirements review | REVIEWED | `README.md`, `docs/current_iteration.md`, `docs/fluo_preview_01.md` |
| FSM execution | NOT YET VALIDATED | No new executable milestone claimed |
| Desktop / Android manual review | PENDING FINAL GATE | Separate acceptance lists required |

## Obstacles and safeguards

- The current work environment cannot resolve github.com through the container's Git client and has no detected Godot/Flatpak binary. GitHub connector reads/writes work, but **local headless Godot execution is not available here**. Any verification not actually run must remain pending. Never fabricate a successful command or approval.
- The baseline branch contains schema 5 stores that are not covered by Ready/Timer execution. Do not silently enable them when implementing FSM.
- `FlowStateDefinition.blocks` currently carries ordered blocks; any `enter/exit` additions need a defined compatibility policy.
- Changing Inspector/Fluo UI requires manual verification for focus and Android/touch; headless tests cannot substitute for that evidence.

## Next work and handoff

1. Freeze the first numbered runtime/specification decisions and establish remote test evidence.
2. Implement the smallest independently auditable FSM runtime slice after the baseline gate.
3. Add transitions, events, multiple machines, dynamic state registry, persistence, UI and debug incrementally.
4. After the branch implementation and automated evidence, download it on Fedora for one grouped human validation matrix.
5. At each milestone append **observed** behavior, exact files/commands, pass/fail or not-run status, regressions, causes, fixes and reusable Skill rules here. Include only available engineering-flow metrics.

**Skill takeaway:** require explicit FSM separation between authored definitions, instance-local scheduler, serializable snapshots, and the editor; keep all acceptance evidence labeled automatic/manual/unrun.

Todo es Flujo; todo fluye. 🌊

## 2026-11-01 — Node-panel drag/drop authoring recipe

**Achieved:** documented a detailed reuse-first, skill-guided authoring recipe at [recipe_node_drag_drop_custom_blocks.md](recipe_node_drag_drop_custom_blocks.md) and linked it from the existing block-builder skill as a **planning reference only**. It distinguishes the already implemented Scene Node → NodeRef payload/slot flow from the unimplemented scene-node → discovered block insertion flow.

**Challenge:** manifest v1 has a frozen whitelist of fields and D4 supports a limited generic scalar surface; a node-class compatibility descriptor and deterministic destination-phase binding are not existing public SDK capabilities. Do not claim the proposal is already supported or sneak its fields into manifest v1.

**Next iteration:** maintainer review of the proposed C-class SDK extension; test a single node-class family and the same distributable block in Process, Timer and each State Machine phase; verify Undo/Redo, focus, cancel, persistence and Android separately. Apply actual evidence to the skill after the first approved dogfood.

**Reusable skill lesson:** treat scene-node drag/drop as authoring composition, not as a new block type or per-container runtime implementation.

## 2026-11-01 — Phase 4 audit and recovery checkpoint

- **4B:** added `tests/runtime/flow_fsm_lifecycle_edge_test.gd/.tscn`: repeated Update on a single state, reset Exit→Enter, delta, signal order, disable→enable, idempotent stop, Exit on scene teardown. [CI 41346215618](https://github.com/mercurysama/Flujo/actions/runs/41346215618): **PASS**.
- **4C:** added `tests/runtime/flow_fsm_engine_clocks_test.gd/.tscn`: live PROCESS/PHYSICS scheduling, SceneTree pause/resume, stop deferred from Update callback, no duplicate Exit. [CI 41346334448](https://github.com/mercurysama/Flujo/actions/runs/41346334448): **PASS**.
- **Result:** phase 4 runtime contract has focused automated evidence; no production runtime changes were needed. This does not certify Android, human visual behavior, exhaustive error injection or every possible reentrant callback.
- **Next:** move to phase 5 micro-lots, retaining separate automated and manual gate status. The case sequence and URLs are indexed in [fsm_phase4_audit.md](fsm_phase4_audit.md).
- **Skill lesson:** a green one-state test only proves its tested clock; a separate real-clock/paused-tree focal is required to substantiate engine-level lifecycle behavior.

## 2026-11-01 — Phase 5A event arbitration checkpoint

- Added `tests/runtime/flow_fsm_event_order_test.gd/.tscn` and independent CI step; covers event rejection/no-match consumption, same-priority authored tie break, higher-priority resolution, Update→Exit→Enter order, deferred destination Update, and events raised from synchronous Update observers.
- The first pass [CI 41347838123](https://github.com/mercurysama/Flujo/actions/runs/41347838123) was green. Test fixture subsequently refined to define priorities before gameplay; targeted step for [CI 41347899663](https://github.com/mercurysama/Flujo/actions/runs/41347899663) also passed.
- Engine unchanged; tests characterize previously unasserted scenarios. Do not claim phase 5 overall completion. Next **5B**: condition false/true/type errors and self transitions; **5C**: request overflow and multievent edge conflicts.
- Recovery plan: read `docs/fsm_phase5_microblocks.md` and resume after the last commit; preserve strict separation of tests and fixes and maintain one micro-lot per commit.

## 2026-11-01 — Phase 5B recovery checkpoint

- Commit `ef856654ecefcd3a6760ab68a4881e928c288cfa`: focused conditions/self no-op regression `flow_fsm_conditions_test.gd/.tscn` and an isolated workflow step.
- [CI 41349532108](https://github.com/mercurysama/Flujo/actions/runs/41349532108): focused 5B step passed. Detailed assertions: false/true priority including self edge, one commit, next-tick Update, invalid int/null condition rejection, startup refusal.
- No FSM runtime code changed. Resume with `docs/fsm_phase5_microblocks.md` section **FSM-5B**, then implement **5C** separately.
- Learned: type-invalid authored conditions should fail before runtime creation; self-target requests are consumed without reentering the same state.

## 2026-11-01 — FSM-5C RED/GREEN checkpoint

- Reproduced full cross-clock queue callback admission bug with `tests/runtime/flow_fsm_queue_capacity_test.gd/.tscn` and CI [41350741548](https://github.com/mercurysama/Flujo/actions/runs/41350741548) (FAIL). Test commit `70082beb8d81234c037a050f2370f29156ead2f3`.
- Fixed in separate runtime-only commit `81ed1de668e64a62ba49db08551c3f398aa81865`: reserve inflight queue capacity for requests of nonmatching clock, reject overflow during synchronous Update instead of accepting then dropping. CI [41350821319](https://github.com/mercurysama/Flujo/actions/runs/41350821319) **SUCCESS** including all existing baselines.
- Lesson: pending request size alone is **not** the full capacity in an active tick; include in-flight carryover for deferred multi-clock delivery. Preserve failing diagnostic run for root-cause traceability.
- Next: 5D multiple event arbitration; detailed history in [fsm_phase5_microblocks.md](fsm_phase5_microblocks.md). No human Android approval claimed.

## 2026-11-01 — Phase 5D recovery checkpoint

- Commit `c5673a2068d2cd0bf9d07c8be7c4cf62c7584963`: multi-event arbitration test and dedicated CI focal; [CI 41351135946](https://github.com/mercurysama/Flujo/actions/runs/41351135946) **SUCCESS**.
- Priority overrides arrival across distinct events; equal-priority ties use FIFO arrival, direct requests preempt events and are FIFO, other-clock pending events survive; callback requests defer to following tick.
- No runtime code changes. Next: phase 5 gap audit, then phase 6 multi-machine integration in independently recoverable lots. See `docs/fsm_phase5_microblocks.md`.

## 2026-11-01 — Phase 5E audit and red/green recovery

- **Failing characterization:** test/CI commit `a6b75ee44c4a6bdefda32a2a1a4c193c68ab7fab`, [Actions 41351598674](https://github.com/mercurysama/Flujo/actions/runs/41351598674) FAIL. Self-target event stole arbitration from usable lower-priority edge, though conditional self edges were already ignored.
- **Minimal fix:** `e08c6772b42423ae7a337ec83ff0a3eb055fba18` skips self-target event candidates in `_pick_request`. [Actions 41351659685](https://github.com/mercurysama/Flujo/actions/runs/41351659685) SUCCESS with all existing focal/regression suites.
- **Open before full phase 5 acceptance:** typed event payload and explicit event scope (current `emit_event` carries only `StringName`); saturation diagnostics; FSM Condition Tok # editor (separate UI-FSM). Do not conflate the narrower approved runtime protocol with the broader nine-point plan. See [phase5 microblocks](fsm_phase5_microblocks.md).
- **Next:** 5F contract-first scoped payload behavior (one small commit per step). Reuse public data validator, not a parallel serialization format; avoid multi-machine phase 6 scope until specifically specified.

## 2026-11-01 — Potok naming and FSM-5F-1 checkpoint

- User-facing name **Potok** chosen from the established multilingual flow glossary. Fluo/Flow/Flusso and Akis/Tok unchanged. Existing `FlowFSMRuntime` and `FlowStateMachineDefinition` identifiers frozen.
- Specification `20bd97957ec57ff36f914aa88aa49ea3d19ca255` → red focal `b4367d69558379400d37da13d7715db26e28a89c` ([CI 41352181305](https://github.com/mercurysama/Flujo/actions/runs/41352181305) failed as expected) → minimal runtime `f27edb2fb7ec2b64cd14387e8804d0b79ee71efd` ([CI 41352245217](https://github.com/mercurysama/Flujo/actions/runs/41352245217) SUCCESS).
- `emit_event(machine_id,event_name,payload={})` validates existing JSON-safe bounded dictionary and takes an independent deep copy. No visible payload binding to Akis/Toks yet; do not claim that consumers can read event payloads.
- Continue at `docs/fsm_phase5_microblocks.md` section 5F-1, then 5F-2 delivery/consumer contract and specific focal. Android/manual validation remains at grouped final stage.

## 2026-11-01 — Potok 5F-2 consumption observer checkpoint

- Contract `de7e4b0de954afd615a1a649534943b9e7d2032d`; test `14dae4b143a106003a762950fb97c20402943aaf` ([CI 41352804834](https://github.com/mercurysama/Flujo/actions/runs/41352804834) FAIL); runtime `59eaa042af38562872c532f15178340c9a7bf91e` ([CI 41352843883](https://github.com/mercurysama/Flujo/actions/runs/41352843883) SUCCESS).
- Added `event_consumed(machine_id,event_name,payload)` read-only signal for each incoming event addressed to current clock, after Update and before arbitration. Payload deep copied on emission; no mutation of source graph or controller state. Unmatched events still notify observers. Callback requests remain queued for next tick.
- Not yet a Condition Tok binding or per-listener immutable object, and no cross-controller event broadcasting. Resume through `docs/fsm_phase5_microblocks.md` 5F-2 and consider isolated queue error diagnostics 5G.

## 2026-11-01 — Potok 5G admission diagnostics checkpoint

- Contract `be370f3a92f92beab30ca27b88ab49d64daa2010`; test commit `a82ecfe6700042949c19e948a685ddfc37789d30` ([CI 41353542099](https://github.com/mercurysama/Flujo/actions/runs/41353542099) FAIL); runtime commit `ad65cfde37f55635b28dd5b66f944b993a68f411` ([CI 41353576853](https://github.com/mercurysama/Flujo/actions/runs/41353576853) SUCCESS).
- Admission now emits `request_rejected(machine_id,kind,code)` with stable reasons while returning the original bool; refusal never enqueues anything. Covers invalid event, missing machine/target, invalid payload, full queue including in-flight carryover, stopped runtime.
- Resume through `docs/fsm_phase5_microblocks.md` 5G. Do not claim visual/Android approval or typed payload binding to Tok. Phase 6 remains separate.

## 2026-11-01 — Potok phase 5 final audit / phase 6 entry

- **Audit commit:** `a561b00ee468519918750085a9c1a1c11c5989c9`, document `docs/fsm_phase5_final_audit.md`. Pre-audit code baseline `7cfce77474a6b44da2e0ad4e58cab37d1cbb704a` passed full [CI 41353678703](https://github.com/mercurysama/Flujo/actions/runs/41353678703).
- **Decision:** phase 5 deterministic kernel and scoped payload observer receive **automated acceptance**, not full nine-item feature closure. Potok Condition Tok `#` editor authoring and typed payload-to-Tok binding remain missing. Admission diagnostics are present but broader fault-injection handling is not.
- **Approved next engineering direction:** proceed in separately committed phase-6 micro-lots, beginning 6A contract and headless focal for a machine requesting a transition in another machine's clock. Do **not** call the feature release-ready or claim Android/manual FSM review.
- Keep prior RED/GREEN and all source contracts intact. The audit changes no runtime/model code.

## 2026-11-01 — Potok 6A green checkpoint

- Contract commit `f288301c68852fe8e82ac55bffd2a2b0377ca4ad`; test `d44968843f4c324c33b5aa3a2d12b4339dc807ff`; workflow `738584a568ecf360590bb9bd31b3416b8fa63d67`. [CI 41354940595](https://github.com/mercurysama/Flujo/actions/runs/41354940595) **SUCCESS**.
- A's Update callback requests B state transition; the request waits until B's own PHYSICS clock and cannot execute in recursive tick. Transition atomic; source unchanged. Unknown machine and foreign target fail without mutation.
- No runtime patch needed. Next independent lot 6B: Enter/Exit cross-machine deferral. Potok phase 5 Tok authoring pending.

## 2026-11-01 — Potok 6B green recovery

- Contract `23b3c915607f6bd5a00cb16a8dd3e0751222e90d`, test `e936c392d4b38851ec6722904cfa4b0c7ebc7b98`, workflow `84e8fc218e9a03407206823a39ba225670563c0e`. [GitHub Actions 41356265134](https://github.com/mercurysama/Flujo/actions/runs/41356265134) SUCCESS.
- Cross-machine commands from Enter/Exit observers defer to target clock and obey FIFO, including callbacks in both directions; reentrant tick ignored. No engine code changed.
- Next 6C: contract-first cyclic chaining / budget saturation independent of unimplemented visual Potok/Tok authoring.

## 2026-11-01 — Potok 6C-2 chain budget RED/GREEN recovery

- Contract `27fc4eda2df870dc84eb946c1c294f5c03b0b21b`; failing test/CI `dbf00cc72626054d90ec165e3219cf7d672b4d46`, `1c767018fcd03426576009dc0e7e3e620d3fe473`, `f49181a87d071e173f49a5ce595696956dd79a16` ([CI 41357182605](https://github.com/mercurysama/Flujo/actions/runs/41357182605) FAIL).
- Runtime fix `612f57bf23cf47e3723f8e3f031300eed4fe454f`; [CI 41357280685](https://github.com/mercurysama/Flujo/actions/runs/41357280685) SUCCESS including all prior tests.
- Instance-local lineage carried through direct/event requests and transition callbacks; max eight committed hops in inherited chain; ninth-hop rejection `chain_budget_exceeded` suppresses chain descendants while preserving an independent root. No schema/UI change.
- Resume via `docs/fsm_phase6_6c2_result.md`, then 6D event lineage/sibling/multiple-controller test. Per-tick CPU budget, direct request reason/payload, Potok UI and Android manual testing are not done.

## 2026-11-01 — Potok 6D green checkpoint

- Contract `435dd379c04669bcf11594ed94d9a89c45de43cc`, tests `19da090c52fa591c364396375aac809b5a1b4c5d` + `2644fb16129bf298f5ba43984dbda1288c73b79c`, CI focal `4c0c37d3ecc5fb6b044f653462ce788425dbf7e6`.
- [Actions 41357686834](https://github.com/mercurysama/Flujo/actions/runs/41357686834) SUCCESS. Event-driven A↔B lineage, ninth-hop rejection, sibling cancellation, unrelated request preservation, and isolated second PVController verified. Runtime code unchanged.
- Next: phase-6 gap audit (6E), then narrow reason/payload and per-tick budget tests. No manual/Android or phase-5 Tok visual acceptance inferred.

## 2026-11-01 — Potok 6E phase-6 gap audit

- [6E audit](fsm_phase6_6e_audit.md) commit `a3ae38b0004b4d466d1d3a9a9fad1e8d497da4d1`; pre-audit HEAD `499711314c1e11465c0c59fb528eb1f8e95f3a8d` [CI 41357770163](https://github.com/mercurysama/Flujo/actions/runs/41357770163) SUCCESS. This lot modified documentation only.
- Accepted: runtime cross-machine IDs, deterministic queues and callback deferral, finite A↔B chains, 8-hop lineage and independent roots (6A–6D). Unfinished: direct-request typed reason/payload, per-tick work budget, negative machine disable/invalidation permutations, human Android testing.
- Next lot: 6F-1 define backwards-compatible optional request metadata and observable consumption/commit without altering existing four-argument `transition_committed`, then RED/GREEN CI. Phase 5 Condition Tok UI remains pending.

## 2026-11-01 — Potok 6F-1 green recovery

- Contract `f8630d20f5fd6a2947ad45fbd77e376cce36c617`; RED test `9dac7cefb3140a642d92299a18c9dee7fe6b1393` + scene `87726b0f8ae3208b5d3855f706800b09b496f426`, workflow `c935d757799ed0f34656c6b4f886b071e550d290` ([CI 41359653289](https://github.com/mercurysama/Flujo/actions/runs/41359653289) FAIL).
- Runtime GREEN `d0e670af2af8dd5f86009d83f7bb5b7e214e2f89`; [CI 41359760201](https://github.com/mercurysama/Flujo/actions/runs/41359760201) SUCCESS all regressions.
- Direct `request_transition` accepts optional `reason: StringName`, `payload: Dictionary`, validates, deep-copies and reports only on committed direct transitions via new signal. Old two-argument API and `transition_committed` preserved; denied metadata emits stable diagnostics; callbacks defer. See `docs/fsm_phase6_6f1_result.md`.
- Next 6G per-tick work budget/fairness, then 6H negative testing. Do not claim full phase 6, Tok UI or manual Android acceptance.

## 2026-11-01 — Potok 6G per-machine packet budget green

- Contract `76057049fcb0b5d80e08919cecf363754ca147b0`, RED test `387ffded2840665a706040d94592abb37d0d087f`, scene `2299c301229580582b1a04dd16727e4c8d640b72`, CI focal `84ef9bdc6e8ca56350f97cf2c7ddc8b92ab2b796` ([Actions 41360868794](https://github.com/mercurysama/Flujo/actions/runs/41360868794) FAIL expected).
- Engine `c22ef8fd2693b2356948bfb6b3363ecdaea1b707`, updated 5G `36095a4e024a3e85fbe453d9fbc6f43aebf9efab` and 5C `46f4f82fee34d0e24efb2d7b8d35cc8fd8c3eb00` drain assertions, [Actions 41361104238](https://github.com/mercurysama/Flujo/actions/runs/41361104238) SUCCESS all tests.
- Per-machine 32-packet tick processing with fair independent machines, precise carryover reservation and `work_budget_deferred` telemetry; not a CPU-time or all-machine total budget. See `docs/fsm_phase6_6g_result.md`.
- Resume next at 6H fault-injection tests and phase-6 acceptance; do not close phase-5 Condition Tok and Potok Android UI work.

## 2026-11-01 — Potok 6H final runtime acceptance recovery

- Contract `1cf700c783f4e38bbb2eb0db45788d8eb39d26cd`; tests `5857efa96e728de08aabbb22656b53f3d449f875`, `94b8a942e793adac9e762cddacb4ce2094ee3e23`, `efe478c3517fcc9bfff1fde7001292aa946299f8`, `58832cf2792b3b17bd010612e1ed1a1b757bbea2`; workflow `28ea30ceb7441ed90e3aa1d6612e009494c0da66`.
- [CI 41363216050](https://github.com/mercurysama/Flujo/actions/runs/41363216050) FAIL for nested-stop lifecycle duplicates (6H-1 green); runtime `_stopping` fix `e494bcf39d27aa1ab25b6c31688ceb1287a98887` produced full [CI 41363328505](https://github.com/mercurysama/Flujo/actions/runs/41363328505) SUCCESS.
- See `docs/fsm_phase6_6h_result.md` and `docs/fsm_phase6_final_audit.md`. FLU-FSM-002 core multi-machine runtime is automated-pass, **not** global CPU-budget guarantee, complete fault fuzzing, phase-5 Tok integration or Potok UI/Android release validation.
- Resume at 7A authoring contract for Potok UI with explicit Tok payload/condition dependencies, or a separately scoped 6I global-work-SLA lot if necessary. Preserve red/green commits and the GitHub workflow as recovery evidence.

## 2026-11-01 — Potok 7A read-only UI projection green recovery

- Contract `6c44d8614f03269fe9575ef813148c6827aa3440` in `docs/fsm_phase7_7a_contract.md`; RED test `7c55954c76a3585bfb85cefb4e408d172d429c8d`, scene `b5f71ca2a7b2ac04786ddad7b9180321a598db4f`, CI `6467f163e5a6c1aa58bb1db0d3aeaa40ce55b9d2`. [CI 41364627238](https://github.com/mercurysama/Flujo/actions/runs/41364627238) FAIL as expected.
- GREEN editor-only `FlowFSMEditorProjection` `1afd8e3a90f02e73fbcfd0fc21a60e99f54dcf60`; [CI 41364696760](https://github.com/mercurysama/Flujo/actions/runs/41364696760) SUCCESS all regressions.
- Projection owns no graph state; returns stable IDs, machine/state order, true initial ID, three phase block IDs and typed transition metadata, Empty draft as inert placeholder. Same names do not confuse machine selection. No runtime or schema changes.
- Recovery through `docs/fsm_phase7_7a_result.md` and `docs/fsm_phase7_microblocks.md`. **Next lot 7B:** wire Inspector machine activation via existing Fluo/Flow shell and stable-ID list navigation; then 7C property editing, 7D Tok bridge, 7E keyboard/touch/manual Android.
- Do not assert that 7A provided interactive FSM UI or closed phase-5 Tok binding or Android acceptance. Human tests remain batched for final review.

## 2026-11-01 — Potok 7B Fluo navigation green checkpoint

- Contract `70360ab9069e0d34f90088118966c834505ea57d`; test `e902c52a2de9f25192d8fa05a087471958743ceb`, workflow `7c4fa7ec9ddd1b0be64f589f8f5c45c0619ea3df`, RED [41365606656](https://github.com/mercurysama/Flujo/actions/runs/41365606656).
- Inspector stable-ID activation `d9f5eb66f7cad98e1754a7a121dfb71747451cf5`, Fluo state hierarchy `1bbfb56dc735c242ca70e2729f58dd04f442b1be`, keyboard/Escape focus `ba8fb88caecb0001b9f2e780a2bf808bb89ce2f9`, reorder/removed-controller test `1956397ce8cda4d74ea1153afae389611518222c`. [Full CI 41365966187](https://github.com/mercurysama/Flujo/actions/runs/41365966187) SUCCESS.
- Existing Fluo and Flow view, state list, initial marker and Enter/Update/Exit presentation are read-only. Current editor focus, machine-ID synchronization and unchanged Ready paths proven by automated editor focal. Human Android UI acceptance remains batched.
- Resume using `docs/fsm_phase7_7b_result.md` and `docs/fsm_phase7_microblocks.md`. Next 7C-1 small property-editing commands/Flusso, then 7C-2 transitions and deletion, 7D Condition Tok/payload bridge and 7E manual/persistence checks; no full phase-7 closure yet.

## 2026-11-01 — Potok 7C-1 validated Flusso scalar forms and Undo/Redo

- Contract `92eb751db2d115144f71da8a05f4c8d8bd6e4c05`; RED test `70d5189ba3a9c01569bdc07cac6c2be0048f0c5b`, workflow `436ae51cee8ab871e973c98277a0d534e11aebc0`; expected [RED CI 41368002884](https://github.com/mercurysama/Flujo/actions/runs/41368002884).
- Commands `d4e69b297ac34c524ac08b1870b7d5035535bbd3`, Flusso editor `816e2a1115c4b68dcccb8bb36e5734ed59f61d36`, guard-test `5f7c38566d46495040c8aa46ea873948962ab29d`, enhanced UI test `5089266f20c1ec568692922fa3e75ee5cf4953ca`. [GREEN CI 41368408164](https://github.com/mercurysama/Flujo/actions/runs/41368408164) all FSM/model/editor regressions.
- Machine fields name/enabled/autostart/tick/note/initial ID; state fields name/enabled/note. Detached candidate validation, exact ID ownership and `EditorUndoRedoManager` single-action edits. Native Flusso widgets, texts committed via Enter (not on typing); unchanged legacy state `is_initial`. Current initial state cannot be disabled.
- Read `docs/fsm_phase7_7c1_result.md` before **7C-2A** transition metadata authoring and **7C-2B** structural state/edge commands. Condition Tok/event payload integration and Android manual QA not complete.

## 2026-11-01 — Potok 7C-2A transition metadata and Flusso green recovery

- Contract `1096d5a02e59dbd074c9fbd0c579d61cbf28ec3d`; RED test `c3b90c37c11d1f1ced595a7b73ecbb9a3a2cb7b5`, workflow `0f67d70fee29a1f54855a539a2299da0fddf9730`, [CI 41371010519](https://github.com/mercurysama/Flujo/actions/runs/41371010519) expected failure.
- Safe commands `35e787da9e24cdc50b55ddf60f5aca1a41438b8a`; Flow edge list `a86134f7fcd00ee9737e7d9fd8b49f75cd4b0e38`; Flusso controls `ecc12fc1379a786accb3d3d3147eacacf11db079`; expanded UI test `8013dc53cdbe49bad976f1f804205c0ac6fde5d4`, feedback `e7f1a97cbbb6ad748d56a77cec965c4f71c46fbf`, final negative UI regression `40a9b70075f3a73cf53293b34ac08063e5047a4c`. [Full CI 41371757005](https://github.com/mercurysama/Flujo/actions/runs/41371757005) SUCCESS.
- Existing transition metadata edits by stable IDs validated on detached graph candidate, committed via Undo/Redo. Invalid foreign targets, blank event or missing Bool source blocked; UI shows trigger rejection feedback and Empty state draft. No graph or runtime changes.
- Resume from `docs/fsm_phase7_7c2a_result.md` and `docs/fsm_phase7_microblocks.md`; **next 7C-2B** structure/dependency/Cancel, 7D Condition Tok and event payload binding, 7E persistence/Android visual QA. Preserve small RED/GREEN commits and delay manual reviews until consolidated acceptance.

## 2026-11-01 — Potok 7C-2B structural Flow editor green recovery

- Contract `d46a9482d3fb90e2abfcb3f887a12b08e5058f50`; RED `0ba60a18fcbd33c57f004cf706c991b81a73494a`, workflow `ae9f04cbabad9eaffe58023f794548d625e7f817` [Actions 41373165948](https://github.com/mercurysama/Flujo/actions/runs/41373165948) FAIL as expected. UI focal `f165f75164897ccf8464fd6110f34a616e6cf340` with workflow `c27b56c5b377f8f18103b614354bbc4cdcc62d92`.
- State commands `682c36e304372d7d3f0e88665775a5d36def31be`, transition commands `1df74115e2e02aea8c352393607c23b594011002`, Flow actions `0b8b0163cee7ca665af31581d8e9b72106ade628`, safe confirmation `8d60f953384903ee802d393356b8c045ec8b2f8f`, final first-selection improvement `69b67bdf0bf6a614bd8c4770b40c31250d788902`, final test `ae90066bcefdf63d8154d71f52287f06c35929a3`. [Full GREEN CI 41374189278](https://github.com/mercurysama/Flujo/actions/runs/41374189278).
- Add/duplicate/move/delete states and transitions; new IDs and self-loop remap on duplication; initial-state atomic repair; reject deletion with any surviving inbound edges (including disabled), true Cancel/close/stale-selection guards and single-action Undo/Redo. None of these mutations come from the read-only `FlowFSMEditorProjection`.
- Read `docs/fsm_phase7_7c2b_result.md`, `docs/fsm_phase7_7c2b_contract.md` and `docs/fsm_phase7_microblocks.md` before **7D** Tok `#` and typed payload expression UI. 7E saved scene and final Android human QA not yet done.

## 2026-11-01 — Potok 7D Condition Tok and event-payload binding recovery

- **7D-1 visual Tok # bridge:** contract `34d047109a6235c6ec62d3bd9ad97d1f2521aea6`, RED test `e61ac400d09bc26deb792d98cdd6b0b8e700ea4b`, UI `6f1161692994a99044aa0195ad8621cd718d5cf5`, test fix `18e6333f8b2c38ad79d30533ecda5645b433b0bf`. [GREEN CI 41381250681](https://github.com/mercurysama/Flujo/actions/runs/41381250681), documentation `docs/fsm_phase7_7d1_result.md`.
- **7D-2 event field typed condition operand:** contract `106354de39cdea1cfdaf7870c3be9814005dbc7e`, source `086a1a00a249ce947a60b8c6d0b797c2eddf0ddf`, context `b483f3f549ca62eeb3e3c6bd985638346c6c995f`, model `ba590913cbd9781d27e0af4611271e9dfd290b8d`, runtime `2dfb9a22f89a1567a554bf6468e8b5705a1ae941`, Tok UI `67b636cec08e6357531f58f5a731d7b72e0b8d58` and Potok context `ad5c1127db045ef82254dab4223cdae23e627535`, final test `3a7c92f6e71d3d2072c9e1d7d01557b254be0762`. [Full CI 41382298522](https://github.com/mercurysama/Flujo/actions/runs/41382298522) SUCCESS. Documentation `docs/fsm_phase7_7d2_result.md`.
- Condition Tok # now edits via detached popup + validated Undo/Redo. Typed event payload source holds only event name, field and exact type, not packet values. An unmatched event can feed a fallback condition on that machine's matching clock, never a stale other-machine/controller scope; missing/mismatched types fail. Event edge arbitration still has precedence; event-field values are not accessible in StateEnter/Exit.
- **Next 7E:** saved scene roundtrips, focus/keyboard/touch and consolidated manual Android visual pass. Do not claim full phase 7 release/manual acceptance solely from green headless CI.


## 2026-11-01 — Potok 7E-1A authored scene persistence regression

- Source [7E-1A contract](fsm_phase7_7e1a_contract.md); implementation `96322e705475c3fd80e944935136332a28f0785a`; [Actions 41389274900](https://github.com/mercurysama/Flujo/actions/runs/41389274900) SUCCESS (new focal and existing CI regressions).
- Reused the established normal `PackedScene` / `ResourceSaver` pattern to verify exact persisted graph, machine, ordered state, transition and phase block IDs, initial/target references, block content and valid reopen. No runtime, model schema or editor production change.
- Lesson: separate authored-scene serializability from command Undo/Redo and Condition Tok semantic-payload persistence; these belong in their own fail-localized microblocks 7E-1B and 7E-1C.
- Formal local skill gates, `git diff --check` and manual Android/desktop review NOT RUN here; remote green CI cannot approve them. Next: 7E-1B contract → test → CI → result checkpoint.


## 2026-11-01 — Potok 7E-1B1 skill-guided remote testing

- Contract `docs/fsm_phase7_7e1b1_contract.md`, test `tests/editor/flow_fsm_edited_scene_roundtrip_test.gd`, code commit `5e956b28a9587c3a96617f06ea613bc8b6d4a2f0`, CI gate fix `a0dc7f97ff07470b2ef909d4ab12b68fb13bba84`; [full CI 41390280243](https://github.com/mercurysama/Flujo/actions/runs/41390280243) SUCCESS. Two repeated Undo/Redo cycles plus save/reopen preserve IDs, state order, initial and event target.
- Lesson: `git show --check HEAD` with GitHub Actions default shallow checkout may reinterpret the current commit as a root and report unrelated historical whitespace; first [CI 41390202530](https://github.com/mercurysama/Flujo/actions/runs/41390202530) FAIL in this new gate and skipped the focal. Fix by `fetch-depth: 2`, `git diff --check HEAD^ HEAD`; second CI passed. Do not edit unrelated historical Markdown merely to get green.
- Repo Skills `$flujo-baseline` and `$flujo-prove` can be consulted and their checks followed through GitHub + Actions, **but they cannot be invoked as standalone agent tools** in this session; record procedure-applied vs direct-invocation-not-run, without claiming formal READY/PASA. Manual UI remains separate.
- Next: 7E-1B2 structural/edge command Undo/Redo persistence regression; stay within editor tests and existing commands unless failing evidence identifies a real production defect.


## 2026-11-01 — Potok 7E-1B2 structural scene history

- Contract `docs/fsm_phase7_7e1b2_contract.md` in `839c490aafede1b1e69f20fb517b2ef4afa4c681`; focused regression `tests/editor/flow_fsm_structural_scene_roundtrip_test.gd` and CI wiring in `4984b6c39b0062676e99b268b31a8528daf99aac`. [GitHub Actions 41392544536](https://github.com/mercurysama/Flujo/actions/runs/41392544536) **SUCCESS**, 47 steps.
- Existing validated editor commands can be composed into a structurally complex authored scene: duplicating a state copies phase/edges with new IDs and self-loop remap; deleting initial state repairs its ID, while foreign incoming targets block deletion. Two full ten-action Undo/Redo cycles and a `PackedScene` reopen preserve exact state/edge order, IDs and references.
- No production changes, so no model migration. `$flujo-baseline` and `$flujo-prove` instructions were read and followed as remote verification; **no direct Skill invocation or formal READY/PASA** was performed in this session. Human Godot desktop/Android acceptance remains pending.
- Next 7E-1C verifies saved nested Bool Condition Tok `#` and typed Event field source semantics without writing ephemeral payload values. Preserve focused standalone tests and incremental checkpoints.


## 2026-11-01 — Potok 7E-1C typed event source persistence

- Contract `docs/fsm_phase7_7e1c_contract.md` at `839b4cc508b3a3b60e6faf4bbff25bbef52d6d61` and test `tests/editor/flow_fsm_condition_tok_scene_roundtrip_test.gd` at `4064115ddd7fbe340934d0b63a33efd8d8305015`. [Full CI 41393859434](https://github.com/mercurysama/Flujo/actions/runs/41393859434) **SUCCESS**, 48 steps.
- Authored Bool Condition Tok with four typed event fields (INT/BOOL/FLOAT/STRING), comparison IDs, literal/operand IDs, three AND connectors and outer NOT survives a real saved-scene cycle after validated property commands and Undo/Redo. No source ID changes were needed.
- Distinguish declared event/key/type stored in the graph from machine-tick payload held in `FlowValueResolutionContext`: a private packet sentinel stays out of `.tscn`, freshly reopened sources initially have no packet, and explicit fresh packets resolve with exact type diagnostics. Never persist event packet snapshots as a convenience.
- Repository Skills `$flujo-baseline` and `$flujo-prove` were **read and followed remotely but not invoked as standalone gates**; no formal READY/PASA or human GUI/Android claim. Next 7E-1D repeated saves and instance isolation.


## 2026-11-01 — Potok 7E-1D repeated PackedScene and runtime isolation

- 7E-1D contract `c4e7d129f79babe26d3a464718137146e2dd3b33`; test `tests/model/flow_fsm_double_roundtrip_instance_isolation_test.gd` and CI step `7b1e53b8f6cc84669aed254e70cf8e14aeac07cd`. [Full CI 41394604235](https://github.com/mercurysama/Flujo/actions/runs/41394604235) **SUCCESS, 49 steps**.
- Two actual successive `PackedScene` saves/reopens retain authored graph/machine/state/edge/phase block IDs, order, metadata and valid references. Two instances from the second saved scene begin separately; their `FlowFSMRuntime` and `FlowValueResolutionContext` are distinct. A's queued event, variable and event packet do not reach B; stopping A does not stop B. Authored graph definitions may be shared without violating runtime instance isolation.
- No changes to schema, runtime or editor production; the code test is separate from 7E-1C typed event field serialization. The `$flujo-baseline` and `$flujo-prove` instructions were consulted and applied remotely through GitHub CI, **not directly executed as Skills**; do not claim formal READY/PASA or manual visual approval.
- **Next:** 7E-2A keyboard/selection behavior. Keep the original phase-7 Add-phase-block UI and manual Android matrix open for closure audit.


## 2026-11-01 — Potok 7E-2A FSM keyboard and focus characterization

- Contract commit `8acbb823e260440aecdc19cde847231e772596a6`, test `tests/editor/flow_fsm_keyboard_navigation_test.gd` and CI wiring `9a7b6358b3a3351e13332683e7321a75ec3c9e9c`; [full CI 41395513992](https://github.com/mercurysama/Flujo/actions/runs/41395513992) **SUCCESS (50 steps)**, new focal prints a passing marker with successful process termination.
- Inspector activation relay and Potok Flow stable IDs remain correct even with duplicate names and authored reorder; Ctrl+Page cycles states, plain Page cycles machines with Inspector synchronization; focus recovers after rebuild, plain Page from text editor does not navigate, foreign control Page keys remain unclaimed. No production/UI code changed.
- Test uses real key event objects handed to the existing drawer handler and native ItemList selection signal, but **does not simulate real physical keyboard/Android display**. Do not claim visual approval.
- Godot headless editor shutdown prints RID/ObjectDB leak diagnostics in this and prior baseline CI, despite successful job exit; the existing invalid JSON negative snapshot focal also logs its expected parser error. Record separately rather than claiming completely clean stderr.
- Repo Skills `$flujo-baseline`, `$flujo-prove`, `$flujo-fluo-maintenance` **read and applied as remote procedures only**; no direct Skill invocation or formal READY/PASA. Next: 7E-2B focus, Alt traversal, Revertir/Escape.


## 2026-11-01 — Potok 7E-2B1 Alt traversal, Escape and Fluo regression gate

- Contract `888027ad7d847f2169b5de0c0ef782c9d0c558a2`. New red characterization `ffaede4aef1251efb4b33d91d195b800fbb4e0d3` ([CI 41396344559](https://github.com/mercurysama/Flujo/actions/runs/41396344559) expected failure: no Potok Alt traversal and premature Fluo close). Minimal editor-only fix `2b7673862d0a50e8233abba168ef0bb4b27444ab` ([CI 41396486742](https://github.com/mercurysama/Flujo/actions/runs/41396486742), 51 steps SUCCESS); additional four required Fluo tests `cb9d34de80b8e712531f5b89d69d824613b03795` ([CI 41396669545](https://github.com/mercurysama/Flujo/actions/runs/41396669545), **55 steps SUCCESS**).
- Reuse existing drawer focus boundary: Alt cycles native Potok scalar controls in machine/state/transition order (with reverse/wrap), while Ready block option focus has priority. If a Potok condition/delete modal is visible, first Escape cancels it and restores Flow focus; second Escape closes Fluo and requests Inspector focus; no authored edits made by cancellation.
- Regression lessons: original Potok keyboard coverage missed nested UI modal precedence; keep distinct popup, Flusso session and Fluo drawer layers. Explicit Ready Process/Timer, Revertir, Drawer and Integration tests were absent from the FSM CI; add their canonical standalone `--headless --editor --script` invocations instead of assuming generic Ready baseline covered them.
- Potok machine/state/edge forms do **not** yet have the same session-opening Revertir snapshot as Ready blocks. Split 7E-2B2 and define a separate validated FSM scalar snapshot/Revertir contract. Do not claim Potok Revertir or Android/desktop visual acceptance from headless tests. Repository Skills procedures applied remotely, not invoked as local standalone Skills; formal READY/PASA pending.


## 2026-11-02 — Potok 7E-2B2 native scalar Revertir

- Scope contract `b3422315533dd486221959f420e700f8b649ad4d`; RED test-first `48f07ef30a707252698cd9f3f8b95764a60280bc` [CI 41397843359](https://github.com/mercurysama/Flujo/actions/runs/41397843359) exposed missing Potok Revertir. Implementation `8b8692767c57f79c19992a632a8161c9f04dfee1` made new focal PASS; earlier 7E-2B1 traversal needed updating for new final Revertir control ([CI 41398126177](https://github.com/mercurysama/Flujo/actions/runs/41398126177), FAILURE after new focal passed). Test-order strengthening `eb842c99214501dbf4f38dc82d91d82931120c94` retains Note assertion and adds Revertir focus; [CI 41398311659](https://github.com/mercurysama/Flujo/actions/runs/41398311659) **SUCCESS, 56/56**.
- Per-controller/graph/target weak-ref plus machine/state/edge-ID snapshots should survive ordinary UI rebuild and UndoRedo, but reset on target switch/controller close. Never reuse Ready block snapshot machinery for Potok resource scalars.
- A **single** validated detached graph candidate protects an atomic multi-field revert, avoiding partial restore across dependent transition fields. Undo restores edited pre-revert values; Redo restores opening values. No-op and invalid or stale snapshot calls have no effects or Undo steps.
- Expanding a form's focusable controls alters Alt wrap destination: distinguish an intentional new field in test expectations from a broken shortcut. Add stronger adjacent-field assertions instead of deleting tests.
- Repo Skills procedures consulted remotely; no direct standalone `$flujo-baseline`, `$flujo-prove` or `$flujo-fluo-maintenance` invocation, no formal READY/PASA. Manual Fedora/Android visual acceptance remains pending. Next 7E-2C cross-context UndoRedo focus recovery.


## 2026-11-02 — Potok 7E-2C UndoRedo semantic focus recovery

- Frozen contract `e3461a79b9abef581f44aa66f1de348cb5bc2c49`. Test-first `b31c41672dec5845127dd1705fd176bc4fd3d4f5` exposed real loss of native focus after deferred editor rebuild ([CI 41399398547](https://github.com/mercurysama/Flujo/actions/runs/41399398547) expected RED). Minimal editor fix `3f5286c721d1c2e39df2b4d4ca238b3e6a4144cc`; [CI 41399683013](https://github.com/mercurysama/Flujo/actions/runs/41399683013) **SUCCESS 57/57**.
- Never store references to a Potok native Control across `_content` teardown. Capture semantic control name, WeakRef to owner controller and stable machine/state/edge IDs before the rebuild; only on the latest generation, and only while the same visible Fluo/controller/machine holds, find the freshly rendered matching control and grant focus. If state/edge changed, fall back to live State list.
- A foreign focused editor or explicit `_flow_entry_focus_pending` navigation wins over deferred recovery. Deletion/UndoRedo must leave valid state/edge IDs; stale detached form callbacks cannot edit the new selected resource. Test two Undo/Redo loops, transition edit, deletion/undo/redo, foreign focus, and closure.
- Remote repo Skills `$flujo-baseline`, `$flujo-prove` and `$flujo-fluo-maintenance` consulted/applied; **not directly executable here**, no formal READY/PASA or manual desktop/Android acceptance. Next 7E-3A scroll/disposition.


## 2026-11-02 — Potok 7E-3A real scrollable Fluo geometry

- Baseline `78c05ff915cb93246227922a731481247137338a`, [CI 41400006665](https://github.com/mercurysama/Flujo/actions/runs/41400006665) 57 SUCCESS. Contract `b37815fcfab1cf39f074630b43a4052089ae9927`; test `tests/editor/flow_fsm_fluo_scroll_resize_test.gd` added at `a5aa57aa0a4f546d066e1d5e584d40716ee53d55`. First two test-only CI runs [41400913602](https://github.com/mercurysama/Flujo/actions/runs/41400913602) and [41401064850](https://github.com/mercurysama/Flujo/actions/runs/41401064850) **FAIL** due missing GDScript `await`, corrected at `90edf2258fa7f1ce1dd6418b7451e84a50e50932`.
- [CI 41401094424](https://github.com/mercurysama/Flujo/actions/runs/41401094424) **FAIL on actual new behavior**: horizontal DISABLED and DrawerPanel overflowing host shell at wide/narrow sizes. First task cycle stopped; user renewed 🙆🏻 authorization. Minimal `fluo_drawer.gd` editor-only change at `d07c34d7bfbd8e853a8386adb97e3ab1862a705d`: horizontal AUTO, inner logical minimum width 320px; existing vertical AUTO/follow-focus, 46% shell ratio and neutral offset unchanged.
- [**CI 41402796226**](https://github.com/mercurysama/Flujo/actions/runs/41402796226) **SUCCESS 58/58**. Native long-content FSM test exercises 25 states/12 transitions, real geometry at 1200×800 and 480×640, both sides, scroll range, focus-follow, retained IDs, graph validation. Prior Ready Revertir/Fluo drawer and Potok keyboard/UndoRedo/runtimes remain green.
- Do not confuse native headless scroll range with desktop/Android touch/accessibility approval. Repository `$flujo-baseline`, `$flujo-prove` and `$flujo-fluo-maintenance` read as procedures only, not executable standalone Skills, so formal READY/PASA and local Fedora worktree status remain unverified.
- **Next:** 7E-3B context restoration and scene/controller changes; retain 7E-4 manual matrix and original phase-block Add visual authoring closure audit.


## 2026-11-02 — Potok 7E-3B controller and scene context close

- Contract `decc47054f915676e6b9455bf59d78f7f7ba357c`; test-first `3af7cc149b7b1a0436b192e4774c1bd7c5b53c35`, [CI 41403809934](https://github.com/mercurysama/Flujo/actions/runs/41403809934) **RED** characterized four stale open/context cases, without script parse problems. Minimal `fluo_drawer.gd` fix `9240aa06651bc600d18bfb99d06f3ec0b8b2e73f`; [CI 41403989846](https://github.com/mercurysama/Flujo/actions/runs/41403989846) **SUCCESS 59/59**.
- Distinguish **normal user close** (restores valid external Inspector-like focus) from **forced controller/scene context invalidation** (clear `_focus_reference`, close before rebinding to new controller or on selected `tree_exited`; never steal an unrelated focus control). Same-controller Potok→Ready Process switching stays open, left/right position persists, and stale refresh never reopens old content. Test actual node detachment in live SceneTree, not the Godot editor's scene tab UI.
- Versioned `$flujo-baseline`, `$flujo-prove`, `$flujo-fluo-maintenance` read as remote procedures; no direct standalone Skill invocation, formal READY/PASA or Fedora staged/worktree inspection. Manual desktop/Android UI and full phase-7 Add-block flow still pending.
- **Next:** 7E-4A reproducible manual QA matrix, 7E-4B consolidation, then original phase-7 authoring gap audit. No merge to `main`.


## 2026-11-02 — Potok 7E-4A matriz de revisión manual, sin ejecución

- Contrato y guía `docs/fsm_phase7_7e4a_contract.md`, `docs/fsm_phase7_7e4a_manual_review.md`; 15 escenarios Fedora Godot 4.7.2 y 10 escenarios Android en dos orientaciones, cada uno estrictamente **PENDING** hasta observación. Plantilla por ID para versión, SHA, entrada, resultado observado y prueba audiovisual.
- Se distinguió carga/render antiguo Android (Fluo preview 2026-10-27), CI headless 7E-3B [41404376030](https://github.com/mercurysama/Flujo/actions/runs/41404376030) 59/59 y aceptación humana actual, que **no existe todavía**. Ningún PASS inferido.
- **Gates funcionales:** F03/F04/F14/F15 y A10; en especial revisar si el usuario puede añadir bloques desde UI en las fases Enter/Update/Exit. La existencia de etiquetas/proyección de fases no es evidencia de autoría; si la UI carece de Add, registrar BLOCKED y subdividir su implementación en otro microbloque.
- `$flujo-baseline`, `$flujo-prove`, `$flujo-fluo-maintenance` consultados como procedimientos remotos; no se ejecutaron autónomamente. Fase 7 NO está cerrada. **Siguiente: 7E-4B** consolidación y auditoría de requisitos, sin publicar/merging.

- **Validación 7E-4A:** primer commit de matriz `e1b39b654ab4e77580fbf13c467303921023be6c` falló `git diff --check` por espacio al final de la línea 62 ([CI 41406161805](https://github.com/mercurysama/Flujo/actions/runs/41406161805)); corrección solo documental `c192254344c8fc9704f2e858c39acb7af208a589`, [CI 41406266525](https://github.com/mercurysama/Flujo/actions/runs/41406266525) **SUCCESS 59/59**. Cero pruebas humanas ejecutadas.


## 2026-11-02 — Potok 7E-4B auditoría nueve requisitos y registro 25 humanos

- Green base `cbd68a56c762d1f11a51e62f99b436fc53e91ec9` ([CI 41406599140](https://github.com/mercurysama/Flujo/actions/runs/41406599140), 59/59); contrato `32c99169de3d5563f3177c5d64dcfb95c0492b92` ([CI 41407321246](https://github.com/mercurysama/Flujo/actions/runs/41407321246), 59/59); auditoría y registro `1891b373c7cce8e2e6e4b47ac646bcac662647d3` ([CI 41407788672](https://github.com/mercurysama/Flujo/actions/runs/41407788672), 59/59). Solo documentación, sin cambios de código.
- **Brecha de cierre de fase 7 comprobada en la fuente:** `_render_potok_state_phases` muestra Labels Enter/Update/Exit + bloques existentes sin Add ni configuración por fase. Estado `FlowStateDefinition` guarda `enter_blocks`, `blocks` (Update), `exit_blocks`; `add_ready_block` escribe en el array Ready y NO debe aplicarse directamente a las fases Enter/Exit. Estado/transición sí tienen Add y comandos de UndoRedo. Siguiente ruta: 7F-1A comandos por fase, 7F-1B UI Add, 7F-1C1/1C2 Flusso y operaciones, 7F-1D persistencia/ejecución desde UI, 7F-2 manual.
- Nueve requisitos documentados en `docs/fsm_phase7_7e4b_gap_audit.md`; registro `docs/fsm_phase7_7e4b_review_register.md` mantiene **25/25 PENDING**, cero resultados humanos. La anterior aprobación Android del Fluo Preview no se transfiere. En el checkpoint se corrigió una referencia textual de test inexistente a `flow_fsm_condition_tok_bridge_test.gd`.
- Procedimientos versionados `$flujo-baseline`, `$flujo-prove`, `$flujo-fluo-maintenance` aplicados remotamente como guías, no invocados como Skills autónomas; sin acceso al worktree Fedora, sin READY/PASA formal ni aceptación visual. No mezclar código de fase 8/9 o empaquetado fase 11 con cierre de UI.

## 2026-11-02 — Potok 7F-1A FSM phase Add commands

- Baseline `7678bff96587851863671914f92a327b670f25cf`, [CI 41408095389](https://github.com/mercurysama/Flujo/actions/runs/41408095389) 59 SUCCESS. Contract `9f4867ad9a8926875da46804ac26d48c741860e9`, [CI 41408725071](https://github.com/mercurysama/Flujo/actions/runs/41408725071) 59 SUCCESS; test `da2fbbe858670aa9890da8ce5e145fcf95ed82f6`, [RED CI 41408895454](https://github.com/mercurysama/Flujo/actions/runs/41408895454) missing API; implementation `8e31559c71e4eedd3f23d3e869cec7b950a932b4`, [GREEN CI 41409041578](https://github.com/mercurysama/Flujo/actions/runs/41409041578) **SUCCESS 60/60**.
- `add_fsm_phase_block_by_authoring_id`: strict phase StringName, machine/state stable IDs, integrated/external catalog factory, detached graph candidate validation, one atomic UndoRedo; preserves other arrays, null/IDs and resource identity. Ready's Add may not substitute Enter/Exit. Test external + built-in, invalid owner/phase/catalog and repeated Undo/Redo.
- **Next 7F-1B** native per-phase Add UI; 7F-1C editing/moves, 7F-1D UI persistence/runtime and 7F-2 physical Fedora/Android review remain PENDING. Remote repo Skills consulted, not direct invocation; formal READY/PASA not claimed.

## 2026-11-02 — Potok 7F-1B native Enter/Update/Exit phase Add UI

- Base `887593e3348c728a186e6afc8cded8db083279b8` [CI 41409492088](https://github.com/mercurysama/Flujo/actions/runs/41409492088) 60/60. Contract `731a8037afc1840516306b2ecb32fbdbe7247318`, [CI 41410787296](https://github.com/mercurysama/Flujo/actions/runs/41410787296) SUCCESS. Test-first `3fb9b1e849e0f405d15dd18a7ad17b9c4ab0cb33`, [CI 41410970019](https://github.com/mercurysama/Flujo/actions/runs/41410970019) FAILED: three expected absent-UI checks **plus test null deref/100s timeout**. Hardened guard with editor fix `8912287441d352339a4b93aaa7675fdf3967a932`; [CI 41411425281](https://github.com/mercurysama/Flujo/actions/runs/41411425281) **SUCCESS 61/61**.
- Reuse the single injected/production authoring context for native `PotokPhaseEnter/Update/ExitAddActions`, each with stable authoring-ID metadata and a named phase ItemList carrying each FlowBlock's persistent ID; null and Empty disabled. Callback binds weak controller + stable machine/state IDs to reject stale buttons. After valid Add reselect new ID and focus new list, guarded by generation, context and foreign focus. Undo clears removed selection; Redo preserves model ID without resurrecting a stale selection.
- Code only in `flow_graph_inspector_property.gd` (one editor), new focal and three CI lines; no runtime/schema changes. F03/A10 still manual PENDING because block properties in Flusso and phase move/delete are not implemented. **Next 7F-1C1**, then 7F-1C2, 7F-1D, 7F-2. Formal Skills READY/PASA unavailable through remote GitHub workflow.

## 2026-11-02 — Potok 7F-1C1A / 7F-1C1B phase-block Flusso activation

- 7F-1C1A contract checkpoint `d2ebf9076baf9ff1d6d210ac66aa7caa2b4f93bc` splits exact contextual block authoring into activation, editing, revert/focus and integration.
- 7F-1C1B new `flow_fsm_phase_block_activation_test.gd` and CI focal: [RED 41472435256](https://github.com/mercurysama/Flujo/actions/runs/41472435256) failure on absent activation; first implementation [41472656493](https://github.com/mercurysama/Flujo/actions/runs/41472656493) failure on stale prior properties panel after selection; corrected `1ac8da9c35cb4d540ec8cd5f97c0bed1bace83fc`, [GREEN 41472698791](https://github.com/mercurysama/Flujo/actions/runs/41472698791) SUCCESS.
- Lesson: `ItemList.item_activated` can activate phase block from Godot's native Enter/double-click path, but its metadata must be revalidated against current controller/machine/state/phase resource; guard detached-list callbacks. Selection alone must discard old block property UI immediately without causing a false activation.
- Shared property descriptors can project block metadata without another registry, but the current phase detail display is **read-only**. Editing through properly scoped UndoRedo commands, live values, Revertir session, Escape and return focus are separate required 7F-1C1C/D work; do not treat display as fully editable Flusso. Manual Fedora 15/15 and Android 10/10 still pending; no direct execution of versioned Skills and no local Fedora worktree audit.
- [7F-1C1B detailed result](fsm_phase7_7f1c1b_result.md). **Next:** 7F-1C1C.

## 2026-11-02 — Potok 7F-1C1C phase-owned Flusso editing

- Test-first RED `7e9cc18371872c0609da02fc2ef1f93332ee2231`, [CI 41475084787](https://github.com/mercurysama/Flujo/actions/runs/41475084787) FAILURE expected: no dedicated phase-block command. Command implementation `b561182ddc85bc964f6deaecd974bc2abe96fbfa`; native UI controls `c9f6cbd2469509afdf23dfbd84597e108dfa21cf`; UI focal and CI `ea968ae4099e50f7949c2df452e6be8f5f19feb4`, [GREEN 41475514388](https://github.com/mercurysama/Flujo/actions/runs/41475514388) **64/64 SUCCESS**.
- Lesson: editor-only phase identity must be resolved by `controller + machine + state + phase + block` before invoking UndoRedo. Editing the block resource in place preserves ID and undo target; a detached candidate must validate before the mutation. Reuse current generic property descriptors; do not turn an arbitrary export into an editor-owned property. UI controls need selection/context guards to reject stale callbacks.
- Scope intentionally limited to scalar descriptor input and built-in name/enabled/print text. Full structured document and SDK-specific integration evidence remains open, along with Revertir session and Escape/focus (7F-1C1D) and 7F-1C1E regression closure. Human checks 25/25 pending. No formal local Skills READY/PASA or Fedora worktree audit.
- [Detailed 7F-1C1C result](fsm_phase7_7f1c1c_result.md).

## 2026-11-02 — Potok 7F-1C1D phase-block Flusso session and focus

- Baseline `9a12e6e26082d7baa1367593e70f268f2b526729`, [CI 41476096311](https://github.com/mercurysama/Flujo/actions/runs/41476096311) SUCCESS. Atomic snapshot command `44d048575636937025121467fc8e35ae9426614d`; session-bound UI `1b84b12e275647345e511f88403896f3d13f49df`; Escape + drawer cleanup `7893a39b4136f52ddad4fbe15f7ee657984355a7`/`91e0b23b3ac51de5e62d6decd70c88bf3495f4fb`. Focal test `34264b0cc81c5885876166fc67922b7585ff1886` and Escape extension `1776abcd973aaf987a684dec781fdce17c8a19d1`; CI step `0c90df5f5737b5310c302678aff835ae1dcb646c`, [GREEN Actions 41491611189](https://github.com/mercurysama/Flujo/actions/runs/41491611189) **SUCCESS 65/65**.
- Lesson: phase-block configuration session must own weak controller and resource references, plus machine/state/phase/block IDs, and capture only currently presented editable properties. Revertir validates snapshot and restores as one UndoRedo action without resetting unrelated fields. Escape closes the phase Flusso before closing Fluo, and close retains live edits; focus restoration targets exact phase and persistent block ID after rebuild.
- No runtime or persistent schema changes. SDK/structured-document completeness, further stale callback/scene persistence coverage and phase 7 manual Fedora 15 + Android 10 remain pending. Versioned skills were consulted, not invoked autonomously; local worktree and physical input were not audited. **Next 7F-1C1E**.
- [7F-1C1D result](fsm_phase7_7f1c1d_result.md).

## 2026-11-02 — Potok 7F-1C1E SDK/scene regression checkpoint

- Baseline `be5b736cf87ae181651febad9e3a354116c081aa`, [CI 41492174870](https://github.com/mercurysama/Flujo/actions/runs/41492174870) SUCCESS. New SDK integration and scene persistence test `d4bcca55053ea30ff196be2b3d8ed97a86ec33f1`; CI focal `048ef4f728a8c6c9190c7b2a02f3584b0d458244`; extended SDK Revertir/non-authorable property checks `e4dded207ab8a5a54b4ed3555f646e89a1be443f`. [GREEN 41495516898](https://github.com/mercurysama/Flujo/actions/runs/41495516898): **66/66 CI steps SUCCESS**, zero failed.
- Evidence: real external SDK `manual_output:output` with property presentation JSON, edited typed message/boolean/range/enum through native phase Flusso, UndoRedo, Revertir and Undo of Revertir; no unsupported Vector2 or storage-only property exposure; ID, null slot, Update, Exit, Ready untouched; saved and reopened .tscn retained values/IDs.
- **Limit:** structured document editing is still unsupported for phase Flusso and this SDK fixture does not cover all extension variants. Manual review 15 Fedora + 10 Android = 25 outstanding; no main merge; GitHub CI not Fedora local test or formal autonomous Skills.
- [7F-1C1E result](fsm_phase7_7f1c1e_result.md). **Next:** 7F-1C2A small-test-first Move/Duplicate/Delete ownership contract.

## 2026-11-02 — Potok 7F-1C2A phase-block Move

- Baseline `43d8c3413a17e4ad24d929e75d12f4adaf56669d` [CI 41496047937](https://github.com/mercurysama/Flujo/actions/runs/41496047937) SUCCESS. Contract `39a726b15319c7d5c561725394144f8e66908053`; RED focal `0e8af907608458b183f387e0bf136fe78366cb99`, registered via workflow `ba10f1be42ccd385220c177feb8c037a8be1c123`, [CI 41497932628](https://github.com/mercurysama/Flujo/actions/runs/41497932628) failed at the new focal because Move command did not yet exist. Implementation `40495da7547955643434f9569710ed4159ad22ae`; [GREEN 41498107835](https://github.com/mercurysama/Flujo/actions/runs/41498107835), **67/67 SUCCESS**, zero failures.
- Lesson: Move is physical-adjacent slot swap with strictly canonical Enter/Update/Exit ownership. Null slots act as barriers and remain at their original positions; rejection is not a history step. Detached state/graph validation precedes one undoable array assignment; IDs/resources unchanged and sibling phases untouched.
- Remaining 7F-1C2: Duplicate, Delete, UI and integrated persistence; Move command currently has no UI controls. Manual 15 Fedora + 10 Android = 25 PENDING; main untouched. [Contract](fsm_phase7_7f1c2_contract.md) and [result](fsm_phase7_7f1c2a_result.md).

## 2026-11-02 — Potok 7F-1C2B phase block Duplicate

- Baseline `22a0e36e9f5fc0e31710b5c5f93e479f1b345bab` [CI 41498768286](https://github.com/mercurysama/Flujo/actions/runs/41498768286) SUCCESS. Test-first `9521b0694d2b263ca3030614c665481225b49996` plus workflow `6b19511ffbe25d0de5502176b1f6e6e82ec2713b` [RED 41508412591](https://github.com/mercurysama/Flujo/actions/runs/41508412591) expected missing method; implementation `fea73dfbf784d0e8f52486d147a71598f5f066a2`; [GREEN 41508625773](https://github.com/mercurysama/Flujo/actions/runs/41508625773) **68/68 SUCCESS**, zero failures.
- Lesson: reuse `FlowBlock.duplicate_with_new_id()` for deep resource-copy and own-ID remap; preserve external SDK script and exported values; insert immediately after original (including with null slots). Duplicate name based on original + " Copy" with local uniqueness, no catalog factory. Validate detached state and graph before exactly one UndoRedo action; redo uses same copied resource.
- Coverage: invalid phase/owner/ID; Enter, Update, Exit, SDK external, properties, preserved null and siblings, UndoRedo, Ready untouched. Deep nested mutable documents not separately exercised; full UI remains 7F-1C2D. **Next 7F-1C2C** strict Delete with Cancel/confirmation to follow in UI stage. Human 15 Fedora + 10 Android PENDING, main unchanged.
- [7F-1C2B result](fsm_phase7_7f1c2b_result.md).

## 2026-11-02 — Potok 7F-1C2C phase block Delete

- Baseline `f051c8f8ec20e651451ae0ec4f8941f987dca408`, [CI 41509176626](https://github.com/mercurysama/Flujo/actions/runs/41509176626) SUCCESS. RED focal `32e6e6ced2f3b0043ba39a93955cf804cfc86bb5` added in workflow `abc98c60321d011bba665a982cb7ea9d77eeeab4`: [RED Actions 41512635281](https://github.com/mercurysama/Flujo/actions/runs/41512635281) failed at absent method. Implementation `b5b5643607fd621280414f1af5455c5db934e0cd`. [GREEN Actions 41512783269](https://github.com/mercurysama/Flujo/actions/runs/41512783269), **69/69 SUCCESS**, zero failures.
- Lesson: Delete resolves exact controller/machine/state/phase/block ownership, removes one array element without replacing it with null or compacting preexisting null holes, validates a detached FSM candidate then commits one UndoRedo action. Undo restores the same block resource and stable ID; stale second Delete is rejected without history. SDK script, values, Ready and sibling phases remain safe.
- API command only; UI confirmation, Cancel, focus/scroll recovery and Move/Duplicate/Delete buttons are due **7F-1C2D**, followed by 7F-1C2E persistence/integration. Manual tests 15 Fedora + 10 Android **PENDING**; main/runtime/schema untouched.
- [7F-1C2C result](fsm_phase7_7f1c2c_result.md).

## 2026-11-02 — Potok 7F-1C2D structural phase actions in native Fluo

- Baseline `c8c1fff55b2656ba11b0d5bed2cfec5247ec569f`, [CI 41513400370](https://github.com/mercurysama/Flujo/actions/runs/41513400370) SUCCESS. RED native UI focal `bcb34078e178b3cd213a59d2b84d621622bbc280` registered `ad68cfb1dca9025f037427b666c3325e11036d66`, [RED CI 41515164995](https://github.com/mercurysama/Flujo/actions/runs/41515164995) missing controls. UI integration `6de79d83ca652acf266b1d5f146a6e2339a70016`; selection fix `a0e07f756b11111f7a0c87e8420efbe8c16891a2`; Escape/modal stale-graph fix `a382ee55293631ac9f80914601f4dee744c9749c`, focal Escape coverage `ae0c3e14422d5873eed9845c1d4f2adf1e2a2bd6`, stale-button guard `25c53e758cf7542fc45b7505adbbf62fdfe7aa7b`. [GREEN CI 41515628731](https://github.com/mercurysama/Flujo/actions/runs/41515628731), **70/70 SUCCESS**, zero failures.
- Lesson: phase Move/Duplicate/Delete buttons must be enabled synchronously on ItemList selection without a rebuild, and callbacks require exact controller/machine/state/phase/block plus WeakRef to the still-attached UI control. Delete uses existing modal and commits only after confirmed; Cancel/Escape invalidates session, retains UndoRedo and returns focus to owning phase. Successful Move retains selected stable ID, Duplicate selects new ID; Delete chooses surviving neighbor by ID, respecting null holes.
- Ready, Timer, Tok, structure dialogs, EditorUndoRedoManager and FSM regressions green. **Next 7F-1C2E** end-to-end scene roundtrip and SDK/host test consolidation. Manual 15 Fedora + 10 Android PENDING; main unchanged; GitHub CI is not a physical worktree audit.
- [7F-1C2D result](fsm_phase7_7f1c2d_result.md).

## 2026-11-02 — Potok 7F-1C2E end-to-end structural persistence

- Verified baseline `b406c690835aeac054d13d4684cf46f586ece275`, [CI 41516183343](https://github.com/mercurysama/Flujo/actions/runs/41516183343) SUCCESS. Added scene roundtrip focal `a52e00c7396b964f9338a1f2272c6473c1c83cfb` and workflow step `fd9204edd55a5acba163027597c10793884842fe`. [GREEN Actions 41517598801](https://github.com/mercurysama/Flujo/actions/runs/41517598801) completed **71/71 SUCCESS**, zero failed; native Godot 4.7.2 test and historical regressions passed.
- Lesson: test sequential structural Move/Duplicate/Delete and Undo/Redo through actual `EditorUndoRedoManager`, then serialize the edited graph through `PackedScene` and reload with cache ignored. Compare persistent machine/state/block IDs, exact ordering and null-slot positions, SDK external script and value, unaffected Ready and sibling states, schema and validator.
- 7F-1C2A–E code and targeted native UI tests now present. Remaining physical acceptance **15 Fedora + 10 Android pending**, SDK special structured document UI excluded, no local Fedora worktree audit or merge to main. **Next 7F-1D** end-to-end user journey; then 7F-2.
- [7F-1C2E result](fsm_phase7_7f1c2e_result.md).

## 2026-11-02 — Potok 7F-1D1 full native user journey

- Baseline `bbc8d763e8a998b1c38a7763ddc3715ab0e8561e`, [CI 41518184412](https://github.com/mercurysama/Flujo/actions/runs/41518184412) SUCCESS. Recoverable 7F-1D contract `e8d163bf78e77e66c6c3123a43284d5ea33cfe2b`, initial native test `d92b786160938b556892265f5293f253758a2288` and workflow `f55cb6b32b74a75d7dbe2beeeb992252ccdc8e47`; extended actions in `2d3ed5ca3a099726d0451ac8b8c2d30d9a4bc732`. [RED CI 41521035360](https://github.com/mercurysama/Flujo/actions/runs/41521035360) detected test script parse failure (the `added` block variable was scoped to nested if); fixed test only in `822cf9bae3e824310d964b8b8f41920e98b14215`. [GREEN CI 41521212041](https://github.com/mercurysama/Flujo/actions/runs/41521212041): **72/72 SUCCESS**, zero failures.
- Lesson: combine independently green UI paths into one user-level journey to catch integration and test lifetime issues. Native catalog Add, ID selection, Flusso Edit and Close, Move physical neighbor, Duplicate preserves edited text with new ID, Cancel Delete creates no action, Confirm Delete and Undo/Redo preserve copies and intentional null slots. No production modifications were necessary.
- [7F-1D contract](fsm_phase7_7f1d_contract.md); [7F-1D1 result](fsm_phase7_7f1d1_result.md). **Next 7F-1D2** external SDK and stale-context journey; 7F-1D3 saved scene journey; 7F-1D4 audit. Physical acceptance 15 Fedora + 10 Android PENDING; `main` unchanged and GitHub CI not Fedora audit.

## 2026-11-02 — Potok 7F-1D2A external SDK native three-phase journey

- Baseline `0b1aabb9900589ba251fe14d09c10980c18beaed` [CI 41521795353](https://github.com/mercurysama/Flujo/actions/runs/41521795353) SUCCESS. New native external SDK test `2be0fc54b092047c221c4c2986dd153ae944a8a3`, CI registration `dd55fce5ba2a419505d8669c8168f7409602c52b`; [GREEN 41522433103](https://github.com/mercurysama/Flujo/actions/runs/41522433103), **73/73 SUCCESS**, zero failures.
- Learning: run an actual `manual_output:output` catalog entry across all three authored phases, open the existing generic descriptor Flusso, edit multiline `message`, duplicate by the native phase action and confirm copied script, typed value and distinct persistent ID. Capture a former state action, navigate to a sibling and emit its stale signal; strict owner checks must reject without a new UndoRedo action. Null Enter slot remains intact. No production changes required.
- **Next 7F-1D2B:** invalidated controller/machine and typed Revertir/UndoRedo context within SDK user session; **7F-1D2C** close SDK scenario, followed by 7F-1D3 persistence. Physical 15 Fedora + 10 Android **PENDING**, main untouched. [7F-1D2A result](fsm_phase7_7f1d2a_result.md).

## 2026-11-02 — Potok 7F-1D2B typed SDK Revertir and cross-owner isolation

- Baseline `c2a281ed3be9e1c9db5bfcf886cf1a777ca00bff`, [CI 41523094769](https://github.com/mercurysama/Flujo/actions/runs/41523094769) SUCCESS. Focal `8981530f143bc48c75fba9d2fb0ad3d216c5a29c`, CI registration `a996b60d4a97f13b363668ec44290e3f9a66cee5`; [Actions 41523995815](https://github.com/mercurysama/Flujo/actions/runs/41523995815) passed SDK focal but initially remained marked in_progress; **completed GREEN confirmed in [Actions 41524160884](https://github.com/mercurysama/Flujo/actions/runs/41524160884), 74/74 SUCCESS, zero failures**, on same test/code with documentation-only commit.
- Learning: extended the SDK user journey to boolean, ranged integer and multiline descriptor edits; Revertir must be one UndoRedo action restoring the opening snapshot; Undo/Redo must preserve typed values. Stale descriptor and structural button callbacks from machine A must not write to machine B or another PVController, and must not create undo history. No product code changes.
- Next 7F-1D2C: external SDK native Delete modal and structural UndoRedo, then 7F-1D3 persistence, 7F-1D4 acceptance audit. Manual **15 Fedora + 10 Android PENDING**, `main` intact. [7F-1D2B result](fsm_phase7_7f1d2b_result.md).

## 2026-11-02 — Potok 7F-1D2C native SDK Delete/Undo recovery

- Baseline `a578e1bb854f43f1d1ee1b1e1af25ab406d5533d`; native test `da1b51afd303f2781add27cde6a0d7b4de07fa1f`, registered to GitHub Actions in `a551de763dbf4ec8be6bb7b5492efab517b7ce58`. [GREEN Actions 41525063836](https://github.com/mercurysama/Flujo/actions/runs/41525063836): completed **75/75 SUCCESS**, 0 failures, including focal and all Godot 4.7.2 regressions.
- Lesson: test an actual SDK `manual_output:output` Flusso message edit, Close, native Duplicate preserving SDK script with new ID, modal Delete Cancel without any history mutation, Confirm/Delete as one action, Undo reusing the identical resource, Redo removing it, and reopening the original SDK block with unchanged ID/script/edited message. Keep null slots, Ready and sibling state intact. No production code needed.
- **Next 7F-1D3**: combine Flusso SDK edits and phase UI actions with a true saved/reloaded scene; **7F-1D4** audit. Manual matrix 15 Fedora + 10 Android remains PENDING. `main` unchanged.
- [7F-1D2C checkpoint](fsm_phase7_7f1d2c_result.md).

## 2026-11-02 — Potok 7F-1D3 native SDK UI scene save/reload

- Baseline `d58174698f8e9d79c66e28d407f184daf0ca6d71`, [CI 41525575708](https://github.com/mercurysama/Flujo/actions/runs/41525575708) SUCCESS. New integrated test `de43009c0702647674487741de7468ad5deab43f`, CI registration `4ee94e7bf88238e4215665b7312628dafae4aa2e`. [GREEN Actions 41526101676](https://github.com/mercurysama/Flujo/actions/runs/41526101676): **76/76 SUCCESS**, zero failures.
- Learning: combine true native Fluo/Flusso SDK property edits with Duplicate, modal Cancel/Confirm Delete, UndoRedo and real `PackedScene` persistence in one continuous test. A save/reload boundary uses `ResourceLoader.CACHE_MODE_IGNORE` and compares machine/state/block IDs, original SDK script and edited message, null slots, Update/Exit, Ready, sibling state, schema 3 and validator. No production code changes; no new runtime behavior.
- **Next 7F-1D4**: audit integration, docs/behavior_catalog.json, reproduce 25 manual acceptance tests, plan 7F-2. Manual 15 Fedora + 10 Android PENDING, no local worktree audit or main merge.
- [7F-1D3 result](fsm_phase7_7f1d3_result.md).

## 2026-11-02 — Potok 7F-1D4 audit and 7F-2 manual acceptance gate

- Functional baseline `9842d438219b0de8ee06ba71aa0876d023b8d084` [CI 41526776843](https://github.com/mercurysama/Flujo/actions/runs/41526776843) **SUCCESS 76/76**. Audited `AGENTS.md`, `docs/constitution.md`, `docs/current_iteration.md`, `docs/development_workflow.md`, `docs/project_memory.md`, `docs/fluo_preview_01.md`, three Fluo/verification skill checklists and `docs/behavior_catalog.json`.
- Findings: Potok 7F had no dedicated behavior catalog IDs (69 pre-audit entries), and the current iteration's opening section only described the older Fluo branch; manual approval remained unverified. Added [25-case Fedora/Android matrix](fsm_phase7_7f2_manual_acceptance_matrix.md) in `052076cc5a40d719ecc2d174955afcfaf1ce8fcc`; added four catalog IDs `FLUJO-BHV-POTOK-PHASE-UI-001`, `-SDK-001`, `-PERSIST-001`, `-MANUAL-001` in `49b6949c557223c2f9d9699fd74ef2dbfae8864a` (now 73 total, manual_pending preserved); appended Potok-specific current iteration in `777e38e86628eb11181fea116a6b07c8f01b1faa`; [audit report](fsm_phase7_7f1d4_audit.md) in `b1177b30a5de4950313014997dcff818b3189ee4`.
- GitHub Actions [41528772341](https://github.com/mercurysama/Flujo/actions/runs/41528772341) confirmed the catalog validator and all five 7F-1D focal steps successful; global completion/conclusion should be verified before certifying overall suite. No production code, runtime, schema or demo changes; `main` untouched. Repository GitHub source checks do **not** prove local Fedora index/worktree or physical acceptance.
- **Next 7F-2:** maintainer performs F01–F15 Fedora and A01–A10 Android, with real OS/Godot version, images/logs, PASS/FAIL/BLOCKED, patches for regressions, and explicit acceptance. This remains **0/25 physical acceptance**, not automatic GREEN.

- 7F-1D4 audit follow-up: the updated 73-behavior catalog and current iteration passed [Actions 41528630526](https://github.com/mercurysama/Flujo/actions/runs/41528630526), completed SUCCESS 76/76, including validator. The 25 physical test cases remain PENDING; no Fedora worktree or Android acceptance was executed in GitHub CI.

## 2026-11-02 — Potok 7F-2A Fedora physical acceptance preflight

- Latest 7F-1D4 source: `1b65f06370a02a84fe5bc080428e683c015300e0`; historical catalog/CI baseline [41528630526](https://github.com/mercurysama/Flujo/actions/runs/41528630526) completed SUCCESS 76/76. A new [Fedora preflight and F01–F05 evidence guide](fsm_phase7_7f2a_fedora_preflight.md) was committed as `67be60407e46aaee898fb2392228c6a0d85710f3` without modifying runtime, editor, schema or test semantics.
- Preflight keeps `git status`, worktree checks and Godot executor version read-only; it disallows guessing Fedora paths, overwriting `demo/main.tscn` or marking a test PASS without maintainer interaction. **Physical acceptance remains 0/25**, F01–F15 and A01–A10 PENDING. Next: collect F01–F05 real evidence and only then diagnose visual defects, then next batches.

## 2026-11-02 — Potok 7F-2B Fedora F06–F10 manual checklist

- Baseline `2ccb8133ea4fea3548d18e4a98716c6e7596d905`; [CI 41530251175](https://github.com/mercurysama/Flujo/actions/runs/41530251175) completed SUCCESS, confirming prior documentation checkpoint. [7F-2B Fedora guide](fsm_phase7_7f2b_fedora_edit_operations.md) added in `7d7be1119b96442889f055f862ba783bf51115ac` for live Flusso editing/closing, Revertir plus UndoRedo, adjacent Move/null boundary, independent Duplicate, modal Delete Cancel/Escape/Confirm and UndoRedo, with step-by-step expected evidence. No editor, runtime, schema or demo changes were made.
- Test-status invariant: the guide prepares physical evaluation but performs none. **All 15 Fedora + 10 Android cases remain PENDING**, including F01–F05. Next human gate: recorded Fedora evidence, or next document microblock F11–F15 if preparing the remaining procedures. Never infer visual approval from green CI.

## 2026-11-02 — Potok 7F-2C Fedora manual review F11–F15

- Baseline `9092577253a6cc8bf5ffaf233088463ed904c559`; prior CI [41534699129](https://github.com/mercurysama/Flujo/actions/runs/41534699129) completed SUCCESS, and [41534739699](https://github.com/mercurysama/Flujo/actions/runs/41534739699) was still running at initial check. [Manual guide for Fedora F11–F15](fsm_phase7_7f2c_fedora_sdk_navigation_persistence.md) committed as `0c7dd8c8293335c2815848027d4e0f5f9ccba473`; it covers SDK all-phase editing, stale controller/state context, keyboard/focus/Escape, actual saved/reopened scenes and responsive drawer/scroll. Documentation only; no runtime/editor code or demo changes.
- Remaining acceptance: **15 Fedora + 10 Android cases still PENDING** until direct human evidence; 7F-2D/2E next for Android preparation. No physical Fedora workstation or Android app execution claimed.

## 2026-11-02 — Potok 7F-2D Android acceptance preparation A01–A05

- Starting HEAD `e3e0ccca79bc7be6aba03118f763da89f08a5b5f`, [CI 41535467283](https://github.com/mercurysama/Flujo/actions/runs/41535467283) completed SUCCESS. Added [Android A01–A05 guide](fsm_phase7_7f2d_android_loading_touch_orientation.md) at `5333a8ea0bdb4fc48659a71ca5b01da729d0afcf` for project loading, Fluo/Flow/Flusso, vertical/horizontal layouts, double-tap activation and touch Add of Print plus SDK.
- Evidence stays separated: October Fluo Preview 1 Android screenshot is historical load/render only; 7F-2 Android acceptance remains **0/10**, Fedora **0/15**. No Android device operated from GitHub, and no production, runtime, schema, scene or `main` edits. Next 7F-2E A06–A10 then actual device evidence, defect triage and human sign-off.

## 2026-11-02 — Potok 7F-2E Android A06–A10; manual protocol set prepared

- Baseline `9daac620c1fc913c84d6afbdda1b0e5d60246401`, [Actions 41536419194](https://github.com/mercurysama/Flujo/actions/runs/41536419194) completed SUCCESS. Added [Android A06–A10 guide](fsm_phase7_7f2e_android_edit_persistence.md), commit `9b7cf2ae16f759e16742afba1df564f90a640822`: touchscreen/virtual keyboard SDK fields, Revertir and available UndoRedo, Move/Duplicate/Delete Cancel/Confirm, scroll/orientation and save/reopen with owner isolation.
- All five review guides now cover **F01–F15 and A01–A10 (25/25 procedures documented)**. **Physical execution remains 0/25; 25 PENDING**, so 7F-2 cannot be accepted or merged. Next: actual Fedora first batch F01–F05 and subsequent Android hands-on results, followed by bug triage if observed. No production, schema, demo, or `main` changes.

## 2026-11-02 — Phase 7 implementation complete, human acceptance deferred; Phase 8A begins

- Maintainer explicitly authorized continuing to Phase 8 with Phase 7 physical acceptance postponed. **Do not mark the phase formally signed off:** automated 7F complete and CI green [41538641710](https://github.com/mercurysama/Flujo/actions/runs/41538641710), but **15 Fedora + 10 Android = 0/25 human cases completed**. The 7F-2A through 7F-2E guides remain valid and deferred before release.
- [Phase 8A gap audit](fsm_phase8_8a_gap_audit.md), commit `291e5f02ffae35716a2d47b81113fe6cd428110e`, discovered **existing** FSM-003 runtime and test, including `register_state`, `has_state`, `change_state`, `remove_state`, three lifetimes, script-safe cloned data and per-controller registry. **Avoid reimplementing**. Add narrow tests for unverified quota 128, ID re-registration, deterministic enumeration, lifecycle fallback, pending requests and SDK context capability. The Phase 8 plan is split into 8A, 8B1/B2, 8C1/C2, 8D1/D2 and 8E.
- `docs/current_iteration.md` updated on Phase 8 branch in `a17cbf24d252dd6f481e35183015d798c110934b`. Next is **8B1 tests-first**, after checkpoint CI. Production/runtime/schema/main untouched.

## 2026-11-02 — Potok 8B1 dynamic ID and quota characterization

- Baseline `83c8441ed38fba94415f4753f9818e614bf43333`, [CI 41544539146](https://github.com/mercurysama/Flujo/actions/runs/41544539146) SUCCESS. Added `tests/runtime/flow_fsm_dynamic_quota_identity_test.gd` (`3b6540bf43b6d41216b0ac9149d5b6291a6ed0f6`), scene (`7cfda8e1831811f2b87a92ec784384339d855c27`) and GitHub Actions gate (`7c1fefc3a2c64ad46cf063b69557dfd412a31210`). [Actions 41547536522](https://github.com/mercurysama/Flujo/actions/runs/41547536522) completed **SUCCESS 77/77**, including 8B1 focal, original dynamic-state focal, catalog validator and existing regressions.
- Tested exact capacity 128, overflow refusal, authored/foreign template collisions, deterministic enumeration, interior removal, re-registration of freed runtime ID with fresh lifetime/data, independent controller and second machine, unchanged authored graph and stop cleanup. Production code was already capable; no runtime/schema or demo edits. [8B1 result](fsm_phase8_8b1_result.md).
- Next **8B2** structured data/template characterization; Phase 7 physical Fedora 15 + Android 10 remains deferred, not approved.

## 2026-11-02 — Potok 8B2 template validation and JSON-safe data boundaries

- Functional baseline `cd6fbe5c1415ae1aa245db3f420c7285051ea43f` with [CI 41548045003](https://github.com/mercurysama/Flujo/actions/runs/41548045003) completed SUCCESS. New focal `tests/runtime/flow_fsm_dynamic_template_data_test.gd` (`727459addf18861f900e225a1cf1f39dfd01cdd4`), scene `7e12fd611a223a73f0774e0c2a55c91f622ccd3a`, workflow `5a1528dc995039560aacd66b8c27f63618da819c`. [CI 41548395878](https://github.com/mercurysama/Flujo/actions/runs/41548395878) completed **SUCCESS 78/78**, including 8B2 and 8B1 focals and the whole existing regression workflow.
- Characterized disabled/foreign/missing templates and unchanged registry on rejection; deep-clone on entry/read/update for nested JSON data; invalid Array cardinality, non-String Dictionary keys, INF, oversized JSON, excessive depth, Callable, Vector2 and live Node rejected without mutation. Existing production code passed; no runtime/schema changes. Do **not** inject cyclic containers directly into recursive validator until cycle handling is designed/tested, to avoid hangs. [8B2 result](fsm_phase8_8b2_result.md).
- Next **8C1** active dynamic alias lifecycle/fallback; Phase 7's 25 human cases remain deferred.

## 2026-11-02 — Potok 8C1 active alias safe fallback

- Baseline `459913a3514ef3239ad32f2b189e637af7abfdae`. Added `tests/runtime/flow_fsm_dynamic_active_removal_test.gd` (`f1a669b601680408671a8492b32fdd3bd10eab9c`), scene `9a6ccf64b4e8f21375b784a4d5f31dd4bd40bd37`, workflow integration `f1922e8de2e6a6ad513c49bde200b22b3c6f2539`. [CI 41549228081](https://github.com/mercurysama/Flujo/actions/runs/41549228081) completed **SUCCESS 79/79**, including 8C1 focal and all prior regressions.
- Rejected active removal without fallback, same ID, missing target, disabled target, foreign-machine target and within real `state_updated` callback during tick; verified no mutation/signals on rejection. Successful dynamic→dynamic and dynamic→authored fallback emits Exit/Enter/transition_commit in order, removes source ID, leaves authored graph unchanged. [Result](fsm_phase8_8c1_result.md). No production/runtime/schema edits. Next **8C2** pending requests and multi-machine reference integrity; Fase 7 25 physical tests deferred.

## 2026-11-02 — Potok 8C2 selective pending-queue purge

- Baseline `bfbbb020029f7a7094f729a6484669395b997d28`. Test `tests/runtime/flow_fsm_dynamic_pending_multimachine_test.gd` (`35b573c935f8983ba9b4c1d8076a2bccc7d3a0fb`), scene (`03df48438487328bfbe84295c73efabcd6587408`) and workflow (`2604a3a252dfff256dd4735b9bbeb26408e942fd`). [CI 41550131409](https://github.com/mercurysama/Flujo/actions/runs/41550131409) completed **SUCCESS 80/80**, including 8C2 focal and all earlier regressions.
- Mixed 5 requests across two machines: removing inactive alias A purges only its 2 direct requests, preserves A/B unrelated events and B valid direct transition. Re-registration of same ID cannot revive stale requests, second controller unaffected, authored graph untouched. [8C2 result](fsm_phase8_8c2_result.md). No production/runtime/schema edits. Next **8D1** SDK authorized runtime context audit, then 8D2 lifecycle isolation and 8E. Phase 7 physical acceptance still 0/25 deferred.

## 2026-11-02 — Potok 8D1-A SDK runtime access boundary audit

- Baseline `d0b20b38cb487987ad94492e4c60ab0fe7321642`; confirmed [8C2 CI 41550131409](https://github.com/mercurysama/Flujo/actions/runs/41550131409) SUCCESS 80/80. [8D1-A contract/audit](fsm_phase8_8d1a_sdk_boundary_audit.md), commit `2a531a65f968986459fed7d50ab0d822bddbe363` documents the shared executor route: `FlowFSMRuntime._execute_phase` → `FlowReadyExecutor._execute_blocks` → `FlowNavigationContext` → official/external `get_navigation_decision`. Existing context supplies `controller`, `graph`, `entry_point` and value context, but **not the FSM owner machine ID as a scoped capability**, and public graph/controller references mean this is not a sandbox.
- Planned recoverable 8D1-B1 (RED public contract test), 8D1-B2 (minimal facade passing machine ID, with context lifetime guard), 8D1-C (external block/owner/stale regression). No production or schema changes in 8D1-A, and no claim of successful FSM SDK capability yet. Next 8D1-B1, after baseline/constitution review. Phase 7 25 manual tests still deferred.

## 2026-11-02 — Potok 8D1-B1 expected RED SDK FSM capability contract

- Baseline `00bc533ed1ba7205606fc08c2c6ea649cba98b4a`; previous [CI 41551132124](https://github.com/mercurysama/Flujo/actions/runs/41551132124) SUCCESS. Added external-style `FlowBlock` probe `tests/fixtures/fsm_sdk_capability_probe.gd` (`d7106692`), integration test `tests/runtime/flow_fsm_sdk_context_capability_contract_test.gd` (`53d1ad6e`), `.tscn` (`8540e9b4`) and hard-gated CI (`13a49433`). [CI 41552195224](https://github.com/mercurysama/Flujo/actions/runs/41552195224) **completed FAILURE as expected** at 8D1-B1 focal: StateEnter, StateUpdate, StateExit lack scoped registration capability; the third expected alias registrations are absent. This is a **real feature RED**, not a successful CI. No production edits. [RED result](fsm_phase8_8d1b1_red_contract_result.md).
- Next **8D1-B2**: minimum facade and executor pass-through, preserve Ready/Timer isolation and lifecycle safety, then verify against the unchanged test; follow baseline/prove. No merge. Phase 7 physical acceptance 0/25 deferred.

## 2026-11-02 — Potok 8D1-B2 callback-scoped FSM runtime operations facade

- Baseline `3ceb73389eb06b7e6cd4aa154906bf1ba635fa45` retained expected RED contract [41552195224](https://github.com/mercurysama/Flujo/actions/runs/41552195224). Implemented `FlowFSMOperations` per-machine facade (`650cea19`), `FlowNavigationContext.get_fsm_operations` optional FSM-only callback context (`a82960b0`), executor pass-through with immediate invalidation after block callback (`ea74dd99`), and `_execute_phase` self injection (`9ceebb73`). No new registry; no schema or editor changes.
- The first runtime check [41558346002](https://github.com/mercurysama/Flujo/actions/runs/41558346002) showed Enter/Update worked but exposed a **test expectation error**: an additional Update precedes Exit when a direct transition is processed on the following tick. Corrected the focal to demand four valid unique registrations in order with Exit as the fifth observation (`5dbc64e1`); [CI 41558491721](https://github.com/mercurysama/Flujo/actions/runs/41558491721) completed **SUCCESS 81/81** (8D1-B1 contract now GREEN and all existing regressions).
- [8D1-B2 result](fsm_phase8_8d1b2_result.md). Next **8D1-C** test stale saved facades, multiple controllers, Ready/Timer/Constructor absence and actual SDK add/change/remove; confirm existing baseline and lifecycle before any other functional change. Physical Fase 7 remains 0/25 deferred, `main` unchanged.

## 2026-11-03 — Potok 9R1-B two-process snapshot closeout

- GitHub branch `feature/fsm-runtime-flow-flusso`, functional baseline `eaa95cb9239fd37bb3a69d07298e5684dc7688c1`. [Actions 41722469207](https://github.com/mercurysama/Flujo/actions/runs/41722469207) **completed SUCCESS**, Godot 4.7.2, specific 9R1-A two-process step passed: real logs `[Flujo] Potok 9R1 process write passed` and `[Flujo] Potok 9R1 process restore passed` (two separate OS launches and one shared isolated `user://` data path). No local execution or formal Skills verdict.
- `FLUJO-BHV-POTOK-SNAPSHOT-TWO-PROCESS-020` catalog `not_run → passing` only after this evidence; [9R1-A](fsm_phase9_9r1a_two_process_restart_result.md), [9R1-B](fsm_phase9_9r1b_two_process_restart_closeout.md) and [9E1-D](fsm_phase9_9e1d_post_restart_conditional_verdict.md) record exact scope. No new runtime/code/scene/schema/CI implementation in this closure.
- **Phase 9 remains CONDITIONALLY accepted**, not released: F5–F7/F7R NOT RUN, F9 recovery-policy approval outstanding, F10 no autoload, 25 physical Fedora/Android reviews deferred (0/25). Next 9R2 only upon explicit policy authorization; otherwise independent phase-10 planning may proceed without representing phase 9 as fully approved.
