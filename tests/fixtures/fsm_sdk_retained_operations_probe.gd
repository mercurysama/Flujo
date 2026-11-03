@tool
extends FlowBlock

## Potok 8D1-C1A: simulated SDK block retains the callback-local facade.
## This is a test fixture, not an installed package or a security sandbox.
@export var template_state_id: String = ""


func get_navigation_decision(context: FlowNavigationContext) -> FlowNavigationDecision:
	var owner: Node = context.controller
	if owner == null:
		return FlowNavigationDecision.continue_execution()
	var operations: FlowFSMOperations = context.get_fsm_operations()
	var created_id: String = ""
	if operations != null:
		created_id = operations.register_state(
			template_state_id, "",
			FlowFSMDynamicStateRecord.Lifetime.SESSION,
			{"origin": "inside_callback", "nested": {"count": 1}}
		)
	var observed: Array = owner.get_meta("potok_8d1c1_records", [])
	observed.append({
		"phase": String(context.entry_point),
		"operations": operations,
		"created_id": created_id
	})
	owner.set_meta("potok_8d1c1_records", observed)
	return FlowNavigationDecision.continue_execution()
