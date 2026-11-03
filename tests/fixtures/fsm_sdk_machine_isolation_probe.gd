@tool
extends FlowBlock

## Potok 8D1-C2: an SDK-style callback probes its own machine and a sibling.
## Intentional: no controller/graph is supplied through the facade.
@export var own_machine_id: String = ""
@export var own_template_id: String = ""
@export var foreign_state_id: String = ""
@export var foreign_template_id: String = ""
@export var shared_alias_id: String = ""


func get_navigation_decision(context: FlowNavigationContext) -> FlowNavigationDecision:
	var owner: Node = context.controller
	if owner == null:
		return FlowNavigationDecision.continue_execution()
	var operations: FlowFSMOperations = context.get_fsm_operations()
	var observation: Dictionary = {
		"machine_id": own_machine_id,
		"phase": String(context.entry_point),
		"facade": operations,
		"alias": "",
		"owns_state": false,
		"wrote_own_data": false,
		"foreign_template_result": "",
		"foreign_state_visible": false,
		"foreign_change_accepted": false,
		"foreign_remove_accepted": false,
		"foreign_write_accepted": false,
		"foreign_read": {}
	}
	if operations != null:
		var alias: String = operations.register_state(
			own_template_id,
			shared_alias_id,
			FlowFSMDynamicStateRecord.Lifetime.SESSION,
			{"machine": own_machine_id, "controller": String(owner.name)}
		)
		observation["alias"] = alias
		observation["owns_state"] = operations.has_state(alias)
		observation["wrote_own_data"] = operations.set_state_data(alias, {
			"machine": own_machine_id,
			"controller": String(owner.name),
			"written_from_callback": true
		})
		observation["foreign_template_result"] = operations.register_state(foreign_template_id)
		observation["foreign_state_visible"] = operations.has_state(foreign_state_id)
		observation["foreign_change_accepted"] = operations.change_state(foreign_state_id)
		observation["foreign_remove_accepted"] = operations.remove_state(foreign_state_id)
		observation["foreign_write_accepted"] = operations.set_state_data(
			foreign_state_id, {"wrong_machine": true}
		)
		observation["foreign_read"] = operations.get_state_data(foreign_state_id)
	var observations: Array = owner.get_meta("potok_8d1c2_observations", [])
	observations.append(observation)
	owner.set_meta("potok_8d1c2_observations", observations)
	return FlowNavigationDecision.continue_execution()
