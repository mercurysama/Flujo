class_name FlowReadyExecutor
extends RefCounted

## Only built-in definitions with explicit handlers can execute. Definitions contain no code.
const PRINT_BLOCK: Script = preload("res://addons/vp_flujo/runtime/model/flow_print_block.gd")
const EVERYTHING_FLOWS_BLOCK: Script = preload("res://addons/vp_flujo/runtime/model/flow_everything_flows_block.gd")

var _handlers: Dictionary[Script, Callable] = {
	PRINT_BLOCK: _print_message,
	EVERYTHING_FLOWS_BLOCK: _everything_flows_message,
}


func execute(controller: Node, graph: FlowGraph, output: FlowRuntimeOutput) -> void:
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
	for process_index: int in graph.processes.size():
		var process: FlowProcess = graph.processes[process_index]
		var process_path: String = "processes[%d]" % process_index
		if process == null or not process.enabled or invalid_paths.has(process_path):
			continue
		if not FlowProcess.ProcessType.values().has(process.process_type):
			push_warning("[Flujo] Invalid process type at %s; skipping." % process_path)
			continue
		if process.process_type != FlowProcess.ProcessType.READY:
			continue
		for block_index: int in process.blocks.size():
			var block: FlowBlock = process.blocks[block_index]
			if block == null or not block.enabled:
				continue
			var block_path: String = "%s.blocks[%d]" % [process_path, block_index]
			if _is_invalid_block(block_path, invalid_paths):
				continue
			var handler: Callable = _handlers.get(block.get_script(), Callable())
			if not handler.is_valid():
				push_warning("[Flujo] Unsupported block at %s (%s); skipping." % [block_path, block.get_internal_id()])
				continue
			var message: String = handler.call(block)
			output.write(controller, process.get_internal_id(), block.get_internal_id(), message)


func _is_invalid_block(path: String, invalid_paths: Array[String]) -> bool:
	for invalid_path: String in invalid_paths:
		if invalid_path == path or invalid_path.begins_with(path + "."):
			return true
	return false


func _print_message(block: FlowBlock) -> String:
	return (block as FlowPrintBlock).text


func _everything_flows_message(_block: FlowBlock) -> String:
	return "Todo es Flujo; todo fluye."
