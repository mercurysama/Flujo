extends Node

var _failures: Array[String] = []
var _events: Array[String] = []


class FlowNavigationFixtureBlock extends FlowBlock:
	var target_block_id: String = ""
	var decision_kind: FlowNavigationDecision.Kind = FlowNavigationDecision.Kind.CONTINUE
	var evaluations: int = 0
	var context_is_valid: bool = false


	func get_navigation_decision(context: FlowNavigationContext) -> FlowNavigationDecision:
		evaluations += 1
		context_is_valid = context != null and context.container != null and context.current_block_id == get_internal_id()
		match decision_kind:
			FlowNavigationDecision.Kind.JUMP:
				return FlowNavigationDecision.jump_to(target_block_id)
			FlowNavigationDecision.Kind.STOP:
				return FlowNavigationDecision.stop_execution()
		return FlowNavigationDecision.continue_execution()


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	_test_decision_factories()
	_test_linear_continue_and_existing_blocks()
	_test_jump_by_stable_id()
	_test_stop()
	_test_invalid_target()
	_test_duplicate_id()
	_test_step_budget()
	if _failures.is_empty():
		print("[Flujo] Navigation runtime test passed")
		get_tree().quit(0)
	else:
		for failure: String in _failures:
			push_error(failure)
		get_tree().quit(1)


func _graph(blocks: Array[FlowBlock]) -> FlowGraph:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var process: FlowProcess = FlowProcess.new()
	process.blocks = blocks
	graph.processes = [process]
	return graph


func _execute(graph: FlowGraph) -> void:
	_events.clear()
	var controller: Node = Node.new()
	var output: FlowRuntimeOutput = FlowRuntimeOutput.new()
	output.message_emitted.connect(_record)
	FlowReadyExecutor.new().execute(controller, graph, output)
	controller.free()


func _test_decision_factories() -> void:
	var continue_decision: FlowNavigationDecision = FlowNavigationDecision.continue_execution()
	var jump_decision: FlowNavigationDecision = FlowNavigationDecision.jump_to("target")
	var stop_decision: FlowNavigationDecision = FlowNavigationDecision.stop_execution()
	_check(continue_decision.kind == FlowNavigationDecision.Kind.CONTINUE and continue_decision.is_well_formed(), "CONTINUE decision is well formed.")
	_check(jump_decision.kind == FlowNavigationDecision.Kind.JUMP and jump_decision.target_block_id == "target", "JUMP carries its stable target ID.")
	_check(stop_decision.kind == FlowNavigationDecision.Kind.STOP and stop_decision.is_well_formed(), "STOP decision is well formed.")
	_check(not FlowNavigationDecision.jump_to("").is_well_formed(), "Empty JUMP targets are rejected deterministically.")


func _test_linear_continue_and_existing_blocks() -> void:
	var print_block: FlowPrintBlock = FlowPrintBlock.new()
	print_block.text = "Print baseline"
	var everything: FlowEverythingFlowsBlock = FlowEverythingFlowsBlock.new()
	var custom: FlowCustomHelloBlock = FlowCustomHelloBlock.new()
	var graph: FlowGraph = _graph([print_block, everything, custom])
	_execute(graph)
	_check(_events == ["Print baseline", "Todo es Flujo; todo fluye.", "Hola desde un bloque personalizado"], "Linear CONTINUE preserves Print, Everything Flows, and Custom Hello order.")


func _test_jump_by_stable_id() -> void:
	var jump: FlowNavigationFixtureBlock = FlowNavigationFixtureBlock.new()
	jump.decision_kind = FlowNavigationDecision.Kind.JUMP
	var skipped: FlowPrintBlock = FlowPrintBlock.new()
	skipped.text = "must be skipped"
	var target: FlowPrintBlock = FlowPrintBlock.new()
	target.text = "stable target"
	jump.target_block_id = target.get_internal_id()
	var graph: FlowGraph = _graph([jump, skipped, target])
	_execute(graph)
	_check(_events == ["stable target"], "JUMP executes only the block addressed by stable ID.")
	_check(jump.context_is_valid, "Navigation receives the current container and stable block context.")


func _test_stop() -> void:
	var stop: FlowNavigationFixtureBlock = FlowNavigationFixtureBlock.new()
	stop.decision_kind = FlowNavigationDecision.Kind.STOP
	var after: FlowPrintBlock = FlowPrintBlock.new()
	after.text = "must stop"
	_execute(_graph([stop, after]))
	_check(_events.is_empty(), "STOP prevents later blocks in the current container from executing.")


func _test_invalid_target() -> void:
	var jump: FlowNavigationFixtureBlock = FlowNavigationFixtureBlock.new()
	jump.decision_kind = FlowNavigationDecision.Kind.JUMP
	jump.target_block_id = "missing-stable-id"
	var after: FlowPrintBlock = FlowPrintBlock.new()
	after.text = "must not execute after invalid target"
	_execute(_graph([jump, after]))
	_check(_events.is_empty(), "An absent JUMP target stops the current path without executing later blocks.")


func _test_duplicate_id() -> void:
	var first: FlowPrintBlock = FlowPrintBlock.new()
	first.text = "must not execute"
	var second: FlowPrintBlock = FlowPrintBlock.new()
	second.text = "must not execute"
	second._internal_id = first.get_internal_id()
	_execute(_graph([first, second]))
	_check(_events.is_empty(), "Ambiguous stable IDs stop navigation before execution.")


func _test_step_budget() -> void:
	var loop: FlowNavigationFixtureBlock = FlowNavigationFixtureBlock.new()
	loop.decision_kind = FlowNavigationDecision.Kind.JUMP
	loop.target_block_id = loop.get_internal_id()
	_execute(_graph([loop]))
	_check(loop.evaluations == 1024, "The navigation step budget stops an accidental infinite jump deterministically.")


func _record(_controller: Node, _process_id: String, _block_id: String, message: String) -> void:
	_events.append(message)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_failures.append(message)
	return condition
