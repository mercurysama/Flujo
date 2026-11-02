@tool
extends SceneTree

## Potok 7F-1D2C: SDK clone deletion requires confirm, survives undo and reopen.
const ROOT: String = "res://tests/fixtures/property_descriptors"
const AUTHORING: Script = preload("res://addons/vp_flujo/editor/flow_editor_block_authoring_context.gd")
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	for i: int in 5:
		await process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	var context: RefCounted = AUTHORING.new(ROOT) as RefCounted
	var created: Object = context.call(&"create_block", "manual_output:output") as Object
	if not _check(created != null and bool(created.call(&"is_successful")), "External authoring entry works"):
		quit(1)
		return
	var sdk: FlowBlock = created.get("block") as FlowBlock
	var host := Control.new()
	host.size = Vector2(1100, 770)
	get_root().add_child(host)
	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var state := FlowStateDefinition.new()
	state.enter_blocks = [null, sdk]
	var other := FlowStateDefinition.new()
	var machine := FlowStateMachineDefinition.new()
	machine.states = [state, other]
	machine.initial_state_id = state.get_internal_id()
	graph.state_machines = [machine]
	var ready := FlowProcess.new()
	graph.processes = [ready]
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
	var list: ItemList = _phase_list(drawer)
	if not _check(list != null and list.item_count == 2, "Enter SDK list available"):
		await _finish(drawer, host)
		return
	list.select(1)
	list.item_selected.emit(1)
	list.item_activated.emit(1)
	await _frames(5)
	var input: TextEdit = drawer.find_child(
		"PotokPhaseGenericmessage", true, false) as TextEdit
	if not _check(input != null, "SDK descriptor editor opens"):
		await _finish(drawer, host)
		return
	input.text = "SDK message after edit"
	input.text_changed.emit()
	_check(String(sdk.get(&"message")) == "SDK message after edit",
		"SDK Flusso edit reaches original")
	var close: Button = drawer.find_child(
		"PotokPhaseBlockClose", true, false) as Button
	if _check(close != null, "Close control present"):
		close.pressed.emit()
		await _frames(5)
	var duplicate: Button = drawer.find_child(
		"PotokPhaseEnterDuplicate", true, false) as Button
	if not _check(duplicate != null, "SDK Duplicate control present"):
		await _finish(drawer, host)
		return
	duplicate.pressed.emit()
	await _frames(5)
	if not _check(state.enter_blocks.size() == 3 and state.enter_blocks[0] == null,
			"SDK clone inserted, null retained"):
		await _finish(drawer, host)
		return
	var copy: FlowBlock = state.enter_blocks[2]
	var original_id: String = sdk.get_internal_id()
	var copy_id: String = copy.get_internal_id()
	_check(copy != sdk and copy_id != original_id
		and copy.get_script() == sdk.get_script()
		and String(copy.get(&"message")) == "SDK message after edit",
		"Clone owns distinct stable ID and original SDK script and values")
	var undo: UndoRedo = manager.get_history_undo_redo(manager.get_object_history_id(controller))
	var before: int = undo.get_version()
	var delete_button: Button = drawer.find_child(
		"PotokPhaseEnterDelete", true, false) as Button
	if not _check(delete_button != null, "Delete action present"):
		await _finish(drawer, host)
		return
	delete_button.pressed.emit()
	await _frames(3)
	var dialog: ConfirmationDialog = editor.find_child(
		"PotokStructureDeleteDialog", true, false) as ConfirmationDialog
	_check(dialog != null and dialog.visible and undo.get_version() == before,
		"Delete is deferred until ConfirmationDialog")
	if dialog != null:
		dialog.canceled.emit()
	await _frames(3)
	_check(state.enter_blocks.size() == 3 and state.enter_blocks[2] == copy
		and undo.get_version() == before, "Cancel preserves SDK clone and history")
	delete_button = drawer.find_child(
		"PotokPhaseEnterDelete", true, false) as Button
	if delete_button != null:
		delete_button.pressed.emit()
	await _frames(3)
	dialog = editor.find_child(
		"PotokStructureDeleteDialog", true, false) as ConfirmationDialog
	if _check(dialog != null and dialog.visible, "Confirm dialog reopens"):
		dialog.confirmed.emit()
	await _frames(5)
	_check(state.enter_blocks.size() == 2 and state.enter_blocks[0] == null
		and state.enter_blocks[1] == sdk and undo.get_version() == before + 1,
		"Confirm removes just cloned SDK block in one undo entry")
	undo.undo()
	_check(state.enter_blocks.size() == 3 and state.enter_blocks[2] == copy
		and copy.get_internal_id() == copy_id,
		"Undo restores same SDK clone reference and ID")
	undo.redo()
	_check(state.enter_blocks.size() == 2 and state.enter_blocks[1] == sdk,
		"Redo deletes copy without touching original")
	# Reorient editor and activate surviving block's original SDK descriptors.
	list = _phase_list(drawer)
	if _check(list != null and list.item_count == 2, "Rebuilt Enter list survives delete"):
		list.select(1)
		list.item_selected.emit(1)
		list.item_activated.emit(1)
		await _frames(5)
		var reopened: TextEdit = drawer.find_child(
			"PotokPhaseGenericmessage", true, false) as TextEdit
		_check(reopened != null and reopened.text == "SDK message after edit"
			and sdk.get_internal_id() == original_id
			and sdk.get_script() == copy.get_script(),
			"Original SDK can reopen Flusso with its script, ID and edited value")
	_check(other.enter_blocks.is_empty() and ready.blocks.is_empty()
		and not FlowGraphValidator.validate(graph).has_errors(),
		"Sibling and Ready unchanged; graph validates")
	await _finish(drawer, host)

func _phase_list(drawer: FluoDrawer) -> ItemList:
	return drawer.find_child("PotokPhaseEnterBlocksList", true, false) as ItemList

func _frames(n: int) -> void:
	for i: int in n:
		await process_frame

func _check(ok: bool, description: String) -> bool:
	if not ok:
		failures.append(description)
		push_error("[Flujo] Potok 7F-1D2C: " + description)
	return ok

func _finish(drawer: FluoDrawer, host: Control) -> void:
	drawer.close()
	drawer.set_controller(null)
	drawer.queue_free()
	host.queue_free()
	await _frames(4)
	if failures.is_empty():
		print("[Flujo] Potok 7F-1D2C SDK native Delete Cancel Confirm UndoRedo passed")
	quit(0 if failures.is_empty() else 1)
