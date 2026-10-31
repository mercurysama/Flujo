@tool
## Disambiguates a selected SceneTree node when an Akis slot accepts both a
## NodeRef and a NodePropertyRef.
class_name FlowSceneReferenceChoice
extends PopupPanel


signal node_requested
signal property_requested
signal cancelled


var _closing_for_action: bool = false


func _init() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name = &"FlowSceneReferenceChoice"
	min_size = Vector2i(360, 150)
	size = Vector2i(420, 180)
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
	content.add_theme_constant_override(&"separation", 10)
	margin.add_child(content)

	var title: Label = Label.new()
	title.name = &"SceneReferenceChoiceTitle"
	title.text = "Use selected scene node as..."
	title.add_theme_font_size_override(&"font_size", 16)
	content.add_child(title)

	var actions: HBoxContainer = HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(actions)

	var node_button: Button = Button.new()
	node_button.name = &"UseSceneNode"
	node_button.text = "Use Node"
	node_button.tooltip_text = "Insert the selected Node itself as an Object-valued Tok."
	node_button.pressed.connect(_choose_node)
	actions.add_child(node_button)

	var property_button: Button = Button.new()
	property_button.name = &"ChooseSceneProperty"
	property_button.text = "Choose Property"
	property_button.tooltip_text = "Choose one typed property from the selected Node."
	property_button.pressed.connect(_choose_property)
	actions.add_child(property_button)

	var cancel_button: Button = Button.new()
	cancel_button.name = &"CancelSceneReferenceChoice"
	cancel_button.text = "Cancel"
	cancel_button.pressed.connect(_cancel)
	actions.add_child(cancel_button)


func open_for_node(node_name: String, anchor: Rect2 = Rect2()) -> void:
	_closing_for_action = false
	var title: Label = find_child(
		"SceneReferenceChoiceTitle",
		true,
		false
	) as Label
	if title != null:
		title.text = "Use %s as..." % (node_name if not node_name.is_empty() else "selected node")
	var popup_position: Vector2i = Vector2i(
		int(anchor.position.x),
		int(anchor.position.y + anchor.size.y)
	)
	popup(Rect2i(popup_position, Vector2i(size)))


func _choose_node() -> void:
	_closing_for_action = true
	node_requested.emit()
	hide()


func _choose_property() -> void:
	_closing_for_action = true
	property_requested.emit()
	hide()


func _cancel() -> void:
	_closing_for_action = false
	hide()


func _on_popup_hide() -> void:
	if not _closing_for_action:
		cancelled.emit()
	_closing_for_action = false
