@tool
extends SceneTree

## Potok 7F-1C2E: phase structural edits survive real PackedScene save/reload.
## All mutations use current production commands and Godot EditorUndoRedoManager.
const SDK: Script = preload("res://tests/fixtures/manual_block_sdk/manual_output/block.gd")
const TEMP_DIR: String = "res://.godot/flujo_tests"
const FILE_PATH: String = TEMP_DIR + "/potok_7f1c2e_structure_roundtrip.tscn"
var failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for i: int in 5:
		await process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if not _check(manager != null, "EditorUndoRedoManager exists"):
		quit(1)
		return
	var root := Node.new()
	root.name = "Potok7F1C2E"
	var controller := PVController.new()
	controller.name = "Controller"
	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var state := FlowStateDefinition.new()
	state.display_name = "Active"
	var second := FlowStateDefinition.new()
	second.display_name = "Idle"
	var enter_a := FlowPrintBlock.new()
	enter_a.display_name = "Enter A"
	enter_a.text = "alpha"
	var enter_b := FlowPrintBlock.new()
	enter_b.display_name = "Enter B"
	enter_b.text = "beta"
	var update := FlowPrintBlock.new()
	update.text = "update retained"
	var exit_sdk: FlowBlock = SDK.new() as FlowBlock
	exit_sdk.display_name = "SDK exit"
	exit_sdk.set(&"message", "persistent SDK content")
	state.enter_blocks = [null, enter_a, enter_b, null]
	state.blocks = [update]
	state.exit_blocks = [exit_sdk]
	var machine := FlowStateMachineDefinition.new()
	machine.states = [state, second]
	machine.initial_state_id = state.get_internal_id()
	graph.state_machines = [machine]
	var ready := FlowProcess.new()
	var ready_block := FlowPrintBlock.new()
	ready_block.text = "Ready untouched"
	ready.blocks = [ready_block]
	graph.processes = [ready]
	controller.flow_graph = graph
	root.add_child(controller)
	controller.owner = root
	get_root().add_child(root)
	var commands := FlowGraphEditorCommands.new(manager)
	var mid: String = machine.get_internal_id()
	var sid: String = state.get_internal_id()
	var original_sdk_id: String = exit_sdk.get_internal_id()
	var enter_a_id: String = enter_a.get_internal_id()
	var enter_b_id: String = enter_b.get_internal_id()
	var update_id: String = update.get_internal_id()
	var ready_id: String = ready_block.get_internal_id()
	var history: UndoRedo = manager.get_history_undo_redo(
		manager.get_object_history_id(controller))
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Initial graph valid")

	# Move preserves null slots; duplicate creates an independent persistent ID.
	_check(commands.move_fsm_phase_block(controller, mid, sid, &"enter", enter_a_id, 1),
		"Enter Move succeeds")
	_check(state.enter_blocks[0] == null and state.enter_blocks[1] == enter_b
		and state.enter_blocks[2] == enter_a and state.enter_blocks[3] == null,
		"Enter move keeps physical null slots")
	var copy_id: String = commands.duplicate_fsm_phase_block(
		controller, mid, sid, &"enter", enter_a_id
	)
	_check(not copy_id.is_empty() and copy_id != enter_a_id,
		"Enter Duplicate generates fresh ID")
	var copy: FlowBlock = state.enter_blocks[3] if state.enter_blocks.size() == 5 else null
	_check(copy != null and copy.get_internal_id() == copy_id
		and (copy as FlowPrintBlock).text == "alpha"
		and state.enter_blocks[4] == null, "Duplicate preserves text and final null")
	var version: int = history.get_version()
	_check(commands.delete_fsm_phase_block(controller, mid, sid, &"enter", enter_b_id),
		"Enter Delete removes exact second block")
	_check(state.enter_blocks.size() == 4 and state.enter_blocks[0] == null
		and state.enter_blocks[1] == enter_a and state.enter_blocks[2] == copy
		and state.enter_blocks[3] == null and history.get_version() == version + 1,
		"Delete changes only selected element; two null holes survive")
	history.undo()
	_check(state.enter_blocks.size() == 5 and state.enter_blocks[1] == enter_b,
		"Undo Delete restores exact original reference")
	history.redo()
	_check(state.enter_blocks.size() == 4 and state.enter_blocks[1] == enter_a,
		"Redo Delete restores final authored order")

	# Same command set on Update and the external script on Exit.
	var update_copy_id: String = commands.duplicate_fsm_phase_block(
		controller, mid, sid, &"update", update_id
	)
	_check(not update_copy_id.is_empty() and state.blocks.size() == 2
		and state.blocks[1].get_internal_id() == update_copy_id,
		"Update Duplicate uses inherited blocks")
	var sdk_copy_id: String = commands.duplicate_fsm_phase_block(
		controller, mid, sid, &"exit", original_sdk_id
	)
	_check(not sdk_copy_id.is_empty() and state.exit_blocks.size() == 2
		and state.exit_blocks[1].get_script() == exit_sdk.get_script(),
		"Exit SDK Duplicate preserves original script")
	_check(commands.move_fsm_phase_block(controller, mid, sid, &"exit", sdk_copy_id, -1),
		"Exit SDK copy reorders")
	_check(state.exit_blocks[0].get_internal_id() == sdk_copy_id
		and state.exit_blocks[1] == exit_sdk, "SDK order swaps exact resources")
	_check(commands.delete_fsm_phase_block(controller, mid, sid, &"exit", original_sdk_id),
		"Original SDK block can be deleted independently")
	_check(state.exit_blocks.size() == 1
		and state.exit_blocks[0].get_internal_id() == sdk_copy_id
		and String(state.exit_blocks[0].get(&"message")) == "persistent SDK content",
		"Surviving SDK copy has independent ID and preserved properties")
	_check(ready.blocks.size() == 1 and ready.blocks[0] == ready_block
		and second.enter_blocks.is_empty()
		and not FlowGraphValidator.validate(graph).has_errors(),
		"Ready and other state remain identical; authored graph valid")

	# Real serialization boundary, not just an in-memory duplication.
	_check(DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(TEMP_DIR)) == OK,
		"Temporary directory exists")
	var packed := PackedScene.new()
	var packed_ok: bool = packed.pack(root) == OK
	_check(packed_ok, "Scene packs after sequential phase edits")
	var saved: bool = packed_ok and ResourceSaver.save(
		packed, ProjectSettings.globalize_path(FILE_PATH)) == OK
	_check(saved, "Authored scene saves to .tscn")
	if saved:
		var loaded: PackedScene = ResourceLoader.load(
			FILE_PATH, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE
		) as PackedScene
		if _check(loaded != null, "Saved scene reopens through ResourceLoader"):
			var instance: Node = loaded.instantiate()
			if _check(instance != null, "Reopened PackedScene instantiates"):
				var again: PVController = instance.get_node_or_null("Controller") as PVController
				if _check(again != null and again.flow_graph != null,
						"Reopened PVController retains FlowGraph"):
					var loaded_graph: FlowGraph = again.flow_graph
					_check(not FlowGraphValidator.validate(loaded_graph).has_errors(),
						"Reopened graph validates")
					_check(loaded_graph.schema_version == FlowGraph.SCHEMA_VERSION_3,
						"Runtime resource schema unchanged")
					var found: Array[FlowStateMachineDefinition] = loaded_graph.state_machines
					if _check(found.size() == 1 and found[0].get_internal_id() == mid,
							"Machine ID persists"):
						var states: Array[FlowStateDefinition] = found[0].states
						if _check(states.size() == 2 and states[0].get_internal_id() == sid
								and states[1].get_internal_id() == second.get_internal_id(),
								"Both owned state IDs persist"):
							var enter: Array[FlowBlock] = states[0].enter_blocks
							_check(enter.size() == 4 and enter[0] == null and enter[3] == null
								and enter[1] != null and enter[2] != null
								and enter[1].get_internal_id() == enter_a_id
								and enter[2].get_internal_id() == copy_id
								and enter[1] != enter[2],
								"Saved Enter order, null slots, unique IDs and objects survive")
							if enter.size() == 4 and enter[2] != null:
								_check((enter[2] as FlowPrintBlock).text == "alpha",
									"Duplicated Enter block text persists")
							var updates: Array[FlowBlock] = states[0].blocks
							_check(updates.size() == 2 and updates[0].get_internal_id() == update_id
								and updates[1].get_internal_id() == update_copy_id,
								"Updated Update array IDs and order persist")
							var exits: Array[FlowBlock] = states[0].exit_blocks
							_check(exits.size() == 1 and exits[0] != null
								and exits[0].get_internal_id() == sdk_copy_id
								and exits[0].get_script() == SDK
								and String(exits[0].get(&"message")) == "persistent SDK content",
								"SDK copied script, ID and value persist after real scene reload")
							_check(states[1].enter_blocks.is_empty()
								and states[1].exit_blocks.is_empty(),
								"Sibling state unchanged after real scene reload")
					_check(loaded_graph.processes.size() == 1
						and loaded_graph.processes[0].blocks.size() == 1
						and loaded_graph.processes[0].blocks[0].get_internal_id() == ready_id
						and (loaded_graph.processes[0].blocks[0] as FlowPrintBlock).text == "Ready untouched",
						"Ready remains unchanged after scene serialization")
				instance.free()
	await _finish(root)


func _check(ok: bool, message: String) -> bool:
	if not ok:
		failures.append(message)
		push_error("[Flujo] Potok 7F-1C2E roundtrip: " + message)
	return ok


func _finish(root: Node) -> void:
	root.queue_free()
	for i: int in 4:
		await process_frame
	var file: String = ProjectSettings.globalize_path(FILE_PATH)
	if FileAccess.file_exists(file):
		DirAccess.remove_absolute(file)
	if failures.is_empty():
		print("[Flujo] Potok 7F-1C2E phase structure scene roundtrip passed")
	quit(0 if failures.is_empty() else 1)
