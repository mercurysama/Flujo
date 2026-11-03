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

## Potok — 8D2-B3B1–B4 callback guards PASS CI; next 8D2-C1 (2026-11-03)

- **B3B1:** [Actions 41590902774](https://github.com/mercurysama/Flujo/actions/runs/41590902774) SUCCESS, per-machine bounded reset callback order and owner-only queue clearing.
- **B3B2:** [Actions 41591954025](https://github.com/mercurysama/Flujo/actions/runs/41591954025) SUCCESS, global snapshot restore callbacks, queue clearing and sibling isolation.
- **B3B3:** [Actions 41592345621](https://github.com/mercurysama/Flujo/actions/runs/41592345621) SUCCESS, rejects reset/restore inside tick and nested execution. Behavior catalog ID `FLUJO-BHV-POTOK-RESET-RESTORE-REENTRANCY-011` marked `passing` after CI.
- **B3B4:** [evidence audit](fsm_phase8_8d2b3b4_audit.md) consolidated without production changes. Next **8D2-C1**; **8D2 overall and 8E not closed**. 25 Fedora/Android manual checks pending; no local Godot or formal repo skill invocation.

## Potok — 8D2-B3A1–A5 determinism audit PASS; next 8D2-B3B (2026-11-03)

- [Audit B3A5](fsm_phase8_8d2b3a5_audit.md) consolidates four independent real-PVController characterization focals: [B3A1 CI 41584361713](https://github.com/mercurysama/Flujo/actions/runs/41584361713) PASS; [B3A2 CI 41584784409](https://github.com/mercurysama/Flujo/actions/runs/41584784409) PASS; [B3A3 CI 41588927428](https://github.com/mercurysama/Flujo/actions/runs/41588927428) PASS; [B3A4 CI 41589766004](https://github.com/mercurysama/Flujo/actions/runs/41589766004) PASS after correcting a test-only callback ordering expectation, historical [FAIL 41589653144](https://github.com/mercurysama/Flujo/actions/runs/41589653144) preserved. All four catalog behaviors marked `passing` with required CI gates.
- **Next:** B3B1 bounded `reset()` callbacks/queue guards, B3B2 `restore_snapshot()` lifecycle, B3B3 reentrancy/isolation, B3B4 close; then B3C and 8E. **8D2, phase 8 and phase 9 NOT closed.** No production changes in B3A; 25 Fedora/Android manual tests pending. Repository Skills read but not formally invoked.

# Current Iteration

## Potok — 8D2-B2B atomicidad snapshots PASS; siguiente 8D2-B3A (2026-11-02)

- [Actions 41582200667](https://github.com/mercurysama/Flujo/actions/runs/41582200667) **SUCCESS 94/94**, commit focal `32f6ab6a95ccb31c51dac882be578180afbe9dd4`. Los **23 snapshots inválidos** rechazan sin alterar registros, estados activos, cola o callbacks; restauración posterior válida sí limpia cola y ejecuta lifecycle correcto. El [primer CI 41581962872](https://github.com/mercurysama/Flujo/actions/runs/41581962872) falló por TypedArray del fixture, corregido sin cambiar aserciones.
- [Informe B2B](fsm_phase8_8d2b2b_result.md), [plan 8D2](fsm_phase8_8d2_microblocks.md); `FLUJO-BHV-POTOK-SNAPSHOT-ATOMIC-004` `passing`, cero producción editada. **Siguiente: 8D2-B3A** determinismo multi-instancia y múltiples máquinas. Fase 9 independiente; 25 manuales Fase 7 diferidas.

## Potok — 8D2-B2A snapshot transitorio activo PASS; siguiente 8D2-B2B (2026-11-02)

- [Actions 41579446980](https://github.com/mercurysama/Flujo/actions/runs/41579446980) **SUCCESS 93/93** para focal `78a9a7d265ddad369f2473de661b01bb906d3fe5`. Tres máquinas activas EPHEMERAL/SESSION/PERSISTENT: las dos transitorias exportan recuperación al inicial authored, persistente conserva ID, y seis registros persistentes mantienen orden y datos; restore en segundo controlador sin afectar al primero.
- [Informe B2A](fsm_phase8_8d2b2a_result.md), [plan](fsm_phase8_8d2_microblocks.md); catálogo `FLUJO-BHV-POTOK-SNAPSHOT-TRANSIENT-003` `passing`. **Siguiente 8D2-B2B:** rechazo atómico de snapshots inválidos. Codec Fase 9 y producción sin modificaciones; 25 pruebas humanas de Fase 7 diferidas.

## Potok — 8D2-B1B stop/restart PASS; siguiente 8D2-B2A (2026-11-02)

- [CI 41578192657](https://github.com/mercurysama/Flujo/actions/runs/41578192657) **SUCCESS 92/92**; focal `2dad13c6815ae4269cbd42ebd07eb79f8fac2854`. `stop()` libera EPHEMERAL, SESSION y PERSISTENT y elimina la cola; al reactivar el mismo `PVController` aparece nuevo runtime sin alias viejos. SDK retenidos no pueden operar. El segundo controlador preserva su alias y solicitud pendiente.
- [Informe B1B](fsm_phase8_8d2b1b_result.md), [plan](fsm_phase8_8d2_microblocks.md); catálogo `FLUJO-BHV-POTOK-LIFETIME-STOP-002` en PASS tras CI. **Siguiente 8D2-B2A**: exportación con alias transitorios activos y fallback authored. Sin cambios de producción ni fase 9. Las 25 pruebas humanas siguen diferidas.

## Potok — 8D2-B1A lifetime y reset PASS; siguiente 8D2-B1B (2026-11-02)

- [CI 41576973539](https://github.com/mercurysama/Flujo/actions/runs/41576973539) **SUCCESS 91/91**, commit focal `7d9f702c1eef19af52d7ba90a600bf153eeb204e`. Alias `EPHEMERAL` activo eliminado por reset con Exit→Enter; `SESSION` y `PERSISTENT` retienen IDs/datos y pueden activarse; solo se vacía la cola del controlador reset, y el otro permanece independiente.
- [Informe B1A](fsm_phase8_8d2b1a_result.md), [plan 8D2](fsm_phase8_8d2_microblocks.md); `FLUJO-BHV-POTOK-LIFETIME-RESET-001` `passing` solo después de CI. Sin cambios productivos. Siguiente **8D2-B1B**, stop/restart integral. Las 25 pruebas humanas de Fase 7 continúan diferidas.

## Potok — 8D2-A auditoría de lifetimes y snapshots; próximo 8D2-B1A (2026-11-02)

- Baseline [Actions 41575182608](https://github.com/mercurysama/Flujo/actions/runs/41575182608) **SUCCESS 90/90** Godot 4.7.2, incluidos FSM 003 dynamic states, FSM 004 snapshot, 8B1/8B2/8C1/8C2. Auditoría documental [8D2-A](fsm_phase8_8d2a_audit.md): políticas EPHEMERAL/SESSION/PERSISTENT, reset, stop/restart, codec de snapshots y almacenamiento `user://` **ya implementados**; no se reescribe producción ni Fase 9.
- [Microbloques 8D2](fsm_phase8_8d2_microblocks.md): siguiente **8D2-B1A**, matriz de lifetime y reset con alias temporal activo, segundo controlador y secuencia Exit→Enter. Los experimentos nuevos están **NOT RUN**, no PASS. 8D1-C cerrado técnicamente y 25 pruebas humanas de Fase 7 diferidas.

## Potok — 8D1-C5 auditoría técnica cerrada; siguiente 8D2-A (2026-11-02)

- [CI 41574412835](https://github.com/mercurysama/Flujo/actions/runs/41574412835) **SUCCESS 90/90** y las 9 focales de 8D1-C verificadas por conclusión y marcador Godot 4.7.2. Comparación desde `85a9ace1` a `ae8b4710`: 24 commits, 38 rutas afectadas; cero archivos de producción modificados.
- [Auditoría C5](fsm_phase8_8d1c5_audit.md): 8D1-C queda **cerrada técnicamente en CI**, con límites explícitos: C4C2 fuera de tick mediante ejecutor de prueba, SDK no es sandbox, Skills no ejecutadas formalmente, 25 pruebas humanas (15 Fedora/10 Android) diferidas. No implica aceptación del mantenedor ni cierre de fase 8.
- Próximo microbloque **8D2-A**: auditar implementaciones existentes y planificar lifetime, stop/restart, snapshots y determinismo antes de escribir código. Rama exclusiva `feature/fsm-runtime-flow-flusso`.

## Potok — 8D1-C4C2 PASS; siguiente 8D1-C5 (2026-11-02)

- [Actions 41573978889](https://github.com/mercurysama/Flujo/actions/runs/41573978889) **SUCCESS 90/90**, commit `6650d5c7571887f13e61d18f4c4753c5e59e80eb`. C4C2 ahora contiene dos pruebas independientes: A para fallback dinámico y B para fallback authored, con reingreso legítimo `StateEnter` **sin duplicar alias**. Conservan Exit→Enter→Commit, cola selectiva y rechazo dentro del tick. No hubo cambios productivos.
- [Informe C4C2](fsm_phase8_8d1c4c2_result.md); siguiente **8D1-C5** auditoría de evidencia, no fase 8D2 automáticamente. Las pruebas humanas de fase 7 siguen pendientes (15 Fedora + 10 Android).

## Potok — 8D1-C4C1 PASS; próximo 8D1-C4C2 (2026-11-02)

- [Actions 41570578617](https://github.com/mercurysama/Flujo/actions/runs/41570578617) **SUCCESS 88/88** para `948c3b9d8a9f4d5df08d31a20e0ad7dba57ba631`. Callback real SDK `StateUpdate` elimina alias inactivo y limpia **solo dos** solicitudes a ese ID; conserva la transición de otra máquina y el segundo alias, que se confirman en el tick posterior. Cero cambios productivos.
- [Informe C4C1](fsm_phase8_8d1c4c1_result.md) y [plan C](fsm_phase8_8d1c_microblocks.md). Próximo **8D1-C4C2**: eliminación de alias activo con fallback y Exit→Enter. Las 25 pruebas humanas permanecen diferidas.

## Potok — 8D1-C4B PASS; siguiente 8D1-C4C (2026-11-02)

- [CI 41568809804](https://github.com/mercurysama/Flujo/actions/runs/41568809804) **SUCCESS 87/87** para `6dda6c74637170905877cb59ee7c50bc23bb4f07`. Copias profundas verificadas desde callbacks SDK reales, ocho categorías inválidas rechazadas, dos controladores independientes, `FlowGraph` intacto; sin cambios productivos.
- [Informe C4B](fsm_phase8_8d1c4b_result.md) y [plan C](fsm_phase8_8d1c_microblocks.md). Próximo **8D1-C4C**: retirada de alias desde el SDK con fallback y cola selectiva. Revisión humana de fase 7: 15 Fedora + 10 Android pendientes.

## Potok — 8D1-C4A PASS; siguiente 8D1-C4B (2026-11-02)

- [CI 41567631405](https://github.com/mercurysama/Flujo/actions/runs/41567631405) **SUCCESS 86/86** en `89d9bfb7382f44eaa2b52862a3e8562253db4ca9`. Un FlowBlock SDK crea un alias dinámico SESSION con datos, solicita su activación y la transición espera al tick manual; se conserva la secuencia Update→Exit→Enter y el Update dinámico ocurre en el tick siguiente. Código productivo sin cambios.
- [Informe C4A](fsm_phase8_8d1c4a_result.md) y [plan 8D1-C](fsm_phase8_8d1c_microblocks.md); próximo **8D1-C4B** (copias profundas y validación de datos del SDK). Se mantienen 25 pruebas manuales pendientes (15 Fedora, 10 Android).

## Potok — 8D1-C3 PASS; próximo 8D1-C4A (2026-11-02)

- [CI 41566863222](https://github.com/mercurysama/Flujo/actions/runs/41566863222) **SUCCESS 85/85** en `1989bf6fc52b52903770c8c53ec4207f304cd2af`. Las rutas reales Ready, Timer, Constructor y Method carecen de capacidad FSM aun con runtime activo o cuando Method hereda `StateUpdate`; las fases FSM sí reciben acceso acotado. Cero cambios productivos.
- [Reporte C3](fsm_phase8_8d1c3_result.md) y [plan 8D1-C](fsm_phase8_8d1c_microblocks.md). Próximo **8D1-C4A**: Add→Change desde SDK. Pruebas humanas fase 7, 15 Fedora + 10 Android, continúan pendientes.

## Potok — 8D1-C2 PASS; próximo 8D1-C3 (2026-11-02)

- [CI 41565743817](https://github.com/mercurysama/Flujo/actions/runs/41565743817) **SUCCESS 84/84** en `4c867d45d6bc5878eb42cd57bdf6c08279a40049`. Cuatro registros independientes con ID idéntico, dos controladores y dos máquinas, SDK acotado y `FlowGraph` intacto; cero cambios de producción.
- [Reporte 8D1-C2](fsm_phase8_8d1c2_result.md) y [plan de microbloques](fsm_phase8_8d1c_microblocks.md). Próximo **8D1-C3**: Ready/Timer/Constructor y rutas no FSM sin capacidad. Fase 7 conserva 25 pruebas humanas pendientes (15 Fedora + 10 Android).

## Potok — 8D1-C1B PASS; próximo 8D1-C2 (2026-11-02)

- [CI 41563021661](https://github.com/mercurysama/Flujo/actions/runs/41563021661), commit `1df32fdbb0ccba29eede437bc3f1ae6b33374a33`: **SUCCESS 83/83**. Focal SDK de reset/stop/reinicio/grafo y regresiones aprobadas; sin cambios de producción.
- [Reporte C1B](fsm_phase8_8d1c1b_result.md), [reporte C1A](fsm_phase8_8d1c1a_result.md) y [microbloques C1–C5](fsm_phase8_8d1c_microblocks.md).
- Próximo **8D1-C2**: aislamiento de dos `PVController` con grafo compartido y máquinas múltiples. 25 pruebas manuales fase 7 siguen pendientes (15 Fedora, 10 Android).

## Potok — 8D1-C1A PASS, siguiente 8D1-C1B (2026-11-02)

- [CI 41562328203](https://github.com/mercurysama/Flujo/actions/runs/41562328203), HEAD `f315ddb1d459f1685da2a339647008a501a47aef`: **SUCCESS 82/82**. Sin cambios productivos.
- Contrato SDK de referencia retenida tras StateEnter caracterizado; [resultado](fsm_phase8_8d1c1a_result.md) y [plan 8D1-C](fsm_phase8_8d1c_microblocks.md).
- 25 pruebas humanas de fase 7 siguen pendientes (15 Fedora, 10 Android). Próximo 8D1-C1B: Update/Exit, parada/reinicio y grafo.

## Potok — Phase 8 active; Phase 7 physical acceptance explicitly deferred (2026-11-02)

- Maintainer authorized moving to **Phase 8** without performing the 25 physical acceptance tests now. **Phase 7 implementation and automatic coverage finished, but final visual acceptance remains deferred/PENDING**, not a signed-off release. F01–F15 Fedora and A01–A10 Android must be revisited before a stable merge/release; see [manual matrix](fsm_phase7_7f2_manual_acceptance_matrix.md).
- **8A dynamic-state audit launched:** [contract and gap inventory](fsm_phase8_8a_gap_audit.md). Existing FSM-003 runtime already includes dynamic registration, lookup, activation, deletion, lifetime/data access and a runtime focal; avoid restarting it. Audit identifies narrow tests needed for quota, determinism, re-registration, edge cases and SDK capability boundary.
- **Next microblock 8B1:** tests-first on dynamic-state identity/quota/re-registration/deterministic listing. Preserve existing API and schema; no changes to runtime without proven defect. Branch `feature/fsm-runtime-flow-flusso`; no merge to `main`.
- Baseline before 8A: `30bb62256f09c50ec195f9ff01b23635c2fc9394`, [GitHub Actions 41538641710](https://github.com/mercurysama/Flujo/actions/runs/41538641710) completed SUCCESS. Audit documentation CI must be verified separately.


## Potok — FSM feature branch Phase 7F-1D4 audit (2026-11-02)

- **Scope-specific branch:** `feature/fsm-runtime-flow-flusso`. This Potok track is distinct from the earlier `feature/block-builder-fprint-dogfood` Fluo-preview and Akis tracks documented below; those histories are not replaced or reclassified.
- **Last functionally validated milestone:** **7F-1D3**, [CI 41526101676](https://github.com/mercurysama/Flujo/actions/runs/41526101676) completed **SUCCESS 76/76** on `4ee94e7bf88238e4215665b7312628dafae4aa2e`. Scope covers native Fluo/Flusso Add/Edit/Revertir/Close/Move/Duplicate/Delete and the SDK editor-to-PackedScene persistence journey. Latest documentation-only commits require independent verification.
- **Phase 7F-1D4:** audit + [traceability report](fsm_phase7_7f1d4_audit.md) and [manual test matrix](fsm_phase7_7f2_manual_acceptance_matrix.md); catalog adds `FLUJO-BHV-POTOK-{PHASE-UI,SDK,PERSIST,MANUAL}-001` so previous automated milestones and unapproved manual tests are separately tracked.
- **Remaining gate:** **15 Fedora + 10 Android** physical interaction scenarios `PENDING`; complete matrix before claiming 7F-2 or accepting a stable release. Fluo Preview 1 historical Android load/render is earlier evidence, not Potok manual acceptance. No `main` merge, runtime/schema migration, demo mutation or new Godot release.
- **Continuity:** original [7F-1D contract](fsm_phase7_7f1d_contract.md), [7F-1D3 result](fsm_phase7_7f1d3_result.md), [FSM journal](fsm_iteration_01_learning.md), and current [manual matrix](fsm_phase7_7f2_manual_acceptance_matrix.md). The next work unit is formal audit closure/CI and **7F-2** manual validation on actual devices.


## Active UI delivery — Fluo Preview 1

- **Branch:** `feature/block-builder-fprint-dogfood`.
- **Validated functional checkpoint:** `cd7e969c38193d718c948262107d1f7a45ca8083`.
- **Frozen code backup:** `backup/fluo-preview-1-2026-10-27` at the same checkpoint.
- **Preview package:** `Flujo-0.1.0-fluo-preview.1`; `plugin.cfg` remains `0.1.0`.
- **Naming:** Fluo = complete sliding drawer; Flow = left block panel; Flusso = right selected-block configuration panel; Inspector = Godot Inspector.
- **Inspector rule:** no duplicate Blocks list belongs in the Inspector. Existing container rows such as `Processes → Flujo`, `Flujo 1`, Timers, Constructor, or Methods are the entry points.
- **Open rule:** double-click or Enter on an existing Inspector container opens Fluo with Flow visible and Flusso initially closed. Flow focuses the first existing block, or the first Add-block button when empty.
- **Block rule:** double-click or Enter on a Flow block opens Flusso. Closing Flusso returns real keyboard focus to the same selected Flow block after rebuild.
- **Persistence rule:** Flusso configuration changes are live/immediate; Escape only closes. Revertir restores the persistent configuration snapshot captured when that Flusso session opened.
- **Keyboard:** Up/Down uses native Flow list movement; Ctrl+PageUp/PageDown cycles Flow blocks; plain PageUp/PageDown cycles the current Inspector container view and synchronizes the Inspector's visible selection while keyboard focus stays in Flow; Alt+PageUp/PageDown cycles Flusso controls and Shift reverses that Alt direction.
- **Drawer:** side switch moves the complete Fluo drawer left/right. First Escape closes Flusso when open; the next Escape closes Fluo.
- **Legacy surface:** the plugin no longer mounts the visible `Flujo` dock or registers `Open Fluo (POC)`; `vp_flujo_dock.gd` remains only for isolated compatibility coverage. Fluo is the primary F4, menu, and Inspector surface.
- **Manual evidence:** desktop interaction was repeatedly approved during implementation. On 2026-10-27 the full-project preview opened under Godot on Android and visibly rendered Fluo, Flow and Flusso. This is load/render evidence, not a claim that the full Android interaction matrix is complete.
- **Automation evidence:** the final focal editor/regression run on 2026-10-29 passed; known editor-layout and teardown diagnostics remain recorded separately.

Read [Project memory / handoff](project_memory.md) and [Fluo Preview 1](fluo_preview_01.md) before continuing this branch.

Custom-block SDK research and the recovered requirements for `flujo-block-builder` are consolidated in [Custom Block SDK and Block Builder Skill Research](custom_block_sdk_research.md). The research confirms the external manifest/catalog/factory/hooks foundation and the normal Flow/Fluo external Add integration are implemented; D4-A, D4-B and the D4-C generic Flusso renderer are complete, with the D4-C manual Flusso review approved. The canonical contract has no technical D4-D delivery or D4-D A–E acceptance matrix; the historical `D4-D NEXT` wording is retired, not a pending implementation task. D5 is the next eligible ecosystem delivery.

## D0 — Block ecosystem contract

The reconciled block ecosystem roadmap is documented in [Flujo Block Ecosystem Plan](flujo_block_ecosystem_plan.md), and the maintainer-approved architectural boundary is frozen in [Flujo Block Ecosystem Contract](block_ecosystem_contract.md).

D0 is documentation/governance only. It fixes the D0–D9 implementation order, one distributable block per package, manual authoring as a first-class path, `flujo-block-builder` as optional automation, Theme/Motion ownership in the Fluo host, generic Flow/Flusso integration requirements, declared provenance separated from cryptographic authenticity, and gradual compatibility-first migration of official blocks to independent Mercury packages. Functional implementation begins only in later numbered deliveries.

## D1 — Manual Block SDK profile

D1 is specified by [Manual Block SDK Profile Contract](manual_block_sdk_contract.md). It proves the one-block-per-package manual authoring profile over the existing manifest loader, script validator, editor catalog and external factory without modifying `addons/vp_flujo/`, connecting the normal Flow Add path, or claiming generic Flusso support.

The canonical D1 fixture lives under `tests/fixtures/manual_block_sdk/` and is test evidence rather than an installed user package. D1 did not include presentation metadata; the later D4-A contract now names the optional sidecar `block_property_presentation.json`. `provenance.json` remains intentionally outside D1.

## D2 — Theme + Motion contract

D2-A is specified by [Fluo Theme + Motion Contract](fluo_theme_motion_contract.md). It freezes the editor-side ownership, Container/layout boundary, focus/input rules, transition state semantics and offset-transform safety requirements before any functional Motion refactor.

D2-A changes documentation only and runs the current Fluo baseline. D2-B may modify production only after the required `$flujo-baseline` gate is explicitly invoked for this scope.

### D2 completion — Theme + Motion Foundation

- D0 is complete.
- D1 is complete.
- D2-A is complete.
- D2-B1 is complete, including the Godot 4.7 offset-transform characterization.
- D2-B2 is complete, including the host-owned Theme boundary and Motion foundation.
- The desktop manual review is complete: `Desktop manual review PASS — maintainer approval 🙆‍♀️ — 2026-10-27`.

The Theme + Motion foundation now exists without visible animation polish. D8 remains responsible for final Motion visual/polish work; D2 does not add visible Motion.

The host architecture is:

```text
FluoDrawer
├── Backdrop
└── DrawerMotionShell
    └── DrawerPanel
```

Backdrop and DrawerMotionShell are siblings. `DrawerMotionShell` is the single Motion boundary and `DrawerPanel` remains inside it. D2 validates `visual_only=false` for the interactive shell, keeps Theme ownership in the host/editor, installs no global Theme, uses a synchronous state machine, provides a reduced-motion policy boundary, and uses no Tween or animation path. Flow, Flusso, and ScrollContainer content remain under their logical Container/layout ownership; Backdrop is not transformed.

The desktop evidence covered open/close, X, exterior click, Escape hierarchy, Flow focus, Flusso return focus, Page/Ctrl+Page/Alt+Page navigation, left/right switching, long scroll, equivalent visual appearance, and absence of visible Motion. Android is not approved by this review.

## D3 — External catalog in the real Add row — D3 COMPLETE

### D3 closure record

**Status:** `D3 COMPLETE` — automated A–E PASS, manual desktop review PASS, and `$flujo-prove` PASS.

D3 closure: `D3 COMPLETE — PROVE PASS — READY FOR D4`.

D3 is the generic external-authoring and persistence/runtime delivery. Its architecture is:

- **Phase A — editor-only authoring composition:** `FlowEditorBlockAuthoringContext`, `FlowEditorBlockCreationResult`, integrated plus external catalog/factory composition, the canonical production package root, and an injectable fixture root for tests.
- **Phase B — generic Add command:** `FlowGraphEditorCommands.add_ready_block_by_authoring_id(...)`; integrated blocks remain registry-backed, external blocks use the external factory, failures are atomic, Undo/Redo reuses the same block and FlowId, and the creation path is independent of the compatible host container.
- **Phase C — catalog-driven Add UI:** `FlowReadyProcessEditor` enumerates generic catalog entries rather than concrete external types; button identity is `authoring_id`; UI and commands share one authoring context; Add Call Method remains separate.
- **Phase D — pre-D4 generic Flusso compatibility:** external blocks use the common selection/activation path; no external-specific UI is added; `message` is intentionally hidden; Flusso-owned properties are `display_name`, `enabled`, `text`, and `method_id`; Revertir snapshots only properties owned by rendered controls, leaving unknown exported external properties untouched. A property on `FlowBlock` is not thereby Flusso-owned. Reflection and presentation metadata belong to D4; their reusable contract is now D4-A.
- **Phase E — persistence/runtime:** external blocks survive PackedScene save/reload with the same FlowId, script path, exported data, order and process identity; runtime consumes the persisted `FlowBlock` through the generic executor without editor authoring context, catalog, manifest or factory, fallback, or substitution.

Automated D3 evidence is recorded as A–E PASS. The required focal paths are the authoring-context, external command Add, catalog-driven editor, owned-property Revertir, persistence/runtime, manual SDK profile, and the existing runtime/editor regressions listed in the behavior catalog.

### D3 manual desktop review

`D3 manual desktop review: PASS`

Environment: `Godot 4.7.2 stable Flathub`

Observed: Manual Output was available through production package discovery in Process and Timer; it could be added and selected; Enter/double activation opened Flusso with generic controls; `message` was not rendered; Block Name/Enabled and Revertir worked; multiple external instances, Delete, Undo/Redo, separate Add Call Method, and built-ins all remained available. The known `SplitContainer dragger_index` visual diagnostic is recorded separately. This review does not claim visual FlowId inspection; FlowId persistence/identity is automated-test evidence.

D3 does not include Android/touch manual acceptance unless explicitly performed. D4-A is complete, D4-B provides the runtime-safe metadata/reflection descriptor boundary, and D4-C provides the complete generic Flusso property renderer with approved manual visual evidence. D4 is complete at the defined A/B/C boundary; no D4-D scope is approved.

## Continuity checkpoint — initial `flujo-block-builder` (2026-10-28)

This checkpoint records the initial Builder Skill after D3. It does **not** start
D4, create a custom block, or authorize IF/While/Do/For implementation.

| Milestone | Status | Current boundary |
| --- | --- | --- |
| D0 | **COMPLETE** | Block ecosystem contract and governance frozen. |
| D1 | **COMPLETE** | Manual one-block-per-package SDK profile proven. |
| D2 | **COMPLETE** | Theme/Motion host boundary and foundation proven. |
| D3 | **COMPLETE** | Generic Add, external Undo/Redo, owned-property boundary, persistence/runtime and container-independent creation path proven; manual desktop review and `$flujo-prove` passed. |
| D4-A | **COMPLETE** | Reusable generic property/presentation architecture is frozen and accepted as the D4 boundary. |
| D4-B | **COMPLETE** | Runtime-safe reflection, validated sidecar metadata and deterministic generic property descriptors are implemented; no UI or ownership registration. |
| D4-C | **COMPLETE — MANUAL PASS** | Descriptor-driven generic Flusso controls, live editing, ownership, diagnostics, Process/Timer equivalence and Revertir are accepted by manual review. |
| D4-D | **NOT DEFINED** | The canonical contract defines no delivery, requirements, dependencies, or A–E acceptance matrix. A future D4-D requires a new numbered specification and approval. |

The Builder run was `RUN_ID=159c0dbf-1f91-49ad-af20-58b75b2aab24`. Its actual
output ended with `FLUJO-BLOCK-BUILDER V1 SKILL READY — NO BLOCK GENERATED`.
The created artifact is only
`tools/agent_skills/flujo-block-builder/SKILL.md`; its checks reported
`git diff --check` PASS, the behavior-catalog validator PASS, and the model smoke
marker `[Flujo] Model mist test passed`. The headless editor load exited normally
with the known `dragger_index` diagnostic and planned-shutdown
`Scan thread aborted...` warning. The initial and final run inventories show no
custom block package, no Builder-created production edit, and no commit.

The governing architecture is:

- The Skill automates the public Block SDK; **the Skill is not the SDK**.
- Manual GDScript, JSON and ordinary readable package files remain first-class and equivalent.
- One distributable block is one package under `res://flow_packages/<package_id>/`.
- Generated packages have no Builder runtime dependency and must remain manually maintainable.
- Every request uses the mandatory planning gate in `tools/agent_skills/flujo-block-builder/SKILL.md`: recover context → classify capability → specify → plan implementation → plan validation → human review → `🙆🏻` explicit approval → build/validate/test/manual review as applicable.
- Capability classifications are mixed when needed: A = SDK-supported now; B = SDK-supported but authoring-limited; C = SDK extension required; D = core-only capability. C/D requests stop with an explained plan and approval; the Builder never silently patches Flujo core.
- A `FlowBlock` is container-agnostic. Do not create `ProcessMyBlock`, `TimerMyBlock` or `IfMyBlock` variants; compatible containers control sequence timing while the block preserves its own behavior.
- IF, While, Do / Do While and For are future custom blocks that must eventually use this public Builder workflow, not private control-flow creation paths. IF remains unimplemented; While/Do/For have no sufficiently complete approved specifications and must not be invented.
- Theme, Motion, focus, layout and standard interaction remain owned by the Fluo host/editor, never by a package.

The current handoff at this checkpoint was D4 next, before the subsequent D4-A
contract-only delivery. The protected `demo/main.tscn` change remains untouched.
The checkpoint itself is documentation and Skill memory only; no full Godot suite
was required for that prior scope beyond the repository-governed checks recorded
above.

## D4-A — Generic Block Property / Presentation Contract — COMPLETE

D4-A is documentation-only and is specified by [FlowBlock Property Presentation Contract](flow_block_property_presentation_contract.md).
It freezes a reusable, UI-independent descriptor boundary built from limited
Godot property reflection plus optional data-only
`block_property_presentation.json` metadata. The model/script remains
authoritative for property existence, type, current/default values, and
persistence. The contract defines eligible properties, supported scalar types
and standard hints, deterministic ordering, invalid-metadata fallback,
Flusso-owned-property registration, Revertir snapshots, container independence,
and runtime-safe reuse.

The terminology deliberately replaces the historical `editor_schema.json`
proposal because the same safe presentation description may later serve the
runtime Game Debug Panel. The future panel is an architectural constraint, not a
D4-A implementation. It must not require editor APIs, and its initial edits are
live-runtime-only without implicit scene/package/source write-back.

Production generic rendering is implemented by D4-C from the D4-B descriptor
layer. No custom block or `IF`/`While`/`Do`/`For` implementation is authorized by
this contract.

## D4-C — Generic Flusso renderer — COMPLETE — MANUAL PASS

D4-C implements the descriptor-driven Flusso surface authorized by D4-A and D4-B.
`FlowEditorBlockAuthoringContext.describe_block_properties()` resolves optional
package-relative presentation metadata through the reusable runtime catalog; the
editor does not parse metadata itself. `FlowReadyProcessEditor` creates common
controls from descriptor `presentation_kind`, excludes actively explicit built-ins
to prevent duplicates, presents diagnostics, and registers Flusso ownership only
after an editable generic control is created. Live edits use the descriptor-
validated `FlowGraphEditorCommands.set_ready_property_descriptor_live()` boundary,
preserving the existing undo/live-edit path. Session snapshots and Revertir cover
only the rendered owned set.

The focal test `tests/editor/flow_generic_flusso_property_editor_test.gd` covers
bool, int, float, String, StringName, range, enum, multiline, labels, order,
groups, tooltips, diagnostics, live editing, ownership, Revertir, built-in collision
protection, and Process/Timer equivalence. The behavior entry is
`FLUJO-BHV-FLUO-GENERIC-PROPERTY-001`. Proportionate persistence/runtime and
editor regressions also pass. No schema, manifest, runtime execution, custom block,
control-flow block, or protected `demo/main.tscn` change is part of D4-C.

Manual visual review is complete for the rendered Flusso field surface, multiline
editing, labels/tooltips, keyboard focus, scrolling, Theme presentation,
empty/diagnostic states, save/reopen interaction and navigation. Android/touch
acceptance remains a separate Preview 1 gate.

### D4-C closure record

`D4-C COMPLETE — MANUAL FLUSSO REVIEW PASS`

Environment: `Godot 4.7.2 stable Flathub`; human approval: `🙆‍♀️`.

- **Process PASS; Timer PASS; container independence PASS:** `manual_output:output` was available in the Add row and the same generic configuration worked in both containers.
- **Generic property controls PASS:** Boolean, String multiline, enum selector, ranged int, plain String, ranged float, StringName and User Note multiline rendered and edited correctly; presentation labels, deterministic order, groups and headings were visible.
- **Live editing PASS; Revertir PASS:** edits were live, close/reopen preserved the edited state, and Revertir restored the session snapshot.
- **Multiple instances PASS:** Descriptor Output instances remained independent; no duplicate Block Name, Block Enabled or other explicit built-in controls appeared.
- **Flow/Flusso behavior PASS:** scrolling, navigation and selection remained functional; no package-specific visual branch was observed.
- **Console evidence:** real Add, Edit and Revertir operations were observed for Descriptor Output in Process and Timer.
- The only visible engine diagnostic was the known `scene/gui/split_container.cpp:124 - Index dragger_index = 2 is out of bounds`, classified as non-blocking. The `unsupported_property_type` diagnostic is intentional fixture/contract behavior for the D4 v1 scalar boundary; supported types were not expanded and diagnostic presentation was not redesigned.

The temporary `flow_packages/manual_output/` package was removed after review;
the canonical fixture under `tests/fixtures/` remains. The D4-C review is closed
by the Major Increment Checkpoint below.

## Major Increment Checkpoint — D4-C / D5 boundary — 2026-10-29

### D4-D audit result

The canonical [Flujo Block Ecosystem Contract](block_ecosystem_contract.md)
defines D4-A, D4-B and D4-C, then proceeds directly to D5. It contains no
technical D4-D scope, requirement set, dependency list, or A–E acceptance
matrix. Therefore D4 is complete at D4-C; `D4-D NEXT` is a stale continuity
label, not an authorized task. If a future delivery is called D4-D, it must
first receive its own numbered specification, plan, acceptance matrix and
maintainer approval.

### D5 definition

D5 means a **functional `flujo-block-builder v1`**, not merely the planning
Skill. The functional delivery must generate and validate an ordinary,
one-block package through the public SDK, produce deterministic and manually
reproducible files, reject unsupported or invalid requests through the A/B/C/D
capability gate, and prove the package through Flow Add, Flusso, persistence
and runtime without a Builder runtime dependency or a silent Flujo-core patch.
The current `tools/agent_skills/flujo-block-builder/SKILL.md` is planning-ready
only. The approved Guardería package exists as ordinary dogfood evidence, but
functional `flujo-block-builder v1` and FPrint v1 are not complete.

`FPrint` is the approved first dogfood slice for this workflow and is distinct
from legacy `Print`. The slice is frozen as package
`mercury.fprint`, type `fprint`, authoring ID `mercury.fprint:fprint`, with the
literal exported fields `prefix`, `message`, and `suffix`, and output
`prefix + message + suffix`. Runtime, persistence, Flow Add and Flusso are all
implemented through the existing public contracts; no core extension was needed.

### D5 dogfood status — FPrint Guardería

**Status:** `FPRINT GUARDERÍA MANUAL PASS`

**Closure:** `FPRINT GUARDERÍA CLOSED — EDITOR CLEANUP READY FOR MANUAL REVIEW`

The ordinary package lives under `res://flow_packages/mercury.fprint/` with
`manifest.json`, `block.gd`, and `block_property_presentation.json`. Automated
coverage proves manifest/discovery, FlowOutputBlock validation, public catalog
Add, FlowId identity, generic Prefix/Message/Suffix rendering and live editing,
Revertir, duplication, independent instances, ResourceSaver/PackedScene reload,
runtime dependency separation, static audits, and one compatible `Process` host.
The delivery intentionally does not claim Timer, State Machine, or future
container coverage. Manual Godot review approved the visible Add, Flusso,
Revertir, independent-instance, exact Process execution, Inspector → Fluo entry,
Fluo-primary F4/menu path, and active-block deletion/Undo/Redo behavior.
This closes the Guardería slice only; functional `flujo-block-builder v1` is not
declared complete. FPrint Kínder K3 is tracked separately and does not migrate
the package or introduce a visual chip.

### FPrint Kínder — K3 Generic Chip Descriptor — READY

K3 adds the public, runtime-safe Generic Typed Chip System boundary under
`addons/vp_flujo/runtime/model/`: `FlowChipTypeDescriptor`,
`FlowChipTooltipData`, and the descriptor/label/tooltip queries on
`FlowChipSegment`. `FlowLiteralValueSegment` is the first consumer for the
stable `literal_value` type, deterministic labels, and ordered Type/Value/Variant
tooltip fields. The descriptor data is ephemeral and UI-neutral; no visual chip,
editor widget, color, FPrint migration, or future VariableRef/Expression/
NodePropertyRef type is included.

The focal evidence is `tests/model/flow_chip_descriptor_test.tscn`; the existing
structured-document and FPrint Guardería paths remain separate regressions.

> **Builder Lesson Candidate:** Los bloques que necesiten contenido mixto de
> texto + valores estructurados no deben construir chips privados. Deben
> consumir el Generic Typed Chip System público.

### FPrint Kínder — K4 Generic Chip Visual + FlowStructuredDocumentEditor — MANUAL REVIEW PENDING

K4 adds the editor-only `FlowChipControl` and
`FlowStructuredDocumentEditor`. The visual surface preserves ordered text and
chip segments, keeps text literal (including whitespace, Unicode and `@/#/$`),
selects chips by `segment_id`, and uses the editor's
`EditorUndoRedoManager` for insertion, deletion, typed literal edits and text
edits. `+ Value` is the only K4 chip creation path and starts with int `0`.

The runtime boundary remains editor-independent: only the generic typed edit
contract was added to `FlowChipSegment`/`FlowChipTypeDescriptor`; the visual
controls, Theme adapter and review harness live under `addons/vp_flujo/editor/`.
FPrint Guardería still retains `prefix`, `message` and `suffix`; no package
migration or parser was added. The focal evidence is
`tests/editor/flow_structured_document_editor_test.tscn`. Manual approval is
still required for the visible chip, selection, tooltip, editing,
multiline/text-symbol behavior and Undo/Redo checklist.

> **Builder Lesson Candidate:** Los bloques que necesiten edición de contenido
> estructurado deben reutilizar `FlowStructuredDocumentEditor` y el Generic
> Typed Chip Control; no deben crear widgets privados por tipo de bloque.

### FPrint Kínder — K5 Structured Document Package Integration — AUTOMATIC PASS — MANUAL REVIEW PENDING

K5 is specified by [FPrint Kínder K5 Contract](fprint_kinder_k5_contract.md).
It integrates the existing `FlowStructuredDocument`, generic descriptor/catalog
presentation, `FlowStructuredDocumentEditor`, and public Typed Chip System into
the ordinary `mercury.fprint` package. `document` is optional: `null` keeps the
Guardería composition `prefix + message + suffix`; a present document renders
in place of `message` and uses `prefix + rendered_document + suffix`.

The generic descriptor/Flusso resource presentation is the smallest approved C
extension. Package data, Process runtime, and persistence remain A capabilities;
private package widgets, parsers, and control-flow/core changes are D/out of
scope. No FPrint-specific editor, `FPrintChip`, automatic legacy conversion,
graph schema, manifest v1 field, or functional Builder v1 claim is introduced.

Automatic evidence covers reflection, Flow Add, Flusso enable/editing,
Unicode/multiline text with escaped-@ and literal #/$, typed chip insertion/deletion, owner-scoped
Undo/Redo, Revertir snapshots, duplication, ResourceSaver/PackedScene reload,
legacy/structured Process output, and runtime/editor boundary audits through
the K5 behavior-catalog entries. The K4 focal test remains a regression.
The refreshed escaped-@ expectation, K4 regression, and proportionate model,
editor, and runtime runs pass; the integrated manual K5 checklist remains
pending. The visual smoke review is not treated as maintainer approval and does
not cover save/reopen or the full Unicode/multiline/tooltip/selection checklist.

> **Builder Lesson Candidate:** Los bloques con contenido estructurado opcional
> deben declarar el campo público y reutilizar el renderer/editor genérico; no
> deben convertir `message` implícitamente ni mantener un editor privado.

> **Builder Lesson Candidate:** El historial de edición de contenido debe usar
> el `PVController` propietario y snapshots profundos que preserven los IDs al
> revertir, mientras la duplicación persistente genera IDs nuevos.

## Flujo Chips Core Step 1B — SCHEMA + SLOTS + VALUE SOURCE — READY

Step 1B establishes the reusable runtime/model contract independently of FPrint:
`FlowChipFieldSchema`, `FlowChipSlotDefinition`, `FlowValueSource`, and the first
real `FlowLiteralValueSource`. Neutral FIXED, FLEXIBLE, and HYBRID fixtures cover
semantic slot identity, variadic limits, accepted exact types/source kinds,
documentation/runtime/disabled text policy, read-only diagnostics, duplication,
and ResourceSaver round-trips. `FlowLiteralValueSegment` remains the K1/K2
persistent compatibility path and exposes `get_value_source()` without a
destructive migration.

The focal evidence is
`tests/model/flow_chip_core_step_1b_test.tscn`, with Step 1A, K1/K2, K3, K4,
and FPrint regressions remaining separate. This step adds no inline interface,
caret, parser, trigger, block runtime, FPrint integration, or concrete For/If/
Process block.

> **Builder Lesson Candidate:** Cada bloque que utilice chips debe declarar un
> `FlowChipFieldSchema` reusable en lugar de implementar reglas privadas de
> cantidad, orden, tipos y obligatoriedad.

> **Builder Lesson Candidate:** Los valores ejecutables de chips deben
> expresarse mediante `FlowValueSource`, no mediante widgets o texto visible.

## Flujo Chips Step 2A — Inline Chip Field — READY FOR MANUAL REVIEW

Step 2A introduces the reusable editor-side `FlowChipFieldEditor`. It consumes
`FlowChipFieldSchema` and `FlowStructuredDocument`, keeps text and
`FlowChipControl` instances in one inline flow, and uses real `TextEdit` caret
positions to split text only at the insertion point. `FlowStructuredDocumentEditor`
remains a compatibility name that delegates to the generic field editor.

The editor now exposes schema-aware FIXED, FLEXIBLE, and HYBRID interaction,
segment-id selection, whole-chip keyboard deletion/navigation, structured
`FlowChipTooltipData` tooltips, typed literal editing, minimal validation
feedback, and `EditorUndoRedoManager` history for text, values, insertion,
deletion, type changes, and allowed movement. `insert_value_source_at_caret()`
is the future drag/source boundary; it has no SceneTree or node-picker
dependency. The neutral Tools-menu harness exposes all three fixture modes.

Automatic evidence is `tests/editor/flow_chip_field_editor_step_2a_test.gd`
and the compatibility K4 focal `tests/editor/flow_structured_document_editor_test.gd`.
The maintainer's Step 2A manual checkpoint confirmed FIXED, FLEXIBLE, HYBRID,
chip selection, and chip editing from beginning to end. Step 2B is the current
delivery for continuous text input and complete literal insertion.

## Flujo Chips Step 2B — TEXT INPUT + LITERAL INSERTION — COMPLETE

Step 2B keeps the active native `TextEdit`/`LineEdit` controls alive during
`text_changed` and value changes, so continuous typing preserves focus, caret,
selection behavior, Unicode/IME input, and paste content. `+ Value` now opens a
reusable schema-filtered literal selector for Bool, Int, Float, String, and
StringName with safe typed defaults. FLEXIBLE and HYBRID insertion respects
accepted types and the HYBRID variadic zone; FIXED schema-generated chips keep
their declared types/defaults.

Automatic evidence is `tests/editor/flow_chip_field_editor_step_2b_test.gd`;
the neutral review harness remains
`tests/editor/flow_structured_document_editor_harness.tscn`. The protected
`demo/main.tscn` remains outside this delivery. The prior functional/manual
Step 2B PASS and the Godot Expert/UI audit remain the acceptance evidence; this
micro-fix adds schema-cause-specific `+ Value` feedback without changing the
accepted HYBRID Bool/Int intersection.

### Flujo Chips Step 2B.1 — SCHEMA RESTRICTION FEEDBACK

The generic editor now distinguishes a schema maximum, an invalid caret/zone,
and an empty literal intersection when `+ Value` has no options. Limits and
accepted value/source types remain defined by `FlowChipFieldSchema` and its
slot definitions; no block-specific rule is added.

## Flujo Chips Step 2C-A — `@` TRIGGER + VARIABLE REF — READY FOR MANUAL REVIEW

Step 2C-A adds the generic graph-owned `FlowVariableRefValueSource` and
`FlowVariableRefSegment`. The source persists only its stable source ID,
variable ID, and declared type; display names are resolved from the active
`FlowGraph.variables` collection. `FlowVariableSelector` is a reusable popup
with schema filtering, search, keyboard/mouse/touch-capable activation, and
Escape cancellation.

The native text surface recognizes only unescaped `@`. `\\@` becomes literal
`@` and `\\\\` becomes literal `\\`; `#` and `$` remain inactive. FLEXIBLE and
HYBRID insert VariableRef at the caret in the declared variadic zone. FIXED
replaces the adjacent compatible generated chip while preserving its
`segment_id` and `slot_id`. The same `FlowChipControl` renders the reference;
graph renames update its label without changing its binding ID.

The selector gives Search focus on open and supports Arrow Up/Down, Enter, and
Escape without a prerequisite mouse click. A selected Variable Tok exposes
structured source details and a generic `Change Variable` action; double-click
or Enter opens the same selector for a schema/slot-filtered reference change.
The change preserves `segment_id`, `slot_id`, location, and source identity,
updates `variable_id`/declared type, and uses the owning document history.
Cancellation is history-free; missing references remain unresolved until an
explicit repair selection.

Graph-aware validation reports missing-variable and declared-type mismatch
diagnostics without repairing authored data. ResourceSaver reload,
duplication, editor Undo/Redo, Unicode text, cancellation, and invalid visual
state are covered by the model/editor focal tests. The neutral manual harness
now includes Count, Enabled, Message, Position, and Tint graph variables.

Automatic evidence:

- `tests/model/flow_variable_ref_step_2c_a_test.tscn`
- `tests/editor/flow_chip_field_editor_step_2c_a_test.gd`

Manual Godot review remains pending. Step 2C-A does not implement `#`, `$`,
Expression, NodePropertyRef, drag/drop, runtime value resolution, FPrint
migration, or any change to the protected `demo/main.tscn`.

### Flujo Chips Step 2C-A.1 — TOK EDITABILITY + CARET RESTORATION — READY FOR MANUAL REVIEW

Step 2C-A.1 is the required correction before any `#` or `$` trigger work.
The numbered contract is [flow_chip_field_step_2c_a_1_contract.md](flow_chip_field_step_2c_a_1_contract.md).
It keeps required presence, editability, deletion, type lock, and source-kind
lock independent; makes Variable Tok click/double-click/Enter editing use
stable IDs and one owning-document history action; and restores semantic
TextEdit focus/caret when insertion or Tok editing is cancelled. `#` and `$`
remain inactive literals, and `+ Value` remains harness/debug-only.

The focal evidence is
`tests/editor/flow_chip_field_editor_step_2c_a_1_test.gd`. The corrected FPrint
escaped-`@` expectation and proportionate model/editor/runtime regressions pass;
the active-trigger scanner now limits detection to the native edit span so a
previously normalized literal `@` is not reactivated by a later edit. `$flujo-prove`
is the final verification gate. Manual review remains required for the
immutable/locked Tok presentation and focus checklist.

### Flujo Chips Step 2C-A.2 — UNIFIED UNDO + TOK EDITING — READY FOR MANUAL REVIEW

Step 2C-A.2 is now automatic PASS for the unified document-history boundary. The
focused String Tok route uses the contextual `LineEdit` through `text_changed`,
`text_submitted`, and `focus_exited`; each value-edit session is keyed by the
Tok `segment_id` and native control, captures one `before → after` transition,
and updates continuous typing without creating per-character Akis actions.
`Ctrl+Z`, `Ctrl+Shift+Z`, and `Ctrl+Y` remain captured by the owning
`FlowChipFieldEditor` before native LineEdit/TextEdit history, and Undo/Redo
updates the existing LineEdit without rebuilding it.

The corrected focal covers String, StringName, Tok focus, Akis text focus, and
mixed text/String chronology. The prior String divergence came from using
`UndoRedo.MERGE_ENDS` for value actions: a String action could merge with a
previous same-named value action (including Int) in the editor history, so Undo
consumed the wrong transition and Redo did not restore the String. Per-session
`MERGE_DISABLE` actions remove that cross-Tok merge while preserving continuous
writing. Tests that create document history must begin only after Godot finishes
restoring the editor layout (`loading_editor_layout`); startup history activity
is not document evidence.

Automatic evidence is `tests/editor/flow_chip_field_editor_step_2c_a_2_test.gd`
and `tests/editor/flow_chip_field_editor_history_shortcut_cycle_test.gd`.
Manual Godot review remains required for the neutral harness focus, native
LineEdit/TextEdit editing, cancellation, and visual presentation checklist.

### Flujo Chips Step 2C-B — `#` TRIGGER + EXPRESSION TOK — READY FOR MANUAL REVIEW

Step 2C-B adds the runtime-safe `FlowExpressionValueSource` and generic
`FlowExpressionSegment`, backed by a fixed catalog of `add`, `greater_than`,
`equal`, and `and` exact signatures. Expressions persist only their operator ID
and ordered Literal/VariableRef operands; result type and preview are derived.
The numbered contract is
[flow_chip_field_step_2c_b_contract.md](flow_chip_field_step_2c_b_contract.md).

The native text surface recognizes unescaped `#` at the real caret. `\#` is a
literal `#`, and `$` remains inactive. A detached popup draft lets the user
choose an operator and typed operands; Confirm inserts or replaces one
Expression Tok through the owning document history, while Cancel restores the
semantic text/caret without history. FIXED, FLEXIBLE, and HYBRID acceptance is
still schema/slot-driven, and the neutral harness now includes an EXPRESSION
fixture.

Automatic evidence is `tests/model/flow_expression_step_2c_b_test.tscn` and
`tests/editor/flow_chip_field_editor_step_2c_b_test.gd`. Manual Godot review
remains required for popup focus, keyboard navigation, caret insertion,
escaped/literal trigger behavior, cancellation, existing Tok editing,
save/reopen, and Undo/Redo. `$`, NodePropertyRef, nested expressions, textual
parsing, drag/drop, runtime value resolution, FPrint migration, and
`demo/main.tscn` remain out of scope. This checkpoint is not a COMPLETE claim.

### Flujo Chips Step 2C-B.1 — EXPRESSION EDITOR USABILITY + PERSISTENCE

Step 2C-B.1 is the focused correction for the human review findings in the
Expression popup. The numbered contract is
[flow_chip_field_step_2c_b_1_contract.md](flow_chip_field_step_2c_b_1_contract.md).
Operand rows now react synchronously to Source kind and Literal type, expose
editable int/float/String controls or a bool toggle, filter and bind compatible
graph variables, and keep Confirm disabled for missing VariableRefs. Existing
Expression Toks load their full semantic content into a detached draft.

The neutral harness now provides explicit Save Expression Fixture, Reload Saved
Expression, and Reset Saved Expression actions. Save/load covers the document
and its fixture graph under the ignored `.godot/flujo_tests/` review area; it is
not a production persistence path. The real ResourceSaver/ResourceLoader focal
uses `Count + 1`, and insertion assigns the declared variadic `slot_id` instead
of weakening the validator. `$`, NodePropertyRef, nesting, parsing, runtime
evaluation, StringName Expression operands, and `demo/main.tscn` remain out of
scope. Automatic evidence and manual review are still separate gates.

### Compatibility decisions protected by this checkpoint

- Official Mercury blocks and external/user blocks use the same public SDK and
  package contract; official status does not create a private route.
- Legacy `Print`, `Custom Hello` and `Everything Flows` remain available and
  unchanged for compatibility/reference. `Add Call Method` remains a separate
  editorial category and route. `FlowBlockRegistry` is not changed here.
- The canonical future distribution profile is one block per package, while
  the manifest v1 loader remains compatible with historical multi-descriptor
  manifests. No graph schema or manifest v1 field is added by this checkpoint.
- Official-block migration remains gradual and compatibility-first; persisted
  script paths, IDs, scenes and supported projects require an explicit shim or
  migration before any later migration removes the integrated route.

## Iteration 7 planning — Typed Variables

- **Latest completed iteration:** Iteration 6 — Constructor and Reusable Methods.
- **Integration:** `06d759cf3c53bae95fbf2c022873cbef4d7db94e` on 2026-09-07T22:01:55-06:00. See the [Iteration 6 postmortem](iteration_06.md).
- **Primary environment:** Fedora with Godot 4.7.2. Windows remains a supported compatible platform; no Windows-specific workflow is required.
- **Approved planning contract:** [Typed Variables contract](typed_variables_contract.md). Implementation begins only through its numbered deliveries.

### Implemented

- Schema 3 persistent structure, deterministic validation, deep duplication, and PackedScene persistence coverage.
- Atomic schema 2 → 3 migration that preserves validated schema 2 data and creates an empty constructor and methods collection.
- `FlowConstructorDefinition` as a specialized `FlowBlockContainer`, including inherited blocks and ordered nullable dependencies.
- Reusable method definitions and typed parameter declarations as persistent structural data.
- Persistent `FlowMethodCallBlock` references from constructor, method, process, and state containers, with deterministic schema/reference validation and order-independent duplication remapping.
- Optional typed `FlowMethodReturnDefinition` declarations with global identity validation, deep duplication, and ResourceSaver/PackedScene persistence.

### Iteration 7 scope

- Preserve the existing seven-member `FlowVariableDefinition.ValueType` taxonomy and its typed defaults without changing numeric serialization values.
- Delivery 2 implemented: deterministic validation rejects out-of-range `Scope`, `Binding`, and shared `ValueType` metadata while preserving invalid values and existing schema 2/3 compatibility.
- Delivery 3 implemented: smoke, `ResourceSaver`, and `PackedScene` regressions cover every canonical typed field through schema 2/schema 3 duplication and schema 2 to 3 migration, preserving IDs, references, order, `null` positions, and independent copies.
- Delivery 4 implemented: the Godot Inspector owns schema 3 Variable structure—ordered nullable list, stable-ID selection, add, move, and confirmed delete—while the Flujo panel edits only the selected variable's typed options. A plugin-owned editor-only coordinator relays the active `PVController` and selection without persisting UI state. Stable-ID selection remains correct when keyboard focus naturally remains elsewhere; popup close and undo/redo do not force focus. A stronger unfocused-selection shade is deferred as a visual improvement. It preserves inactive typed values, nullable collection positions, schema 1/schema 2 behavior, and invalid enum metadata until an explicit replacement.
- Delivery 5 implemented: editor regressions cover keyboard entry to an unselected schema 3 Variables list, arrow-key row selection, native Tab/Shift+Tab focus traversal, Enter/Escape behavior, Ctrl+Enter for multiline String and Note fields, `OptionButton`, COLOR, and Delete confirmation. Public plugin metadata, controls, dialogs, tooltips, undo/redo labels, and mechanically translatable plugin comments are English. Semantic stable-ID selection remains independent from keyboard focus. Automated evidence is complete; manual visual approval remains pending.
- Temporary user-experience debt: schema 3 creation currently follows `Create FlowGraph → migrate schema 2 → migrate schema 3`. This is not the intended final creation workflow and requires a separately approved design.
- A friendly separate user guide is deliberately deferred to a separately approved follow-up; it is not implemented by Delivery 5.

### Deliberately pending

- Implementation of the remaining `ARGRET` contract: argument bindings, value-source validation, return blocks, and incomplete-return-path validation.
- Recursion and call-cycle validation.
- Dependency bindings, general runtime state, and execution beyond the scoped Constructor, Ready, Timer and one-level method starter paths.
- Constructor dependency authoring and method parameter/return authoring.
- Enumerators, nullable values, persistent object references, and value-source resources; these require an approved schema 4 contract and migration.

### Not implemented by Iteration 6

This iteration has not introduced argument bindings, return blocks or runtime return values, value-source connections, cycle detection, an executor, scene bindings, method-call execution, runtime mutation, or editor interface for schema 3 declarations.

### Current delivery

- Schema 5 runtime attribute stores now include catalog-backed inherited layouts, controller-owned INSTANCE values, declaring-class CLASS routing within the active `SceneTree`, and requester visibility checks with the symmetric PRIVATE name exception. Focused coverage verifies three-level base-to-derived layout, stable-ID collisions, access, exact types, nullability, readonly/const rejection, reset, scene continuity and deterministic teardown; general model, persistence, schema 3 runtime and editor regressions pass. Schema 5 remains excluded from executable block paths. Call frames, accessors, UI, and Apply Constructor remain pending. See FOBJ-001/002/003/005/009 in the [Flujo Object Model contract](flow_object_model_contract.md).

- Declarative Constructor persistent foundation on `feature/declarative-constructor`: schema 4 requirements, deterministic structural validation, deep duplication, confirmed 3→4 migration and the public 2→3→4 chain are implemented, with ResourceSaver/PackedScene focal coverage and passing general regressions. Controller-owned relative binding dictionaries remain independent across controllers and scene instances sharing one graph. Constructor blocks/dependencies are preserved as inert legacy data. Schemas 1–3 retain their behavior; the executor still accepts only schema 3. Apply Constructor, scene-node creation, declarative UI, binding resolution and runtime verification remain pending under the [Declarative Constructor contract](declarative_constructor_contract.md).

- Schema 5 object-model foundation on `feature/declarative-constructor`: the existing graph ID is class identity; portable UID/path catalog entries, single-inheritance validation, INSTANCE/CLASS attribute definitions, typed reference resources, ordered method outputs, deep duplication and atomic 4→5 / 2→3→4→5 migration are implemented. Existing Variables and controller bindings remain separate and unchanged. Initial runtime attribute stores are described above; call frames, accessors, overloads, polymorphic execution, schema 5 execution, editor authoring and Apply Constructor remain pending under the [Flujo Object Model contract](flow_object_model_contract.md).

- Constructor/Methods vertical delivery on `feature/constructor-methods`: `CMRUN-001`–`CMRUN-006` in the [Constructor and Methods contract](constructor_methods_contract.md) reuse schema 3 unchanged. Inspector order is Constructor → Processes → Timers → State Machines → Methods → Variables; all configuration remains in Flujo. Constructor is unique/non-removable and executes once before Ready in controlled controller startup. Methods have independent names, Enabled and starter blocks; Ready/Timer Call Method blocks resolve stable target IDs and skip invalid targets without stopping later blocks. Existing output signals remain, with additional method/call context. Parameters, returns, recursion, nested calls and bindings remain deferred. Automated focal and general regression evidence is complete; visual validation remains pending.

- Delivery 7 is implemented: the editor-only Flow interaction coordinator specified by `TVAR-016` provides explicit `GODOT`, `FLOW`, and `GAME` states, an editor-configurable F4 default, and an equivalent dock button. In GODOT, F4 reuses a controller below the current hierarchy target or creates exactly one undoable `PVController` below the selected editable node/scene root, then selects it and enters FLOW. It uses weak focus references, suspends editing and controller creation during actual game execution, and does not change schemas, runtime execution, or variable-model data. Automated coverage is complete; the required manual visual review remains pending.
- Ready starter delivery on `feature/processes-ready-runtime`: schema 3 reuses the existing Processes and block model; only Ready, configurable Print, and fixed Everything Flows are implemented. Block names are persistent visible metadata and never runtime dispatch. Output is console text plus a structured runtime signal; there is no on-screen presentation or debugger transport. Schema 2 remains migration coverage only. See `READY-001`–`READY-009` in the [model contract](model_contract.md). Automated verification is complete; manual visual acceptance remains pending. No export or performance work belongs to this delivery.
- Process and Timer authoring delivery on `feature/processes-ready-runtime`: schema 3 keeps one polymorphic Processes collection and presents Timers as a filtered Inspector view. The Inspector orders Processes, Timers, State Machines, then Variables, and owns their Add actions and selection lists; the Flujo panel owns selected Process, Timer, and Variable configuration and structural actions. Each schema 3 collection uses its own `Flujo`, `Flujo 1`, … sequence. Ready and Timer blocks retain independent subtype/container visible-name sequences with compatible Print/Everything Flows defaults, ID-based rename actions, Enter/Escape, and F2 access with complete text selection; Print uses a subtly contrasting theme-derived multiline surface. Runtime dispatch remains based on subtype and ID. Timers remain visually neutral; process-type colors and Page Up/Page Down navigation are deferred. State Machine editing remains deferred. Enabled one-shot or repeating Timers use transient runtime `Timer` nodes and the same ordered Print/Everything Flows executor and output boundary as Ready. Schema 2 remains migration-only and schema 4 is not introduced. See `TIMER-001`–`TIMER-008` and `READY-009` in the [model contract](model_contract.md). Automated verification is complete; manual visual acceptance remains pending.

### Next delivery

For the block ecosystem, D4 is complete at D4-C. D4-D is not defined or
authorized; any future D4-D must be separately specified and approved. FPrint
Guardería is closed after its manual pass, but functional `flujo-block-builder
v1` remains incomplete. K3 Generic Chip Descriptor is ready; K4 is implemented
and awaiting manual visual approval; K5 automatic evidence passes while its
integrated manual review remains pending; D6 remains future work.
Android/touch acceptance remains outside D4-C and is still governed by the Fluo
Preview 1 hardening sequence: portrait/landscape, touch targets, scrolling,
double-tap activation, keyboard behavior, focus restoration, Page navigation and
drawer side placement. The legacy visible Flujo dock and obsolete POC entry
surface are no longer production-mounted; their reusable implementation remains
isolated for compatibility tests and must not become the primary surface again.

Constructor/Methods, Typed Variables, schema 4/5 and runtime work remain governed by their existing contracts; Fluo preview hardening must not silently expand those scopes. The friendly user guide remains a separately approved follow-up.

Update this file after each approved Iteration 7 delivery so it remains a brief, factual handoff.

Todo es Flujo; todo fluye. 🌊


## Major Increment Checkpoint — Akis/Tok Lot 10 — 2026-10-31

Lotes 02–10 del impulso Akis/Tok están implementados en
`feature/block-builder-fprint-dogfood`. El contrato de cierre es
[flow_akis_tok_lot_10_contract.md](flow_akis_tok_lot_10_contract.md).

### Estado funcional alcanzado

- `@` Variable, `#` Condition, `~` Operation y `$` Node/Node Property
  comparten el mismo documento Akis y el mismo `FlowValueSource` runtime.
- Array, Dictionary, Resource, Enum y Bitfield forman parte del mismo sistema y
  pueden participar en composición anidada.
- Array/Dictionary authoring ya puede crear Scalar, Variable, Operation,
  Condition, Node, Node Property, Array, Dictionary, Resource, Enum y Bitfield,
  reutilizando los editores públicos existentes.
- Akis puede resolverse a texto compuesto o a un valor tipado único.
- `FlowPrintBlock.content` consume Akis en runtime sin eliminar el fallback
  compatible `text`.
- Graph Variables soportan Array/Dictionary/Resource defaults, runtime override
  por instancia y detección de ciclos. BOOL..COLOR conservan 0–6 como taxonomía
  escalar compartida; los tipos complejos son una extensión exclusiva de Variables
  y no amplían Method parameters/returns ni Schema 5 Attributes/Outputs.
- Duplicación del grafo remapea Variable IDs y Requirement IDs dentro de árboles
  ValueSource y Akis de bloques después de completar el mapa de identidades.
- Schema 4 entra al runtime existente para Ready/Process y Timer con
  `requirement_bindings` validados. Sus `constructor.blocks` legacy siguen
  inertes; Apply Constructor y creación declarativa de Nodes continúan
  pendientes.
- Schema 5 continúa fuera del executor Ready/Timer.

### Evidencia preparada

- `tests/model/flow_integration_lot_10_test.tscn`
- `tests/runtime/flow_integration_lot_10_test.tscn`
- `tests/editor/flow_integration_lot_10_editor_test.gd`
- `tests/model/flow_tok_matrix_lot_10_test.tscn`
- focales de Lotes 02–09 ya versionados en `tests/`.

El catálogo registra las nuevas conductas Lot 10 como `not_run` y el gate
visual como `manual_pending`. Esta sesión GitHub-only no dispone de un
ejecutor Godot/Flatpak, por lo que no reclama una ejecución fresca ni un PASS.

### Siguiente paso

No hay un Lote 11 implícito. El siguiente paso es el **gate único de Godot
4.7.2** definido en el contrato de Lote 10: focales afectados, regresiones,
save/reopen, Undo/Redo y revisión visual integrada. Sólo esa evidencia puede
cambiar el estado a aprobado.

Todo es Flujo; todo fluye. 🌊
