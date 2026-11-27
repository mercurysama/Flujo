extends Node


const FPRINT_SCRIPT: Script = preload("res://flow_packages/mercury.fprint/block.gd")


var _failures: Array[String] = []
var _events: Array[Dictionary] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	# Acceptance: continuous phrase in a single Text Tok.
	var block: FlowBlock = FPRINT_SCRIPT.new() as FlowBlock
	block.set(&"prefix", "")
	block.set(&"suffix", "")
	var doc: FlowStructuredDocument = FlowStructuredDocument.new()
	doc.akis_type_config = {"text": {"insertable": true, "evaluable": true}}
	doc.akis_preconfiguration = ["text"]
	doc.ensure_default_text_tok_if_empty()
	var tok: FlowTextSegment = doc.segments[0] as FlowTextSegment
	tok.text = "Hola mundo"
	block.set(&"document", doc)

	var process: FlowProcess = FlowProcess.new()
	process.display_name = "FPrint Akis V1"
	process.blocks = [block]
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	graph.processes = [process]
	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	controller.runtime_output.contextual_message_emitted.connect(_record)
	get_tree().root.add_child(controller)
	await get_tree().process_frame
	_check(_events.size() == 1, "FPrint Akis V1 emits one runtime output.")
	if _events.size() == 1:
		_check(_events[0]["message"] == "Hola mundo",
			"FPrint outputs a continuous single Text Tok exactly: 'Hola mundo'.")
		_check(_events[0]["block_id"] == block.get_internal_id(),
			"Runtime output carries the FPrint block FlowId.")
	controller.queue_free()
	await get_tree().process_frame

	# evaluable=false excludes the tok's text (general rule).
	_events.clear()
	var controller2: PVController = PVController.new()
	var block2: FlowBlock = FPRINT_SCRIPT.new() as FlowBlock
	block2.set(&"prefix", "")
	block2.set(&"suffix", "")
	var doc2: FlowStructuredDocument = FlowStructuredDocument.new()
	var t: FlowTextSegment = FlowTextSegment.new()
	t.text = "Hola mundo"
	t.evaluable = false
	doc2.segments = [t]
	block2.set(&"document", doc2)
	var process2: FlowProcess = FlowProcess.new()
	process2.blocks = [block2]
	var graph2: FlowGraph = FlowGraph.new()
	graph2.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph2.constructor = FlowConstructorDefinition.new()
	graph2.processes = [process2]
	controller2.flow_graph = graph2
	controller2.runtime_output.contextual_message_emitted.connect(_record)
	get_tree().root.add_child(controller2)
	await get_tree().process_frame
	_check(_events.size() == 1 and _events[0]["message"] == "",
		"With evaluable=false on the Text Tok, FPrint excludes its text.")
	controller2.queue_free()
	await get_tree().process_frame
	_finish()


func _record(
		_controller: Node,
		_process_id: String,
		block_id: String,
		message: String,
		_entry_point: StringName,
		_method_id: String,
		_call_id: String
) -> void:
	_events.append({
		"block_id": block_id,
		"message": message,
	})


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_failures.append(message)
		push_error(message)
	return condition


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] FPrint Akis Text V1 runtime test passed")
	else:
		for failure: String in _failures:
			push_error(failure)
	get_tree().quit(0 if _failures.is_empty() else 1)
