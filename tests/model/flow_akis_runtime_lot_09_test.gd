extends Node


var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_text_and_typed_resolution()
	_test_complex_variable_defaults()
	_test_variable_cycle_guard()
	_test_graph_duplication_remaps_nested_variable_refs()
	_finish()


func _test_text_and_typed_resolution() -> void:
	var graph: FlowGraph = FlowGraph.new()
	var name: FlowVariableDefinition = FlowVariableDefinition.new()
	name.display_name = "Name"
	name.value_type = FlowVariableDefinition.ValueType.STRING
	name.string_value = "Mercury"
	graph.variables = [name]

	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	var prefix: FlowTextSegment = FlowTextSegment.new()
	prefix.text = "Hola "
	document.segments = [
		prefix,
		FlowVariableRefSegment.new(
			FlowVariableRefValueSource.new(name.get_internal_id(), name.value_type)
		),
	]
	var context: FlowValueResolutionContext = FlowValueResolutionContext.new(graph)
	var rendered: FlowStructuredRenderResult = FlowStructuredDocumentResolver.resolve_text(
		document,
		context
	)
	_check(
		not rendered.has_errors() and rendered.text == "Hola Mercury",
		"Akis text resolves VariableRef through runtime context."
	)

	var array_source: FlowArrayValueSource = FlowArrayValueSource.new([
		FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 1),
		FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 2),
	])
	var value_document: FlowStructuredDocument = FlowStructuredDocument.new()
	value_document.segments = [FlowArraySegment.new(array_source)]
	var value: FlowValueResult = FlowStructuredDocumentResolver.resolve_value(
		value_document,
		context
	)
	_check(
		value.success
			and value.value_type == Variant.Type.TYPE_ARRAY
			and value.value == [1, 2],
		"One-Tok Akis resolves as a typed Array without text coercion."
	)

	var invalid_shape: FlowStructuredDocument = FlowStructuredDocument.new()
	var text: FlowTextSegment = FlowTextSegment.new()
	text.text = "not a typed value"
	invalid_shape.segments = [text, FlowArraySegment.new(array_source)]
	var invalid: FlowValueResult = FlowStructuredDocumentResolver.resolve_value(
		invalid_shape,
		context
	)
	_check(
		not invalid.success
			and invalid.diagnostic != null
			and invalid.diagnostic.code == FlowDiagnostic.CODE_STRUCTURED_VALUE_SHAPE_INVALID,
		"Typed Akis rejects mixed runtime text plus Tok."
	)


func _test_complex_variable_defaults() -> void:
	var array_variable: FlowVariableDefinition = FlowVariableDefinition.new()
	array_variable.display_name = "Items"
	array_variable.value_type = FlowVariableDefinition.ValueType.ARRAY
	array_variable.complex_value_source = FlowArrayValueSource.new([
		FlowLiteralValueSource.new(Variant.Type.TYPE_STRING, "A"),
		FlowLiteralValueSource.new(Variant.Type.TYPE_STRING, "B"),
	])
	var dictionary_variable: FlowVariableDefinition = FlowVariableDefinition.new()
	dictionary_variable.display_name = "Config"
	dictionary_variable.value_type = FlowVariableDefinition.ValueType.DICTIONARY
	dictionary_variable.complex_value_source = FlowDictionaryValueSource.new([
		FlowDictionaryEntry.new(
			"enabled",
			FlowLiteralValueSource.new(Variant.Type.TYPE_BOOL, true)
		),
	])
	var graph: FlowGraph = FlowGraph.new()
	graph.variables = [array_variable, dictionary_variable]
	var context: FlowValueResolutionContext = FlowValueResolutionContext.new(graph)

	var array_ref: FlowVariableRefValueSource = FlowVariableRefValueSource.new(
		array_variable.get_internal_id(),
		array_variable.value_type
	)
	var dictionary_ref: FlowVariableRefValueSource = FlowVariableRefValueSource.new(
		dictionary_variable.get_internal_id(),
		dictionary_variable.value_type
	)
	var array_result: FlowValueResult = array_ref.resolve(context)
	var dictionary_result: FlowValueResult = dictionary_ref.resolve(context)
	_check(
		array_result.success and array_result.value == ["A", "B"],
		"Array graph variable resolves its owned structured default."
	)
	_check(
		dictionary_result.success
			and dictionary_result.value is Dictionary
			and dictionary_result.value["enabled"] == true,
		"Dictionary graph variable resolves its owned structured default."
	)

	context.set_variable_value(array_variable.get_internal_id(), [9, 8, 7])
	var override: FlowValueResult = array_ref.resolve(context)
	_check(
		override.success and override.value == [9, 8, 7],
		"Per-instance runtime variable value overrides the persisted complex default."
	)


func _test_variable_cycle_guard() -> void:
	var left: FlowVariableDefinition = FlowVariableDefinition.new()
	left.display_name = "Left"
	left.value_type = FlowVariableDefinition.ValueType.ARRAY
	var right: FlowVariableDefinition = FlowVariableDefinition.new()
	right.display_name = "Right"
	right.value_type = FlowVariableDefinition.ValueType.ARRAY

	left.complex_value_source = FlowArrayValueSource.new([
		FlowVariableRefValueSource.new(right.get_internal_id(), right.value_type),
	])
	right.complex_value_source = FlowArrayValueSource.new([
		FlowVariableRefValueSource.new(left.get_internal_id(), left.value_type),
	])

	var graph: FlowGraph = FlowGraph.new()
	graph.variables = [left, right]
	var result: FlowValueResult = FlowVariableRefValueSource.new(
		left.get_internal_id(),
		left.value_type
	).resolve(FlowValueResolutionContext.new(graph))
	_check(
		not result.success
			and result.diagnostic != null
			and result.diagnostic.code == FlowDiagnostic.CODE_VARIABLE_RESOLUTION_CYCLE,
		"Nested complex VariableRefs stop recursive cycles deterministically."
	)


func _test_graph_duplication_remaps_nested_variable_refs() -> void:
	var source: FlowVariableDefinition = FlowVariableDefinition.new()
	source.display_name = "Source"
	source.value_type = FlowVariableDefinition.ValueType.ARRAY
	source.complex_value_source = FlowArrayValueSource.new([
		FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 4),
	])
	var dependent: FlowVariableDefinition = FlowVariableDefinition.new()
	dependent.display_name = "Dependent"
	dependent.value_type = FlowVariableDefinition.ValueType.ARRAY
	dependent.complex_value_source = FlowArrayValueSource.new([
		FlowVariableRefValueSource.new(source.get_internal_id(), source.value_type),
	])
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	graph.variables = [source, dependent]

	var print_block: FlowPrintBlock = FlowPrintBlock.new()
	print_block.content = FlowStructuredDocument.new()
	print_block.content.segments = [
		FlowVariableRefSegment.new(
			FlowVariableRefValueSource.new(
				source.get_internal_id(),
				source.value_type
			)
		),
	]
	var process: FlowProcess = FlowProcess.new()
	process.blocks = [print_block]
	graph.processes = [process]

	var copy: FlowGraph = graph.duplicate_with_new_ids()
	_check(copy != null and copy.variables.size() == 2, "Graph duplicate preserves complex variables.")
	if copy == null or copy.variables.size() != 2:
		return
	var copied_source: FlowVariableDefinition = copy.variables[0]
	var copied_dependent: FlowVariableDefinition = copy.variables[1]
	var copied_array: FlowArrayValueSource = 		copied_dependent.complex_value_source as FlowArrayValueSource
	var nested_ref: FlowVariableRefValueSource = copied_array.elements[0] as FlowVariableRefValueSource
	_check(
		copied_source.get_internal_id() != source.get_internal_id()
			and copied_dependent.complex_value_source.source_id 				!= dependent.complex_value_source.source_id
			and nested_ref.variable_id == copied_source.get_internal_id(),
		"Graph duplication renews owned source IDs and remaps nested VariableRef identity."
	)

	var copied_print: FlowPrintBlock = copy.processes[0].blocks[0] as FlowPrintBlock
	var copied_chip: FlowVariableRefSegment = copied_print.content.segments[0] as FlowVariableRefSegment
	var copied_block_ref: FlowVariableRefValueSource = 		copied_chip.get_value_source() as FlowVariableRefValueSource
	_check(
		copied_print != print_block
			and copied_print.content != print_block.content
			and copied_block_ref.variable_id == copied_source.get_internal_id(),
		"Graph duplication deep-copies block Akis and remaps its nested VariableRef."
	)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("[Flujo] Lot 09 model check failed: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Lot 09 Akis runtime model test passed")
	else:
		push_error("[Flujo] Lot 09 model test failed: %d failures" % _failures.size())
	get_tree().quit(0 if _failures.is_empty() else 1)
