# Potok 7D-1 — Condition Tok # in Flusso, automated checkpoint

**Date:** 2026-11-01 (Actions timestamps UTC 2026-11-02). **Branch:** `feature/fsm-runtime-flow-flusso`. **Contract:** [7D-1 Condition Tok contract](fsm_phase7_7d1_condition_tok_contract.md), commit `34d047109a6235c6ec62d3bd9ad97d1f2521aea6`.

- **RED:** `tests/editor/flow_fsm_condition_tok_bridge_test.gd` commit `e61ac400d09bc26deb792d98cdd6b0b8e700ea4b`; CI step `420306685378fec1fce17f4f6624f7925b39306c`. [Actions 41380931279](https://github.com/mercurysama/Flujo/actions/runs/41380931279) FAIL, expected while the Flusso bridge button did not exist.
- **Implementation:** `6f1161692994a99044aa0195ad8621cd718d5cf5` wires the existing `FlowConditionEditor` popup into Potok's selected transition. The original graph remains unchanged until valid confirmation; a detached Condition Tok # source is submitted via existing `set_fsm_transition_property(...,&"condition", source)` as one Undo/Redo action. The EVENT/CONDITION trigger type is never implicitly changed. The original condition is preserved if Cancel, Escape, X or popup dismissal occurs.
- **Negative test fix:** `18e6333f8b2c38ad79d30533ecda5645b433b0bf` simulates stale Confirm during the same frame **before** Godot reclaims an invalidated popup; previously the harness itself called a method on an already freed instance. It tests that changing the selected state invalidates a pending commit.
- **Full GREEN:** [Actions 41381250681](https://github.com/mercurysama/Flujo/actions/runs/41381250681) SUCCESS for new editor focal and previous Potok and Ready/navigation regressions.

**Accepted boundary:** full visual Condition Tok comparison authoring via the already implemented popup, unchanged resource until Confirm, condition source history roundtrip, guarded selected-controller/machine/state/edge identity. The popup can prepare a condition while an edge still has EVENT trigger. No new separate editor graph, model schema, or runtime changes in this sublot.

This 7D-1 result alone does not implement event-payload-to-expression access. That is covered by [7D-2](fsm_phase7_7d2_result.md) with separate evidence. Human Android UI approval and save/reopen persistence remain due in 7E.
