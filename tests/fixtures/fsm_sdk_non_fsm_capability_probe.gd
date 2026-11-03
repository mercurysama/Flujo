@tool
extends FlowBlock

## Potok 8D1-C3: the same SDK probe runs through real non-FSM and FSM entries.
@export var probe_label: String = ""
@export var template_state_id: String = ""


func get_navigation_decision(context: FlowNavigationContext) -> FlowNavigationDecision:
	var owner: Node = context.controller
	if owner == null:
		return FlowNavigationDecision.continue_execution()
	var operations: FlowFSMOperations = context.get_fsm_operations()
	var alias: String = ""
	if operations != null:
		alias = operations.register_state(
			template_state_id, "",
			FlowFSMDynamicStateRecord.Lifetime.SESSION,
			{"label": probe_label, "phase": String(context.entry_point)}
		)
	var records: Array = owner.get_meta("potok_8d1c3_records", [])
	records.append({
		"label": probe_label,
		"entry": String(context.entry_point),
		"operations": operations,
		"alias": alias
	})
	owner.set_meta("potok_8d1c3_records", records)
	return FlowNavigationDecision.continue_execution()
