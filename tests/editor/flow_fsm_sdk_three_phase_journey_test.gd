@tool
extends SceneTree

## 7F-1D2A: one external SDK journey across Enter/Update/Exit and stale state.
const SDK_ROOT: String = "res://tests/fixtures/property_descriptors"
const AUTHORING: Script = preload(
	"res://addons/vp_flujo/editor/flow_editor_block_authoring_context.gd"
)
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	for i: int in 5:
		await process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	var context: RefCounted = AUTHORING.new(SDK_ROOT) as RefCounted
	var host := Control.new()
	host.size = Vector2(1100, 770)
	get_root().add_child(host)
	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var first := FlowStateDefinition.new()
	first.enter_blocks = [null]
	var second := FlowStateDefinition.new()
	var machine := FlowStateMachineDefinition.new()
	machine.states = [first, second]
	machine.initial_state_id = first.get_internal_id()
	graph.state_machines = [machine]
	var controller := PVController.new()
	controller.flow_graph = graph
	host.add_child(controller)
	var drawer := FluoDrawer.new()
	EditorInterface.get_base_control().add_child(drawer)
	drawer.configure(manager)
	var editor: FlowGraphInspectorProperty = drawer.find_child(
		"FluoFlowEditor", true, false) as FlowGraphInspectorProperty
	editor.configure(manager, context)
	drawer.open_container(controller, FlowGraphEditorCommands.Collection.STATE_MACHINES,
		machine.get_internal_id())
	await _frames(6)
	var history: UndoRedo = manager.get_history_undo_redo(manager.get_object_history_id(controller))
	var sdk_script: Script = null
	for phase: String in ["Enter", "Update", "Exit"]:
		var actions: HFlowContainer = drawer.find_child(
			"PotokPhase" + phase + "AddActions", true, false) as HFlowContainer
		var add: Button = null
		if actions != null:
			for child: Node in actions.get_children():
				var candidate: Button = child as Button
				if candidate != null and candidate.get_meta(&"authoring_id", "") == "manual_output:output":
					add = candidate
					break
		if not _check(add != null, phase + " SDK catalog action exists"):
			continue
		add.pressed.emit()
		await _frames(6)
		var blocks: Array[FlowBlock] = first.blocks
		match phase:
			"Enter":
				blocks = first.enter_blocks
			"Exit":
				blocks = first.exit_blocks
		if not _check(not blocks.is_empty() and blocks.back() != null,
				phase + " creates SDK block in exact owned array"):
			continue
		var block: FlowBlock = blocks.back()
		if sdk_script == null:
			sdk_script = block.get_script()
		_check(block.get_script() == sdk_script and sdk_script != null,
			phase + " retains external SDK script")
		var list: ItemList = drawer.find_child(
			"PotokPhase" + phase + "BlocksList", true, false) as ItemList
		if not _check(list != null and list.item_count == blocks.size(),
				phase + " native list matches slots"):
			continue
		var index: int = list.item_count - 1
		list.select(index)
		list.item_selected.emit(index)
		list.item_activated.emit(index)
		await _frames(5)
		var input: TextEdit = drawer.find_child(
			"PotokPhaseGenericmessage", true, false) as TextEdit
		if _check(input != null, phase + " opens generic SDK message descriptor"):
			input.text = "SDK " + phase
			input.text_changed.emit()
			_check(String(block.get(&"message")) == "SDK " + phase,
				phase + " generic descriptor edits exactly owned resource")
		var duplicate: Button = drawer.find_child(
			"PotokPhase" + phase + "Duplicate", true, false) as Button
		if _check(duplicate != null, phase + " exposes native Duplicate"):
			duplicate.pressed.emit()
			await _frames(5)
			var copied: FlowBlock = blocks.back() if blocks.size() > 1 else null
			# A fresh source list is required because UndoRedo replaces the array.
			match phase:
				"Enter":
					blocks = first.enter_blocks
				"Update":
					blocks = first.blocks
				"Exit":
					blocks = first.exit_blocks
			copied = blocks.back() if not blocks.is_empty() else null
			_check(copied != null and copied != block
				and copied.get_internal_id() != block.get_internal_id()
				and copied.get_script() == sdk_script
				and String(copied.get(&"message")) == "SDK " + phase,
				phase + " copy has new ID and preserved edited SDK content")
	# After changing state, prior action must be inert.
	var stale: Button = drawer.find_child(
		"PotokPhaseExitDuplicate", true, false) as Button
	var before: int = history.get_version()
	var states: ItemList = drawer.find_child("PotokStateList", true, false) as ItemList
	if _check(states != null and stale != null, "State list and stale action are available"):
		states.select(1)
		states.item_selected.emit(1)
		stale.pressed.emit()
		await _frames(6)
		_check(second.enter_blocks.is_empty() and second.blocks.is_empty()
			and second.exit_blocks.is_empty() and history.get_version() == before,
			"Old SDK action cannot write to another state after selection")
	_check(first.enter_blocks[0] == null
		and not FlowGraphValidator.validate(graph).has_errors(),
		"Null slot and SDK graph remain valid")
	drawer.close()
	drawer.set_controller(null)
	drawer.queue_free()
	host.queue_free()
	await _frames(4)
	if failures.is_empty():
		print("[Flujo] Potok 7F-1D2A external SDK three phase and stale state journey passed")
	quit(0 if failures.is_empty() else 1)

func _frames(n: int) -> void:
	for i: int in n:
		await process_frame

func _check(ok: bool, message: String) -> bool:
	if not ok:
		failures.append(message)
		push_error("[Flujo] Potok 7F-1D2A: " + message)
	return ok
