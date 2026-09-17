class_name FlowTimerRuntime
extends Node

## Per-controller, transient scheduler. Definitions are never mutated or made scene nodes.
var _controller: PVController
var _graph: FlowGraph
var _active: Dictionary[String, Timer] = {}


func start(controller: PVController) -> void:
	if Engine.is_editor_hint() or not controller.can_execute_visual_program():
		return
	_controller = controller
	_graph = controller.flow_graph
	if _graph == null or _graph.schema_version != FlowGraph.SCHEMA_VERSION_3:
		return
	var invalid_paths: Array[String] = []
	for diagnostic: FlowDiagnostic in FlowGraphValidator.validate(_graph).diagnostics:
		if diagnostic.severity == FlowDiagnostic.Severity.ERROR:
			invalid_paths.append(diagnostic.element_path)
	if invalid_paths.has("graph"):
		return
	for index: int in _graph.processes.size():
		var definition: FlowTimerDefinition = _graph.processes[index] as FlowTimerDefinition
		if definition == null or not definition.enabled:
			continue
		var path: String = "processes[%d]" % index
		if not definition.has_valid_interval() or definition.process_type != FlowProcess.ProcessType.TIMER \
				or invalid_paths.has(path):
			push_warning("[Flujo] Invalid Timer at %s; not started." % path)
			continue
		var timer: Timer = Timer.new()
		timer.one_shot = not definition.repeat
		timer.wait_time = definition.interval_seconds
		timer.timeout.connect(_on_timeout.bind(definition.get_internal_id(), definition, timer))
		add_child(timer, false, Node.INTERNAL_MODE_BACK)
		_active[definition.get_internal_id()] = timer
		timer.start()


func _on_timeout(process_id: String, definition: FlowTimerDefinition, timer: Timer) -> void:
	if not is_inside_tree() or not is_instance_valid(_controller) \
			or not _controller.can_execute_visual_program() or _controller.flow_graph != _graph \
			or _active.get(process_id) != timer:
		return
	if timer.one_shot:
		_active.erase(process_id)
		timer.stop()
	if definition.enabled:
		FlowReadyExecutor.new().execute(_controller, _graph, _controller.runtime_output, &"Timer", process_id)
	if timer.one_shot:
		timer.queue_free()


func stop() -> void:
	_active.clear()
	for child: Node in get_children(true):
		var timer: Timer = child as Timer
		if timer != null:
			timer.stop()
			for connection: Dictionary in timer.timeout.get_connections():
				timer.timeout.disconnect(connection["callable"])
			timer.queue_free()


func _exit_tree() -> void:
	stop()
