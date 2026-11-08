@tool
extends Control

## One selectable reference image. Move/resize gestures are managed by the board.

signal selected(item: Control)
signal remove_requested(item: Control)
signal manipulation_started(item: Control, mode: StringName)

var reference_id: String = ""
var source_path: String = ""

var _picture: TextureRect
var _missing: Label
var _outline: Panel
var _move: Button
var _close: Button
var _resize: Button


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2.ZERO
	_build_ui()


func configure(item_id: String, path: String, loaded: Texture2D) -> void:
	reference_id = item_id
	source_path = path
	_picture.texture = loaded
	_missing.visible = loaded == null
	_picture.tooltip_text = path
	_missing.tooltip_text = path
	_missing.text = "Image unavailable\n" + path.get_file()


func set_selected(active: bool) -> void:
	_outline.visible = active
	_move.visible = active
	_close.visible = active
	_resize.visible = active


func _build_ui() -> void:
	_picture = TextureRect.new()
	_picture.name = "Image"
	_picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_picture.texture_filter = Control.TEXTURE_FILTER_NEAREST
	_picture.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_picture)
	_picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_picture.gui_input.connect(_on_picture_input)

	_missing = Label.new()
	_missing.name = "Unavailable"
	_missing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_missing.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_missing.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_missing.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_missing)
	_missing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_missing.gui_input.connect(_on_picture_input)

	_outline = Panel.new()
	_outline.name = "SelectionOutline"
	_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var stroke := StyleBoxFlat.new()
	stroke.bg_color = Color.TRANSPARENT
	stroke.border_color = Color(0.3, 0.75, 1.0, 1.0)
	stroke.set_border_width_all(2)
	_outline.add_theme_stylebox_override("panel", stroke)
	add_child(_outline)
	_outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_move = _create_button("Drag to move image", "Move", "↔")
	add_child(_move)
	_move.anchor_left = 0.0
	_move.anchor_right = 0.0
	_move.anchor_top = 0.0
	_move.anchor_bottom = 0.0
	_move.set_offsets_preset(Control.PRESET_TOP_LEFT)
	_move.button_down.connect(_on_move_down)

	_close = _create_button("Remove reference", "Close", "×")
	add_child(_close)
	_close.anchor_left = 1.0
	_close.anchor_right = 1.0
	_close.anchor_top = 0.0
	_close.anchor_bottom = 0.0
	_close.offset_left = -28.0
	_close.offset_right = 0.0
	_close.offset_top = 0.0
	_close.offset_bottom = 28.0
	_close.pressed.connect(_on_remove)

	_resize = _create_button("Drag to resize image", "Resize", "↘")
	add_child(_resize)
	_resize.anchor_left = 1.0
	_resize.anchor_right = 1.0
	_resize.anchor_top = 1.0
	_resize.anchor_bottom = 1.0
	_resize.offset_left = -28.0
	_resize.offset_right = 0.0
	_resize.offset_top = -28.0
	_resize.offset_bottom = 0.0
	_resize.button_down.connect(_on_resize_down)
	set_selected(false)


func _create_button(hint: String, icon_id: StringName, fallback: String) -> Button:
	var button := Button.new()
	button.name = hint.replace(" ", "")
	button.flat = false
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = hint
	button.custom_minimum_size = Vector2.ZERO
	button.size = Vector2(28.0, 28.0)
	var theme: Theme = EditorInterface.get_editor_theme()
	if theme != null and theme.has_icon(icon_id, &"EditorIcons"):
		button.icon = theme.get_icon(icon_id, &"EditorIcons")
	else:
		button.text = fallback
	return button


func _on_picture_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT and click.pressed:
			selected.emit(self)
			accept_event()


func _on_move_down() -> void:
	selected.emit(self)
	manipulation_started.emit(self, &"move")


func _on_resize_down() -> void:
	selected.emit(self)
	manipulation_started.emit(self, &"resize")


func _on_remove() -> void:
	remove_requested.emit(self)
