@tool
extends EditorPlugin

## Punto de composición de las clases que forman el complemento.

const PV_CONTROLLER_SCRIPT := preload("res://addons/vp_flujo/runtime/pv_controller.gd")
const PV_SCENE_INSPECTOR_CLASS := preload("res://addons/vp_flujo/editor/pv_scene_inspector.gd")
const VP_FLUJO_DOCK_CLASS := preload("res://addons/vp_flujo/editor/vp_flujo_dock.gd")
const PV_CONTROLLER_INSPECTOR_PLUGIN_CLASS := preload("res://addons/vp_flujo/editor/pv_controller_inspector_plugin.gd")

var _dock
var _scene_inspector
var _controller_inspector_plugin: EditorInspectorPlugin
var _editor_selection: EditorSelection
var _selected_node: Node


func _enter_tree() -> void:
	_scene_inspector = PV_SCENE_INSPECTOR_CLASS.new(PV_CONTROLLER_SCRIPT)
	_controller_inspector_plugin = PV_CONTROLLER_INSPECTOR_PLUGIN_CLASS.new()
	_controller_inspector_plugin.set_undo_redo(get_undo_redo())
	add_inspector_plugin(_controller_inspector_plugin)
	_dock = VP_FLUJO_DOCK_CLASS.new()
	add_dock(_dock)
	_connect_editor_signals()
	_refresh_current_scene.call_deferred()


func _exit_tree() -> void:
	_disconnect_editor_signals()
	if is_instance_valid(_controller_inspector_plugin):
		remove_inspector_plugin(_controller_inspector_plugin)
	_controller_inspector_plugin = null

	if is_instance_valid(_dock):
		remove_dock(_dock)
		_dock.queue_free()

	_dock = null
	_scene_inspector = null


func _connect_editor_signals() -> void:
	scene_changed.connect(_on_scene_changed)
	get_tree().node_added.connect(_on_scene_tree_changed)
	get_tree().node_removed.connect(_on_scene_tree_changed)

	_editor_selection = EditorInterface.get_selection()
	if (
		_editor_selection != null
		and not _editor_selection.selection_changed.is_connected(_on_selection_changed)
	):
		_editor_selection.selection_changed.connect(_on_selection_changed)

	_on_selection_changed()


func _disconnect_editor_signals() -> void:
	if scene_changed.is_connected(_on_scene_changed):
		scene_changed.disconnect(_on_scene_changed)
	if get_tree().node_added.is_connected(_on_scene_tree_changed):
		get_tree().node_added.disconnect(_on_scene_tree_changed)
	if get_tree().node_removed.is_connected(_on_scene_tree_changed):
		get_tree().node_removed.disconnect(_on_scene_tree_changed)
	if (
		_editor_selection != null
		and _editor_selection.selection_changed.is_connected(_on_selection_changed)
	):
		_editor_selection.selection_changed.disconnect(_on_selection_changed)

	_editor_selection = null
	_selected_node = null


func _on_selection_changed() -> void:
	_selected_node = null

	if _editor_selection == null:
		return

	var selected_nodes: Array[Node] = _editor_selection.get_selected_nodes()
	if selected_nodes.size() != 1:
		return

	_selected_node = selected_nodes[0]


func _shortcut_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return

	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.keycode != KEY_F4:
		return
	if (
		key_event.alt_pressed
		or key_event.ctrl_pressed
		or key_event.meta_pressed
		or key_event.shift_pressed
	):
		return
	if not is_instance_valid(_selected_node):
		return
	if _scene_inspector == null or not is_instance_valid(_dock):
		return

	if _scene_inspector.contains_controller(_selected_node):
		_dock.toggle_visibility()
		get_viewport().set_input_as_handled()
		return

	if _add_controller_to_selected_node():
		get_viewport().set_input_as_handled()


func _add_controller_to_selected_node() -> bool:
	var scene_root: Node = EditorInterface.get_edited_scene_root()
	if not is_instance_valid(scene_root):
		return false

	var selected_node: Node = _selected_node
	if selected_node != scene_root and not scene_root.is_ancestor_of(selected_node):
		return false

	var undo_redo: EditorUndoRedoManager = get_undo_redo()
	if undo_redo == null:
		return false

	var controller: Node = PV_CONTROLLER_SCRIPT.new()
	controller.name = "PVController"

	undo_redo.create_action("Add Flujo Controller")
	undo_redo.add_do_method(selected_node, &"add_child", controller, true)
	undo_redo.add_do_method(controller, &"set_owner", scene_root)
	undo_redo.add_undo_method(selected_node, &"remove_child", controller)
	undo_redo.add_do_reference(controller)
	undo_redo.commit_action()

	return controller.get_parent() == selected_node and controller.owner == scene_root


func _on_scene_changed(_scene_root: Node) -> void:
	_refresh_current_scene.call_deferred()


func _on_scene_tree_changed(_node: Node) -> void:
	_refresh_current_scene.call_deferred()


func _refresh_current_scene() -> void:
	if not is_instance_valid(_dock) or _scene_inspector == null:
		return

	var scene_root := EditorInterface.get_edited_scene_root()
	if scene_root == null:
		return

	var has_controller: bool = _scene_inspector.contains_controller(scene_root)
	_dock.set_controller_present(has_controller)
