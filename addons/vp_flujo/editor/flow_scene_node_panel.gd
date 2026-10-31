@tool
## SceneTree projection used as the Node drag source for $ NodePropertyRef.
class_name FlowSceneNodePanel
extends Control


const PANEL_WIDTH_RATIO: float = 0.28

var _panel: PanelContainer
var _tree: FlowSceneNodeTree
var _controller_reference: WeakRef
var _request_target_reference: WeakRef
var _right_side: bool = true
var _is_open: bool = false


func _init() -> void:
	name = &"FlowSceneNodePanel"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_interface()
	visible = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_side_layout()


func set_controller(controller: PVController) -> void:
	_controller_reference = weakref(controller) if is_instance_valid(controller) else null
	refresh()


func get_controller() -> PVController:
	if _controller_reference == null:
		return null
	var controller: PVController = _controller_reference.get_ref() as PVController
	return controller if is_instance_valid(controller) else null


func begin_request(target: Object = null) -> void:
	_request_target_reference = weakref(target) if is_instance_valid(target) else null
	refresh()
	open()


func clear_request_target() -> void:
	_request_target_reference = null


func open() -> void:
	_is_open = true
	show()
	move_to_front()


func close() -> void:
	_is_open = false
	_request_target_reference = null
	hide()


func is_open() -> bool:
	return _is_open


func set_opposite_to_fluo(fluo_right_side: bool) -> void:
	_right_side = not fluo_right_side
	_apply_side_layout()


func refresh() -> void:
	if _tree == null:
		return
	_tree.clear()
	var scene_root: Node = EditorInterface.get_edited_scene_root()
	if not is_instance_valid(scene_root):
		return
	var root_item: TreeItem = _tree.create_item()
	root_item.set_text(0, "%s  [%s]" % [scene_root.name, scene_root.get_class()])
	root_item.set_metadata(0, {
		"type": "flujo_scene_node",
		"node_path": NodePath("."),
		"node_name": String(scene_root.name),
		"class_name": String(scene_root.get_class()),
		"requirement_id": _requirement_id_for_node(scene_root),
	})
	_populate_children(scene_root, scene_root, root_item)


func _build_interface() -> void:
	_panel = PanelContainer.new()
	_panel.name = &"SceneNodePanelShell"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override(&"separation", 6)
	_panel.add_child(content)

	var header: HBoxContainer = HBoxContainer.new()
	header.custom_minimum_size.y = 44.0
	content.add_child(header)

	var title: Label = Label.new()
	title.text = "Scene Nodes"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_button: Button = Button.new()
	close_button.text = "✕"
	close_button.tooltip_text = "Close Node Panel"
	close_button.pressed.connect(close)
	header.add_child(close_button)

	var hint: Label = Label.new()
	hint.text = "Drag a node into an Akis field, or double-click it after typing $."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(hint)

	_tree = FlowSceneNodeTree.new()
	_tree.name = &"SceneNodeTree"
	_tree.hide_root = false
	_tree.columns = 1
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tree.node_payload_activated.connect(_on_node_payload_activated)
	content.add_child(_tree)


func _apply_side_layout() -> void:
	if _panel == null:
		return
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 1.0
	_panel.offset_top = 0.0
	_panel.offset_bottom = 0.0
	if _right_side:
		_panel.anchor_left = 1.0 - PANEL_WIDTH_RATIO
		_panel.anchor_right = 1.0
	else:
		_panel.anchor_left = 0.0
		_panel.anchor_right = PANEL_WIDTH_RATIO
	_panel.offset_left = 0.0
	_panel.offset_right = 0.0


func _populate_children(scene_root: Node, parent_node: Node, parent_item: TreeItem) -> void:
	for child: Node in parent_node.get_children():
		var item: TreeItem = _tree.create_item(parent_item)
		item.set_text(0, "%s  [%s]" % [child.name, child.get_class()])
		var relative_path: NodePath = scene_root.get_path_to(child)
		var requirement_id: String = _requirement_id_for_node(child)
		item.set_metadata(0, {
			"type": "flujo_scene_node",
			"node_path": relative_path,
			"node_name": String(child.name),
			"class_name": String(child.get_class()),
			"requirement_id": requirement_id,
		})
		if not requirement_id.is_empty():
			item.set_tooltip_text(0, "Bound Requirement: %s" % requirement_id)
		_populate_children(scene_root, child, item)


func _requirement_id_for_node(node: Node) -> String:
	var controller: PVController = get_controller()
	if controller == null or not is_instance_valid(node):
		return ""
	var keys: Array = controller.requirement_bindings.keys()
	keys.sort()
	for key: Variant in keys:
		var requirement_id: String = String(key)
		var binding: NodePath = controller.requirement_bindings[requirement_id]
		if controller.get_node_or_null(binding) == node:
			return requirement_id
	return ""


func _on_node_payload_activated(payload: Dictionary) -> void:
	if _request_target_reference == null:
		return
	var target: Object = _request_target_reference.get_ref()
	if not is_instance_valid(target) or not target.has_method(&"accept_scene_node_payload"):
		_request_target_reference = null
		return
	target.call(&"accept_scene_node_payload", payload)
