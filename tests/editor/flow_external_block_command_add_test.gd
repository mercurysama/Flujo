@tool
extends SceneTree


const MANUAL_FIXTURE_ROOT: String = "res://tests/fixtures/manual_block_sdk"
const AUTHORING_ID: String = "manual_output:output"
const AUTHORING_CONTEXT_SCRIPT: Script = preload(
	"res://addons/vp_flujo/editor/flow_editor_block_authoring_context.gd"
)


class CountingAuthoringContext extends RefCounted:
	var _delegate: RefCounted
	var create_calls: int = 0

	func _init(delegate: RefCounted) -> void:
		_delegate = delegate

	func create_block(authoring_id: String) -> Variant:
		create_calls += 1
		return _delegate.call(&"create_block", authoring_id)


var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if undo_redo == null:
		_failures.append("Editor undo/redo manager is unavailable.")
		_finish()
		return

	var controller: PVController = PVController.new()
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var ready: FlowProcess = FlowProcess.new()
	ready.display_name = "Ready A"
	ready.blocks = [null]
	var second_ready: FlowProcess = FlowProcess.new()
	second_ready.display_name = "Ready B"
	graph.processes = [ready, second_ready]
	controller.flow_graph = graph

	var delegate: RefCounted = AUTHORING_CONTEXT_SCRIPT.new(MANUAL_FIXTURE_ROOT) as RefCounted
	var counting_context: CountingAuthoringContext = CountingAuthoringContext.new(delegate)
	var commands: FlowGraphEditorCommands = FlowGraphEditorCommands.new(undo_redo, counting_context)
	var history: UndoRedo = undo_redo.get_history_undo_redo(undo_redo.get_object_history_id(controller))

	_test_builtin_adds(commands, controller, ready)
	_test_external_add(commands, controller, second_ready, history, counting_context)
	_test_stale_entry(commands, controller, second_ready, history, counting_context)

	controller.free()
	_finish()


func _test_builtin_adds(
		commands: FlowGraphEditorCommands,
		controller: PVController,
		process: FlowProcess
) -> void:
	var print_id: String = commands.add_ready_block(controller, process.get_internal_id(), FlowBlockRegistry.PRINT)
	var everything_id: String = commands.add_ready_block(
		controller, process.get_internal_id(), FlowBlockRegistry.EVERYTHING_FLOWS
	)
	var custom_id: String = commands.add_ready_block(
		controller, process.get_internal_id(), FlowBlockRegistry.CUSTOM_HELLO
	)
	_check(not print_id.is_empty() and process.blocks[1].get_internal_id() == print_id,
		"Built-in Print Add still publishes the created Flow ID.")
	_check(not everything_id.is_empty() and process.blocks[2] is FlowEverythingFlowsBlock,
		"Built-in Everything Flows Add remains registry-backed.")
	_check(not custom_id.is_empty() and process.blocks[3] is FlowCustomHelloBlock,
		"Built-in Custom Hello Add remains registry-backed.")
	_check(process.blocks[0] == null, "Built-in Add preserves an existing deliberate null position.")


func _test_external_add(
		commands: FlowGraphEditorCommands,
		controller: PVController,
		process: FlowProcess,
		history: UndoRedo,
		counting_context: CountingAuthoringContext
) -> void:
	var process_id: String = process.get_internal_id()
	var before_version: int = history.get_version()
	var first_id: String = commands.add_ready_block_by_authoring_id(controller, process_id, AUTHORING_ID)
	_check(not first_id.is_empty(), "External Add returns the new Flow ID.")
	_check(history.get_version() == before_version + 1, "External Add records exactly one undoable action.")
	_check(process.blocks.size() == 1 and process.blocks[0] != null,
		"External instance enters the Process resolved by stable ID.")
	var first_block: FlowBlock = process.blocks[0]
	_check(first_block.get_internal_id() == first_id, "External Add publishes the same final ID as the instance.")
	_check(first_block.get_script().resource_path.ends_with(
		"/tests/fixtures/manual_block_sdk/manual_output/block.gd"
	), "External Add preserves the package script through the authoring context.")
	_check(first_block.display_name == "Manual Output", "External Add preserves the existing unique-name base policy.")
	_check(counting_context.create_calls == 1, "External creation calls the authoring context once.")

	history.undo()
	_check(process.blocks.is_empty(), "Undo removes the external instance from the Process.")
	history.redo()
	_check(process.blocks.size() == 1 and process.blocks[0] == first_block,
		"Redo reintroduces the same external instance.")
	_check(process.blocks[0].get_internal_id() == first_id and process.blocks[0].get_script() == first_block.get_script(),
		"Redo preserves the external Flow ID and script identity.")
	_check(counting_context.create_calls == 1, "Redo does not reinvoke context creation or the factory.")

	var second_id: String = commands.add_ready_block(controller, process_id, AUTHORING_ID)
	var second_block: FlowBlock = process.blocks[1]
	_check(second_id != first_id and second_block.get_internal_id() == second_id,
		"Two external Adds receive distinct persistent IDs.")
	_check(second_block.display_name == "Manual Output 1", "External Adds retain the existing per-script unique-name policy.")
	_check(counting_context.create_calls == 2, "The second external Add performs one additional creation.")

	var second_before_undo: int = history.get_version()
	history.undo()
	_check(history.get_version() == second_before_undo - 1 and process.blocks.size() == 1,
		"Undo removes only the latest external Add.")
	history.redo()
	_check(process.blocks.size() == 2 and process.blocks[1] == second_block,
		"Redo restores the same second external object.")
	_check(process.blocks[1].get_internal_id() == second_id and counting_context.create_calls == 2,
		"Second redo preserves identity without a new factory/context call.")


func _test_stale_entry(
		commands: FlowGraphEditorCommands,
		controller: PVController,
		process: FlowProcess,
		history: UndoRedo,
		counting_context: CountingAuthoringContext
) -> void:
	var before_blocks: Array[FlowBlock] = process.blocks.duplicate()
	var before_version: int = history.get_version()
	var published_id: String = process.blocks[0].get_internal_id()
	var result_id: String = commands.add_ready_block_by_authoring_id(
		controller, process.get_internal_id(), "stale_package:missing"
	)
	_check(result_id.is_empty(), "A stale authoring ID fails without a fallback block.")
	_check(_same_blocks(process.blocks, before_blocks), "A failed external Add leaves process.blocks identical.")
	_check(history.get_version() == before_version, "A failed external Add records zero undo actions.")
	_check(process.blocks[0].get_internal_id() == published_id, "A failed Add leaves the published selection ID unchanged.")
	_check(
		_has_diagnostic(commands.get_last_diagnostics(), &"editor_authoring_entry_missing"),
		"Diagnostics remain available after a stale external Add failure."
	)
	_check(counting_context.create_calls == 3, "The stale request reaches context once and does not create a partial instance.")


func _same_blocks(left: Array[FlowBlock], right: Array[FlowBlock]) -> bool:
	if left.size() != right.size():
		return false
	for index: int in left.size():
		if left[index] != right[index]:
			return false
	return true


func _has_diagnostic(diagnostics: Array[FlowDiagnostic], code: StringName) -> bool:
	for diagnostic: FlowDiagnostic in diagnostics:
		if diagnostic.code == code:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] External block command Add test passed")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)
