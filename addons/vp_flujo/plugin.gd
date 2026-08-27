@tool
extends EditorPlugin

## Punto de composición de las clases que forman el complemento.

const PV_CONTROLLER_SCRIPT := preload("res://addons/vp_flujo/runtime/pv_controller.gd")
const PV_SCENE_INSPECTOR_CLASS := preload("res://addons/vp_flujo/editor/pv_scene_inspector.gd")
const VP_FLUJO_DOCK_CLASS := preload("res://addons/vp_flujo/editor/vp_flujo_dock.gd")

var _dock
var _scene_inspector


func _enter_tree() -> void:
	_scene_inspector = PV_SCENE_INSPECTOR_CLASS.new(PV_CONTROLLER_SCRIPT)
	_dock = VP_FLUJO_DOCK_CLASS.new()
	add_dock(_dock)
	_connect_editor_signals()
	_refresh_current_scene.call_deferred()


func _exit_tree() -> void:
	_disconnect_editor_signals()

	if is_instance_valid(_dock):
		remove_dock(_dock)
		_dock.queue_free()

	_dock = null
	_scene_inspector = null


func _connect_editor_signals() -> void:
	scene_changed.connect(_on_scene_changed)
	get_tree().node_added.connect(_on_scene_tree_changed)
	get_tree().node_removed.connect(_on_scene_tree_changed)


func _disconnect_editor_signals() -> void:
	if scene_changed.is_connected(_on_scene_changed):
		scene_changed.disconnect(_on_scene_changed)
	if get_tree().node_added.is_connected(_on_scene_tree_changed):
		get_tree().node_added.disconnect(_on_scene_tree_changed)
	if get_tree().node_removed.is_connected(_on_scene_tree_changed):
		get_tree().node_removed.disconnect(_on_scene_tree_changed)


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
