extends Node


class ExternalHookBlock extends FlowBlock:
	@export_storage var structure_valid: bool = true
	@export_storage var internal_reference_id: String = ""
	var validation_calls: int = 0
	var validation_path: String = ""
	var remap_calls: int = 0


	func validate_structure(context: Dictionary) -> void:
		validation_calls += 1
		validation_path = String(context.get("path", ""))
		if structure_valid:
			return
		var result: FlowValidationResult = context.get("result") as FlowValidationResult
		if result != null:
			result.add_diagnostic(FlowDiagnostic.new(
				&"external_block_structure_invalid",
				FlowDiagnostic.Severity.ERROR,
				"External block structure is invalid.",
				validation_path,
				get_internal_id()
			))


	func remap_internal_references(id_map: Dictionary[String, String]) -> void:
		remap_calls += 1
		internal_reference_id = id_map.get(internal_reference_id, internal_reference_id)


var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_base_hooks_are_no_ops()
	_test_validation_hook()
	_test_graph_duplication_hook()
	_test_schema_5_duplication_hook()
	if _failures.is_empty():
		print("[Flujo] External block hooks test passed")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	get_tree().quit(1)


func _test_base_hooks_are_no_ops() -> void:
	var block: FlowBlock = FlowBlock.new()
	block.validate_structure({})
	block.remap_internal_references({})
	_check(true, "The base hooks accept empty contexts and maps.")


func _test_validation_hook() -> void:
	var valid_block: ExternalHookBlock = ExternalHookBlock.new()
	var graph: FlowGraph = _graph_with_blocks([valid_block])
	var valid_result: FlowValidationResult = FlowGraphValidator.validate(graph)
	_check(not valid_result.has_errors(), "A valid external block structure keeps the graph valid.")
	_check(valid_block.validation_calls == 1, "The graph validator invokes the block validation hook once.")
	_check(valid_block.validation_path == "processes[0].blocks[0]", "The validation hook receives the block path.")

	var invalid_block: ExternalHookBlock = ExternalHookBlock.new()
	invalid_block.structure_valid = false
	var invalid_result: FlowValidationResult = FlowGraphValidator.validate(_graph_with_blocks([invalid_block]))
	_check(_has(invalid_result, &"external_block_structure_invalid", "processes[0].blocks[0"), "External structural diagnostics are returned by graph validation.")


func _test_graph_duplication_hook() -> void:
	var source: ExternalHookBlock = ExternalHookBlock.new()
	var target: FlowBlock = FlowBlock.new()
	source.internal_reference_id = target.get_internal_id()
	var graph: FlowGraph = _graph_with_blocks([source, target])
	var copy: FlowGraph = graph.duplicate_with_new_ids()
	var copied_source: ExternalHookBlock = copy.processes[0].blocks[0] as ExternalHookBlock
	var copied_target: FlowBlock = copy.processes[0].blocks[1]
	_check(copied_source != null and copied_target != null, "Graph duplication preserves the external block and its target.")
	if copied_source == null or copied_target == null:
		return
	_check(copied_source.get_internal_id() != source.get_internal_id(), "Graph duplication gives the external block a new ID.")
	_check(copied_source.internal_reference_id == copied_target.get_internal_id(), "Graph duplication remaps external block references with the complete ID map.")
	_check(copied_source.remap_calls >= 1, "Graph duplication invokes the external remapping hook.")

	var direct: ExternalHookBlock = ExternalHookBlock.new()
	direct.internal_reference_id = direct.get_internal_id()
	var direct_copy: ExternalHookBlock = direct.duplicate_with_new_id() as ExternalHookBlock
	_check(direct_copy.internal_reference_id == direct_copy.get_internal_id(), "Direct block duplication remaps its own internal ID reference.")
	_check(direct_copy.remap_calls >= 1, "Direct block duplication invokes the remapping hook.")


func _test_schema_5_duplication_hook() -> void:
	var source: ExternalHookBlock = ExternalHookBlock.new()
	var target: FlowBlock = FlowBlock.new()
	source.internal_reference_id = target.get_internal_id()
	var graph: FlowGraph = _graph_with_blocks([source, target])
	graph.schema_version = FlowGraph.SCHEMA_VERSION_5
	var copy: FlowGraph = graph.duplicate_with_new_ids()
	var copied_source: ExternalHookBlock = copy.processes[0].blocks[0] as ExternalHookBlock
	var copied_target: FlowBlock = copy.processes[0].blocks[1]
	_check(copied_source != null and copied_target != null, "Schema 5 duplication preserves external blocks.")
	if copied_source == null or copied_target == null:
		return
	_check(copied_source.internal_reference_id == copied_target.get_internal_id(), "Schema 5 duplication remaps external block references.")
	_check(copied_source.remap_calls >= 1, "Schema 5 duplication invokes the remapping hook.")


func _graph_with_blocks(blocks: Array[FlowBlock]) -> FlowGraph:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var process: FlowProcess = FlowProcess.new()
	process.blocks = blocks
	graph.processes = [process]
	return graph


func _has(result: FlowValidationResult, code: StringName, path_fragment: String) -> bool:
	for diagnostic: FlowDiagnostic in result.diagnostics:
		if diagnostic.code == code and diagnostic.element_path.contains(path_fragment):
			return true
	return false


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_failures.append(message)
	return condition
