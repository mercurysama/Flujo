class_name FlowStateMachineDefinition
extends Resource


@export_storage var _internal_id: String = FlowId.create()

@export var display_name: String = "State Machine"
@export var enabled: bool = true
@export_multiline var user_note: String = ""
@export var states: Array[FlowStateDefinition] = []
@export_storage var initial_state_id: String = ""


func get_internal_id() -> String:
	return _internal_id


func get_initial_state() -> FlowStateDefinition:
	if initial_state_id.is_empty():
		return null

	for state: FlowStateDefinition in states:
		if state != null and state.get_internal_id() == initial_state_id:
			return state

	return null


func add_state(state: FlowStateDefinition) -> void:
	var has_existing_state: bool = false
	for existing_state: FlowStateDefinition in states:
		if existing_state != null:
			has_existing_state = true
			break

	states.append(state)

	if initial_state_id.is_empty() and state != null and not has_existing_state:
		initial_state_id = state.get_internal_id()


func set_initial_state_by_id(state_id: String) -> bool:
	if state_id.is_empty():
		return false

	for state: FlowStateDefinition in states:
		if state != null and state.get_internal_id() == state_id:
			initial_state_id = state_id
			return true

	return false


func duplicate_with_new_ids() -> FlowStateMachineDefinition:
	var copy: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	var state_id_map: Dictionary[String, String] = {}

	copy._internal_id = FlowId.create()
	copy.display_name = display_name
	copy.enabled = enabled
	copy.user_note = user_note
	copy.states = []

	for state: FlowStateDefinition in states:
		if state == null:
			copy.states.append(null)
			continue

		var state_copy: FlowStateDefinition = state.duplicate_state_with_new_ids()
		copy.states.append(state_copy)
		state_id_map[state.get_internal_id()] = state_copy.get_internal_id()

	if initial_state_id.is_empty():
		for state_copy: FlowStateDefinition in copy.states:
			if state_copy != null:
				copy.initial_state_id = state_copy.get_internal_id()
				break
	elif state_id_map.has(initial_state_id):
		copy.initial_state_id = state_id_map[initial_state_id]
	else:
		copy.initial_state_id = ""

	return copy
