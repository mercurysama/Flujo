@tool
## Reusable Scene Node -> compatible property picker for nested value-source editors.
##
## This helper performs authoring only. It does not create Requirements; the
## owning Akis editor promotes nested NodePropertyRefs at final Tok commit so
## popup Cancel remains side-effect free.
class_name FlowNodePropertyOperandPicker
extends Node


signal source_selected(source: FlowNodePropertyRefValueSource)
signal cancelled


var _controller: PVController = null
var _scene_root: Node = null
var _accepted_types: Array[Variant.Type] = []
var _anchor: Rect2 = Rect2()
var _selector: FlowNodePropertySelector


func _init() -> void:
	name = &"FlowNodePropertyOperandPicker"
	_selector = FlowNodePropertySelector.new()
	_selector.property_selected.connect(_on_property_selected)
	_selector.cancelled.connect(_on_selector_cancelled)
	add_child(_selector)


func configure(controller: PVController, scene_root: Node = null) -> void:
	_controller = controller if is_instance_valid(controller) else null
	_scene_root = scene_root if is_instance_valid(scene_root) else null
	if _scene_root == null:
		_scene_root = EditorInterface.get_edited_scene_root()


func open_for_types(
		accepted_types: Array[Variant.Type],
		anchor: Rect2 = Rect2()
) -> bool:
	_accepted_types = accepted_types.duplicate()
	_anchor = anchor
	var panel: FlowSceneNodePanel = _scene_node_panel()
	if panel == null:
		cancelled.emit()
		return false
	if _controller == null:
		_controller = panel.get_controller()
	if _scene_root == null:
		_scene_root = EditorInterface.get_edited_scene_root()
	panel.begin_request(self)
	return true


func accept_scene_node_payload(payload: Dictionary) -> bool:
	if String(payload.get("type", "")) != "flujo_scene_node":
		return false
	var root: Node = _scene_root
	if not is_instance_valid(root):
		root = EditorInterface.get_edited_scene_root()
		_scene_root = root
	if not is_instance_valid(root):
		cancelled.emit()
		return false
	var node_path: NodePath = payload.get("node_path", NodePath())
	var node: Node = root.get_node_or_null(node_path)
	if not is_instance_valid(node):
		cancelled.emit()
		return false
	_selector.open_for_node(
		node,
		String(payload.get("requirement_id", "")),
		node_path,
		_accepted_types,
		_anchor
	)
	return true


func get_selector() -> FlowNodePropertySelector:
	return _selector


func cancel_request() -> void:
	var panel: FlowSceneNodePanel = _scene_node_panel()
	if panel != null:
		panel.clear_request_target()
	if _selector != null and _selector.visible:
		_selector.hide()


func _on_property_selected(source: FlowNodePropertyRefValueSource) -> void:
	var panel: FlowSceneNodePanel = _scene_node_panel()
	if panel != null:
		panel.clear_request_target()
	source_selected.emit(source)


func _on_selector_cancelled() -> void:
	var panel: FlowSceneNodePanel = _scene_node_panel()
	if panel != null:
		panel.clear_request_target()
	cancelled.emit()


func _scene_node_panel() -> FlowSceneNodePanel:
	var base: Control = EditorInterface.get_base_control()
	if not is_instance_valid(base):
		return null
	return base.find_child("FlowSceneNodePanel", true, false) as FlowSceneNodePanel
