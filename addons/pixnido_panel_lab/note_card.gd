@tool
extends Control

## Independent editable note with move/resize/delete controls.

signal selected(item: Control)
signal manipulation_started(item: Control, mode: StringName)
signal remove_requested(item: Control)
signal text_edited

var note_id: String = ""
var _editor: TextEdit
var _outline: Panel
var _resize: Button
var _remove: Button


func _init() -> void:
	name = "NidoLabNoteCard"
	mouse_filter = Control.MOUSE_FILTER_PASS
	custom_minimum_size = Vector2.ZERO
	_build_ui()


func configure(item_id: String, content: String) -> void:
	note_id = item_id
	_editor.text = content


func get_note_text() -> String:
	return _editor.text


func set_selected(active: bool) -> void:
	_outline.visible = active
	_resize.visible = active
	_remove.visible = active


func _build_ui() -> void:
	var paper := Panel.new()
	paper.name = "NotePaper"
	paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.94, 0.90, 0.72)
	style.border_color = Color(0.71, 0.65, 0.42)
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	paper.add_theme_stylebox_override("panel", style)
	add_child(paper)
	paper.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var header := HBoxContainer.new()
	header.name = "NoteHeader"
	add_child(header)
	header.anchor_right = 1.0
	header.offset_bottom = 30.0
	var move_button := Button.new()
	move_button.name = "MoveNote"
	move_button.text = "↔"
	move_button.tooltip_text = "Drag to move note"
	move_button.custom_minimum_size = Vector2(32, 28)
	move_button.button_down.connect(func() -> void:
		selected.emit(self)
		manipulation_started.emit(self, &"move")
	)
	header.add_child(move_button)
	var heading := Label.new()
	heading.text = "Note"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_color_override("font_color", Color(0.14, 0.14, 0.15))
	header.add_child(heading)
	_remove = Button.new()
	_remove.name = "RemoveNote"
	_remove.text = "×"
	_remove.tooltip_text = "Remove note"
	_remove.custom_minimum_size = Vector2(28, 28)
	_remove.pressed.connect(func() -> void: remove_requested.emit(self))
	header.add_child(_remove)

	_editor = TextEdit.new()
	_editor.name = "NoteText"
	_editor.placeholder_text = "Write a note…"
	_editor.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_editor.add_theme_color_override("font_color", Color(0.12, 0.12, 0.13))
	_editor.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	_editor.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_editor.text_changed.connect(func() -> void: text_edited.emit())
	_editor.focus_entered.connect(func() -> void: selected.emit(self))
	add_child(_editor)
	_editor.anchor_right = 1.0
	_editor.anchor_bottom = 1.0
	_editor.offset_left = 7.0
	_editor.offset_top = 34.0
	_editor.offset_right = -7.0
	_editor.offset_bottom = -32.0

	_outline = Panel.new()
	_outline.name = "NoteSelection"
	_outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var selected_style := StyleBoxFlat.new()
	selected_style.bg_color = Color.TRANSPARENT
	selected_style.border_color = Color(0.26, 0.58, 0.97)
	selected_style.set_border_width_all(2)
	_outline.add_theme_stylebox_override("panel", selected_style)
	add_child(_outline)
	_outline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_resize = Button.new()
	_resize.name = "ResizeNote"
	_resize.text = "↘"
	_resize.tooltip_text = "Drag to resize note"
	_resize.anchor_left = 1.0
	_resize.anchor_top = 1.0
	_resize.anchor_right = 1.0
	_resize.anchor_bottom = 1.0
	_resize.offset_left = -30
	_resize.offset_top = -30
	_resize.offset_right = 0
	_resize.offset_bottom = 0
	_resize.button_down.connect(func() -> void:
		selected.emit(self)
		manipulation_started.emit(self, &"resize")
	)
	add_child(_resize)
	set_selected(false)
