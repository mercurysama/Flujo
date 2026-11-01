extends Node


var _failures: Array[String] = []
var _messages: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_print_akis_through_executor()
	await _test_invalid_block_akis_is_skipped()
	_finish()


func _test_print_akis_through_executor() -> void:
	var graph: FlowGraph = _runtime_graph()
	var validation: FlowValidationResult = FlowGraphValidator.validate(graph)
	_check(not validation.has_errors(), "Runtime fixture with block-owned Akis validates.")
	if validation.has_errors():
		return

	var name: FlowVariableDefinition = graph.variables[0]
	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	controller.runtime_output.message_emitted.connect(_record)
	controller.get_value_resolution_context().set_variable_value(
		name.get_internal_id(),
		"Runtime Mercury"
	)
	_messages.clear()
	add_child(controller)
	await get_tree().process_frame
	_check(
		_messages == ["Hola Runtime Mercury", "[1, 2]", "legacy"],
		"ReadyExecutor resolves Print Akis, complex VariableRef and legacy text in stable block order."
	)

	controller.get_value_resolution_context().set_variable_value(
		name.get_internal_id(),
		"Second pass"
	)
	FlowReadyExecutor.new().execute(
		controller,
		graph,
		controller.runtime_output,
		&"Ready"
	)
	_check(
		_messages.size() == 6
			and _messages[3] == "Hola Second pass"
			and _messages[4] == "[1, 2]",
		"Repeated execution reuses per-controller runtime variable state."
	)
	controller.queue_free()
	await get_tree().process_frame


func _test_invalid_block_akis_is_skipped() -> void:
	var graph: FlowGraph = _runtime_graph()
	var broken: FlowPrintBlock = FlowPrintBlock.new()
	broken.content = FlowStructuredDocument.new()
	broken.content.segments = [
		FlowVariableRefSegment.new(
			FlowVariableRefValueSource.new(
				FlowId.create(),
				FlowVariableDefinition.ValueType.STRING
			)
		),
	]
	graph.processes[0].blocks.insert(0, broken)
	var validation: FlowValidationResult = FlowGraphValidator.validate(graph)
	var found_block_path: bool = false
	for diagnostic: FlowDiagnostic in validation.diagnostics:
		if diagnostic.severity == FlowDiagnostic.Severity.ERROR 				and diagnostic.element_path.begins_with(
					"processes[0].blocks[0].content"
				):
			found_block_path = true
			break
	_check(
		found_block_path,
		"GraphValidator prefixes nested Akis diagnostics with the owning block property path."
	)

	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	controller.runtime_output.message_emitted.connect(_record)
	_messages.clear()
	add_child(controller)
	await get_tree().process_frame
	_check(
		_messages == ["Hola Mercury", "[1, 2]", "legacy"],
		"Invalid Akis block is skipped without stopping later valid blocks."
	)
	controller.queue_free()
	await get_tree().process_frame


func _runtime_graph() -> FlowGraph:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()

	var name: FlowVariableDefinition = FlowVariableDefinition.new()
	name.display_name = "Name"
	name.value_type = FlowVariableDefinition.ValueType.STRING
	name.string_value = "Mercury"

	var items: FlowVariableDefinition = FlowVariableDefinition.new()
	items.display_name = "Items"
	items.value_type = FlowVariableDefinition.ValueType.ARRAY
	items.complex_value_source = FlowArrayValueSource.new([
		FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 1),
		FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 2),
	])
	graph.variables = [name, items]

	var greeting: FlowPrintBlock = FlowPrintBlock.new()
	greeting.content = FlowStructuredDocument.new()
	var prefix: FlowTextSegment = FlowTextSegment.new()
	prefix.text = "Hola "
	greeting.content.segments = [
		prefix,
		FlowVariableRefSegment.new(
			FlowVariableRefValueSource.new(
				name.get_internal_id(),
				name.value_type
			)
		),
	]

	var array_print: FlowPrintBlock = FlowPrintBlock.new()
	array_print.content = FlowStructuredDocument.new()
	array_print.content.segments = [
		FlowVariableRefSegment.new(
			FlowVariableRefValueSource.new(
				items.get_internal_id(),
				items.value_type
			)
		),
	]

	var legacy: FlowPrintBlock = FlowPrintBlock.new()
	legacy.text = "legacy"

	var process: FlowProcess = FlowProcess.new()
	process.process_type = FlowProcess.ProcessType.READY
	process.blocks = [greeting, array_print, legacy]
	graph.processes = [process]
	return graph


func _record(_controller: Node, _process_id: String, _block_id: String, message: String) -> void:
	_messages.append(message)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("[Flujo] Lot 09 runtime check failed: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Lot 09 runtime integration test passed")
	else:
		push_error("[Flujo] Lot 09 runtime test failed: %d failures" % _failures.size())
	get_tree().quit(0 if _failures.is_empty() else 1)
