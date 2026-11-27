@tool
class_name FluxusDrawer
extends FlowDrawerHost

## Top drawer host for Fluxus tools.
## Workspace instances are disposable; debug session state survives editor session.

const DEBUG_WORKSPACE_SCRIPT := preload("res://addons/vp_flujo/editor/fluxus_debug_workspace.gd")

var _debug_workspace: FlowDrawerWorkspace
var _debug_session_state: Dictionary = {}


func _init() -> void:
	super._init()
	name = "FluxusDrawer"
	slide_direction = SlideDirection.TOP
	panel_ratio = 0.5


func get_drawer_title() -> String:
	return "Fluxus"


func open() -> void:
	_ensure_debug_workspace()
	super.open()


func close() -> void:
	_capture_debug_session_state()
	super.close()


func _on_after_closed() -> void:
	_release_debug_workspace()
	super._on_after_closed()


func get_debug_workspace() -> FlowDrawerWorkspace:
	return _debug_workspace


func get_debug_session_state() -> Dictionary:
	return _debug_session_state.duplicate(true)


func _ensure_debug_workspace() -> void:
	if _debug_workspace != null and is_instance_valid(_debug_workspace):
		if not has_instance(_debug_workspace):
			mount_instance(_debug_workspace)
		_restore_debug_session_state()
		return
	_debug_workspace = DEBUG_WORKSPACE_SCRIPT.new() as FlowDrawerWorkspace
	if _debug_workspace == null:
		return
	_debug_workspace.name = &"FluxusDebugWorkspace"
	mount_instance(_debug_workspace)
	_restore_debug_session_state()


func _capture_debug_session_state() -> void:
	if _debug_workspace != null and is_instance_valid(_debug_workspace) \
			and _debug_workspace.has_method(&"capture_state"):
		var captured: Variant = _debug_workspace.call(&"capture_state")
		if captured is Dictionary:
			_debug_session_state = (captured as Dictionary).duplicate(true)


func _restore_debug_session_state() -> void:
	if _debug_session_state.is_empty():
		return
	if _debug_workspace != null and is_instance_valid(_debug_workspace) \
			and _debug_workspace.has_method(&"restore_state"):
		_debug_workspace.call(&"restore_state", _debug_session_state.duplicate(true))


func _release_debug_workspace() -> void:
	if _debug_workspace != null and is_instance_valid(_debug_workspace):
		unmount_instance(_debug_workspace)
	_debug_workspace = null
