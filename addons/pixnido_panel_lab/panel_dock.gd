@tool
extends EditorDock

## Experimental UI shell. HTML5 rendering and reference images are not connected yet.

signal close_requested

const ANIMATION_SECONDS: float = 0.16
const SLIDE_PIXELS: float = 20.0

var panel_id: StringName = &""
var _close_button: Button
var _add_button: Button
var _content: VBoxContainer
var _motion: Tween
var _should_be_open: bool = false
var _slide_from_right: bool = false


func configure(new_panel_id: StringName, slot: int) -> void:
	panel_id = new_panel_id
	var is_pixnido: bool = panel_id == &"pixnido"
	name = "PixNidoEditorDock" if is_pixnido else "PixNidoReferencesDock"
	title = "PixNido" if is_pixnido else "References"
	layout_key = "pixnido_lab_editor" if is_pixnido else "pixnido_lab_references"
	icon_name = &"Sprite2D" if is_pixnido else &"Texture2D"
	default_slot = slot
	available_layouts = EditorDock.DOCK_LAYOUT_VERTICAL
	global = false
	closable = false
	transient = true
	_slide_from_right = not is_pixnido
	_build_content(is_pixnido)


func _ready() -> void:
	_apply_editor_icon(_close_button, &"Close", "×")
	if _add_button != null:
		_apply_editor_icon(_add_button, &"Add", "+")


func _exit_tree() -> void:
	cancel_motion()


func set_slide_side(from_right: bool) -> void:
	_slide_from_right = from_right


func cancel_motion() -> void:
	if _motion != null:
		_motion.kill()
		_motion = null
	if is_instance_valid(_content):
		_content.modulate.a = 1.0
		_content.position.x = 0.0


func show_panel(animated: bool = true) -> void:
	cancel_motion()
	_should_be_open = true
	make_visible()
	if not animated or not is_instance_valid(_content):
		return
	_content.modulate.a = 0.0
	_content.position.x = _slide_offset()
	_motion = create_tween()
	_motion.set_trans(Tween.TRANS_CUBIC)
	_motion.set_ease(Tween.EASE_OUT)
	_motion.tween_property(_content, "modulate:a", 1.0, ANIMATION_SECONDS)
	_motion.parallel().tween_property(_content, "position:x", 0.0, ANIMATION_SECONDS)


func hide_panel(animated: bool = true) -> void:
	cancel_motion()
	_should_be_open = false
	if not animated or not is_visible_in_tree() or not is_instance_valid(_content):
		close()
		return
	_motion = create_tween()
	_motion.set_trans(Tween.TRANS_CUBIC)
	_motion.set_ease(Tween.EASE_IN)
	_motion.tween_property(_content, "modulate:a", 0.0, ANIMATION_SECONDS)
	_motion.parallel().tween_property(_content, "position:x", _slide_offset(), ANIMATION_SECONDS)
	_motion.finished.connect(_finish_hide)


func _finish_hide() -> void:
	if _should_be_open:
		return
	close()
	cancel_motion()


func _slide_offset() -> float:
	return SLIDE_PIXELS if _slide_from_right else -SLIDE_PIXELS


func _build_content(is_pixnido: bool) -> void:
	var mask := Control.new()
	mask.name = "ContentMask"
	mask.clip_contents = true
	mask.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mask.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mask.custom_minimum_size = Vector2(180, 170) if is_pixnido else Vector2(260, 170)
	add_child(mask)

	var content := VBoxContainer.new()
	content.name = "Content"
	mask.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content = content

	var header := HBoxContainer.new()
	header.name = "Header"
	content.add_child(header)

	var heading := Label.new()
	heading.text = "PixNido" if is_pixnido else "References"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)

	if not is_pixnido:
		_add_button = _make_button("Add reference (Phase 03)")
		_add_button.name = "AddReference"
		_add_button.disabled = true
		header.add_child(_add_button)

	_close_button = _make_button("Close panel")
	_close_button.name = "ClosePanel"
	_close_button.pressed.connect(_on_close_pressed)
	header.add_child(_close_button)

	var center := CenterContainer.new()
	center.name = "Placeholder"
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(center)

	var message := Label.new()
	message.name = "Status"
	message.text = "HTML5 editor pending" if is_pixnido else "No reference images yet"
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(message)


func _make_button(hint: String) -> Button:
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = hint
	button.custom_minimum_size = Vector2(30, 30)
	return button


func _apply_editor_icon(button: Button, icon_id: StringName, fallback: String) -> void:
	var editor_theme: Theme = EditorInterface.get_editor_theme()
	if editor_theme != null and editor_theme.has_icon(icon_id, &"EditorIcons"):
		button.icon = editor_theme.get_icon(icon_id, &"EditorIcons")
	else:
		button.text = fallback


func _on_close_pressed() -> void:
	close_requested.emit()
