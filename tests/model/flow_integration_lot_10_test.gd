extends Node


var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_requirement_ids_remap_through_full_source_tree()
	_test_block_akis_requirement_remap()
	_finish()


func _schema4_graph() -> Dictionary:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_4
	graph.constructor = FlowConstructorDefinition.new()

	var requirement: FlowRequiredNodeDefinition = FlowRequiredNodeDefinition.new()
	requirement.display_name = "Target"
	requirement.expected_node_name = &"Target"
	requirement.required_class_name = &"Node2D"
	graph.constructor.requirements = [requirement]

	var variable: FlowVariableDefinition = FlowVariableDefinition.new()
	variable.display_name = "Targets"
	variable.value_type = FlowVariableDefinition.ValueType.ARRAY
	variable.complex_value_source = FlowArrayValueSource.new([
		FlowDictionaryValueSource.new([
			FlowDictionaryEntry.new(
				"node",
				FlowNodeRefValueSource.new(
					requirement.get_internal_id(),
					NodePath("Target"),
					&"Target",
					&"Node2D"
				)
			),
			FlowDictionaryEntry.new(
				"z",
				FlowNodePropertyRefValueSource.new(
					requirement.get_internal_id(),
					NodePath("Target"),
					&"Target",
					&"z_index",
					Variant.Type.TYPE_INT
				)
			),
		]),
	])
	graph.variables = [variable]

	var print_block: FlowPrintBlock = FlowPrintBlock.new()
	print_block.content = FlowStructuredDocument.new()
	print_block.content.segments = [
		FlowNodePropertyRefSegment.new(
			FlowNodePropertyRefValueSource.new(
				requirement.get_internal_id(),
				NodePath("Target"),
				&"Target",
				&"z_index",
				Variant.Type.TYPE_INT
			)
		),
	]
	var process: FlowProcess = FlowProcess.new()
	process.blocks = [print_block]
	graph.processes = [process]
	return {
		"graph": graph,
		"requirement": requirement,
		"variable": variable,
		"print": print_block,
	}


func _test_requirement_ids_remap_through_full_source_tree() -> void:
	var fixture: Dictionary = _schema4_graph()
	var graph: FlowGraph = fixture["graph"]
	var original_requirement: FlowRequiredNodeDefinition = fixture["requirement"]
	var copy: FlowGraph = graph.duplicate_with_new_ids()
	_check(copy != null and copy.constructor != null, "Schema 4 graph duplicates.")
	if copy == null or copy.constructor == null or copy.constructor.requirements.is_empty():
		return
	var copied_requirement: FlowRequiredNodeDefinition = copy.constructor.requirements[0]
	var copied_variable: FlowVariableDefinition = copy.variables[0]
	var copied_array: FlowArrayValueSource = copied_variable.complex_value_source as FlowArrayValueSource
	var copied_dictionary: FlowDictionaryValueSource = copied_array.elements[0] as FlowDictionaryValueSource
	var copied_node: FlowNodeRefValueSource = copied_dictionary.entries[0].value_source as FlowNodeRefValueSource
	var copied_property: FlowNodePropertyRefValueSource = copied_dictionary.entries[1].value_source as FlowNodePropertyRefValueSource
	_check(
		copied_requirement.get_internal_id() != original_requirement.get_internal_id(),
		"Requirement duplicate receives a fresh stable ID."
	)
	_check(
		copied_node.requirement_id == copied_requirement.get_internal_id()
			and copied_property.requirement_id == copied_requirement.get_internal_id(),
		"Nested Array/Dictionary Node references remap to the duplicated Requirement."
	)
	var validation: FlowValidationResult = FlowGraphValidator.validate(copy)
	_check(
		not validation.has_errors(),
		"Duplicated Schema 4 graph validates after nested Requirement remap."
	)


func _test_block_akis_requirement_remap() -> void:
	var fixture: Dictionary = _schema4_graph()
	var graph: FlowGraph = fixture["graph"]
	var copy: FlowGraph = graph.duplicate_with_new_ids()
	if copy == null or copy.constructor == null or copy.processes.is_empty():
		_check(false, "Schema 4 duplicate exposes copied block Akis.")
		return
	var copied_requirement: FlowRequiredNodeDefinition = copy.constructor.requirements[0]
	var copied_print: FlowPrintBlock = copy.processes[0].blocks[0] as FlowPrintBlock
	var segment: FlowNodePropertyRefSegment = copied_print.content.segments[0] as FlowNodePropertyRefSegment
	var source: FlowNodePropertyRefValueSource = segment.get_value_source() as FlowNodePropertyRefValueSource
	_check(
		source.requirement_id == copied_requirement.get_internal_id(),
		"Block-owned Akis remaps NodePropertyRef Requirement identity."
	)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("[Flujo] Lot 10 model check failed: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Lot 10 graph reference integration test passed")
	else:
		push_error("[Flujo] Lot 10 model test failed: %d failures" % _failures.size())
	get_tree().quit(0 if _failures.is_empty() else 1)
