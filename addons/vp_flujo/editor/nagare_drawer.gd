@tool
class_name NagareDrawer
extends FlowDrawerHost

## Lateral drawer host for Nagare tools (node browser + Akis/Tok editing).
## Infrastructure-first: workspace instances are disposable and session state is separate.

const NAGARE_WORKSPACE_SCRIPT := preload("res://addons/vp_flujo/editor/nagare_workspace.gd")

var _workspace: FlowDrawerWorkspace
var _session_state: Dictionary = {}


func _init() -> void:
	super._init()
	name = "NagareDrawer"
	slide_direction = SlideDirection.LEFT
	panel_ratio = 0.42


func get_drawer_title() -> String:
	return "Nagare"


func open() -> void:
	_ensure_workspace()
	super.open()


func close() -> void:
	_capture_session_state()
	super.close()


func _on_after_closed() -> void:
	_release_workspace()
	super._on_after_closed()


func get_workspace() -> FlowDrawerWorkspace:
	return _workspace


func get_session_state() -> Dictionary:
	return _session_state.duplicate(true)


func _ensure_workspace() -> void:
	if _workspace != null and is_instance_valid(_workspace):
		if not has_instance(_workspace):
			mount_instance(_workspace)
		_restore_session_state()
		return
	_workspace = NAGARE_WORKSPACE_SCRIPT.new() as FlowDrawerWorkspace
	if _workspace == null:
		return
	_workspace.name = &"NagareWorkspace"
	mount_instance(_workspace)
	_restore_session_state()


func _capture_session_state() -> void:
	if _workspace != null and is_instance_valid(_workspace) \
			and _workspace.has_method(&"capture_state"):
		var captured: Variant = _workspace.call(&"capture_state")
		if captured is Dictionary:
			_session_state = (captured as Dictionary).duplicate(true)


func _restore_session_state() -> void:
	if _session_state.is_empty():
		return
	if _workspace != null and is_instance_valid(_workspace) \
			and _workspace.has_method(&"restore_state"):
		_workspace.call(&"restore_state", _session_state.duplicate(true))


func _release_workspace() -> void:
	if _workspace != null and is_instance_valid(_workspace):
		unmount_instance(_workspace)
	_workspace = null
