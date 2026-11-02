@tool
extends SceneTree
## Potok 7C-2B: structural command contract (RED before implementation).
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	for _i: int in 4:
		await process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	var host := Node.new()
	get_root().add_child(host)
	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var a := FlowStateDefinition.new()
	a.display_name = "A"
	var b := FlowStateDefinition.new()
	b.display_name = "B"
	var phase := FlowPrintBlock.new()
	phase.text = "hello"
	a.enter_blocks = [phase]
	var loop := _event(a.get_internal_id(), &"loop")
	var toward_b := _event(b.get_internal_id(), &"toward_b")
	a.transitions = [loop, toward_b]
	var machine := FlowStateMachineDefinition.new()
	machine.states = [a, b]
	machine.initial_state_id = a.get_internal_id()
	var empty := FlowStateMachineDefinition.new()
	empty.states = []
	var graph_machines: Array[FlowStateMachineDefinition] = [machine, empty]
	graph.state_machines = graph_machines
	var controller := PVController.new()
	controller.flow_graph = graph
	host.add_child(controller)
	var commands := FlowGraphEditorCommands.new(manager)
	if not _check(commands.has_method("add_fsm_state")
			and commands.has_method("duplicate_fsm_state")
			and commands.has_method("move_fsm_state")
			and commands.has_method("delete_fsm_state")
			and commands.has_method("add_fsm_transition")
			and commands.has_method("duplicate_fsm_transition")
			and commands.has_method("move_fsm_transition")
			and commands.has_method("delete_fsm_transition"), "Structural commands exist (RED gate)"):
		await _finish(host)
		return
	var mid: String = machine.get_internal_id()
	var aid: String = a.get_internal_id()
	var bid: String = b.get_internal_id()
	var history: UndoRedo = manager.get_history_undo_redo(manager.get_object_history_id(controller))
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Fixture valid")
	var new_id: String = commands.add_fsm_state(controller, mid)
	_check(not new_id.is_empty() and machine.states.size() == 3
		and machine.states[2].get_internal_id() == new_id, "Add state appends valid new ID")
	history.undo()
	_check(machine.states.size() == 2, "Undo add state")
	history.redo()
	_check(machine.states.size() == 3 and machine.states[2].get_internal_id() == new_id,
		"Redo reuses same created state ID")
	var duplicated: String = commands.duplicate_fsm_state(controller, mid, aid)
	_check(not duplicated.is_empty() and machine.states.size() == 4
		and machine.states[1].get_internal_id() == duplicated, "Duplicate inserted next to source")
	if machine.states.size() == 4:
		var copy: FlowStateDefinition = machine.states[1]
		_check(copy.get_internal_id() != aid and copy.enter_blocks.size() == 1
			and copy.enter_blocks[0].get_internal_id() != phase.get_internal_id(),
			"Duplicate state and phase block IDs are fresh")
		_check(copy.transitions.size() == 2
			and copy.transitions[0].get_internal_id() != loop.get_internal_id()
			and copy.transitions[0].target_state_id == duplicated
			and copy.transitions[1].target_state_id == bid,
			"Duplicate self-target remapped; external owned edge retained")
	_check(commands.move_fsm_state(controller, mid, duplicated, 1),
		"State moves one position down")
	_check(machine.states[2].get_internal_id() == duplicated, "State order changed")
	history.undo()
	_check(machine.states[1].get_internal_id() == duplicated, "Undo restores state order")
	history.redo()
	_check(machine.states[2].get_internal_id() == duplicated, "Redo restores move")
	_check(not commands.move_fsm_state(controller, mid, aid, -1),
		"Moving first state out of bounds is rejected")
	_check(not commands.delete_fsm_state(controller, mid, bid),
		"Incoming references prevent deletion of target state")
	toward_b.enabled = false
	_check(not commands.delete_fsm_state(controller, mid, bid),
		"Disabled inbound edges also protect state IDs from orphaning")
	toward_b.enabled = true
	_check(machine.states.size() == 4 and machine.initial_state_id == aid,
		"Denied deletion leaves state order and initial state intact")
	var created_edge: String = commands.add_fsm_transition(controller, mid, duplicated)
	var dup_state: FlowStateDefinition = machine.states[2]
	_check(not created_edge.is_empty() and dup_state.transitions.size() == 3
		and dup_state.transitions[2].target_state_id == duplicated
		and dup_state.transitions[2].event_name == &"event",
		"New edge is immediately valid, self-target event")
	var copied_edge: String = commands.duplicate_fsm_transition(controller, mid, duplicated, created_edge)
	_check(not copied_edge.is_empty() and copied_edge != created_edge
		and dup_state.transitions.size() == 4
		and dup_state.transitions[3].get_internal_id() == copied_edge,
		"Duplicate edge has fresh ID and adjacent position")
	_check(commands.move_fsm_transition(controller, mid, duplicated, copied_edge, -1),
		"Move edge to previous authored position")
	_check(dup_state.transitions[2].get_internal_id() == copied_edge,
		"Move edge retains immutable ID")
	history.undo()
	_check(dup_state.transitions[3].get_internal_id() == copied_edge,
		"Undo edge move restores original ordering")
	_check(not commands.move_fsm_transition(controller, mid, aid, loop.get_internal_id(), -1),
		"Invalid first-edge upward move rejected")
	_check(not commands.delete_fsm_transition(controller, mid, bid, loop.get_internal_id()),
		"Foreign edge ownership rejected")
	_check(commands.delete_fsm_transition(controller, mid, aid, toward_b.get_internal_id()),
		"Delete original incoming edge")
	var copied_b_edge: String = dup_state.transitions[1].get_internal_id()
	_check(commands.delete_fsm_transition(controller, mid, duplicated, copied_b_edge),
		"Delete duplicate incoming edge")
	_check(commands.delete_fsm_state(controller, mid, bid), "Now unreferenced B can be deleted")
	_check(machine.states.size() == 3 and machine.initial_state_id == aid, "No initial change for noninitial deletion")
	history.undo()
	_check(machine.states.size() == 4 and machine.states[1].get_internal_id() == bid,
		"Undo restores deleted B with same ID and position")
	history.redo()
	_check(machine.states.size() == 3, "Redo removes B again")
	_check(commands.delete_fsm_state(controller, mid, aid), "Initial A deletion accepted when safe")
	_check(machine.initial_state_id == duplicated, "Initial repairs to first enabled survivor")
	history.undo()
	_check(machine.initial_state_id == aid and machine.states.size() == 3,
		"Undo initial deletion restores original reference and state")
	history.redo()
	_check(machine.initial_state_id == duplicated, "Redo reapplies initial repair")
	var empty_id: String = empty.get_internal_id()
	var first: String = commands.add_fsm_state(controller, empty_id)
	_check(not first.is_empty() and empty.initial_state_id == first,
		"First state automatically becomes initial")
	_check(commands.delete_fsm_state(controller, empty_id, first), "Last state can be removed")
	_check(empty.states.is_empty() and empty.initial_state_id == "",
		"Deleting last state restores true Empty machine")
	history.undo()
	_check(empty.states.size() == 1 and empty.initial_state_id == first,
		"Undo last state deletion restores initial ID")
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Graph remains valid after structural edits")
	host.queue_free()
	await _frames(3)
	if failures.is_empty():
		print("[Flujo] Potok 7C-2B structural commands passed")
	quit(0 if failures.is_empty() else 1)

func _event(target_id: String, event_id: StringName) -> FlowStateTransitionDefinition:
	var edge := FlowStateTransitionDefinition.new()
	edge.trigger = FlowStateTransitionDefinition.Trigger.EVENT
	edge.event_name = event_id
	edge.target_state_id = target_id
	return edge

func _frames(count: int) -> void:
	for _i: int in count:
		await process_frame

func _finish(host: Node) -> void:
	host.queue_free()
	await _frames(3)
	quit(0 if failures.is_empty() else 1)

func _check(value: bool, label: String) -> bool:
	if not value:
		failures.append(label)
		push_error("[Flujo] Potok 7C-2B: " + label)
	return value
