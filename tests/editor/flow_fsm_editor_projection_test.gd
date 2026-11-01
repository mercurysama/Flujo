extends Node
## Potok 7A: read-only editor projection contract, no graph edits.
const PROJECTION_PATH: String = "res://addons/vp_flujo/editor/flow_fsm_editor_projection.gd"
var failures: Array[String] = []

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	if not ResourceLoader.exists(PROJECTION_PATH):
		_check(false, "Potok 7A presenter script is missing (expected RED)")
		get_tree().quit(1)
		return
	var presenter_script: Script = load(PROJECTION_PATH) as Script
	if presenter_script == null:
		_check(false, "Presenter script must be loadable")
		get_tree().quit(1)
		return
	var presenter: Object = presenter_script.new()
	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var idle := FlowStateDefinition.new()
	idle.display_name = "Idle"
	idle.user_note = "First"
	var running := FlowStateDefinition.new()
	running.display_name = "Running"
	running.user_note = "Second"
	running.is_initial = true # Legacy state flag must not override machine.initial_state_id.
	var enter := FlowPrintBlock.new()
	enter.text = "enter"
	var update := FlowPrintBlock.new()
	update.text = "update"
	var exit := FlowPrintBlock.new()
	exit.text = "exit"
	idle.enter_blocks = [enter]
	idle.blocks = [update]
	idle.exit_blocks = [exit]
	var event_edge := FlowStateTransitionDefinition.new()
	event_edge.display_name = "Go"
	event_edge.trigger = FlowStateTransitionDefinition.Trigger.EVENT
	event_edge.event_name = &"go"
	event_edge.target_state_id = running.get_internal_id()
	event_edge.priority = 9
	var condition_edge := FlowStateTransitionDefinition.new()
	condition_edge.display_name = "Back"
	condition_edge.trigger = FlowStateTransitionDefinition.Trigger.CONDITION
	condition_edge.condition = FlowLiteralValueSource.new(Variant.Type.TYPE_BOOL, true)
	condition_edge.target_state_id = running.get_internal_id()
	condition_edge.priority = -3
	idle.transitions = [event_edge, condition_edge]
	var machine := FlowStateMachineDefinition.new()
	machine.display_name = "Machine"
	machine.states = [idle, running]
	machine.initial_state_id = idle.get_internal_id()
	machine.tick_mode = FlowStateMachineDefinition.TickMode.MANUAL
	var other := FlowStateMachineDefinition.new()
	other.display_name = "Machine" # Same name must not change routing.
	other.states = [FlowStateDefinition.new()]
	other.initial_state_id = other.states[0].get_internal_id()
	var empty := FlowStateMachineDefinition.new()
	empty.display_name = "Draft"
	empty.states = []
	graph.state_machines = [other, machine, empty]
	var before_ids: Array[String] = [
		graph.state_machines[0].get_internal_id(), graph.state_machines[1].get_internal_id(),
		idle.get_internal_id(), running.get_internal_id(),
		event_edge.get_internal_id(), condition_edge.get_internal_id()
	]
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Valid fixture graph")
	var view: Dictionary = presenter.call("present", graph, machine.get_internal_id())
	_check(view.get("found") == true and view.get("empty") == false,
		"Select existing nonempty machine by ID")
	var head: Dictionary = view.get("machine", {})
	_check(head.get("id") == machine.get_internal_id() and head.get("name") == "Machine",
		"Machine identity and name preserved")
	_check(head.get("tick_mode") == FlowStateMachineDefinition.TickMode.MANUAL,
		"Clock metadata preserved")
	_check(head.get("initial_state_id") == idle.get_internal_id(),
		"Initial ID is source of truth")
	var states: Array = view.get("states", [])
	_check(states.size() == 2, "Authored state order preserved")
	if states.size() == 2:
		_check(states[0].get("id") == idle.get_internal_id() and
			states[1].get("id") == running.get_internal_id(), "Stable ordered state IDs")
		_check(states[0].get("is_initial") == true and states[1].get("is_initial") == false,
			"Initial flag is derived from machine ID, not legacy state flag")
		_check(states[0].get("name") == "Idle" and states[1].get("note") == "Second",
			"Display properties visible without losing identity")
		var phases: Array = states[0].get("phases", [])
		_check(phases.size() == 3, "All three state phases are presented")
		if phases.size() == 3:
			_check(phases[0].get("name") == "Enter" and
				phases[1].get("name") == "Update" and
				phases[2].get("name") == "Exit", "Enter Update Exit order")
			_check(phases[0].get("blocks", []).size() == 1 and
				phases[0]["blocks"][0].get("id") == enter.get_internal_id() and
				phases[1]["blocks"][0].get("id") == update.get_internal_id() and
				phases[2]["blocks"][0].get("id") == exit.get_internal_id(),
				"Each phase retains its owned block stable ID")
		var edges: Array = states[0].get("transitions", [])
		_check(edges.size() == 2, "Transition authoring order preserved")
		if edges.size() == 2:
			_check(edges[0].get("id") == event_edge.get_internal_id() and
				edges[0].get("trigger") == FlowStateTransitionDefinition.Trigger.EVENT and
				edges[0].get("event_name") == "go" and edges[0].get("priority") == 9,
				"Event transition exposes typed trigger and priority")
			_check(edges[1].get("id") == condition_edge.get_internal_id() and
				edges[1].get("condition_present") == true and
				edges[1].get("priority") == -3, "Condition transition describes readiness only")
	_check(_is_detached(view), "Projection contains no Resource or Node references")
	_check(view == presenter.call("present", graph, machine.get_internal_id()),
		"Repeat presentation produces identical data")
	var missing: Dictionary = presenter.call("present", graph, "not-a-machine")
	_check(missing.get("found") == false and (missing.get("states", []) as Array).is_empty(),
		"Missing selection is inert")
	var draft: Dictionary = presenter.call("present", graph, empty.get_internal_id())
	_check(draft.get("found") == true and draft.get("empty") == true,
		"Empty machine becomes a draft view")
	var rows: Array = draft.get("states", [])
	_check(rows.size() == 1 and rows[0].get("empty") == true and
		rows[0].get("name") == "Empty" and rows[0].get("id") == "",
		"Empty is a presentation placeholder, not an authored state")
	_check(empty.states.is_empty(), "Draft does not create a Resource")
	_check(before_ids == [
		graph.state_machines[0].get_internal_id(), graph.state_machines[1].get_internal_id(),
		idle.get_internal_id(), running.get_internal_id(),
		event_edge.get_internal_id(), condition_edge.get_internal_id()
	], "No authored IDs changed")
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Graph remains validated")
	if failures.is_empty():
		print("[Flujo] Potok 7A read-only editor projection passed")
	get_tree().quit(0 if failures.is_empty() else 1)

func _is_detached(value: Variant) -> bool:
	if value is Resource or value is Node:
		return false
	if value is Dictionary:
		for key: Variant in value:
			if not _is_detached(key) or not _is_detached(value[key]):
				return false
	if value is Array:
		for item: Variant in value:
			if not _is_detached(item):
				return false
	return true

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("[Flujo] Potok 7A: " + message)
