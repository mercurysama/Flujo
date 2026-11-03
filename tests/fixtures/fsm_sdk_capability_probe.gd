@tool
extends FlowBlock

## Potok 8D1-B1 probe intentionally uses only the proposed navigation-context
## capability boundary. This test fixture is NOT an installed SDK package.
@export var template_state_id: String = ""

func get_navigation_decision(context: FlowNavigationContext) -> FlowNavigationDecision:
	var controller: Node = context.controller
	if controller == null:
		return FlowNavigationDecision.continue_execution()
	var observations: Array = controller.get_meta("potok_8d1_observations", [])
	var phase: String = String(context.entry_point)
	var observation: Dictionary = {"phase": phase, "available": false, "id": ""}
	if context.has_method("get_fsm_operations"):
		var operations: Variant = context.call("get_fsm_operations")
		if operations is Object and is_instance_valid(operations) 				and operations.has_method("register_state"):
			observation["available"] = true
			if phase != "Ready":
				observation["id"] = operations.call(
					"register_state", template_state_id, "",
					FlowFSMDynamicStateRecord.Lifetime.SESSION, {"phase": phase}
				)
	observations.append(observation)
	controller.set_meta("potok_8d1_observations", observations)
	return FlowNavigationDecision.continue_execution()
