@tool
extends EditorDock

## Independent docks: reference image board is editor-only; HTML5 PixNido is pending.

signal close_requested
signal references_changed
signal pixnido_source_changed

const REFERENCE_BOARD_SCRIPT := preload("res://addons/pixnido_panel_lab/reference_board.gd")
const PIXNIDO_HOST_SCRIPT := preload("res://addons/pixnido_panel_lab/pixnido_servo_host.gd")

const ANIMATION_SECONDS: float = 0.16
const SLIDE_PIXELS: float = 20.0

var panel_id: StringName = &""
var _close_button: Button
var _add_button: Button
var _content: VBoxContainer
var _motion: Tween
var _should_be_open: bool = false
var _slide_from_right: bool = false
var _board: Control
var _pixnido_host: Control
var _file_dialog: EditorFileDialog


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


func get_pixnido_source() -> String:
	if not is_instance_valid(_pixnido_host):
		return "https://pixnido.pages.dev/"
	return String(_pixnido_host.call(&"get_source"))


func set_pixnido_source(source: String) -> void:
	if is_instance_valid(_pixnido_host):
		_pixnido_host.call(&"set_source", source)


func _on_pixnido_source_changed(value: String) -> void:
	pixnido_source_changed.emit()


func get_references_state() -> Dictionary:
	if not is_instance_valid(_board):
		return {"version": 1, "next_id": 1, "items": []}
	var state: Dictionary = _board.call(&"get_layout_state")
	return state


func set_references_state(state: Dictionary) -> void:
	if is_instance_valid(_board):
		_board.call(&"set_layout_state", state)


func _open_reference_dialog() -> void:
	if is_instance_valid(_file_dialog):
		_file_dialog.popup_centered_ratio(0.7)


func _on_files_selected(paths: PackedStringArray) -> void:
	if is_instance_valid(_board):
		_board.call(&"add_paths", paths)


func _on_references_changed() -> void:
	references_changed.emit()


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
		_add_button = _make_button("Add reference image")
		_add_button.name = "AddReference"
		_add_button.pressed.connect(_open_reference_dialog)
		header.add_child(_add_button)

	_close_button = _make_button("Close panel")
	_close_button.name = "ClosePanel"
	_close_button.pressed.connect(_on_close_pressed)
	header.add_child(_close_button)

	if is_pixnido:
		_pixnido_host = PIXNIDO_HOST_SCRIPT.new()
		_pixnido_host.connect(&"source_changed", _on_pixnido_source_changed)
		content.add_child(_pixnido_host)
	else:
		_board = REFERENCE_BOARD_SCRIPT.new()
		content.add_child(_board)
		_board.connect(&"changed", _on_references_changed)

		_file_dialog = EditorFileDialog.new()
		_file_dialog.name = "ReferenceFilePicker"
		_file_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_FILES
		_file_dialog.access = EditorFileDialog.ACCESS_FILESYSTEM
		_file_dialog.add_filter("*.png, *.jpg, *.jpeg, *.webp, *.bmp", "Image files")
		_file_dialog.files_selected.connect(_on_files_selected)
		add_child(_file_dialog)


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
