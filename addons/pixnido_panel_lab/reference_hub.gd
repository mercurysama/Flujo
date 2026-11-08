@tool
extends TabContainer

## Icon-only References tabs: existing images, movable notes, ordered tasks.

signal changed
signal image_picker_requested

const IMAGE_BOARD := preload("res://addons/pixnido_panel_lab/reference_board.gd")
const NOTES_BOARD := preload("res://addons/pixnido_panel_lab/notes_board.gd")
const TASKS_LIST := preload("res://addons/pixnido_panel_lab/tasks_list.gd")

var _images: Control
var _notes: Control
var _tasks: Control
var _restoring: bool = false


func _init() -> void:
	name = "NidoLabReferences"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_images = IMAGE_BOARD.new()
	_images.name = "ImageReferences"
	add_child(_images)
	_notes = NOTES_BOARD.new()
	_notes.name = "TextNotes"
	add_child(_notes)
	_tasks = TASKS_LIST.new()
	_tasks.name = "TaskChecklist"
	add_child(_tasks)
	_images.connect(&"changed", _emit_changed)
	_notes.connect(&"changed", _emit_changed)
	_tasks.connect(&"changed", _emit_changed)
	tab_changed.connect(_on_tab_changed)
	current_tab = 0


func _ready() -> void:
	var icon_names: Array[StringName] = [&"Texture2D", &"Edit", &"CheckBox"]
	var fallback: Array[String] = ["▧", "✎", "☑"]
	var tooltips: Array[String] = ["Image references", "Text notes", "Task checklist"]
	var theme: Theme = EditorInterface.get_editor_theme()
	for index in range(3):
		set_tab_title(index, "")
		set_tab_tooltip(index, tooltips[index])
		if theme != null and theme.has_icon(icon_names[index], &"EditorIcons"):
			set_tab_icon(index, theme.get_icon(icon_names[index], &"EditorIcons"))
		else:
			# Glyph fallback is a pictogram, never a visible text tab label.
			set_tab_title(index, fallback[index])


func current_section() -> int:
	return current_tab


func set_active_section(tab_index: int) -> void:
	_restoring = true
	current_tab = clampi(tab_index, 0, 2)
	_restoring = false


func add_for_current_tab() -> void:
	match current_tab:
		0:
			image_picker_requested.emit()
		1:
			_notes.call(&"add_note")
		2:
			_tasks.call(&"add_task", "New task", true)


func add_image_paths(paths: PackedStringArray) -> void:
	_images.call(&"add_paths", paths)


func get_images_state() -> Dictionary:
	return _images.call(&"get_layout_state")


func set_images_state(state: Dictionary) -> void:
	_images.call(&"set_layout_state", state)


func get_notes_state() -> Dictionary:
	return _notes.call(&"get_state")


func set_notes_state(state: Dictionary) -> void:
	_notes.call(&"set_state", state)


func get_tasks_state() -> Dictionary:
	return _tasks.call(&"get_state")


func set_tasks_state(state: Dictionary) -> void:
	_tasks.call(&"set_state", state)


func _on_tab_changed(_tab: int) -> void:
	_emit_changed()


func _emit_changed() -> void:
	if not _restoring:
		changed.emit()
