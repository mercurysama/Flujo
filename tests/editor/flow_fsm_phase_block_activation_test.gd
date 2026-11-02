@tool
extends SceneTree

## Potok 7F-1C1B: test-first activation of exactly owned phase blocks.
## Expected RED before implementation: no phase-block Flusso activation surface.
var failures: Array[String] = []
var host: Control
var drawer: FluoDrawer
var editor: FlowGraphInspectorProperty
var controller: PVController
var graph: FlowGraph
var machine: FlowStateMachineDefinition
var state: FlowStateDefinition
var enter_block: FlowPrintBlock
var update_block: FlowPrintBlock
var exit_block: FlowPrintBlock


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for i: int in 5:
		await process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if not _check(manager != null, "Editor undo/redo manager exists"):
		quit(1)
		return
	host = Control.new()
	host.name = "Potok7F1C1BHost"
	host.size = Vector2(1100, 770)
	get_root().add_child(host)
	graph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	state = FlowStateDefinition.new()
	enter_block = FlowPrintBlock.new()
	enter_block.display_name = "Enter owned"
	update_block = FlowPrintBlock.new()
	update_block.display_name = "Update owned"
	exit_block = FlowPrintBlock.new()
	exit_block.display_name = "Exit owned"
	state.enter_blocks = [null, enter_block]
	state.blocks = [update_block]
	state.exit_blocks = [exit_block]
	machine = FlowStateMachineDefinition.new()
	machine.states = [state]
	machine.initial_state_id = state.get_internal_id()
	graph.state_machines = [machine]
	controller = PVController.new()
	controller.flow_graph = graph
	host.add_child(controller)
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Seed model is valid")
	drawer = FluoDrawer.new()
	EditorInterface.get_base_control().add_child(drawer)
	drawer.configure(manager)
	drawer.open_container(controller, FlowGraphEditorCommands.Collection.STATE_MACHINES,
		machine.get_internal_id())
	editor = drawer.find_child("FluoFlowEditor", true, false) as FlowGraphInspectorProperty
	await _frames(6)
	if not _check(editor != null and drawer.is_open(), "Fluo has active Potok editor"):
		await _finish()
		return
	for label: String in ["Enter", "Update", "Exit"]:
		var list: ItemList = drawer.find_child(
			"PotokPhase" + label + "BlocksList", true, false) as ItemList
		if not _check(list != null, label + " list is present"):
			continue
		var index: int = 1 if label == "Enter" else 0
		list.select(index)
		list.item_selected.emit(index)
		var selected_id: String = String(editor.get("_potok_selected_phase_block_id"))
		_check(not selected_id.is_empty(), label + " selection has stable ID")
		# A normal select must not open configuration.
		_check(drawer.find_child("PotokPhaseBlockProperties", true, false) == null,
			"Selection alone keeps Potok phase-block Flusso closed")
		list.item_activated.emit(index)
		await _frames(4)
		var panel: Control = drawer.find_child(
			"PotokPhaseBlockProperties", true, false) as Control
		_check(panel != null and panel.is_visible_in_tree(),
			label + " activation opens phase-block Flusso in existing drawer")
		if panel != null:
			_check(String(panel.get_meta(&"block_id", "")) == selected_id
				and String(panel.get_meta(&"phase", "")) == label.to_lower()
				and String(panel.get_meta(&"state_id", "")) == state.get_internal_id(),
				label + " panel binds exact block, phase and state IDs")
		# The next selection must close or replace previous block properties.
		if label != "Exit" and panel != null:
			_check(drawer.find_children("PotokPhaseBlockProperties", "", true, false).size() == 1,
				"Only one phase-block Flusso is rendered")
	await _finish()


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _check(ok: bool, message: String) -> bool:
	if not ok:
		failures.append(message)
		push_error("[Flujo] Potok 7F-1C1B RED: " + message)
	return ok


func _finish() -> void:
	if drawer != null:
		drawer.close()
		drawer.set_controller(null)
		drawer.queue_free()
	if host != null:
		host.queue_free()
	await _frames(4)
	if failures.is_empty():
		print("[Flujo] Potok 7F-1C1B exact phase-block activation passed")
	quit(0 if failures.is_empty() else 1)
