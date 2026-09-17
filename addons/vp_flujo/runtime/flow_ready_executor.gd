class_name FlowReadyExecutor
extends RefCounted

## Only built-in definitions with explicit handlers can execute. Definitions contain no code.
const PRINT_BLOCK: Script = preload("res://addons/vp_flujo/runtime/model/flow_print_block.gd")
const EVERYTHING_FLOWS_BLOCK: Script = preload("res://addons/vp_flujo/runtime/model/flow_everything_flows_block.gd")

var _handlers: Dictionary[Script, Callable] = {
	PRINT_BLOCK: _print_message,
	EVERYTHING_FLOWS_BLOCK: _everything_flows_message,
}


func execute(controller: Node, graph: FlowGraph, output: FlowRuntimeOutput, entry_point: StringName = &"Ready", process_id: String = "") -> void:
	if Engine.is_editor_hint() or graph == null:
		return
	if graph.schema_version != FlowGraph.SCHEMA_VERSION_3:
		push_warning("[Flujo] Ready requires an explicitly migrated schema 3 FlowGraph.")
		return
	var invalid_paths: Array[String] = []
	var validation: FlowValidationResult = FlowGraphValidator.validate(graph)
	for diagnostic: FlowDiagnostic in validation.diagnostics:
		if diagnostic.severity == FlowDiagnostic.Severity.ERROR:
			invalid_paths.append(diagnostic.element_path)
			push_warning("[Flujo] %s at %s: %s" % [diagnostic.code, diagnostic.element_path, diagnostic.message])
	if invalid_paths.has("graph"):
		return
	if entry_point == &"Constructor":
		if graph.constructor != null and graph.constructor.enabled and not invalid_paths.has("constructor"):
			_execute_blocks(controller, graph, graph.constructor, "constructor", output, entry_point, graph.constructor.get_internal_id(), invalid_paths, false)
		return
	for process_index: int in graph.processes.size():
		var process: FlowProcess = graph.processes[process_index]
		var process_path: String = "processes[%d]" % process_index
		if process == null or not process.enabled or invalid_paths.has(process_path):
			continue
		if not FlowProcess.ProcessType.values().has(process.process_type):
			push_warning("[Flujo] Invalid process type at %s; skipping." % process_path)
			continue
		if entry_point == &"Timer":
			if not process is FlowTimerDefinition or process.get_internal_id() != process_id \
					or not (process as FlowTimerDefinition).has_valid_interval() \
					or process.process_type != FlowProcess.ProcessType.TIMER:
				continue
		elif entry_point != &"Ready" or process.process_type != FlowProcess.ProcessType.READY or process is FlowTimerDefinition:
			continue
		_execute_blocks(controller, graph, process, process_path, output, entry_point, process.get_internal_id(), invalid_paths, true)


## Only an entry container may call a method. Method/constructor blocks never recurse.
func _execute_blocks(controller: Node, graph: FlowGraph, container: FlowBlockContainer, path: String,
		output: FlowRuntimeOutput, entry_point: StringName, entry_id: String,
		invalid_paths: Array[String], allow_calls: bool, method_id: String = "", call_id: String = "") -> void:
	for index: int in container.blocks.size():
		var block: FlowBlock = container.blocks[index]
		if block == null or not block.enabled:
			continue
		var block_path: String = "%s.blocks[%d]" % [path, index]
		if _is_invalid_block(block_path, invalid_paths):
			continue
		if block is FlowMethodCallBlock:
			if not allow_calls:
				push_warning("[Flujo] method_call_unsupported_context at %s; skipping." % block_path)
				continue
			_execute_method(controller, graph, block as FlowMethodCallBlock, output, entry_point, entry_id, invalid_paths)
			continue
		var handler: Callable = _handlers.get(block.get_script(), Callable())
		if not handler.is_valid():
			push_warning("[Flujo] Unsupported block at %s (%s); skipping." % [block_path, block.get_internal_id()])
			continue
		output.write(controller, entry_id, block.get_internal_id(), handler.call(block), entry_point, method_id, call_id)


func _execute_method(controller: Node, graph: FlowGraph, call: FlowMethodCallBlock,
		output: FlowRuntimeOutput, entry_point: StringName, entry_id: String, invalid_paths: Array[String]) -> void:
	var target: FlowMethodDefinition
	var target_path: String = ""
	for index: int in graph.methods.size():
		var method: FlowMethodDefinition = graph.methods[index]
		if method != null and method.get_internal_id() == call.method_id:
			if target != null:
				push_warning("[Flujo] ambiguous_method_reference; skipping call.")
				return
			target = method
			target_path = "methods[%d]" % index
	if target == null or invalid_paths.has(target_path) or invalid_paths.has(target_path + ".display_name"):
		push_warning("[Flujo] invalid_method_target; skipping call.")
		return
	if not target.enabled:
		return
	if not target.parameters.is_empty() or target.return_definition != null:
		push_warning("[Flujo] method_signature_not_executable at %s; arguments and returns are deferred." % target_path)
		return
	_execute_blocks(controller, graph, target, target_path, output, entry_point, entry_id, invalid_paths, false, target.get_internal_id(), call.get_internal_id())


func _is_invalid_block(path: String, invalid_paths: Array[String]) -> bool:
	for invalid_path: String in invalid_paths:
		if invalid_path == path or invalid_path.begins_with(path + "."):
			return true
	return false


func _print_message(block: FlowBlock) -> String:
	return (block as FlowPrintBlock).text


func _everything_flows_message(_block: FlowBlock) -> String:
	return "Todo es Flujo; todo fluye."
