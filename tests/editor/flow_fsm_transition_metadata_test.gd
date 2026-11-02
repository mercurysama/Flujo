@tool
extends SceneTree

## Potok 7C-2A: existing transition metadata, candidate validation and Flusso.
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	for i: int in 5:
		await process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if not _check(manager != null, "Godot editor undo manager available"):
		quit(1)
		return
	var host := Control.new()
	host.name = &"Potok7C2AHost"
	host.size = Vector2(900, 750)
	get_root().add_child(host)
	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var idle := FlowStateDefinition.new()
	idle.display_name = "Idle"
	var running := FlowStateDefinition.new()
	running.display_name = "Running"
	var foreign_state := FlowStateDefinition.new()
	foreign_state.display_name = "Other Machine"
	var event_edge := FlowStateTransitionDefinition.new()
	event_edge.display_name = "Go"
	event_edge.trigger = FlowStateTransitionDefinition.Trigger.EVENT
	event_edge.event_name = &"advance"
	event_edge.target_state_id = running.get_internal_id()
	var condition_edge := FlowStateTransitionDefinition.new()
	condition_edge.display_name = "Condition"
	condition_edge.trigger = FlowStateTransitionDefinition.Trigger.CONDITION
	condition_edge.condition = FlowLiteralValueSource.new(Variant.Type.TYPE_BOOL, true)
	condition_edge.event_name = &"awake"
	condition_edge.target_state_id = idle.get_internal_id()
	idle.transitions = [event_edge, condition_edge]
	var machine := FlowStateMachineDefinition.new()
	machine.states = [idle, running]
	machine.initial_state_id = idle.get_internal_id()
	var foreign := FlowStateMachineDefinition.new()
	foreign.states = [foreign_state]
	foreign.initial_state_id = foreign_state.get_internal_id()
	graph.state_machines = [machine, foreign]
	var controller := PVController.new()
	controller.flow_graph = graph
	host.add_child(controller)
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Starting authored graph valid")
	var command := FlowGraphEditorCommands.new(manager)
	if not _check(command.has_method("set_fsm_transition_property"),
		"Transition command is available (expected RED)"):
		await _finish(host)
		return
	var mid: String = machine.get_internal_id()
	var sid: String = idle.get_internal_id()
	var eid: String = event_edge.get_internal_id()
	var cid: String = condition_edge.get_internal_id()
	var original_id: String = eid
	var history: UndoRedo = manager.get_history_undo_redo(manager.get_object_history_id(controller))
	_check(not command.set_fsm_transition_property(controller, mid, sid, eid,
		&"target_state_id", foreign_state.get_internal_id()), "Foreign target denied")
	_check(not command.set_fsm_transition_property(controller, mid, sid, eid,
		&"trigger", 999), "Invalid trigger rejected")
	_check(not command.set_fsm_transition_property(controller, mid, sid, eid,
		&"trigger", FlowStateTransitionDefinition.Trigger.CONDITION),
		"EVENT edge cannot switch to CONDITION without Bool source")
	_check(not command.set_fsm_transition_property(controller, mid, sid, eid,
		&"event_name", &""), "Active EVENT cannot have blank event")
	_check(not command.set_fsm_transition_property(controller, mid, sid, eid,
		&"priority", "one"), "Wrong priority type rejected")
	_check(not command.set_fsm_transition_property(controller, mid, sid, eid,
		&"display_name", " "), "Blank transition label rejected")
	_check(not command.set_fsm_transition_property(controller, mid, sid, "missing",
		&"enabled", false), "Missing edge ID rejected")
	_check(not command.set_fsm_transition_property(controller, mid, running.get_internal_id(),
		eid, &"enabled", false), "Wrong source-state ownership rejected")
	_check(not command.set_fsm_transition_property(controller, mid, sid, eid,
		&"condition", FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 3)),
		"Non-Bool condition source rejected")
	_check(event_edge.target_state_id == running.get_internal_id() and
		event_edge.trigger == FlowStateTransitionDefinition.Trigger.EVENT and
		event_edge.event_name == &"advance", "Rejected edits leave original edge untouched")
	_check(not history.has_undo(), "Rejections do not create UndoRedo actions")
	_check(command.set_fsm_transition_property(controller, mid, sid, eid,
		&"priority", 42), "Priority edit accepted")
	_check(event_edge.priority == 42 and history.has_undo(), "Priority committed")
	history.undo()
	_check(event_edge.priority == 0, "Priority undo restores original")
	history.redo()
	_check(event_edge.priority == 42, "Priority redo restores value")
	_check(command.set_fsm_transition_property(controller, mid, sid, eid,
		&"target_state_id", idle.get_internal_id()), "Target can be owned source state")
	_check(command.set_fsm_transition_property(controller, mid, sid, eid,
		&"display_name", "Return"), "Transition title commit")
	_check(command.set_fsm_transition_property(controller, mid, sid, eid,
		&"user_note", "User edge"), "Transition note commit")
	_check(command.set_fsm_transition_property(controller, mid, sid, eid,
		&"enabled", false), "Transition enabled toggle accepted")
	_check(command.set_fsm_transition_property(controller, mid, sid, eid,
		&"event_name", &"restart"), "Event name edited")
	var new_bool := FlowLiteralValueSource.new(Variant.Type.TYPE_BOOL, false)
	_check(command.set_fsm_transition_property(controller, mid, sid, eid,
		&"condition", new_bool), "Validated Bool condition source assigned")
	_check(command.set_fsm_transition_property(controller, mid, sid, eid,
		&"trigger", FlowStateTransitionDefinition.Trigger.CONDITION),
		"Prepared Bool source allows CONDITION")
	_check(event_edge.condition == new_bool and
		event_edge.trigger == FlowStateTransitionDefinition.Trigger.CONDITION,
		"Mode change preserves condition source")
	history.undo()
	_check(event_edge.trigger == FlowStateTransitionDefinition.Trigger.EVENT and
		event_edge.condition == new_bool, "Undo restores EVENT without losing source")
	history.redo()
	_check(event_edge.trigger == FlowStateTransitionDefinition.Trigger.CONDITION,
		"Redo selects CONDITION")
	_check(command.set_fsm_transition_property(controller, mid, sid, cid,
		&"trigger", FlowStateTransitionDefinition.Trigger.EVENT),
		"Prepared condition edge can switch to stored EVENT")
	_check(condition_edge.condition != null and condition_edge.event_name == &"awake",
		"Opposite trigger retains both metadata fields")
	_check(event_edge.get_internal_id() == original_id and idle.transitions[0] == event_edge,
		"Authored edge identity and order unchanged")
	var property := FlowGraphInspectorProperty.new()
	property.configure(manager)
	property.configure_for_fluo()
	host.add_child(property)
	property.set_dock_controller(controller)
	property.set_dock_variable_selection(controller, FlowGraphEditorCommands.Collection.STATE_MACHINES, mid)
	await _frames(5)
	var transitions: ItemList = property.find_child("PotokTransitionList", true, false) as ItemList
	_check(transitions != null and transitions.item_count == 2,
		"Existing Flow state shows ordered transitions")
	if transitions != null and transitions.item_count == 2:
		_check((transitions.get_item_metadata(0) as Dictionary).get("id") == eid,
			"Transition list carries stable ID")
	_check(property.find_child("PotokTransitionProperties", true, false) != null,
		"Flusso transition property editor renders")
	var priority: SpinBox = property.find_child("PotokTransitionPriority", true, false) as SpinBox
	_check(priority != null, "Native priority control exists")
	if priority != null:
		priority.value = 17
		priority.value_changed.emit(17)
		await _frames(5)
		_check(event_edge.priority == 17, "Flusso SpinBox commits integer priority")
	var target: OptionButton = property.find_child("PotokTransitionTarget", true, false) as OptionButton
	_check(target != null and target.item_count == 2, "Owned target choices visible")
	var event_field: LineEdit = property.find_child("PotokTransitionEvent", true, false) as LineEdit
	_check(event_field != null, "Event metadata input exists")
	_check(property.find_child("PotokTransitionConditionStatus", true, false) != null,
		"Bool condition status is visible without bypassing Tok editor")
	if event_field != null:
		event_field.text = "ui_restart"
		event_field.text_submitted.emit(event_field.text)
		await _frames(4)
		_check(event_edge.event_name == &"ui_restart",
			"Native event field commits StringName without modifying trigger")
	var trigger: OptionButton = property.find_child("PotokTransitionTrigger", true, false) as OptionButton
	_check(trigger != null, "Native trigger selector exists")
	if trigger != null:
		trigger.select(1)
		trigger.item_selected.emit(1)
		await _frames(4)
		_check(event_edge.trigger == FlowStateTransitionDefinition.Trigger.EVENT,
			"Native trigger selector switches to prepared EVENT metadata")
	target = property.find_child("PotokTransitionTarget", true, false) as OptionButton
	if target != null and target.item_count == 2:
		target.select(1)
		target.item_selected.emit(1)
		await _frames(4)
		_check(event_edge.target_state_id == running.get_internal_id(),
			"Native target selector uses owned stable state ID")
		history.undo()
		await _frames(3)
		_check(event_edge.target_state_id == idle.get_internal_id(),
			"Undo restores target after UI command")
	var states_list: ItemList = property.find_child("PotokStateList", true, false) as ItemList
	if states_list != null and states_list.item_count == 2:
		states_list.select(1)
		states_list.item_selected.emit(1)
		await _frames(4)
		transitions = property.find_child("PotokTransitionList", true, false) as ItemList
		_check(transitions != null and transitions.item_count == 1 and
			transitions.get_item_text(0) == "Empty",
			"State with no transitions shows inert Empty placeholder")
		_check(property.find_child("PotokTransitionProperties", true, false) == null,
			"Empty transition does not create an editable edge")
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Graph valid after UI edits")
	_check(graph.state_machines[0].states[0].transitions[0].get_internal_id() == original_id,
		"UI edits preserve authored identity")
	await _finish(host)

func _frames(count: int) -> void:
	for i: int in count:
		await process_frame

func _finish(host: Control) -> void:
	host.queue_free()
	await _frames(3)
	if failures.is_empty():
		print("[Flujo] Potok 7C-2A transition metadata and Flusso passed")
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> bool:
	if not ok:
		failures.append(message)
		push_error("[Flujo] Potok 7C-2A: " + message)
	return ok
