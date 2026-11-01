@tool
class_name FlowFSMEditorProjection
extends RefCounted

## Read-only Potok view model for the existing Inspector → Fluo → Flow/Flusso UI.
## All resource IDs remain model-owned. Presentation never creates state resources.

func present(graph: FlowGraph, machine_id: String) -> Dictionary:
	var view: Dictionary = {
		"found": false,
		"empty": false,
		"machine": {},
		"states": [],
		"diagnostics": []
	}
	if graph == null or machine_id.is_empty():
		return view
	for machine: FlowStateMachineDefinition in graph.state_machines:
		if machine == null or machine.get_internal_id() != machine_id:
			continue
		view["found"] = true
		view["machine"] = {
			"id": machine.get_internal_id(),
			"name": machine.display_name,
			"enabled": machine.enabled,
			"auto_start": machine.auto_start,
			"tick_mode": machine.tick_mode,
			"note": machine.user_note,
			"initial_state_id": machine.initial_state_id
		}
		var rows: Array[Dictionary] = []
		for state: FlowStateDefinition in machine.states:
			rows.append(_present_state(state, machine.initial_state_id))
		if machine.states.is_empty():
			view["empty"] = true
			rows.append({
				"id": "",
				"name": "Empty",
				"empty": true,
				"is_initial": false,
				"enabled": false,
				"note": "",
				"phases": [],
				"transitions": []
			})
		view["states"] = rows
		return view
	return view


func _present_state(state: FlowStateDefinition, initial_id: String) -> Dictionary:
	if state == null:
		return {
			"id": "", "name": "Empty", "empty": true,
			"is_initial": false, "enabled": false, "note": "",
			"phases": [], "transitions": []
		}
	var phases: Array[Dictionary] = [
		{"name": "Enter", "blocks": _present_blocks(state.enter_blocks)},
		{"name": "Update", "blocks": _present_blocks(state.blocks)},
		{"name": "Exit", "blocks": _present_blocks(state.exit_blocks)}
	]
	return {
		"id": state.get_internal_id(),
		"name": state.display_name,
		"empty": false,
		"enabled": state.enabled,
		"note": state.user_note,
		# Machine.initial_state_id is authoritative; is_initial is legacy metadata.
		"is_initial": state.get_internal_id() == initial_id,
		"phases": phases,
		"transitions": _present_transitions(state.transitions)
	}


func _present_blocks(blocks: Array[FlowBlock]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for block: FlowBlock in blocks:
		if block == null:
			result.append({"id": "", "name": "Empty", "empty": true, "enabled": false})
			continue
		result.append({
			"id": block.get_internal_id(),
			"name": block.display_name,
			"empty": false,
			"enabled": block.enabled
		})
	return result


func _present_transitions(
		transitions: Array[FlowStateTransitionDefinition]
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for edge: FlowStateTransitionDefinition in transitions:
		if edge == null:
			result.append({
				"id": "", "name": "Empty", "empty": true,
				"enabled": false, "target_state_id": "",
				"trigger": -1, "priority": 0,
				"event_name": "", "condition_present": false, "note": ""
			})
			continue
		result.append({
			"id": edge.get_internal_id(),
			"name": edge.display_name,
			"empty": false,
			"enabled": edge.enabled,
			"target_state_id": edge.target_state_id,
			"trigger": edge.trigger,
			"priority": edge.priority,
			"event_name": String(edge.event_name),
			"condition_present": edge.condition != null,
			"note": edge.user_note
		})
	return result
