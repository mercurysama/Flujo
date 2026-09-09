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
var _dock_refresh_queued: bool = false
var _dock_controller: PVController
var _selected_schema_3_variable_id: String = ""


func _enter_tree() -> void:
	_scene_inspector = PV_SCENE_INSPECTOR_CLASS.new(PV_CONTROLLER_SCRIPT)
	_controller_inspector_plugin = PV_CONTROLLER_INSPECTOR_PLUGIN_CLASS.new()
	_controller_inspector_plugin.set_undo_redo(get_undo_redo())
	_controller_inspector_plugin.schema_3_variable_selection_changed.connect(
		_on_schema_3_variable_selection_changed
	)
	add_inspector_plugin(_controller_inspector_plugin)
	_dock = VP_FLUJO_DOCK_CLASS.new()
	_dock.configure(get_undo_redo())
	add_dock(_dock)
	_connect_editor_signals()
	_request_dock_refresh()


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
	_dock_controller = null
	_selected_schema_3_variable_id = ""
	_dock_refresh_queued = false


func _on_selection_changed() -> void:
	_request_dock_refresh()


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
	_request_dock_refresh()


func _on_scene_tree_changed(node: Node) -> void:
	if not _is_relevant_scene_tree_change(node, _scene_inspector):
		return
	_request_dock_refresh()


func _request_dock_refresh() -> void:
	if _dock_refresh_queued:
		return
	_dock_refresh_queued = true
	_refresh_current_scene.call_deferred()


func _refresh_current_scene() -> void:
	_dock_refresh_queued = false
	_update_dock_visibility()


func _update_dock_visibility() -> void:
	if not is_instance_valid(_dock) or _scene_inspector == null:
		return

	var selected_nodes: Array[Node] = []
	if _editor_selection != null:
		selected_nodes = _editor_selection.get_selected_nodes()
	var scene_root: Node = EditorInterface.get_edited_scene_root()
	var controller: PVController = _controller_for_selection(selected_nodes, scene_root)
	var should_show: bool = controller != null
	_selected_node = selected_nodes[0] if selected_nodes.size() == 1 else null
	var current_controller: PVController = _dock_controller if is_instance_valid(_dock_controller) else null
	if current_controller != controller:
		_dock_controller = controller
		_selected_schema_3_variable_id = ""
		_dock.set_controller(controller)
		_dock.set_variable_selection(controller, FlowGraphEditorCommands.Collection.VARIABLES, "")
	_dock.set_controller_present(should_show)


func _on_schema_3_variable_selection_changed(
	controller: PVController,
	collection: FlowGraphEditorCommands.Collection,
	variable_id: String
) -> void:
	if not is_instance_valid(_dock) or controller != _dock_controller:
		return
	if _selected_schema_3_variable_id == variable_id:
		return
	_selected_schema_3_variable_id = variable_id
	_dock.set_variable_selection(controller, collection, variable_id)


func _controller_for_selection(selected_nodes: Array[Node], scene_root: Node) -> PVController:
	if selected_nodes.size() == 1:
		return _scene_inspector.find_controller(selected_nodes[0])
	if selected_nodes.size() > 1:
		return null
	return _scene_inspector.find_controller(scene_root)


static func _is_relevant_scene_tree_change(node: Node, scene_inspector) -> bool:
	return node != null and scene_inspector != null and scene_inspector.contains_controller(node)


static func _should_show_dock(
		selected_nodes: Array[Node],
		scene_root: Node,
		scene_inspector
) -> bool:
	if selected_nodes.size() == 1:
		return scene_inspector != null and scene_inspector.contains_controller(selected_nodes[0])
	if selected_nodes.size() > 1:
		return false
	return scene_inspector != null and scene_inspector.contains_controller(scene_root)
