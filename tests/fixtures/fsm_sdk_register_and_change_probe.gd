@tool
extends FlowBlock

## Potok 8D1-C4A: SDK block registers a templated alias and queues activation.
## No direct FlowFSMRuntime access is used in this fixture.
@export var template_state_id: String = ""


func get_navigation_decision(context: FlowNavigationContext) -> FlowNavigationDecision:
	var owner: Node = context.controller
	if owner == null:
		return FlowNavigationDecision.continue_execution()
	var operations: FlowFSMOperations = context.get_fsm_operations()
	var alias: String = ""
	var queued: bool = false
	var resolved: bool = false
	var observed_data: Dictionary = {}
	if operations != null:
		alias = operations.register_state(
			template_state_id,
			"",
			FlowFSMDynamicStateRecord.Lifetime.SESSION,
			{"source": "SDK", "nested": {"level": 4}}
		)
		if not alias.is_empty():
			resolved = operations.has_state(alias)
			observed_data = operations.get_state_data(alias)
			queued = operations.change_state(alias)
	var records: Array = owner.get_meta("potok_8d1c4a_records", [])
	records.append({
		"phase": String(context.entry_point),
		"facade": operations,
		"alias": alias,
		"resolved": resolved,
		"queued": queued,
		"data": observed_data
	})
	owner.set_meta("potok_8d1c4a_records", records)
	return FlowNavigationDecision.continue_execution()
