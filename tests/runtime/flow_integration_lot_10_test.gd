extends Node


var _failures: Array[String] = []
var _messages: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_schema4_requirement_backed_print()
	await _test_schema4_requirement_backed_timer()
	await _test_invalid_requirement_binding_stops_execution()
	_finish()


func _test_schema4_requirement_backed_print() -> void:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_4
	graph.constructor = FlowConstructorDefinition.new()

	var requirement: FlowRequiredNodeDefinition = FlowRequiredNodeDefinition.new()
	requirement.display_name = "Target"
	requirement.expected_node_name = &"Target"
	requirement.required_class_name = &"Node2D"
	graph.constructor.requirements = [requirement]

	var print_block: FlowPrintBlock = FlowPrintBlock.new()
	print_block.content = FlowStructuredDocument.new()
	var prefix: FlowTextSegment = FlowTextSegment.new()
	prefix.text = "z="
	print_block.content.segments = [
		prefix,
		FlowNodePropertyRefSegment.new(
			FlowNodePropertyRefValueSource.new(
				requirement.get_internal_id(),
				NodePath("WrongFallback"),
				&"Target",
				&"z_index",
				Variant.Type.TYPE_INT
			)
		),
	]

	var process: FlowProcess = FlowProcess.new()
	process.blocks = [print_block]
	graph.processes = [process]

	var validation: FlowValidationResult = FlowGraphValidator.validate(graph)
	_check(not validation.has_errors(), "Schema 4 Requirement-backed Akis graph validates.")
	if validation.has_errors():
		return

	var controller: PVController = PVController.new()
	controller.name = "Controller"
	controller.flow_graph = graph
	var target: Node2D = Node2D.new()
	target.name = "Target"
	target.z_index = 12
	controller.add_child(target)
	controller.requirement_bindings = {
		requirement.get_internal_id(): NodePath("Target"),
	}
	controller.runtime_output.message_emitted.connect(_record)
	_messages.clear()
	add_child(controller)
	await get_tree().process_frame
	_check(
		_messages == ["z=12"],
		"Schema 4 Ready runtime resolves Requirement-backed $ property inside Print Akis."
	)

	target.z_index = 21
	FlowReadyExecutor.new().execute(
		controller,
		graph,
		controller.runtime_output,
		&"Ready"
	)
	_check(
		_messages.size() == 2 and _messages[1] == "z=21",
		"Schema 4 runtime re-reads the live Requirement-bound property on each pass."
	)

	controller.queue_free()
	await get_tree().process_frame


func _test_schema4_requirement_backed_timer() -> void:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_4
	graph.constructor = FlowConstructorDefinition.new()

	var requirement: FlowRequiredNodeDefinition = FlowRequiredNodeDefinition.new()
	requirement.display_name = "Target"
	requirement.expected_node_name = &"Target"
	requirement.required_class_name = &"Node2D"
	graph.constructor.requirements = [requirement]

	var print_block: FlowPrintBlock = FlowPrintBlock.new()
	print_block.content = FlowStructuredDocument.new()
	var prefix: FlowTextSegment = FlowTextSegment.new()
	prefix.text = "timer-z="
	print_block.content.segments = [
		prefix,
		FlowNodePropertyRefSegment.new(
			FlowNodePropertyRefValueSource.new(
				requirement.get_internal_id(),
				NodePath("WrongFallback"),
				&"Target",
				&"z_index",
				Variant.Type.TYPE_INT
			)
		),
	]

	var timer: FlowTimerDefinition = FlowTimerDefinition.new()
	timer.process_type = FlowProcess.ProcessType.TIMER
	timer.interval_seconds = 3600.0
	timer.repeat = true
	timer.blocks = [print_block]
	graph.processes = [timer]

	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	var target: Node2D = Node2D.new()
	target.name = "Target"
	target.z_index = 33
	controller.add_child(target)
	controller.requirement_bindings = {
		requirement.get_internal_id(): NodePath("Target"),
	}
	controller.runtime_output.message_emitted.connect(_record)
	_messages.clear()
	add_child(controller)
	await get_tree().process_frame

	var clocks: Array[Timer] = _native_timers(controller)
	_check(
		clocks.size() == 1,
		"Schema 4 Timer scheduler starts one native clock after valid Requirement binding validation."
	)
	if clocks.size() == 1:
		clocks[0].timeout.emit()
		_check(
			_messages == ["timer-z=33"],
			"Schema 4 Timer resolves Requirement-backed Akis through the shared executor."
		)

	controller.queue_free()
	await get_tree().process_frame


func _native_timers(controller: PVController) -> Array[Timer]:
	var result: Array[Timer] = []
	for child: Node in controller.get_children(true):
		if not child is FlowTimerRuntime:
			continue
		for candidate: Node in child.get_children(true):
			if candidate is Timer:
				result.append(candidate as Timer)
	return result


func _test_invalid_requirement_binding_stops_execution() -> void:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_4
	graph.constructor = FlowConstructorDefinition.new()

	var requirement: FlowRequiredNodeDefinition = FlowRequiredNodeDefinition.new()
	requirement.display_name = "Target"
	requirement.expected_node_name = &"Target"
	requirement.required_class_name = &"Node2D"
	graph.constructor.requirements = [requirement]

	var print_block: FlowPrintBlock = FlowPrintBlock.new()
	print_block.content = FlowStructuredDocument.new()
	print_block.content.segments = [
		FlowNodeRefSegment.new(
			FlowNodeRefValueSource.new(
				requirement.get_internal_id(),
				NodePath("Target"),
				&"Target",
				&"Node2D"
			)
		),
	]
	var process: FlowProcess = FlowProcess.new()
	process.blocks = [print_block]
	graph.processes = [process]

	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	var target: Node2D = Node2D.new()
	target.name = "Target"
	controller.add_child(target)
	controller.requirement_bindings = {
		requirement.get_internal_id(): NodePath("../invalid"),
	}
	controller.runtime_output.message_emitted.connect(_record)
	_messages.clear()
	add_child(controller)
	await get_tree().process_frame
	_check(
		_messages.is_empty(),
		"Malformed Schema 4 Requirement bindings stop execution instead of silently falling back."
	)
	controller.queue_free()
	await get_tree().process_frame


func _record(_controller: Node, _process_id: String, _block_id: String, message: String) -> void:
	_messages.append(message)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("[Flujo] Lot 10 runtime check failed: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Lot 10 schema 4 Akis runtime test passed")
	else:
		push_error("[Flujo] Lot 10 runtime test failed: %d failures" % _failures.size())
	get_tree().quit(0 if _failures.is_empty() else 1)
