@tool
extends SceneTree

## Potok 7E-2C: stable-ID selection, actual focus and detached control safety.
var failures: Array[String] = []
var _host: Control
var _drawer: FluoDrawer
var _editor: FlowGraphInspectorProperty
var _controller: PVController
var _graph: FlowGraph
var _machine: FlowStateMachineDefinition
var _first: FlowStateDefinition
var _selected: FlowStateDefinition
var _other: FlowStateDefinition
var _edge_a: FlowStateTransitionDefinition
var _edge_b: FlowStateTransitionDefinition
var _history: UndoRedo


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for _i: int in 5:
		await process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if not _check(undo != null, "Editor undo manager available"):
		quit(1)
		return
	_host = Control.new()
	_host.name = "Potok7E2CHost"
	_host.size = Vector2(1000, 800)
	get_root().add_child(_host)

	_graph = FlowGraph.new()
	_graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	_graph.constructor = FlowConstructorDefinition.new()
	_first = FlowStateDefinition.new()
	_first.display_name = "Idle"
	_selected = FlowStateDefinition.new()
	_selected.display_name = "Twin"
	_other = FlowStateDefinition.new()
	_other.display_name = "Twin"
	_edge_a = FlowStateTransitionDefinition.new()
	_edge_a.display_name = "First"
	_edge_a.trigger = FlowStateTransitionDefinition.Trigger.EVENT
	_edge_a.event_name = &"first"
	_edge_a.target_state_id = _first.get_internal_id()
	_edge_b = FlowStateTransitionDefinition.new()
	_edge_b.display_name = "Second"
	_edge_b.trigger = FlowStateTransitionDefinition.Trigger.EVENT
	_edge_b.event_name = &"second"
	_edge_b.target_state_id = _other.get_internal_id()
	_selected.transitions = [_edge_a, _edge_b]
	_machine = FlowStateMachineDefinition.new()
	_machine.display_name = "Actor"
	_machine.states = [_first, _selected, _other]
	_machine.initial_state_id = _first.get_internal_id()
	_graph.state_machines = [_machine]
	_controller = PVController.new()
	_controller.name = "Controller"
	_controller.flow_graph = _graph
	_host.add_child(_controller)
	_history = undo.get_history_undo_redo(undo.get_object_history_id(_controller))
	_check(not FlowGraphValidator.validate(_graph).has_errors(),
		"Valid graph with duplicate visible state labels and two edges")

	_drawer = FluoDrawer.new()
	EditorInterface.get_base_control().add_child(_drawer)
	_drawer.configure(undo)
	_drawer.open_container(
		_controller, FlowGraphEditorCommands.Collection.STATE_MACHINES,
		_machine.get_internal_id()
	)
	await _frames(5)
	_editor = _field("FluoFlowEditor") as FlowGraphInspectorProperty
	if not _check(_editor != null and _field("PotokStateList") != null,
			"Existing Inspector machine route renders Potok Flow"):
		await _finish()
		return
	_check(_machine_id() == _machine.get_internal_id() and
		_focused("PotokStateList"), "Initial Inspector machine ID and Flow focus remain intact")

	_select_state(1)
	await _frames(4)
	_check(_state_id() == _selected.get_internal_id() and
		_edge_id() == _edge_a.get_internal_id() and
		_focused("PotokStateList"),
		"Flow resolves duplicate-label state and edge by stable IDs")

	# A focused form field is replaced after each live edit and UndoRedo,
	# yet its semantic focus must be restored to a new instance.
	var original_name: LineEdit = _field("PotokStateName") as LineEdit
	if not _check(original_name != null, "Selected State scalar form exists"):
		await _finish()
		return
	original_name.grab_focus()
	await _frames(2)
	_check(original_name.has_focus(), "Name field owns actual focus before live edit")
	original_name.text = "Running"
	original_name.text_submitted.emit("Running")
	await _frames(5)
	_check(_selected.display_name == "Running" and
		_focused("PotokStateName") and
		_state_id() == _selected.get_internal_id(),
		"Live State edit restores focus to a newly rebuilt name field")
	_check(_field("PotokStateName") != original_name,
		"Focus does not retain the detached LineEdit reference")

	for cycle: int in 2:
		_history.undo()
		await _frames(5)
		_check(_selected.display_name == "Twin" and
			_focused("PotokStateName") and
			_state_id() == _selected.get_internal_id() and
			_machine_id() == _machine.get_internal_id(),
			"Undo cycle %d restores state name, semantic focus and Inspector ID" % (cycle + 1))
		_history.redo()
		await _frames(5)
		_check(_selected.display_name == "Running" and
			_focused("PotokStateName") and
			_state_id() == _selected.get_internal_id(),
			"Redo cycle %d restores state name and focused native field" % (cycle + 1))

	# Transition ItemList and Transition Note must survive a model rebuild.
	_select_edge(1)
	await _frames(4)
	_check(_edge_id() == _edge_b.get_internal_id() and
		_focused("PotokTransitionList"),
		"Transition List keeps keyboard focus and second edge stable ID after selection")
	var note: LineEdit = _field("PotokTransitionNote") as LineEdit
	if _check(note != null, "Existing edge note input found"):
		note.grab_focus()
		await _frames(2)
		note.text = "Changed note"
		note.text_submitted.emit("Changed note")
		await _frames(5)
		_check(_edge_b.user_note == "Changed note" and
			_focused("PotokTransitionNote") and
			_edge_id() == _edge_b.get_internal_id(),
			"Transition live edit keeps selected edge and keyboard focus")
		_history.undo()
		await _frames(5)
		_check(_edge_b.user_note.is_empty() and
			_focused("PotokTransitionNote") and
			_edge_id() == _edge_b.get_internal_id(),
			"Transition Undo preserves its exact selected edge and field focus")
		_history.redo()
		await _frames(5)
		_check(_edge_b.user_note == "Changed note" and
			_focused("PotokTransitionNote") and
			_edge_id() == _edge_b.get_internal_id(),
			"Transition Redo restores note, selected edge and field focus")

	# A stale callback from the detached edge field cannot edit a new selection.
	var stale_note: LineEdit = _field("PotokTransitionNote") as LineEdit
	_select_state(2)
	if stale_note != null:
		stale_note.text_submitted.emit("STALENESS MUST NOT APPLY")
	await _frames(5)
	_check(_state_id() == _other.get_internal_id() and
		_edge_b.user_note == "Changed note" and _other.user_note.is_empty(),
		"Detached form callback cannot modify a newly selected state or old edge")
	_select_state(1)
	await _frames(4)
	_select_edge(1)
	await _frames(4)
	_check(_edge_id() == _edge_b.get_internal_id(), "Second edge reselected by exact ID")

	# After deleting the focused edge, selection must fall back to the survivor.
	var edge_delete: Button = _field("PotokTransitionDelete") as Button
	if _check(edge_delete != null, "Actual Transition Delete button exists"):
		edge_delete.pressed.emit()
		await _frames(3)
		var confirm: ConfirmationDialog = _field(
			"PotokStructureDeleteDialog"
		) as ConfirmationDialog
		if _check(confirm != null and confirm.visible,
				"Structural Delete opens an owned confirmation"):
			confirm.confirmed.emit()
			await _frames(6)
			_check(_selected.transitions.size() == 1 and
				_selected.transitions[0].get_internal_id() == _edge_a.get_internal_id() and
				_edge_id() == _edge_a.get_internal_id() and
				_state_id() == _selected.get_internal_id() and
				_focused("PotokStateList"),
				"Deleted focused edge falls back to surviving stable ID and Flow focus")
			_history.undo()
			await _frames(5)
			_check(_selected.transitions.size() == 2 and
				_selected.transitions[1].get_internal_id() == _edge_b.get_internal_id() and
				_edge_id() == _edge_a.get_internal_id() and
				_focused("PotokStateList"),
				"Undo restores edge structure without selecting stale old position")
			_history.redo()
			await _frames(5)
			_check(_selected.transitions.size() == 1 and
				_edge_id() == _edge_a.get_internal_id() and
				_focused("PotokStateList"),
				"Redo deletes edge again while retaining valid focus and identity")

	# External editor focus always wins over a rebuilt Potok form.
	var outside := LineEdit.new()
	outside.name = "ForeignEditor"
	outside.focus_mode = Control.FOCUS_ALL
	outside.size = Vector2(150, 35)
	_host.add_child(outside)
	outside.grab_focus()
	await _frames(2)
	_history.undo()
	await _frames(5)
	_check(outside.has_focus() and _machine_id() == _machine.get_internal_id() and
		_state_id() == _selected.get_internal_id(),
		"Undo cannot steal focus from an unrelated editor control")
	_editor.refresh_dock_controller()
	await _frames(5)
	_check(outside.has_focus(), "External model refresh cannot steal foreign focus")

	_drawer.close()
	await _frames(3)
	_history.redo()
	await _frames(5)
	_check(not _drawer.is_open() and not _focused("PotokStateList") and
		outside.has_focus(),
		"Late UndoRedo callbacks cannot reopen closed Fluo or restore detached focus")
	_check(_graph.state_machines[0].get_internal_id() == _machine.get_internal_id()
		and _selected.get_internal_id() != _other.get_internal_id()
		and not FlowGraphValidator.validate(_graph).has_errors(),
		"Repeated UndoRedo and focus actions preserve authored graph integrity")
	await _finish()


func _machine_id() -> String:
	return String(_editor.get("_selected_id")) if _editor != null else ""


func _state_id() -> String:
	return String(_editor.get("_potok_selected_state_id")) if _editor != null else ""


func _edge_id() -> String:
	return String(_editor.get("_potok_selected_transition_id")) if _editor != null else ""


func _field(name: String) -> Node:
	return _drawer.find_child(name, true, false) if _drawer != null else null


func _focused(name: String) -> bool:
	var control: Control = _field(name) as Control
	return control != null and control.has_focus()


func _select_state(index: int) -> void:
	var list: ItemList = _field("PotokStateList") as ItemList
	if not _check(list != null and index >= 0 and index < list.item_count,
			"State target row exists"):
		return
	list.grab_focus()
	list.select(index)
	list.item_selected.emit(index)


func _select_edge(index: int) -> void:
	var list: ItemList = _field("PotokTransitionList") as ItemList
	if not _check(list != null and index >= 0 and index < list.item_count,
			"Transition target row exists"):
		return
	list.grab_focus()
	list.select(index)
	list.item_selected.emit(index)


func _frames(count: int) -> void:
	for _i: int in count:
		await process_frame


func _check(ok: bool, label: String) -> bool:
	if not ok:
		failures.append(label)
		push_error("[Flujo] Potok 7E-2C: " + label)
	return ok


func _finish() -> void:
	if _drawer != null:
		_drawer.close()
		_drawer.set_controller(null)
		_drawer.queue_free()
	if _host != null:
		_host.queue_free()
	await _frames(4)
	if failures.is_empty():
		print("[Flujo] Potok 7E-2C UndoRedo focus, selection and stale callbacks passed")
	quit(0 if failures.is_empty() else 1)
