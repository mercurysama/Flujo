@tool
extends SceneTree

## Potok 7B — Inspector relay, existing Fluo and read-only state navigation.
var _failures: Array[String] = []
var _host: Control
var _drawer: FluoDrawer

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	for _i: int in 4:
		await process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	var base: Control = EditorInterface.get_base_control()
	if not _check(undo != null and base != null, "Editor shell exists"):
		quit(1)
		return
	_host = Control.new()
	_host.name = &"Potok7BTestHost"
	_host.size = Vector2(960, 720)
	get_root().add_child(_host)
	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var idle := FlowStateDefinition.new()
	idle.display_name = "Idle"
	var running := FlowStateDefinition.new()
	running.display_name = "Running"
	var enter := FlowPrintBlock.new()
	enter.text = "enter"
	var update := FlowPrintBlock.new()
	update.text = "update"
	var exit := FlowPrintBlock.new()
	exit.text = "exit"
	idle.enter_blocks = [enter]
	idle.blocks = [update]
	idle.exit_blocks = [exit]
	var machine := FlowStateMachineDefinition.new()
	machine.display_name = "Machine"
	machine.states = [idle, running]
	machine.initial_state_id = idle.get_internal_id()
	var empty := FlowStateMachineDefinition.new()
	empty.display_name = "Draft"
	var process := FlowProcess.new()
	process.display_name = "Ready"
	graph.state_machines = [machine, empty]
	graph.processes = [process]
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Fixture graph valid")
	var ctrl := PVController.new()
	ctrl.flow_graph = graph
	_host.add_child(ctrl)
	var inspector_relay := PVControllerInspectorPlugin.new()
	var activated: Array[String] = []
	inspector_relay.schema_3_container_activated.connect(func(_ctrl: PVController,
		collection: FlowGraphEditorCommands.Collection, mid: String) -> void:
		activated.append(str(collection) + ":" + mid)
	)
	inspector_relay.call("_on_schema_3_container_activated", ctrl,
		FlowGraphEditorCommands.Collection.STATE_MACHINES, machine.get_internal_id())
	_check(activated == [str(FlowGraphEditorCommands.Collection.STATE_MACHINES) +
		":" + machine.get_internal_id()], "Inspector relays stable machine selection")
	_drawer = FluoDrawer.new()
	base.add_child(_drawer)
	_drawer.configure(undo)
	var changes: Array[String] = []
	var focuses: Array[String] = []
	_drawer.schema_3_container_navigation_changed.connect(func(_ctrl: PVController,
		collection: FlowGraphEditorCommands.Collection, mid: String) -> void:
		changes.append(str(collection) + ":" + mid)
	)
	_drawer.schema_3_variable_list_focus_requested.connect(func(_ctrl: PVController, mid: String) -> void:
		focuses.append(mid)
	)
	_drawer.open_container(ctrl, FlowGraphEditorCommands.Collection.STATE_MACHINES,
		machine.get_internal_id())
	await _frames(5)
	var property: FlowGraphInspectorProperty = _drawer.find_child(
		"FluoFlowEditor", true, false) as FlowGraphInspectorProperty
	var states: ItemList = _drawer.find_child("PotokStateList", true, false) as ItemList
	_check(_drawer.is_open() and property != null, "Existing Fluo opens machine")
	_check(states != null and states.item_count == 2, "Flow shows two authored states")
	if states != null and states.item_count == 2:
		_check((states.get_item_metadata(0) as Dictionary).get("id") == idle.get_internal_id(),
			"First state has stable ID")
		_check((states.get_item_metadata(1) as Dictionary).get("id") == running.get_internal_id(),
			"Second state has stable ID")
		_check(states.get_item_text(0).contains("Initial"), "Initial is marked")
	var phases: Control = _drawer.find_child("PotokStatePhases", true, false) as Control
	_check(phases != null, "Selected state has phase hierarchy")
	_check(_drawer.find_child("PotokPhaseEnter", true, false) != null and
		_drawer.find_child("PotokPhaseUpdate", true, false) != null and
		_drawer.find_child("PotokPhaseExit", true, false) != null,
		"Enter Update Exit are visible in Flow")
	if states != null and states.item_count == 2:
		states.select(1)
		states.item_selected.emit(1)
		await _frames(4)
		_check(property.get("_potok_selected_state_id") == running.get_internal_id(),
			"Native state selection retains stable ID")
		# An external Undo/Redo reorder must not change the selected state identity.
		machine.states = [running, idle]
		property.refresh_dock_controller()
		await _frames(4)
		states = _drawer.find_child("PotokStateList", true, false) as ItemList
		_check(states != null and states.item_count == 2 and
			(states.get_item_metadata(0) as Dictionary).get("id") == running.get_internal_id(),
			"Reordered view reflects authored state order")
		_check(property.get("_potok_selected_state_id") == running.get_internal_id() and
			states.get_selected_items().size() == 1 and states.get_selected_items()[0] == 0,
			"Stable state selection follows ID across reorder")
		machine.states = [idle, running]
		property.refresh_dock_controller()
		await _frames(4)
		_check(property.call("navigate_potok_state", -1), "Ctrl+PageUp state navigation")
		await _frames(4)
		_check(property.get("_potok_selected_state_id") == idle.get_internal_id(),
			"State keyboard navigation selects original ID")
	_check(property.call("navigate_potok_machine", 1), "PageDown moves to next machine")
	await _frames(4)
	_check(changes.back() == str(FlowGraphEditorCommands.Collection.STATE_MACHINES) +
		":" + empty.get_internal_id(), "Machine navigation syncs Inspector ID")
	states = _drawer.find_child("PotokStateList", true, false) as ItemList
	_check(states != null and states.item_count == 1 and
		states.get_item_text(0) == "Empty", "Empty machine is inert draft")
	_check(empty.states.is_empty(), "Projection never creates authored state")
	_check(property.call("navigate_potok_machine", -1), "PageUp returns by machine ID")
	await _frames(4)
	_check(property.get("_selected_id") == machine.get_internal_id(),
		"Original machine restored")
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	_drawer.call("_input", escape)
	await _frames(4)
	_check(not _drawer.is_open(), "Escape closes Potok Fluo")
	_check(focuses == [machine.get_internal_id()], "Escape requests originating Inspector row")
	_drawer.open_container(ctrl, FlowGraphEditorCommands.Collection.PROCESSES,
		process.get_internal_id())
	await _frames(4)
	_check(_drawer.find_child("ReadyProcessEditor", true, false) != null,
		"Existing Ready Flow still opens")
	_check(_drawer.find_child("PotokStateList", true, false) == null,
		"Process editor does not duplicate Potok tree")
	_drawer.close()
	_drawer.set_controller(null)
	await _frames(3)
	_check(_drawer.find_child("PotokStateList", true, false) == null,
		"Controller removal clears previous machine navigation")
	_check(graph.state_machines[0].states.size() == 2 and
		graph.state_machines[0].initial_state_id == idle.get_internal_id() and
		not FlowGraphValidator.validate(graph).has_errors(),
		"Navigation leaves authored graph unchanged")
	_drawer.queue_free()
	_host.queue_free()
	await _frames(3)
	if _failures.is_empty():
		print("[Flujo] Potok 7B Fluo machine navigation passed")
	quit(0 if _failures.is_empty() else 1)

func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame

func _check(ok: bool, message: String) -> bool:
	if not ok:
		_failures.append(message)
		push_error("[Flujo] Potok 7B: " + message)
	return ok
