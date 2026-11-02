@tool
extends SceneTree

## Potok 7E-2B2: per-target Flusso Revertir, live property writes, atomic Undo/Redo.
var failures: Array[String] = []
var _host: Control
var _drawer: FluoDrawer
var _controller: PVController
var _history: UndoRedo
var _machine: FlowStateMachineDefinition
var _idle: FlowStateDefinition
var _running: FlowStateDefinition
var _edge: FlowStateTransitionDefinition
var _mid: String
var _sid: String
var _eid: String


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for _i: int in 5:
		await process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if not _check(manager != null, "Editor UndoRedo is available"):
		quit(1)
		return

	_host = Control.new()
	_host.name = "Potok7E2B2Host"
	_host.size = Vector2(1000, 800)
	get_root().add_child(_host)
	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	_idle = FlowStateDefinition.new()
	_idle.display_name = "Idle"
	_running = FlowStateDefinition.new()
	_running.display_name = "Running"
	_edge = FlowStateTransitionDefinition.new()
	_edge.display_name = "Advance"
	_edge.trigger = FlowStateTransitionDefinition.Trigger.EVENT
	_edge.event_name = &"advance"
	_edge.target_state_id = _idle.get_internal_id()
	_running.transitions = [_edge]
	_machine = FlowStateMachineDefinition.new()
	_machine.display_name = "Actor"
	_machine.states = [_idle, _running]
	_machine.initial_state_id = _idle.get_internal_id()
	var other := FlowStateDefinition.new()
	other.display_name = "Other"
	var second_machine := FlowStateMachineDefinition.new()
	second_machine.display_name = "Other machine"
	second_machine.states = [other]
	second_machine.initial_state_id = other.get_internal_id()
	graph.state_machines = [_machine, second_machine]
	_controller = PVController.new()
	_controller.name = "Controller"
	_controller.flow_graph = graph
	_host.add_child(_controller)
	_mid = _machine.get_internal_id()
	_sid = _running.get_internal_id()
	_eid = _edge.get_internal_id()
	_history = manager.get_history_undo_redo(manager.get_object_history_id(_controller))
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Original valid schema-3 graph")

	_drawer = FluoDrawer.new()
	EditorInterface.get_base_control().add_child(_drawer)
	_drawer.configure(manager)
	_drawer.open_container(
		_controller, FlowGraphEditorCommands.Collection.STATE_MACHINES, _mid
	)
	await _frames(5)

	# Focal red gate: Potok has its own Revertir, not the Ready block button.
	if not _check(_button("PotokMachineRevert") != null,
			"Potok Machine form exposes its own Revertir button"):
		await _finish()
		return
	_check(_button("PotokStateRevert") != null, "Potok State also has independent Revertir")
	_check(_button("PotokTransitionRevert") == null,
		"Transition Revertir appears only when an edge belongs to the selected state")

	# MACHINE: snapshot survives several live UI rebuilds and yields one undoable revert.
	_edit("PotokMachineName", "Changed actor")
	await _frames(4)
	_toggle("PotokMachineAutoStart", false)
	await _frames(4)
	_edit("PotokMachineNote", "Temporary")
	await _frames(4)
	_check(_machine.display_name == "Changed actor" and not _machine.auto_start
		and _machine.user_note == "Temporary", "Machine changes commit immediately before revert")
	_press("PotokMachineRevert")
	await _frames(5)
	_check(_machine.display_name == "Actor" and _machine.auto_start
		and _machine.user_note.is_empty() and _machine.get_internal_id() == _mid,
		"Machine Revertir restores every opening scalar with original identity")
	_check(_history.get_current_action_name() == "Revert Potok Machine",
		"Multiple Machine fields revert in one labelled Undo action")
	_history.undo()
	await _frames(3)
	_check(_machine.display_name == "Changed actor" and not _machine.auto_start
		and _machine.user_note == "Temporary",
		"Single Undo restores all pre-revert Machine values")
	_history.redo()
	await _frames(3)
	_check(_machine.display_name == "Actor" and _machine.auto_start
		and _machine.user_note.is_empty(),
		"Single Redo reapplies entire machine session snapshot")
	var machine_version: int = _history.get_version()
	_press("PotokMachineRevert")
	await _frames(3)
	_check(_history.get_version() == machine_version,
		"No-op Machine Revertir creates no extra Undo action")

	# STATE: selecting a different state creates its own snapshot.
	var list: ItemList = _field("PotokStateList") as ItemList
	if not _check(list != null and list.item_count == 2, "Two authored Flow states"):
		await _finish()
		return
	list.select(1)
	list.item_selected.emit(1)
	await _frames(4)
	_check(_button("PotokStateRevert") != null and
		_button("PotokTransitionRevert") != null,
		"Running state shows its own State and Edge Revertir controls")
	_edit("PotokStateName", "Sprint")
	await _frames(4)
	_toggle("PotokStateEnabled", false)
	await _frames(4)
	_edit("PotokStateNote", "Private note")
	await _frames(4)
	_check(_running.display_name == "Sprint" and not _running.enabled
		and _running.user_note == "Private note",
		"State fields apply immediately in original resource")
	_press("PotokStateRevert")
	await _frames(4)
	_check(_running.display_name == "Running" and _running.enabled
		and _running.user_note.is_empty() and _running.get_internal_id() == _sid,
		"State session independently restores name, enabled and note")
	_check(_history.get_current_action_name() == "Revert Potok State",
		"State Revertir is one history action")
	_history.undo()
	await _frames(3)
	_check(_running.display_name == "Sprint" and not _running.enabled
		and _running.user_note == "Private note",
		"Undo State Revertir atomically restores all edited values")
	_history.redo()
	await _frames(3)

	# EDGE: the same saved edge ID is used, with typed target and priority fields.
	_edit("PotokTransitionName", "Changed edge")
	await _frames(4)
	_edit("PotokTransitionNote", "Temporary edge note")
	await _frames(4)
	var priority: SpinBox = _field("PotokTransitionPriority") as SpinBox
	if _check(priority != null, "Edge priority editor available"):
		priority.value = 9
		priority.value_changed.emit(9.0)
	await _frames(4)
	_check(_edge.display_name == "Changed edge" and _edge.user_note == "Temporary edge note"
		and _edge.priority == 9, "Edge edits persist without waiting for Revertir")
	_press("PotokTransitionRevert")
	await _frames(4)
	_check(_edge.display_name == "Advance" and _edge.user_note.is_empty()
		and _edge.priority == 0 and _edge.get_internal_id() == _eid,
		"Edge Revertir restores original typed scalar fields and stable ID")
	_check(_history.get_current_action_name() == "Revert Potok Transition",
		"Transition Revertir is exactly one labelled Undo action")
	_history.undo()
	await _frames(3)
	_check(_edge.display_name == "Changed edge" and
		_edge.user_note == "Temporary edge note" and _edge.priority == 9,
		"Undo Transition Revertir restores all pre-revert edits together")
	_history.redo()
	await _frames(3)

	# Reject invalid and partial snapshots *before* any field or history changes.
	var commands := FlowGraphEditorCommands.new(manager)
	var bad_version: int = _history.get_version()
	var invalid: Dictionary = {
		"display_name": "", "enabled": true, "priority": 2,
		"target_state_id": "missing", "trigger": int(_edge.trigger),
		"event_name": _edge.event_name, "user_note": ""
	}
	_check(not commands.restore_fsm_properties_snapshot(
		_controller, _mid, _sid, _eid, invalid
	), "Invalid name/foreign target rejected atomically")
	invalid.erase("target_state_id")
	_check(not commands.restore_fsm_properties_snapshot(
		_controller, _mid, _sid, _eid, invalid
	), "Partial snapshot rejected without writing any scalar")
	_check(_edge.display_name == "Advance" and _edge.priority == 0
		and _history.get_version() == bad_version,
		"Invalid candidate leaves graph/history unchanged")

	# Session changes must not keep a stale snapshot from the prior selection.
	_edit("PotokStateName", "Persisted running")
	await _frames(4)
	list = _field("PotokStateList") as ItemList
	list.select(0)
	list.item_selected.emit(0)
	await _frames(4)
	list = _field("PotokStateList") as ItemList
	list.select(1)
	list.item_selected.emit(1)
	await _frames(4)
	_edit("PotokStateNote", "Second session")
	await _frames(4)
	_press("PotokStateRevert")
	await _frames(4)
	_check(_running.display_name == "Persisted running"
		and _running.user_note.is_empty(),
		"Returning to a state creates a fresh snapshot instead of reverting prior session")

	# Closing Fluo never rolls back live edits; reopening captures the current baseline.
	_edit("PotokMachineName", "Saved through close")
	await _frames(4)
	_drawer.close()
	await _frames(3)
	_check(_machine.display_name == "Saved through close",
		"Closing Fluo does not revert machine changes")
	_drawer.open_container(_controller,
		FlowGraphEditorCommands.Collection.STATE_MACHINES, _mid)
	await _frames(5)
	_edit("PotokMachineNote", "New session note")
	await _frames(4)
	_press("PotokMachineRevert")
	await _frames(4)
	_check(_machine.display_name == "Saved through close"
		and _machine.user_note.is_empty(),
		"Reopening Fluo starts a new Machine Revertir session")

	var original_name: String = _machine.display_name
	var stale_button: Button = _button("PotokMachineRevert")
	_drawer.set_variable_selection(
		_controller, FlowGraphEditorCommands.Collection.STATE_MACHINES,
		second_machine.get_internal_id()
	)
	if stale_button != null:
		stale_button.pressed.emit()
	await _frames(5)
	_check(_machine.display_name == original_name
		and second_machine.display_name == "Other machine",
		"Late Revertir from old machine cannot touch either machine after navigation")
	_check(graph.state_machines[0].get_internal_id() == _mid
		and _running.get_internal_id() == _sid and _edge.get_internal_id() == _eid
		and not FlowGraphValidator.validate(graph).has_errors(),
		"All live edits, undo actions and session switches preserve graph and IDs")
	await _finish()


func _field(name: String) -> Node:
	return _drawer.find_child(name, true, false) if _drawer != null else null


func _button(name: String) -> Button:
	return _field(name) as Button


func _edit(name: String, content: String) -> void:
	var edit: LineEdit = _field(name) as LineEdit
	if not _check(edit != null, name + " exists"):
		return
	edit.text = content
	edit.text_submitted.emit(content)


func _toggle(name: String, value: bool) -> void:
	var check: CheckBox = _field(name) as CheckBox
	if not _check(check != null, name + " exists"):
		return
	check.set_pressed_no_signal(value)
	check.toggled.emit(value)


func _press(name: String) -> void:
	var button: Button = _button(name)
	if not _check(button != null, name + " exists"):
		return
	button.pressed.emit()


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _check(ok: bool, description: String) -> bool:
	if not ok:
		failures.append(description)
		push_error("[Flujo] Potok 7E-2B2: " + description)
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
		print("[Flujo] Potok 7E-2B2 Revertir atomic FSM sessions passed")
	quit(0 if failures.is_empty() else 1)
