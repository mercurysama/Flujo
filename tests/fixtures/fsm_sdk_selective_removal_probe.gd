@tool
extends FlowBlock

## Potok 8D1-C4C1: SDK removes inactive aliases while preserving other requests.
## All mutations pass through the callback-bound FlowFSMOperations facade.
@export var role: String = ""
@export var template_state_id: String = ""
@export var other_target_id: String = ""


func get_navigation_decision(context: FlowNavigationContext) -> FlowNavigationDecision:
	var owner: Node = context.controller
	if owner == null or context.entry_point != &"StateUpdate":
		return FlowNavigationDecision.continue_execution()
	var key: String = "potok_8d1c4c1_done_" + role
	if owner.get_meta(key, false):
		return FlowNavigationDecision.continue_execution()
	owner.set_meta(key, true)
	var operations: FlowFSMOperations = context.get_fsm_operations()
	var result: Dictionary = {
		"role": role, "phase": String(context.entry_point),
		"facade": operations
	}
	if operations != null and role == "sibling":
		result["queued_sibling"] = operations.change_state(other_target_id)
	elif operations != null and role == "remove":
		var retired: String = operations.register_state(
			template_state_id, "",
			FlowFSMDynamicStateRecord.Lifetime.SESSION, {"role": "retired"}
		)
		var survivor: String = operations.register_state(
			template_state_id, "",
			FlowFSMDynamicStateRecord.Lifetime.SESSION, {"role": "survivor"}
		)
		result["retired"] = retired
		result["survivor"] = survivor
		result["first_retired_queued"] = operations.change_state(retired)
		result["survivor_queued"] = operations.change_state(survivor)
		result["second_retired_queued"] = operations.change_state(retired)
		result["removed"] = operations.remove_state(retired)
		result["retired_absent"] = not operations.has_state(retired)
		result["retired_data_empty"] = operations.get_state_data(retired).is_empty()
		result["retired_change_rejected"] = not operations.change_state(retired)
		result["double_remove_rejected"] = not operations.remove_state(retired)
		result["survivor_present"] = operations.has_state(survivor)
	var records: Array = owner.get_meta("potok_8d1c4c1_records", [])
	records.append(result)
	owner.set_meta("potok_8d1c4c1_records", records)
	return FlowNavigationDecision.continue_execution()
