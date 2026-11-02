@tool
extends SceneTree

## 7F-1C2B test-first: owned phase duplication preserves scripts, IDs and Undo.
const METHOD: StringName = &"duplicate_fsm_phase_block"
const SDK_SCRIPT: Script = preload("res://tests/fixtures/manual_block_sdk/manual_output/block.gd")
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	for i: int in 5:
		await process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if manager == null:
		_fail("EditorUndoRedoManager exists")
		quit(1)
		return
	var host := Node.new()
	get_root().add_child(host)
	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var state := FlowStateDefinition.new()
	var sibling := FlowStateDefinition.new()
	var first := FlowPrintBlock.new()
	first.display_name = "First"
	first.text = "alpha"
	first.user_note = "note"
	var second := FlowPrintBlock.new()
	second.display_name = "Second"
	var update_block := FlowPrintBlock.new()
	update_block.text = "update"
	var sdk := SDK_SCRIPT.new() as FlowBlock
	sdk.display_name = "SDK"
	sdk.set(&"message", "external content")
	state.enter_blocks = [null, first, second]
	state.blocks = [update_block]
	state.exit_blocks = [sdk]
	var machine := FlowStateMachineDefinition.new()
	machine.states = [state, sibling]
	machine.initial_state_id = state.get_internal_id()
	graph.state_machines = [machine]
	var ready := FlowProcess.new()
	graph.processes = [ready]
	var controller := PVController.new()
	controller.flow_graph = graph
	host.add_child(controller)
	var commands := FlowGraphEditorCommands.new(manager)
	if not commands.has_method(METHOD):
		_fail("Dedicated phase Duplicate command exists (expected RED)")
		await _finish(host)
		return
	var mid: String = machine.get_internal_id()
	var sid: String = state.get_internal_id()
	var history: UndoRedo = manager.get_history_undo_redo(manager.get_object_history_id(controller))
	var before: int = history.get_version()
	_check(_duplicate(commands, controller, mid, sid, &"enter", "") == ""
		and _duplicate(commands, controller, mid, sid, &"enter", "bogus") == ""
		and _duplicate(commands, controller, mid, sid, &"Enter", first.get_internal_id()) == ""
		and _duplicate(commands, controller, mid, sid, &"exit", first.get_internal_id()) == ""
		and _duplicate(commands, controller, mid, sibling.get_internal_id(), &"enter", first.get_internal_id()) == ""
		and _duplicate(commands, controller, "invalid", sid, &"enter", first.get_internal_id()) == "",
		"Bad phase, unknown block and foreign owners rejected")
	_check(history.get_version() == before and state.enter_blocks.size() == 3,
		"Rejected duplicates do not create history or mutate")
	var duplicate_id: String = _duplicate(
		commands, controller, mid, sid, &"enter", first.get_internal_id())
	_check(not duplicate_id.is_empty() and duplicate_id != first.get_internal_id(),
		"Duplicate creates a fresh block ID")
	_check(state.enter_blocks.size() == 4 and state.enter_blocks[0] == null
		and state.enter_blocks[1] == first and state.enter_blocks[3] == second
		and history.get_version() == before + 1,
		"New duplicate is inserted directly after original, preserving null and order")
	var copy: FlowPrintBlock = state.enter_blocks[2] as FlowPrintBlock
	_check(copy != null and copy != first and copy.get_internal_id() == duplicate_id
		and copy.text == "alpha" and copy.user_note == "note"
		and copy.display_name != first.display_name,
		"Copy preserves authorable properties, changes ID and takes distinct name")
	history.undo()
	_check(state.enter_blocks.size() == 3 and state.enter_blocks[1] == first
		and state.enter_blocks[2] == second, "Undo restores original references and slots")
	history.redo()
	_check(state.enter_blocks.size() == 4 and state.enter_blocks[2] == copy
		and copy.get_internal_id() == duplicate_id,
		"Redo reuses the same duplicate resource and stable ID")
	var update_id: String = _duplicate(
		commands, controller, mid, sid, &"update", update_block.get_internal_id())
	_check(not update_id.is_empty() and state.blocks.size() == 2
		and state.blocks[0] == update_block and state.blocks[1] != update_block
		and state.blocks[1].get_internal_id() == update_id
		and (state.blocks[1] as FlowPrintBlock).text == "update",
		"Update duplication acts only on inherited blocks")
	var sdk_id: String = _duplicate(
		commands, controller, mid, sid, &"exit", sdk.get_internal_id())
	_check(not sdk_id.is_empty() and state.exit_blocks.size() == 2
		and state.exit_blocks[0] == sdk and state.exit_blocks[1] != sdk,
		"Exit SDK duplication inserts new resource")
	if state.exit_blocks.size() == 2:
		var sdk_copy: FlowBlock = state.exit_blocks[1]
		_check(sdk_copy.get_script() == sdk.get_script()
			and sdk_copy.get_internal_id() == sdk_id
			and sdk_copy.get_internal_id() != sdk.get_internal_id()
			and String(sdk_copy.get(&"message")) == "external content",
			"External SDK script and values preserved without factory recreation")
	_check(sibling.enter_blocks.is_empty() and ready.blocks.is_empty()
		and not FlowGraphValidator.validate(graph).has_errors(),
		"Sibling state, Ready and graph invariants survive")
	await _finish(host)

func _duplicate(
		commands: FlowGraphEditorCommands, controller: PVController,
		mid: String, sid: String, phase: StringName, block_id: String
) -> String:
	return String(commands.call(METHOD, controller, mid, sid, phase, block_id))

func _check(ok: bool, message: String) -> void:
	if not ok:
		_fail(message)

func _fail(message: String) -> void:
	failures.append(message)
	push_error("[Flujo] Potok 7F-1C2B: " + message)

func _finish(host: Node) -> void:
	host.queue_free()
	for i: int in 4:
		await process_frame
	if failures.is_empty():
		print("[Flujo] Potok 7F-1C2B phase Duplicate UndoRedo SDK passed")
	quit(0 if failures.is_empty() else 1)
