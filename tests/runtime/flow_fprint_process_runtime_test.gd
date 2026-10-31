extends Node


const FPRINT_SCRIPT: Script = preload("res://flow_packages/mercury.fprint/block.gd")


var _failures: Array[String] = []
var _events: Array[Dictionary] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var legacy_block: FlowBlock = FPRINT_SCRIPT.new() as FlowBlock
	legacy_block.set(&"prefix", "[")
	legacy_block.set(&"message", "Process output")
	legacy_block.set(&"suffix", "]")
	var structured_block: FlowBlock = FPRINT_SCRIPT.new() as FlowBlock
	structured_block.set(&"prefix", "<")
	structured_block.set(&"message", "ignored legacy message")
	structured_block.set(&"suffix", ">")
	structured_block.set(&"document", _make_document("Structured ", 5))
	var process: FlowProcess = FlowProcess.new()
	process.display_name = "FPrint Process"
	process.blocks = [legacy_block, structured_block]
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	graph.processes = [process]
	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	controller.runtime_output.contextual_message_emitted.connect(_record)
	get_tree().root.add_child(controller)
	await get_tree().process_frame
	_check(_events.size() == 2, "Process executes both legacy and structured FPrint outputs through the generic runtime path.")
	if _events.size() == 2:
		_check(_events[0]["message"] == "[Process output]", "Null document preserves exact prefix + message + suffix output.")
		_check(_events[1]["message"] == "<Structured 5>", "Present document replaces Message in exact Process output.")
		_check(_events[0]["process_id"] == process.get_internal_id() and _events[1]["process_id"] == process.get_internal_id(),
			"Process outputs carry the Process FlowId.")
		_check(_events[0]["block_id"] == legacy_block.get_internal_id() and _events[1]["block_id"] == structured_block.get_internal_id(),
			"Process outputs carry each FPrint FlowId.")
		_check(_events[0]["entry_point"] == &"Ready" and _events[1]["entry_point"] == &"Ready",
			"Process uses the generic Ready execution entry point for both FPrint branches.")
	controller.queue_free()
	await get_tree().process_frame
	_finish()


func _record(
		_controller: Node,
		process_id: String,
		block_id: String,
		message: String,
		entry_point: StringName,
		_method_id: String,
		_call_id: String
) -> void:
	_events.append({
		"process_id": process_id,
		"block_id": block_id,
		"message": message,
		"entry_point": entry_point,
	})


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_failures.append(message)
		push_error(message)
	return condition


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] FPrint Process runtime test passed")
	else:
		for failure: String in _failures:
			push_error(failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _make_document(prefix_text: String, integer_value: int) -> FlowStructuredDocument:
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	var text: FlowTextSegment = FlowTextSegment.new()
	text.text = prefix_text
	var value: FlowLiteralValueSegment = FlowLiteralValueSegment.new(
		FlowLiteralValueSegment.TYPE_INT,
		integer_value
	)
	document.segments = [text, value]
	return document
