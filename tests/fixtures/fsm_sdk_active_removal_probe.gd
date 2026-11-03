@tool
extends FlowBlock

## Potok 8D1-C4C2: a callback-bound SDK probe, no direct runtime method use.
## The positive outside-tick callback is driven by the shared executor test seam.
@export var role: String = ""
@export var template_state_id: String = ""


func get_navigation_decision(context: FlowNavigationContext) -> FlowNavigationDecision:
	var owner: Node = context.controller
	if owner == null:
		return FlowNavigationDecision.continue_execution()
	var operations: FlowFSMOperations = context.get_fsm_operations()
	var record: Dictionary = {
		"role": role,
		"phase": String(context.entry_point),
		"authorized": operations != null,
		"facade": operations
	}
	if operations != null and role == "create":
		if not owner.get_meta("potok_8d1c4c2_created", false):
			owner.set_meta("potok_8d1c4c2_created", true)
			var active_id: String = operations.register_state(
				template_state_id, "",
				FlowFSMDynamicStateRecord.Lifetime.SESSION, {"role": "active"}
			)
			var fallback_id: String = operations.register_state(
				owner.get_meta("potok_8d1c4c2_fallback_template", ""), "",
				FlowFSMDynamicStateRecord.Lifetime.SESSION, {"role": "fallback"}
			)
			owner.set_meta("potok_8d1c4c2_active_id", active_id)
			owner.set_meta("potok_8d1c4c2_fallback_id", fallback_id)
			record["active_id"] = active_id
			record["fallback_id"] = fallback_id
			record["queued"] = operations.change_state(active_id)
	elif operations != null and role == "remove":
		var alias: String = owner.get_meta("potok_8d1c4c2_target", "")
		var fallback: String = owner.get_meta("potok_8d1c4c2_target_fallback", "")
		record["target"] = alias
		record["fallback"] = fallback
		if context.entry_point == &"StateUpdate":
			record["removed"] = operations.remove_state(alias, fallback)
		else:
			var disabled: String = owner.get_meta("potok_8d1c4c2_disabled", "")
			var foreign: String = owner.get_meta("potok_8d1c4c2_foreign", "")
			record["invalid_fallbacks_rejected"] = true
			for invalid: String in ["", alias, "missing", disabled, foreign]:
				if operations.remove_state(alias, invalid):
					record["invalid_fallbacks_rejected"] = false
			record["before_valid_still_present"] = operations.has_state(alias)
			record["removed"] = operations.remove_state(alias, fallback)
			record["target_absent"] = not operations.has_state(alias)
			record["fallback_present"] = operations.has_state(fallback)
			record["second_remove_rejected"] = not operations.remove_state(alias, fallback)
			record["target_data_empty"] = operations.get_state_data(alias).is_empty()
	var records: Array = owner.get_meta("potok_8d1c4c2_records", [])
	records.append(record)
	owner.set_meta("potok_8d1c4c2_records", records)
	return FlowNavigationDecision.continue_execution()
