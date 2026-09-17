@tool
extends SceneTree

const TEMP_PATH: String = "res://.godot/flujo_tests/controller_removal_lifecycle.tscn"

var _failures: Array[String] = []
var _scene_root: Node
var _controller: PVController
var _dock: VPFlujoDock
var _external_focus: LineEdit
var _history: UndoRedo
var _controller_index: int = -1


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
	_scene_root = EditorInterface.get_edited_scene_root()
	_controller = _scene_root.get_node_or_null("PVController") as PVController \
		if _scene_root != null else null
	if not _check(_controller != null, "Open the controller-removal scene fixture."):
		_finish()
		return
	_select_and_inspect_controller(_controller)
	await _frames(8)
	_dock = get_root().find_child("VPFlujoDock", true, false) as VPFlujoDock
	var property: FlowGraphInspectorProperty = _inspector_property(_controller)
	var variables: ItemList = _inspector_list(property, "Variables")
	if not _check(
		_dock != null and property != null and variables != null and variables.item_count == 1,
		"Mount the real Inspector, plugin relay, dock, and Variables row."
	):
		_finish()
		return
	var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	_history = manager.get_history_undo_redo(manager.get_object_history_id(_scene_root))
	_external_focus = LineEdit.new()
	_external_focus.name = &"ControllerRemovalExternalFocus"
	get_root().add_child(_external_focus)

	variables.select(0)
	variables.item_selected.emit(0)
	variables.item_activated.emit(0)
	property.update_property()
	_external_focus.grab_focus()
	_controller_index = _controller.get_index()
	manager.create_action("Remove Node(s)", UndoRedo.MERGE_DISABLE, _scene_root, false, true)
	manager.add_do_method(self, &"_detach_controller", _scene_root, _controller)
	manager.add_undo_method(self, &"_restore_controller", _scene_root, _controller, _controller_index)
	manager.commit_action()
	await _frames(3)

	var dock_editor: FlowGraphInspectorProperty = _dock.get_variable_editor()
	_check(_controller.get_parent() == null, "Remove Node(s) detaches the selected PVController.")
	_check(
		dock_editor.find_child("Schema3VariableEditor", true, false) == null,
		"Removing the controller clears the dock editor after pending callbacks."
	)
	_check(
		get_root().gui_get_focus_owner() == _external_focus,
		"Stale selection and focus callbacks do not steal external focus."
	)

	_history.undo()
	await _frames(3)
	_check(
		_controller.get_parent() == _scene_root and get_root().gui_get_focus_owner() == _external_focus,
		"Undo restores the controller without reusing stale focus requests."
	)
	_select_and_inspect_controller(_controller)
	await _frames(8)
	property = _inspector_property(_controller)
	variables = _inspector_list(property, "Variables")
	_check(
		property != null and variables != null and variables.item_count == 1,
		"The restored controller rebinds through the public Inspector selection path."
	)
	if variables != null and variables.item_count == 1:
		variables.select(0)
		variables.item_selected.emit(0)
		await _frames(3)
		var name_input: LineEdit = _dock.find_child("VariableNameInput", true, false) as LineEdit
		_check(
			name_input != null and name_input.text == "Lifecycle Variable",
			"The restored controller can be selected and edited normally."
		)
	_finish()


func _create_fixture() -> bool:
	var root: Node = Node.new()
	root.name = "ControllerRemovalLifecycle"
	var controller: PVController = PVController.new()
	controller.name = "PVController"
	root.add_child(controller)
	controller.owner = root
	var graph: FlowGraph = controller.flow_graph
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var variable: FlowVariableDefinition = FlowVariableDefinition.new()
	variable.display_name = "Lifecycle Variable"
	graph.variables = [variable]
	var packed: PackedScene = PackedScene.new()
	if not _check(packed.pack(root) == OK, "Pack the controller-removal fixture."):
		root.free()
		return false
	root.free()
	if not _check(
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/flujo_tests")) == OK,
		"Create the focal test directory."
	):
		return false
	return _check(ResourceSaver.save(packed, TEMP_PATH) == OK, "Save the controller-removal fixture.")


func _select_and_inspect_controller(controller: PVController) -> void:
	var selection: EditorSelection = EditorInterface.get_selection()
	selection.clear()
	selection.add_node(controller)
	EditorInterface.inspect_object(controller)


func _detach_controller(parent: Node, controller: PVController) -> void:
	if is_instance_valid(parent) and is_instance_valid(controller) and controller.get_parent() == parent:
		parent.remove_child(controller)


func _restore_controller(parent: Node, controller: PVController, child_index: int) -> void:
	if not is_instance_valid(parent) or not is_instance_valid(controller) or controller.get_parent() != null:
		return
	parent.add_child(controller)
	parent.move_child(controller, mini(child_index, parent.get_child_count() - 1))
	controller.owner = parent


func _inspector_property(controller: PVController) -> FlowGraphInspectorProperty:
	for node: Node in get_root().find_children("*", "FlowGraphInspectorProperty", true, false):
		var property: FlowGraphInspectorProperty = node as FlowGraphInspectorProperty
		if property != null and property.get_edited_object() == controller:
			return property
	return null


func _inspector_list(property: FlowGraphInspectorProperty, title: String) -> ItemList:
	if property == null:
		return null
	for label_node: Node in property.find_children("*", "Label", true, false):
		var label: Label = label_node as Label
		if label == null or label.text != title:
			continue
		for child: Node in label.get_parent().get_children():
			if child is ItemList:
				return child as ItemList
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
	if is_instance_valid(_scene_root) and EditorInterface.get_edited_scene_root() == _scene_root:
		EditorInterface.save_scene()
		EditorInterface.close_scene()
	await _frames(6)
	if FileAccess.file_exists(TEMP_PATH):
		_check(
			DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH)) == OK,
			"Remove the controller-removal fixture."
		)
	if _failures.is_empty():
		print("[Flujo] Controller removal lifecycle test passed")
	quit(0 if _failures.is_empty() else 1)
