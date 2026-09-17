@tool
extends SceneTree

const TEMP_PATH: String = "res://.godot/flujo_tests/delete_selection_lifecycle.tscn"

var _failures: Array[String] = []
var _controller: PVController
var _dock: VPFlujoDock
var _history: UndoRedo
var _external_focus: LineEdit


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _frames()
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	if not _create_fixture():
		_finish()
		return
	EditorInterface.open_scene_from_path(TEMP_PATH)
	await _frames(8)
	_controller = EditorInterface.get_edited_scene_root() as PVController
	if not _check(_controller != null, "Open the temporary PVController scene."):
		_finish()
		return
	var selection: EditorSelection = EditorInterface.get_selection()
	selection.clear()
	selection.add_node(_controller)
	EditorInterface.inspect_object(_controller)
	await _frames(8)
	_dock = get_root().find_child("VPFlujoDock", true, false) as VPFlujoDock
	if not _check(_dock != null and _inspector_property() != null, "Mount the real Flujo Inspector property and dock."):
		_finish()
		return
	var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	_history = manager.get_history_undo_redo(manager.get_object_history_id(_controller))
	_external_focus = LineEdit.new()
	_external_focus.name = &"DeleteSelectionExternalFocus"
	get_root().add_child(_external_focus)
	await _exercise_method_delete()
	await _exercise_variable_delete()
	for title: String in ["Processes", "Timers", "Methods"]:
		await _exercise_block_delete(title)
	_finish()


func _create_fixture() -> bool:
	var fixture: PVController = PVController.new()
	fixture.name = "DeleteSelectionLifecycle"
	var graph: FlowGraph = fixture.flow_graph
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	for index: int in 3:
		var process: FlowProcess = FlowProcess.new()
		process.display_name = "Process %d" % index
		_add_blocks(process, "Process %d" % index)
		graph.processes.append(process)
		var timer: FlowTimerDefinition = FlowTimerDefinition.new()
		timer.display_name = "Timer %d" % index
		_add_blocks(timer, "Timer %d" % index)
		graph.processes.append(timer)
		var method: FlowMethodDefinition = FlowMethodDefinition.new()
		method.display_name = "Method %d" % index
		_add_blocks(method, "Method %d" % index)
		graph.methods.append(method)
		var variable: FlowVariableDefinition = FlowVariableDefinition.new()
		variable.display_name = "Variable %d" % index
		graph.variables.append(variable)
	var packed: PackedScene = PackedScene.new()
	if not _check(packed.pack(fixture) == OK, "Pack the delete-selection fixture."):
		fixture.free()
		return false
	fixture.free()
	if not _check(
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/flujo_tests")) == OK,
		"Create the focal test directory."
	):
		return false
	return _check(ResourceSaver.save(packed, TEMP_PATH) == OK, "Save the delete-selection fixture.")


func _add_blocks(container: FlowBlockContainer, prefix: String) -> void:
	for index: int in 3:
		var block: FlowPrintBlock = FlowPrintBlock.new()
		block.display_name = "%s Block %d" % [prefix, index]
		container.blocks.append(block)


func _exercise_method_delete() -> void:
	var deleted_id: String = _controller.flow_graph.methods[1].get_internal_id()
	var replacement_id: String = _controller.flow_graph.methods[2].get_internal_id()
	if not await _select_inspector_row("Methods", 1):
		return
	if not await _confirm_delete(_dock, "Delete Method", "FlowGraphDeleteConfirmation"):
		return
	await _frames(3)
	_check_inspector_selection("Methods", replacement_id, "Method 2", true, "Method Delete selects the same-index replacement.")
	var methods: ItemList = _inspector_list("Methods")
	methods.grab_focus()
	_history.undo()
	await _frames(3)
	_check_inspector_selection("Methods", deleted_id, "Method 1", true, "Method Undo restores and selects the recovered row.")
	methods = _inspector_list("Methods")
	methods.grab_focus()
	_history.redo()
	await _frames(3)
	_check_inspector_selection("Methods", replacement_id, "Method 2", true, "Method Redo selects the replacement again.")


func _exercise_variable_delete() -> void:
	var deleted_id: String = _controller.flow_graph.variables[2].get_internal_id()
	var replacement_id: String = _controller.flow_graph.variables[1].get_internal_id()
	if not await _select_inspector_row("Variables", 2):
		return
	if not await _confirm_delete(_dock, "Delete Variable", "FlowGraphDeleteConfirmation"):
		return
	await _frames(3)
	_check_inspector_selection("Variables", replacement_id, "Variable 1", true, "Deleting the last Variable selects the previous row.")
	_external_focus.grab_focus()
	_history.undo()
	await _frames(3)
	_check_inspector_selection("Variables", deleted_id, "Variable 2", false, "Variable Undo restores selection without stealing external focus.")
	_check(get_root().gui_get_focus_owner() == _external_focus, "Variable Undo preserves an external focus owner.")
	_external_focus.grab_focus()
	_history.redo()
	await _frames(3)
	_check_inspector_selection("Variables", replacement_id, "Variable 1", false, "Variable Redo restores the replacement without stealing external focus.")
	_check(get_root().gui_get_focus_owner() == _external_focus, "Variable Redo preserves an external focus owner.")

	var first_remaining_id: String = _controller.flow_graph.variables[0].get_internal_id()
	if not await _select_inspector_row("Variables", 0):
		return
	if not await _confirm_delete(_dock, "Delete Variable", "FlowGraphDeleteConfirmation"):
		return
	await _frames(3)
	_check_inspector_selection("Variables", replacement_id, "Variable 1", true, "Deleting the first Variable selects the row shifted into its index.")
	_check(not _contains_variable(first_remaining_id), "Deleting the first Variable removes exactly its stable ID.")
	if not await _confirm_delete(_dock, "Delete Variable", "FlowGraphDeleteConfirmation"):
		return
	await _frames(3)
	var empty_list: ItemList = _inspector_list("Variables")
	_check(
		empty_list != null and empty_list.get_selected_items().is_empty() \
			and _dock.find_child("Schema3VariableEditor", true, false) == null,
		"Deleting the only Variable clears the visual selection and dock editor."
	)
	_history.undo()
	await _frames(3)
	_check_inspector_selection("Variables", replacement_id, "Variable 1", false, "Undo restores and selects the only deleted Variable.")
	_history.redo()
	await _frames(3)
	empty_list = _inspector_list("Variables")
	_check(empty_list != null and empty_list.get_selected_items().is_empty(), "Redo clears the only Variable selection again.")


func _exercise_block_delete(title: String) -> void:
	if not await _select_inspector_row(title, 0):
		return
	await _frames(2)
	var blocks: ItemList = _dock.find_child("ReadyBlocksList", true, false) as ItemList
	if not _check(blocks != null and blocks.item_count == 3, title + " mounts three block rows."):
		return
	var deleted_id: String = blocks.get_item_metadata(1) as String
	var deleted_name: String = blocks.get_item_text(1)
	var replacement_id: String = blocks.get_item_metadata(2) as String
	var replacement_name: String = blocks.get_item_text(2)
	blocks.grab_focus()
	blocks.select(1)
	blocks.item_selected.emit(1)
	await _frames(2)
	if not await _confirm_delete(_dock, "Delete Block", "ReadyBlockDeleteConfirmation"):
		return
	await _frames(3)
	_check_block_selection(replacement_id, replacement_name, true, title + " block Delete selects the same-index replacement.")
	blocks = _dock.find_child("ReadyBlocksList", true, false) as ItemList
	blocks.grab_focus()
	_history.undo()
	await _frames(3)
	_check_block_selection(deleted_id, deleted_name, true, title + " block Undo restores the recovered row.")
	blocks = _dock.find_child("ReadyBlocksList", true, false) as ItemList
	blocks.grab_focus()
	_history.redo()
	await _frames(3)
	_check_block_selection(replacement_id, replacement_name, true, title + " block Redo selects the replacement again.")


func _select_inspector_row(title: String, index: int) -> bool:
	var list: ItemList = _inspector_list(title)
	if not _check(list != null and index >= 0 and index < list.item_count, "Selectable Inspector row in " + title + "."):
		return false
	list.grab_focus()
	list.select(index)
	list.item_selected.emit(index)
	await _frames(3)
	return true


func _confirm_delete(root: Node, button_text: String, confirmation_name: String) -> bool:
	var button: Button = _button(root, button_text)
	if not _check(button != null, "Delete action exists: " + button_text + "."):
		return false
	button.grab_focus()
	button.pressed.emit()
	await _frames(2)
	var confirmation: ConfirmationDialog = root.find_child(confirmation_name, true, false) as ConfirmationDialog
	if not _check(confirmation != null, button_text + " opens its public confirmation dialog."):
		return false
	confirmation.get_ok_button().grab_focus()
	confirmation.confirmed.emit()
	return true


func _check_inspector_selection(
		title: String,
		expected_id: String,
		expected_name: String,
		expect_focus: bool,
		message: String
) -> void:
	var list: ItemList = _inspector_list(title)
	var selected_id: String = _selected_id(list)
	var name_input_name: String = "VariableNameInput" if title == "Variables" else "ReadyProcessName"
	var name_input: LineEdit = _dock.find_child(name_input_name, true, false) as LineEdit
	var focus_owner: Control = get_root().gui_get_focus_owner()
	_check(list != null and selected_id == expected_id, message + " Stable-ID row selection matches.")
	_check(list != null and _selected_row_is_visible(list), message + " Selected row is visible.")
	_check(name_input != null and name_input.text == expected_name, message + " Dock context matches.")
	_check(not expect_focus or focus_owner == list, message + " Focus matches its origin.")


func _check_block_selection(expected_id: String, expected_name: String, expect_focus: bool, message: String) -> void:
	var list: ItemList = _dock.find_child("ReadyBlocksList", true, false) as ItemList
	var name_input: LineEdit = _dock.find_child("ReadyBlockName", true, false) as LineEdit
	var focus_owner: Control = get_root().gui_get_focus_owner()
	_check(list != null and _selected_id(list) == expected_id, message + " Stable-ID row selection matches.")
	_check(list != null and _selected_row_is_visible(list), message + " Selected row is visible.")
	_check(name_input != null and name_input.text == expected_name, message + " Dock block context matches.")
	_check(not expect_focus or focus_owner == list, message + " Focus matches its origin.")


func _inspector_property() -> FlowGraphInspectorProperty:
	for node: Node in get_root().find_children("*", "FlowGraphInspectorProperty", true, false):
		var property: FlowGraphInspectorProperty = node as FlowGraphInspectorProperty
		if property != null and property.get_edited_object() == _controller:
			return property
	return null


func _inspector_list(title: String) -> ItemList:
	var property: FlowGraphInspectorProperty = _inspector_property()
	if property == null:
		return null
	for label: Node in property.find_children("*", "Label", true, false):
		if (label as Label).text != title:
			continue
		for child: Node in label.get_parent().get_children():
			if child is ItemList:
				return child as ItemList
	return null


func _selected_id(list: ItemList) -> String:
	if list == null:
		return ""
	var selected: PackedInt32Array = list.get_selected_items()
	if selected.size() != 1:
		return ""
	var metadata: Variant = list.get_item_metadata(selected[0])
	if metadata is Dictionary:
		return (metadata as Dictionary).get("internal_id", "") as String
	return metadata as String


func _selected_row_is_visible(list: ItemList) -> bool:
	var selected: PackedInt32Array = list.get_selected_items()
	if selected.size() != 1:
		return false
	var row: Rect2 = list.get_item_rect(selected[0])
	return row.size.x > 0.0 and row.size.y > 0.0 \
		and Rect2(Vector2.ZERO, list.size).intersects(row)


func _contains_variable(internal_id: String) -> bool:
	for variable: FlowVariableDefinition in _controller.flow_graph.variables:
		if variable != null and variable.get_internal_id() == internal_id:
			return true
	return false


func _button(root: Node, text: String) -> Button:
	if root == null:
		return null
	if root is Button and (root as Button).text == text:
		return root as Button
	for child: Node in root.get_children():
		var found: Button = _button(child, text)
		if found != null:
			return found
	return null


func _frames(count: int = 4) -> void:
	for _index: int in count:
		await process_frame


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_failures.append(message)
		push_error(message)
	return condition


func _finish() -> void:
	if is_instance_valid(_external_focus):
		_external_focus.queue_free()
	if is_instance_valid(_controller) and EditorInterface.get_edited_scene_root() == _controller:
		EditorInterface.save_scene()
		EditorInterface.close_scene()
	await _frames(6)
	if FileAccess.file_exists(TEMP_PATH):
		_check(
			DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH)) == OK,
			"Remove the delete-selection fixture."
		)
	if _failures.is_empty():
		print("[Flujo] Delete selection lifecycle test passed")
	quit(0 if _failures.is_empty() else 1)
