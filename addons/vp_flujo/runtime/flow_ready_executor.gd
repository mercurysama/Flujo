class_name FlowReadyExecutor
extends RefCounted

## Only definitions implementing the explicit output-block contract can emit messages.


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
		invalid_paths: Array[String], allow_calls: bool, method_id: String = "", call_id: String = "") -> FlowNavigationDecision:
	var block_indices: Dictionary[String, int] = {}
	for index: int in container.blocks.size():
		var candidate: FlowBlock = container.blocks[index]
		if candidate == null:
			continue
		var candidate_id: String = candidate.get_internal_id()
		if block_indices.has(candidate_id):
			push_warning("[Flujo] ambiguous_block_id at %s.blocks[%d]: Stable block ID is duplicated." % [path, index])
			return FlowNavigationDecision.stop_execution()
		block_indices[candidate_id] = index

	var index: int = 0
	var steps: int = 0
	var step_budget: int = maxi(1, container.blocks.size()) * 1024
	while index < container.blocks.size():
		steps += 1
		if steps > step_budget:
			push_warning("[Flujo] navigation_step_budget_exceeded at %s: Runtime navigation stopped safely." % path)
			return FlowNavigationDecision.stop_execution()
		var block: FlowBlock = container.blocks[index]
		var block_path: String = "%s.blocks[%d]" % [path, index]
		if block == null or not block.enabled or _is_invalid_block(block_path, invalid_paths):
			index += 1
			continue
		if block is FlowMethodCallBlock:
			if not allow_calls:
				push_warning("[Flujo] method_call_unsupported_context at %s; skipping." % block_path)
			else:
				_execute_method(controller, graph, block as FlowMethodCallBlock, output, entry_point, entry_id, invalid_paths)
		else:
			if block is FlowOutputBlock:
				output.write(
					controller,
					entry_id,
					block.get_internal_id(),
					(block as FlowOutputBlock).get_output_message(),
					entry_point,
					method_id,
					call_id
				)

		var context: FlowNavigationContext = FlowNavigationContext.new(
			controller,
			graph,
			container,
			block.get_internal_id(),
			entry_point
		)
		var decision: FlowNavigationDecision = block.get_navigation_decision(context)
		if decision == null or not decision.is_well_formed():
			push_warning("[Flujo] invalid_navigation_decision at %s: Block returned malformed runtime navigation." % block_path)
			return FlowNavigationDecision.stop_execution()
		match decision.kind:
			FlowNavigationDecision.Kind.CONTINUE:
				index += 1
			FlowNavigationDecision.Kind.JUMP:
				if not block_indices.has(decision.target_block_id):
					push_warning("[Flujo] invalid_navigation_target at %s: Target block ID is absent from this container." % block_path)
					return FlowNavigationDecision.stop_execution()
				index = block_indices[decision.target_block_id]
			FlowNavigationDecision.Kind.STOP:
				return decision
			_:
				push_warning("[Flujo] invalid_navigation_decision at %s: Unknown runtime navigation kind." % block_path)
				return FlowNavigationDecision.stop_execution()
	return FlowNavigationDecision.continue_execution()


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
