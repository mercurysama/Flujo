@tool
extends SceneTree

## Potok 7F-1D1: real editor journey from catalog Add to phase edit and Move.
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	for i: int in 5:
		await process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	var host := Control.new()
	host.size = Vector2(1100, 770)
	get_root().add_child(host)
	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var state := FlowStateDefinition.new()
	var existing := FlowPrintBlock.new()
	existing.text = "existing"
	state.enter_blocks = [null, existing]
	state.blocks = [FlowPrintBlock.new()]
	var machine := FlowStateMachineDefinition.new()
	machine.states = [state]
	machine.initial_state_id = state.get_internal_id()
	graph.state_machines = [machine]
	var controller := PVController.new()
	controller.flow_graph = graph
	host.add_child(controller)
	var drawer := FluoDrawer.new()
	EditorInterface.get_base_control().add_child(drawer)
	drawer.configure(manager)
	drawer.open_container(controller, FlowGraphEditorCommands.Collection.STATE_MACHINES,
		machine.get_internal_id())
	await _frames(6)
	var add: Button = drawer.find_child("PotokPhaseEnterAdd0", true, false) as Button
	if _check(add != null and String(add.get_meta(&"authoring_id", "")) == "print",
			"Existing catalog exposes native Add Print"):
		add.pressed.emit()
		await _frames(6)
		if _check(state.enter_blocks.size() == 3 and state.enter_blocks[0] == null
				and state.enter_blocks[2] is FlowPrintBlock,
				"Native Add preserves null slot and inserts Print"):
			var added: FlowPrintBlock = state.enter_blocks[2] as FlowPrintBlock
			var block_id: String = added.get_internal_id()
			var list: ItemList = drawer.find_child(
				"PotokPhaseEnterBlocksList", true, false) as ItemList
			if _check(list != null, "Native Enter phase list exists"):
				var at: int = -1
				for i: int in list.item_count:
					if String((list.get_item_metadata(i) as Dictionary).get("id", "")) == block_id:
						at = i
				if _check(at >= 0, "Added block is in the list by stable ID"):
					list.select(at)
					list.item_selected.emit(at)
					list.item_activated.emit(at)
					await _frames(5)
					var input: TextEdit = drawer.find_child(
						"PotokPhaseBlockPrintText", true, false) as TextEdit
					if _check(input != null, "Activation opens existing Flusso"):
						input.text = "Journey edit"
						input.text_changed.emit()
						_check(added.text == "Journey edit", "Flusso writes to exact block")
						var close: Button = drawer.find_child(
							"PotokPhaseBlockClose", true, false) as Button
						if _check(close != null, "Flusso Close exists"):
							close.pressed.emit()
							await _frames(5)
							var up: Button = drawer.find_child(
								"PotokPhaseEnterMoveUp", true, false) as Button
							if _check(up != null, "Native Move Up exists"):
								up.pressed.emit()
								await _frames(5)
								_check(state.enter_blocks.size() == 3
									and state.enter_blocks[0] == null
									and state.enter_blocks[1] == added
									and state.enter_blocks[2] == existing
									and added.text == "Journey edit",
									"Close and Move preserve edit, null and instances")
	_check(state.blocks.size() == 1 and not FlowGraphValidator.validate(graph).has_errors(),
		"Update and graph remain valid")
	drawer.close()
	drawer.set_controller(null)
	drawer.queue_free()
	host.queue_free()
	await _frames(4)
	if failures.is_empty():
		print("[Flujo] Potok 7F-1D1 native journey passed")
	quit(0 if failures.is_empty() else 1)

func _frames(n: int) -> void:
	for i: int in n:
		await process_frame

func _check(ok: bool, message: String) -> bool:
	if not ok:
		failures.append(message)
		push_error("[Flujo] Potok 7F-1D1: " + message)
	return ok
