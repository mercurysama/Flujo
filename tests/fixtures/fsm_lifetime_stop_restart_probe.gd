@tool
extends FlowBlock

## Potok 8D2-B1B: retain SDK callback facades across controller stop/restart.
## This fixture performs no mutation; it records actual phase authorization.
@export var authored_state_id: String = ""


func get_navigation_decision(context: FlowNavigationContext) -> FlowNavigationDecision:
	var controller: Node = context.controller
	if controller == null:
		return FlowNavigationDecision.continue_execution()
	var ops: FlowFSMOperations = context.get_fsm_operations()
	var record: Dictionary = {
		"phase": String(context.entry_point),
		"operations": ops,
		"issued": ops != null,
		"can_read_in_callback": ops != null and ops.has_state(authored_state_id)
	}
	var records: Array = controller.get_meta("potok_8d2b1b_records", [])
	records.append(record)
	controller.set_meta("potok_8d2b1b_records", records)
	return FlowNavigationDecision.continue_execution()
