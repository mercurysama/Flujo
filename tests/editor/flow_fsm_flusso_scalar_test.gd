@tool
extends SceneTree

## Potok 7C-1 — scalar commands, atomic history and Flusso native controls.
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	for i: int in 5:
		await process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if not _check(manager != null, "Editor undo manager exists"):
		quit(1)
		return
	var host := Control.new()
	host.name = &"Potok7C1Host"
	host.size = Vector2(900, 700)
	get_root().add_child(host)
	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var idle := FlowStateDefinition.new()
	idle.display_name = "Idle"
	var run := FlowStateDefinition.new()
	run.display_name = "Run"
	var other := FlowStateDefinition.new()
	other.display_name = "External"
	var machine := FlowStateMachineDefinition.new()
	machine.display_name = "Main"
	machine.states = [idle, run]
	machine.initial_state_id = idle.get_internal_id()
	var foreign := FlowStateMachineDefinition.new()
	foreign.states = [other]
	foreign.initial_state_id = other.get_internal_id()
	graph.state_machines = [machine, foreign]
	var controller := PVController.new()
	controller.flow_graph = graph
	host.add_child(controller)
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Graph valid before edits")
	var commands := FlowGraphEditorCommands.new(manager)
	var mid: String = machine.get_internal_id()
	var sid: String = run.get_internal_id()
	_check(not commands.set_fsm_machine_property(controller, mid, &"tick_mode", 999),
		"Invalid tick enum rejected")
	_check(not commands.set_fsm_machine_property(controller, mid, &"initial_state_id",
		other.get_internal_id()), "Foreign initial state rejected")
	_check(not commands.set_fsm_machine_property(controller, mid, &"display_name", "   "),
		"Whitespace-only name rejected")
	_check(not commands.set_fsm_state_property(controller, mid, sid, &"is_initial", true),
		"Legacy initial flag remains read-only")
	_check(not commands.set_fsm_state_property(controller, mid, "missing", &"enabled", false),
		"Unknown stable state ID rejected")
	_check(not commands.set_fsm_machine_property(controller, mid, &"states", []),
		"State ownership cannot be edited as property")
	_check(machine.tick_mode == FlowStateMachineDefinition.TickMode.PROCESS
		and machine.initial_state_id == idle.get_internal_id() and run.enabled,
		"Rejections leave actual resources unchanged")
	var history: UndoRedo = manager.get_history_undo_redo(manager.get_object_history_id(controller))
	_check(commands.set_fsm_machine_property(controller, mid, &"tick_mode",
		FlowStateMachineDefinition.TickMode.PHYSICS), "Tick edit commits")
	_check(machine.tick_mode == FlowStateMachineDefinition.TickMode.PHYSICS, "New tick applied")
	_check(history.has_undo(), "Command is undoable")
	history.undo()
	_check(machine.tick_mode == FlowStateMachineDefinition.TickMode.PROCESS,
		"Undo restores original tick")
	history.redo()
	_check(machine.tick_mode == FlowStateMachineDefinition.TickMode.PHYSICS,
		"Redo restores new tick")
	_check(commands.set_fsm_machine_property(controller, mid, &"initial_state_id", sid),
		"Initial state changed by owned ID")
	_check(machine.initial_state_id == sid and idle.is_initial == false,
		"Machine initial ID changes without legacy is_initial writes")
	_check(commands.set_fsm_state_property(controller, mid, sid, &"display_name", "Sprint"),
		"State name edited")
	_check(run.display_name == "Sprint", "State edit committed")
	history.undo()
	_check(run.display_name == "Run", "State undo restores original name")
	history.redo()
	_check(run.display_name == "Sprint", "State redo reapplies name")
	_check(commands.set_fsm_state_property(controller, mid, sid, &"user_note", "Running state"),
		"State note edited")
	_check(commands.set_fsm_machine_property(controller, mid, &"auto_start", false),
		"Machine autostart flag edited")
	_check(not commands.set_fsm_machine_property(controller, mid, &"auto_start", false),
		"Unchanged value is a no-op")
	var property := FlowGraphInspectorProperty.new()
	property.configure(manager)
	property.configure_for_fluo()
	host.add_child(property)
	property.set_dock_controller(controller)
	property.set_dock_variable_selection(
		controller, FlowGraphEditorCommands.Collection.STATE_MACHINES, mid)
	for i: int in 5:
		await process_frame
	_check(property.find_child("PotokMachineProperties", true, false) != null,
		"Existing Fluo Flow contains machine Flusso controls")
	var input: LineEdit = property.find_child("PotokMachineName", true, false) as LineEdit
	_check(input != null, "Machine Name input exists")
	if input != null:
		input.text = "Edited in Flusso"
		input.text_submitted.emit(input.text)
		for i: int in 5:
			await process_frame
		_check(machine.display_name == "Edited in Flusso",
			"Machine name committed via Flusso")
	var list: ItemList = property.find_child("PotokStateList", true, false) as ItemList
	if list != null and list.item_count == 2:
		list.select(1)
		list.item_selected.emit(1)
	for i: int in 5:
		await process_frame
	_check(property.find_child("PotokStateProperties", true, false) != null,
		"Selected state has native Flusso controls")
	var active: CheckBox = property.find_child("PotokStateEnabled", true, false) as CheckBox
	_check(active != null, "State Enabled input exists")
	if active != null:
		active.button_pressed = false
		active.toggled.emit(false)
		for i: int in 5:
			await process_frame
		_check(not run.enabled, "State enabled toggles through validated command")
		history.undo()
		for i: int in 5:
			await process_frame
		_check(run.enabled, "Flusso undo restores original state")
	_check(not FlowGraphValidator.validate(graph).has_errors(), "All authored edits leave valid graph")
	_check(graph.state_machines[0].get_internal_id() == mid and run.get_internal_id() == sid,
		"Stable IDs unchanged after edits and undo")
	host.queue_free()
	for i: int in 3:
		await process_frame
	if failures.is_empty():
		print("[Flujo] Potok 7C-1 machine state Flusso scalar editing passed")
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, description: String) -> bool:
	if not ok:
		failures.append(description)
		push_error("[Flujo] Potok 7C-1: " + description)
	return ok
