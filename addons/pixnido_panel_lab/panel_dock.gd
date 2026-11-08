@tool
extends EditorDock

## Experimental UI shell. HTML5 rendering and reference images are not connected yet.

signal close_requested

var panel_id: StringName = &""
var _close_button: Button
var _add_button: Button


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
	_build_content(is_pixnido)


func _ready() -> void:
	_apply_editor_icon(_close_button, &"Close", "×")
	if _add_button != null:
		_apply_editor_icon(_add_button, &"Add", "+")


func _build_content(is_pixnido: bool) -> void:
	var content := VBoxContainer.new()
	content.name = "Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.custom_minimum_size = Vector2(180, 170) if is_pixnido else Vector2(260, 170)
	add_child(content)

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
