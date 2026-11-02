@tool
extends SceneTree

## Potok 7E-3B: context changes must not leave a drawer editing stale scene data.
var _failures: Array[String] = []
var _host: Control
var _drawer: FluoDrawer
var _first: PVController
var _second: PVController
var _first_machine: FlowStateMachineDefinition
var _second_machine: FlowStateMachineDefinition
var _first_process: FlowProcess
var _second_process: FlowProcess
var _outside_first: Button
var _outside_second: Button


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for _i: int in 5:
		await process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if not _check(undo != null, "Editor UndoRedo context available"):
		quit(1)
		return

	_host = Control.new()
	_host.name = "Potok7E3BSceneHost"
	_host.size = Vector2(1024, 720)
	get_root().add_child(_host)
	_first = _build_controller("SceneA", "Machine A", "Process A")
	_second = _build_controller("SceneB", "Machine B", "Process B")
	_host.add_child(_first)
	_host.add_child(_second)
	_first_machine = _first.flow_graph.state_machines[0]
	_second_machine = _second.flow_graph.state_machines[0]
	_first_process = _first.flow_graph.processes[0]
	_second_process = _second.flow_graph.processes[0]
	_outside_first = _make_focus_button("InspectorSelectionA")
	_outside_second = _make_focus_button("InspectorSelectionB")
	var first_mid: String = _first_machine.get_internal_id()
	var second_mid: String = _second_machine.get_internal_id()
	var first_pid: String = _first_process.get_internal_id()
	var second_pid: String = _second_process.get_internal_id()
	_check(first_mid != second_mid and first_pid != second_pid
		and not FlowGraphValidator.validate(_first.flow_graph).has_errors()
		and not FlowGraphValidator.validate(_second.flow_graph).has_errors(),
		"Two independent valid controller graphs have distinct stable IDs")

	_drawer = FluoDrawer.new()
	EditorInterface.get_base_control().add_child(_drawer)
	_drawer.configure(undo)
	var inspector_focus_ids: Array[String] = []
	_drawer.schema_3_variable_list_focus_requested.connect(
		func(_controller: PVController, id: String) -> void:
			inspector_focus_ids.append(id)
	)

	# Normal explicit close keeps the older preview focus restoration contract.
	_outside_first.grab_focus()
	await _frames(2)
	_drawer.open_container(
		_first, FlowGraphEditorCommands.Collection.STATE_MACHINES, first_mid
	)
	await _frames(5)
	_check(_drawer.is_open() and _machine_id() == first_mid
		and _drawer.find_child("PotokStateList", true, false) != null,
		"Inspector A opens correct Potok machine")
	_drawer.set_right_side(true)
	_drawer.close()
	await _frames(3)
	_check(not _drawer.is_open() and _outside_first.has_focus()
		and _drawer.is_right_side(),
		"Normal close restores valid Inspector focus and retains right placement")

	# Same controller can switch from Potok to its own Process/Timer route.
	_drawer.open_container(
		_first, FlowGraphEditorCommands.Collection.STATE_MACHINES, first_mid
	)
	await _frames(4)
	_drawer.open_container(
		_first, FlowGraphEditorCommands.Collection.PROCESSES, first_pid
	)
	await _frames(5)
	_check(_drawer.is_open() and _collection() == int(
		FlowGraphEditorCommands.Collection.PROCESSES
	) and _machine_id() == first_pid
		and _drawer.find_child("ReadyProcessEditor", true, false) != null
		and _drawer.find_child("PotokStateList", true, false) == null,
		"Same-controller Process/Timer route remains open without stale Potok controls")

	# Scene/Inspector selection points to another controller while A's Fluo is open.
	_outside_second.grab_focus()
	await _frames(2)
	_drawer.set_controller(_second)
	await _frames(5)
	_check(not _drawer.is_open() and not _drawer.visible
		and _outside_second.has_focus(),
		"Different-controller context closes Fluo without stealing foreign editor focus")
	_check(_machine_id().is_empty() and
		_drawer.find_child("ReadyProcessEditor", true, false) == null
		and _drawer.find_child("PotokStateList", true, false) == null,
		"Different controller clears A Process and Potok presentation state")
	_check(_drawer.is_right_side() and _drawer.get_child_count() == 2,
		"Context switch preserves drawer side and single root hierarchy")

	# The B selection becomes live only after a new explicit Inspector activation.
	_drawer.open_container(
		_second, FlowGraphEditorCommands.Collection.STATE_MACHINES, second_mid
	)
	await _frames(5)
	_check(_drawer.is_open() and _machine_id() == second_mid
		and _collection() == int(FlowGraphEditorCommands.Collection.STATE_MACHINES)
		and _drawer.find_child("PotokStateList", true, false) != null,
		"Inspector B explicitly reopens its own Potok resource by ID")

	# Removing a selected controller from the live scene is a real tree_exited event.
	_outside_first.grab_focus()
	await _frames(2)
	_host.remove_child(_second)
	await _frames(5)
	_check(not _drawer.is_open() and not _drawer.visible
		and _outside_first.has_focus(),
		"Controller tree exit automatically closes Fluo without focus theft")
	_check(_machine_id().is_empty() and
		_drawer.find_child("PotokStateList", true, false) == null,
		"Removed controller leaves no old machine selection or editable controls")
	_drawer.refresh_controller()
	await _frames(4)
	_check(not _drawer.is_open() and _machine_id().is_empty(),
		"Stale refresh callback cannot revive removed controller content")
	_host.add_child(_second)

	# Reattached controller must have a genuinely new context and Ready route.
	_drawer.open_container(
		_second, FlowGraphEditorCommands.Collection.PROCESSES, second_pid
	)
	await _frames(5)
	_check(_drawer.is_open() and _machine_id() == second_pid
		and _drawer.find_child("ReadyProcessEditor", true, false) != null,
		"Reattached controller opens Process route without old Potok selection")
	_drawer.set_controller(null)
	await _frames(5)
	_check(not _drawer.is_open() and _machine_id().is_empty()
		and _drawer.find_child("ReadyProcessEditor", true, false) == null,
		"Null scene controller closes Ready and discards old context")
	_check(_drawer.is_right_side(), "Right placement persists after controller unload")

	# Repeated user action still opens the unchanged A machine and closes cleanly.
	_drawer.open_container(
		_first, FlowGraphEditorCommands.Collection.STATE_MACHINES, first_mid
	)
	await _frames(5)
	_check(_drawer.is_open() and _machine_id() == first_mid
		and _drawer.find_child("PotokStateList", true, false) != null,
		"After scene switch, original controller can reopen with original IDs")
	_drawer.close()
	_check(not _drawer.is_open() and _drawer.get_child_count() == 2,
		"Repeated close never duplicates or strands drawer hierarchy")

	_check(_first_machine.get_internal_id() == first_mid
		and _second_machine.get_internal_id() == second_mid
		and _first_process.get_internal_id() == first_pid
		and _second_process.get_internal_id() == second_pid
		and not FlowGraphValidator.validate(_first.flow_graph).has_errors()
		and not FlowGraphValidator.validate(_second.flow_graph).has_errors(),
		"Context churn does not mutate authored resources or stable IDs")
	_check(inspector_focus_ids.is_empty(),
		"Context-forced close never issues a stale Potok Inspector focus request")

	await _finish()


func _build_controller(node_name: String, machine_name: String, process_name: String) -> PVController:
	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var idle := FlowStateDefinition.new()
	idle.display_name = "Idle"
	var run := FlowStateDefinition.new()
	run.display_name = "Running"
	var edge := FlowStateTransitionDefinition.new()
	edge.display_name = "Advance"
	edge.trigger = FlowStateTransitionDefinition.Trigger.EVENT
	edge.event_name = &"advance"
	edge.target_state_id = run.get_internal_id()
	idle.transitions = [edge]
	var machine := FlowStateMachineDefinition.new()
	machine.display_name = machine_name
	machine.states = [idle, run]
	machine.initial_state_id = idle.get_internal_id()
	var process := FlowProcess.new()
	process.display_name = process_name
	graph.state_machines = [machine]
	graph.processes = [process]
	var controller := PVController.new()
	controller.name = node_name
	controller.flow_graph = graph
	return controller


func _make_focus_button(node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = node_name
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(140, 36)
	_host.add_child(button)
	return button


func _machine_id() -> String:
	var editor: FlowGraphInspectorProperty = _drawer.find_child(
		"FluoFlowEditor", true, false
	) as FlowGraphInspectorProperty
	return String(editor.get("_selected_id")) if editor != null else ""


func _collection() -> int:
	var editor: FlowGraphInspectorProperty = _drawer.find_child(
		"FluoFlowEditor", true, false
	) as FlowGraphInspectorProperty
	return int(editor.get("_selected_collection")) if editor != null else -1


func _frames(count: int) -> void:
	for _i: int in count:
		await process_frame


func _check(ok: bool, message: String) -> bool:
	if not ok:
		_failures.append(message)
		push_error("[Flujo] Potok 7E-3B: " + message)
	return ok


func _finish() -> void:
	if _drawer != null:
		_drawer.close()
		_drawer.set_controller(null)
		_drawer.queue_free()
	if _host != null:
		_host.queue_free()
	await _frames(4)
	if _failures.is_empty():
		print("[Flujo] Potok 7E-3B scene/controller context restoration passed")
	quit(0 if _failures.is_empty() else 1)
