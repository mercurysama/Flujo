@tool
extends SceneTree

## Potok 7E-2B1: Potok Alt traversal; Escape cancels transient dialogs before Fluo.
var failures: Array[String] = []
var _host: Control
var _drawer: FluoDrawer
var _graph: FlowGraph
var _edge: FlowStateTransitionDefinition
var _machine_id: String
var _state_id: String
var _controller: PVController


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for _i: int in 5:
		await process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if not _check(undo != null, "Editor undo manager exists"):
		quit(1)
		return

	_host = Control.new()
	_host.name = "Potok7E2B1TestHost"
	_host.size = Vector2(1000, 800)
	get_root().add_child(_host)
	_graph = FlowGraph.new()
	_graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	_graph.constructor = FlowConstructorDefinition.new()
	var idle := FlowStateDefinition.new()
	idle.display_name = "Idle"
	var running := FlowStateDefinition.new()
	running.display_name = "Running"
	_edge = FlowStateTransitionDefinition.new()
	_edge.display_name = "Advance"
	_edge.trigger = FlowStateTransitionDefinition.Trigger.EVENT
	_edge.event_name = &"advance"
	_edge.target_state_id = running.get_internal_id()
	idle.transitions = [_edge]
	var machine := FlowStateMachineDefinition.new()
	machine.display_name = "Machine"
	machine.states = [idle, running]
	machine.initial_state_id = idle.get_internal_id()
	_graph.state_machines = [machine]
	_controller = PVController.new()
	_controller.name = "ControllerNode"
	_controller.flow_graph = _graph
	_host.add_child(_controller)
	_machine_id = machine.get_internal_id()
	_state_id = idle.get_internal_id()
	var initial_edge_id: String = _edge.get_internal_id()
	_check(not FlowGraphValidator.validate(_graph).has_errors(),
		"Valid two-state FSM with an existing EVENT transition")

	_drawer = FluoDrawer.new()
	EditorInterface.get_base_control().add_child(_drawer)
	_drawer.configure(undo)
	_drawer.open_container(
		_controller, FlowGraphEditorCommands.Collection.STATE_MACHINES, _machine_id
	)
	await _frames(5)
	var flow: ItemList = _states()
	var machine_name: LineEdit = _field("PotokMachineName") as LineEdit
	var machine_enabled: CheckBox = _field("PotokMachineEnabled") as CheckBox
	var edge_note: LineEdit = _field("PotokTransitionNote") as LineEdit
	if not _check(flow != null and machine_name != null and machine_enabled != null
			and edge_note != null and _drawer.is_open(),
			"Existing Fluo renders Flow state selection and three Potok scalar forms"):
		await _finish()
		return
	_check(flow.has_focus(), "Opening an FSM focuses its Flow state list")

	# Existing Alt drawer route should choose Potok form controls when no Ready options exist.
	_key(KEY_PAGEDOWN, false, true)
	await _frames(2)
	_check(machine_name.has_focus(),
		"Alt+PageDown from Flow enters first Potok machine scalar control")
	_key(KEY_PAGEDOWN, false, true)
	await _frames(2)
	_check(machine_enabled.has_focus(),
		"Alt+PageDown advances to the second enabled scalar control")
	_key(KEY_PAGEDOWN, false, true, true)
	await _frames(2)
	_check(machine_name.has_focus(),
		"Alt+Shift+PageDown moves backwards to prior Potok scalar control")
	_key(KEY_PAGEUP, false, true)
	await _frames(2)
	_check(edge_note.has_focus(),
		"Alt+PageUp wraps backwards from first machine control to last transition control")
	_check(_selected_state() == _state_id and
		(_drawer.find_child("FluoFlowEditor", true, false) as FlowGraphInspectorProperty).get(
			"_selected_id") == _machine_id,
		"Focus traversal keeps machine/state stable IDs unchanged")

	# Out-of-drawer focus cannot be stolen by a drawer key handler.
	var external := LineEdit.new()
	external.name = "ForeignInput"
	external.focus_mode = Control.FOCUS_ALL
	external.size = Vector2(200, 40)
	_host.add_child(external)
	external.grab_focus()
	await _frames(2)
	_key(KEY_PAGEUP, false, true)
	await _frames(2)
	_check(external.has_focus() and _selected_state() == _state_id,
		"Alt+Page outside Fluo leaves foreign editor focus and Potok selection intact")

	# Closing an unsaved Tok draft must consume the first Escape, not close Fluo.
	flow = _states()
	flow.grab_focus()
	await _frames(2)
	var edit: Button = _field("PotokTransitionConditionEdit") as Button
	if _check(edit != null, "Potok transition exposes existing Condition Tok editor"):
		edit.pressed.emit()
		await _frames(4)
		var modal: FlowConditionEditor = _field("FlowConditionEditor") as FlowConditionEditor
		if _check(modal != null and modal.visible, "Condition Tok popup is visible"):
			modal.set_draft(_valid_condition())
			_key(KEY_ESCAPE)
			await _frames(4)
			_check(_drawer.is_open() and _field("FlowConditionEditor") == null,
				"First Escape dismisses Condition Tok draft without closing Fluo")
			_check(_edge.condition == null and _edge.get_internal_id() == initial_edge_id,
				"Escaping Condition draft cannot persist it or change transition ID")
			_check(_states() != null and _states().has_focus(),
				"After modal Escape, the Flow state selection regains focus")

	# A red baseline may have closed Fluo above; reopen to test delete independently.
	if not _drawer.is_open():
		_drawer.open_container(
			_controller, FlowGraphEditorCommands.Collection.STATE_MACHINES, _machine_id
		)
		await _frames(4)
	var delete_button: Button = _field("PotokTransitionDelete") as Button
	if _check(delete_button != null, "Potok offers explicit transition Delete action"):
		delete_button.pressed.emit()
		await _frames(4)
		var confirmation: ConfirmationDialog = _field(
			"PotokStructureDeleteDialog"
		) as ConfirmationDialog
		if _check(confirmation != null and confirmation.visible,
				"Delete opens a separate visible confirmation dialog"):
			_key(KEY_ESCAPE)
			await _frames(4)
			_check(_drawer.is_open() and _field("PotokStructureDeleteDialog") == null,
				"First Escape cancels delete confirmation before closing Fluo")
			_check(idle.transitions.size() == 1 and idle.transitions[0] == _edge,
				"Dismissed deletion does not change authored edges")
			_check(_states() != null and _states().has_focus(),
				"Delete dismissal returns real focus to the selected Flow state")

	if not _drawer.is_open():
		_drawer.open_container(
			_controller, FlowGraphEditorCommands.Collection.STATE_MACHINES, _machine_id
		)
		await _frames(4)
	var focus_requests: Array[String] = []
	_drawer.schema_3_variable_list_focus_requested.connect(
		func(_c: PVController, id: String) -> void:
			focus_requests.append(id)
	)
	_key(KEY_ESCAPE)
	await _frames(3)
	_check(not _drawer.is_open() and focus_requests == [_machine_id],
		"Second-level Escape closes Fluo and requests originating Inspector machine ID")
	_check(_edge.condition == null and idle.transitions.size() == 1 and
		machine.initial_state_id == _state_id and
		not FlowGraphValidator.validate(_graph).has_errors(),
		"Alt and Escape interactions leave authored graph untouched")
	await _finish()


func _valid_condition() -> FlowConditionValueSource:
	return FlowConditionValueSource.new([
		FlowConditionComparison.new(
			FlowConditionOperatorCatalog.OPERATOR_EQUAL,
			FlowLiteralValueSource.new(Variant.Type.TYPE_BOOL, true),
			FlowLiteralValueSource.new(Variant.Type.TYPE_BOOL, true)
		)
	], [])


func _states() -> ItemList:
	return _field("PotokStateList") as ItemList


func _selected_state() -> String:
	var editor: FlowGraphInspectorProperty = _field("FluoFlowEditor") as FlowGraphInspectorProperty
	return String(editor.get("_potok_selected_state_id")) if editor != null else ""


func _field(name: String) -> Node:
	return _drawer.find_child(name, true, false) if _drawer != null else null


func _key(keycode: Key, ctrl: bool = false, alt: bool = false,
		shift: bool = false) -> void:
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = keycode
	key.ctrl_pressed = ctrl
	key.alt_pressed = alt
	key.shift_pressed = shift
	_drawer.call("_input", key)


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _check(ok: bool, message: String) -> bool:
	if not ok:
		failures.append(message)
		push_error("[Flujo] Potok 7E-2B1: " + message)
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
		print("[Flujo] Potok 7E-2B1 Alt and modal Escape passed")
	quit(0 if failures.is_empty() else 1)
