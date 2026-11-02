@tool
extends SceneTree
## Potok 7C-2B: real Fluo controls, dependency refusal and Cancel/Confirm.
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	for i: int in 5:
		await process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	var history_manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	var host := Control.new()
	host.name = &"Potok7C2BStructureHost"
	host.size = Vector2(950, 820)
	get_root().add_child(host)
	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var a := FlowStateDefinition.new()
	a.display_name = "Source"
	var b := FlowStateDefinition.new()
	b.display_name = "Destination"
	var edge := FlowStateTransitionDefinition.new()
	edge.trigger = FlowStateTransitionDefinition.Trigger.EVENT
	edge.event_name = &"go"
	edge.target_state_id = b.get_internal_id()
	a.transitions = [edge]
	var machine := FlowStateMachineDefinition.new()
	machine.states = [a, b]
	machine.initial_state_id = a.get_internal_id()
	graph.state_machines = [machine]
	var controller := PVController.new()
	controller.flow_graph = graph
	host.add_child(controller)
	var property := FlowGraphInspectorProperty.new()
	property.configure(history_manager)
	property.configure_for_fluo()
	host.add_child(property)
	property.set_dock_controller(controller)
	property.set_dock_variable_selection(
		controller, FlowGraphEditorCommands.Collection.STATE_MACHINES, machine.get_internal_id()
	)
	await _frames(6)
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Valid starting graph")
	_check(_button(property, "PotokStateAdd") != null
		and _button(property, "PotokStateDuplicate") != null
		and _button(property, "PotokStateMoveUp") != null
		and _button(property, "PotokStateMoveDown") != null
		and _button(property, "PotokStateDelete") != null,
		"All native state structure controls visible")
	_check(_button(property, "PotokTransitionAdd") != null
		and _button(property, "PotokTransitionDuplicate") != null
		and _button(property, "PotokTransitionMoveUp") != null
		and _button(property, "PotokTransitionMoveDown") != null
		and _button(property, "PotokTransitionDelete") != null,
		"All native edge structure controls visible")
	var count_before: int = machine.states.size()
	_click(property, "PotokStateAdd")
	await _frames(6)
	_check(machine.states.size() == count_before + 1, "Add state through Flow")
	var new_id: String = machine.states.back().get_internal_id()
	_check(property.get("_potok_selected_state_id") == new_id,
		"New state selected using stable ID")
	_click(property, "PotokStateDuplicate")
	await _frames(6)
	_check(machine.states.size() == count_before + 2
		and machine.states.back().get_internal_id() != new_id,
		"Duplicate state creates independent ID")
	var copied_id: String = machine.states.back().get_internal_id()
	_click(property, "PotokStateMoveUp")
	await _frames(5)
	_check(machine.states[2].get_internal_id() == copied_id,
		"State move up changes authored order")
	# Select B: A has a real incoming edge, so deletion must not open a dialog.
	_select_state(property, b.get_internal_id())
	await _frames(5)
	_click(property, "PotokStateDelete")
	await _frames(4)
	_check(machine.states.size() == 4, "Inbound-dependent deletion refused")
	_check(property.find_child("PotokStructureDeleteDialog", true, false) == null,
		"Blocked deletion never offers misleading confirmation")
	_select_state(property, a.get_internal_id())
	await _frames(5)
	_click(property, "PotokTransitionAdd")
	await _frames(5)
	_check(a.transitions.size() == 2, "Add valid event edge via Flow")
	var new_edge_id: String = a.transitions.back().get_internal_id()
	_check(property.get("_potok_selected_transition_id") == new_edge_id,
		"New edge selected by immutable ID")
	_click(property, "PotokTransitionDuplicate")
	await _frames(5)
	_check(a.transitions.size() == 3
		and a.transitions.back().get_internal_id() != new_edge_id,
		"Duplicate edge gets independent ID")
	_click(property, "PotokTransitionMoveUp")
	await _frames(5)
	var before_cancel: int = a.transitions.size()
	_click(property, "PotokTransitionDelete")
	await _frames(3)
	var dialog: ConfirmationDialog = property.find_child(
		"PotokStructureDeleteDialog", true, false) as ConfirmationDialog
	_check(dialog != null, "Edge delete requires ConfirmationDialog")
	_check(a.transitions.size() == before_cancel, "Opening edge dialog does not mutate model")
	if dialog != null:
		dialog.canceled.emit()
	await _frames(4)
	_check(a.transitions.size() == before_cancel
		and property.find_child("PotokStructureDeleteDialog", true, false) == null,
		"Cancel actually discards pending edge deletion")
	_click(property, "PotokTransitionDelete")
	await _frames(3)
	dialog = property.find_child("PotokStructureDeleteDialog", true, false) as ConfirmationDialog
	if dialog != null:
		dialog.confirmed.emit()
	await _frames(6)
	_check(a.transitions.size() == before_cancel - 1,
		"Only explicit confirmation deletes selected edge")
	var history: UndoRedo = history_manager.get_history_undo_redo(
		history_manager.get_object_history_id(controller)
	)
	history.undo()
	await _frames(5)
	_check(a.transitions.size() == before_cancel, "Undo restores edge after confirmation")
	# Initial A has outgoing edges only; removing it must choose earliest enabled B.
	_select_state(property, a.get_internal_id())
	await _frames(5)
	var states_before: int = machine.states.size()
	_click(property, "PotokStateDelete")
	await _frames(3)
	dialog = property.find_child("PotokStructureDeleteDialog", true, false) as ConfirmationDialog
	_check(dialog != null and machine.states.size() == states_before,
		"Initial state deletion waits for affirmative confirmation")
	if dialog != null:
		dialog.confirmed.emit()
	await _frames(6)
	_check(machine.states.size() == states_before - 1
		and machine.initial_state_id == b.get_internal_id(),
		"Initial-state deletion atomically repairs initial reference")
	history.undo()
	await _frames(5)
	_check(machine.states.size() == states_before
		and machine.initial_state_id == a.get_internal_id(),
		"Undo restores deleted initial state and reference")
	_check(not FlowGraphValidator.validate(graph).has_errors(),
		"Authored graph remains valid after structural UI actions")
	host.queue_free()
	await _frames(3)
	if failures.is_empty():
		print("[Flujo] Potok 7C-2B structural Flusso and true Cancel passed")
	quit(0 if failures.is_empty() else 1)

func _select_state(property: FlowGraphInspectorProperty, id: String) -> void:
	var list: ItemList = property.find_child("PotokStateList", true, false) as ItemList
	if list == null:
		_check(false, "State list available")
		return
	for index: int in list.item_count:
		if String((list.get_item_metadata(index) as Dictionary).get("id", "")) == id:
			list.select(index)
			list.item_selected.emit(index)
			return
	_check(false, "Requested state ID exists in Flow list")

func _button(property: FlowGraphInspectorProperty, name: String) -> Button:
	return property.find_child(name, true, false) as Button

func _click(property: FlowGraphInspectorProperty, name: String) -> void:
	var b: Button = _button(property, name)
	if b != null:
		b.pressed.emit()
	else:
		_check(false, "Missing button " + name)

func _frames(count: int) -> void:
	for i: int in count:
		await process_frame

func _check(ok: bool, message: String) -> bool:
	if not ok:
		failures.append(message)
		push_error("[Flujo] Potok 7C-2B UI: " + message)
	return ok
