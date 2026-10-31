@tool
## Property picker opened after a scene Node has been chosen or dropped.
class_name FlowNodePropertySelector
extends PopupPanel


signal property_selected(source: FlowNodePropertyRefValueSource)
signal cancelled


var _node: Node = null
var _requirement_id: String = ""
var _node_path: NodePath = NodePath()
var _accepted_types: Array[Variant.Type] = []
var _search: LineEdit
var _list: ItemList
var _status: Label
var _confirm: Button
var _closing_for_action: bool = false
var _descriptors: Array[Dictionary] = []


func _init() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name = &"FlowNodePropertySelector"
	min_size = Vector2i(520, 360)
	size = Vector2i(580, 460)
	close_requested.connect(_cancel)
	popup_hide.connect(_on_popup_hide)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override(&"margin_left", 14)
	margin.add_theme_constant_override(&"margin_top", 12)
	margin.add_theme_constant_override(&"margin_right", 14)
	margin.add_theme_constant_override(&"margin_bottom", 12)
	add_child(margin)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override(&"separation", 8)
	margin.add_child(content)

	var title: Label = Label.new()
	title.name = &"PropertySelectorTitle"
	title.text = "Select Node Property"
	title.add_theme_font_size_override(&"font_size", 16)
	content.add_child(title)

	_search = LineEdit.new()
	_search.name = &"PropertySearch"
	_search.placeholder_text = "Search compatible properties..."
	_search.text_changed.connect(_on_search_changed)
	content.add_child(_search)

	_list = ItemList.new()
	_list.name = &"PropertyList"
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.select_mode = ItemList.SELECT_SINGLE
	_list.item_selected.connect(_on_item_selected)
	_list.item_activated.connect(_on_item_activated)
	content.add_child(_list)

	_status = Label.new()
	_status.name = &"PropertyStatus"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status)

	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	var cancel_button: Button = Button.new()
	cancel_button.name = &"CancelNodeProperty"
	cancel_button.text = "Cancel"
	cancel_button.pressed.connect(_cancel)
	actions.add_child(cancel_button)
	_confirm = Button.new()
	_confirm.name = &"ConfirmNodeProperty"
	_confirm.text = "Confirm"
	_confirm.disabled = true
	_confirm.pressed.connect(_confirm_selected)
	actions.add_child(_confirm)
	content.add_child(actions)


func open_for_node(
		node: Node,
		requirement_id: String,
		node_path: NodePath,
		accepted_types: Array[Variant.Type],
		anchor: Rect2 = Rect2()
) -> void:
	_node = node
	_requirement_id = requirement_id
	_node_path = node_path
	_accepted_types = accepted_types.duplicate()
	_closing_for_action = false
	_search.text = ""
	_collect_descriptors()
	_rebuild_list()
	var title: Label = find_child("PropertySelectorTitle", true, false) as Label
	if title != null:
		title.text = "Select property — %s" % (
			String(node.name) if is_instance_valid(node) else "Node"
		)
	var popup_position: Vector2i = Vector2i(
		int(anchor.position.x),
		int(anchor.position.y + anchor.size.y)
	)
	popup(Rect2i(popup_position, Vector2i(size)))
	call_deferred(&"_focus_search")


func compatible_property_count() -> int:
	return _descriptors.size()


func _collect_descriptors() -> void:
	_descriptors.clear()
	if not is_instance_valid(_node):
		return
	for raw: Dictionary in _node.get_property_list():
		var property_name: StringName = StringName(raw.get("name", &""))
		var value_type: Variant.Type = int(
			raw.get("type", Variant.Type.TYPE_NIL)
		) as Variant.Type
		var usage: int = int(raw.get("usage", 0))
		if String(property_name).is_empty():
			continue
		if not FlowLiteralValueSource.is_allowed_type(value_type):
			continue
		if not _accepted_types.is_empty() and not _accepted_types.has(value_type):
			continue
		if (usage & PROPERTY_USAGE_EDITOR) == 0 and (usage & PROPERTY_USAGE_STORAGE) == 0:
			continue
		var descriptor: Dictionary = raw.duplicate(true)
		descriptor["name"] = property_name
		descriptor["type"] = value_type
		_descriptors.append(descriptor)
	_descriptors.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return String(a.get("name", "")).naturalnocasecmp_to(
			String(b.get("name", ""))
		) < 0
	)


func _rebuild_list() -> void:
	_list.clear()
	var query: String = _search.text.strip_edges().to_lower()
	for descriptor: Dictionary in _descriptors:
		var property_name: String = String(descriptor.get("name", ""))
		if not query.is_empty() and not property_name.to_lower().contains(query):
			continue
		var value_type: Variant.Type = int(descriptor.get("type", Variant.Type.TYPE_NIL))
		var index: int = _list.item_count
		_list.add_item("%s   ·   %s" % [
			property_name,
			FlowChipTypeDescriptor.variant_type_display_name(value_type),
		])
		_list.set_item_metadata(index, descriptor)
	_confirm.disabled = true
	if _list.item_count == 0:
		_status.text = "No compatible properties for this field."
	else:
		_status.text = "%d compatible properties." % _list.item_count


func _on_search_changed(_value: String) -> void:
	_rebuild_list()


func _on_item_selected(_index: int) -> void:
	_confirm.disabled = _list.get_selected_items().is_empty()


func _on_item_activated(index: int) -> void:
	_list.select(index)
	_confirm_selected()


func _confirm_selected() -> void:
	var selected: PackedInt32Array = _list.get_selected_items()
	if selected.is_empty() or not is_instance_valid(_node):
		return
	var descriptor: Dictionary = _list.get_item_metadata(selected[0]) as Dictionary
	var property_name: StringName = StringName(descriptor.get("name", &""))
	var value_type: Variant.Type = int(
		descriptor.get("type", Variant.Type.TYPE_NIL)
	) as Variant.Type
	var source: FlowNodePropertyRefValueSource = FlowNodePropertyRefValueSource.new(
		_requirement_id,
		_node_path,
		_node.name,
		property_name,
		value_type
	)
	if not source.is_valid():
		return
	_closing_for_action = true
	property_selected.emit(source)
	hide()


func _cancel() -> void:
	_closing_for_action = false
	hide()


func _on_popup_hide() -> void:
	if not _closing_for_action:
		cancelled.emit()
	_closing_for_action = false


func _focus_search() -> void:
	if visible and _search != null:
		_search.grab_focus()
