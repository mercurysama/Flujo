@tool
extends FlowBlock

## Potok 8D1-C4B: exercise only the callback-scoped FSM facade.
## Caller-owned dictionaries and returned data must not alias runtime storage.
@export var template_state_id: String = ""


func get_navigation_decision(context: FlowNavigationContext) -> FlowNavigationDecision:
	var owner: Node = context.controller
	if owner == null:
		return FlowNavigationDecision.continue_execution()
	var operations: FlowFSMOperations = context.get_fsm_operations()
	var expected_initial: Dictionary = {
		"events": [{"score": 3, "flags": [true, null, 2.5]}],
		"name": "initial"
	}
	var expected_updated: Dictionary = {
		"outer": {"inner": [1, 2, 3]},
		"owner": String(owner.name)
	}
	var result: Dictionary = {
		"phase": String(context.entry_point),
		"facade": operations,
		"alias": "",
		"registered": false,
		"registration_detached": false,
		"read_detached": false,
		"set_accepted": false,
		"set_detached": false,
		"second_read_detached": false,
		"invalid": [],
		"final_data": {}
	}
	if operations != null:
		var initial: Dictionary = expected_initial.duplicate(true)
		var alias: String = operations.register_state(
			template_state_id,
			"",
			FlowFSMDynamicStateRecord.Lifetime.SESSION,
			initial
		)
		result["alias"] = alias
		if not alias.is_empty():
			result["registered"] = operations.has_state(alias)
			(initial["events"] as Array)[0]["score"] = 99
			(initial["events"] as Array).append("corrupt")
			result["registration_detached"] = (
				operations.get_state_data(alias) == expected_initial
			)
			var readback: Dictionary = operations.get_state_data(alias)
			(readback["events"] as Array)[0]["score"] = 22
			(readback["events"] as Array).append("read-mutation")
			result["read_detached"] = (
				operations.get_state_data(alias) == expected_initial
			)
			var replacement: Dictionary = expected_updated.duplicate(true)
			result["set_accepted"] = operations.set_state_data(alias, replacement)
			(replacement["outer"] as Dictionary)["inner"] = ["caller-mutation"]
			result["set_detached"] = (
				operations.get_state_data(alias) == expected_updated
			)
			var second_read: Dictionary = operations.get_state_data(alias)
			((second_read["outer"] as Dictionary)["inner"] as Array).append(777)
			result["second_read_detached"] = (
				operations.get_state_data(alias) == expected_updated
			)

			var too_many: Array = []
			too_many.resize(FlowFSMDataValidator.MAX_ENTRIES + 1)
			var too_deep: Variant = "leaf"
			for depth: int in FlowFSMDataValidator.MAX_DEPTH + 1:
				too_deep = [too_deep]
			var live_node: Node = Node.new()
			var invalid_cases: Array[Dictionary] = [
				{"many": too_many},
				{1: "numeric-key"},
				{"number": INF},
				{"text": "x".repeat(FlowFSMDataValidator.MAX_JSON_LENGTH + 1)},
				{"deep": too_deep},
				{"callable": Callable(owner, "get_name")},
				{"vector": Vector2(1, 2)},
				{"node": live_node}
			]
			for i: int in invalid_cases.size():
				var invalid: Dictionary = invalid_cases[i]
				var forbidden_registration: String = operations.register_state(
					template_state_id,
					"",
					FlowFSMDynamicStateRecord.Lifetime.SESSION,
					invalid
				)
				var forbidden_write: bool = operations.set_state_data(alias, invalid)
				(result["invalid"] as Array).append({
					"index": i,
					"registration_rejected": forbidden_registration.is_empty(),
					"write_rejected": not forbidden_write,
					"data_unchanged": operations.get_state_data(alias) == expected_updated
				})
			live_node.free()
			result["final_data"] = operations.get_state_data(alias)
	var all_records: Array = owner.get_meta("potok_8d1c4b_records", [])
	all_records.append(result)
	owner.set_meta("potok_8d1c4b_records", all_records)
	return FlowNavigationDecision.continue_execution()
