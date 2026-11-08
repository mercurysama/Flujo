@tool
extends PanelContainer

## A single task: checkbox, strikethrough, drag handle and right-hand ⋮ menu.

signal content_changed
signal remove_requested(task_id: String)
signal move_requested(task_id: String, offset: int)
signal reorder_requested(source_id: String, target_id: String, before: bool)

const DRAG_HANDLE := preload("res://addons/pixnido_panel_lab/task_drag_handle.gd")
const ACTION_EDIT: int = 1
const ACTION_UP: int = 2
const ACTION_DOWN: int = 3
const ACTION_DELETE: int = 4

var task_id: String = ""
var _task_text: String = ""
var _done: bool = false
var _check: CheckBox
var _label: RichTextLabel
var _input: LineEdit
var _handle: Control


func _init() -> void:
	name = "NidoLabTaskRow"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_build()


func configure(id: String, label: String, checked: bool, list_id: int) -> void:
	task_id = id
	_task_text = label
	_done = checked
	_handle.task_id = id
	_handle.list_instance_id = list_id
	_check.set_pressed_no_signal(checked)
	_refresh_label()


func get_task_text() -> String:
	return _task_text


func is_complete() -> bool:
	return _done


func set_complete(value: bool) -> void:
	_done = value
	_check.set_pressed_no_signal(value)
	_refresh_label()
	content_changed.emit()


func set_task_text(value: String) -> void:
	_task_text = value.substr(0, 500)
	_refresh_label()
	content_changed.emit()


func start_edit() -> void:
	if _input.visible:
		return
	_input.text = _task_text
	_label.hide()
	_input.show()
	_input.grab_focus()
	_input.select_all()


func _build() -> void:
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	add_child(inner)
	_handle = DRAG_HANDLE.new()
	inner.add_child(_handle)

	_check = CheckBox.new()
	_check.name = "Completed"
	_check.tooltip_text = "Mark task as completed"
	_check.custom_minimum_size = Vector2(27, 30)
	_check.toggled.connect(_on_check_toggled)
	inner.add_child(_check)

	_label = RichTextLabel.new()
	_label.name = "TaskText"
	_label.fit_content = true
	_label.scroll_active = false
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.custom_minimum_size = Vector2(70, 32)
	inner.add_child(_label)

	_input = LineEdit.new()
	_input.name = "EditTask"
	_input.placeholder_text = "Task description"
	_input.max_length = 500
	_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input.text_submitted.connect(func(_value: String) -> void: _commit_edit())
	_input.focus_exited.connect(_commit_edit)
	_input.hide()
	inner.add_child(_input)

	var options := MenuButton.new()
	options.name = "TaskOptions"
	options.text = "⋮"
	options.tooltip_text = "Task options"
	options.flat = true
	options.custom_minimum_size = Vector2(29, 30)
	options.focus_mode = Control.FOCUS_ALL
	inner.add_child(options)
	var popup: PopupMenu = options.get_popup()
	popup.add_item("Edit", ACTION_EDIT)
	popup.add_item("Move up", ACTION_UP)
	popup.add_item("Move down", ACTION_DOWN)
	popup.add_separator()
	popup.add_item("Delete", ACTION_DELETE)
	popup.id_pressed.connect(_on_menu)


func _refresh_label() -> void:
	if not is_instance_valid(_label):
		return
	_label.clear()
	if _done:
		_label.push_strikethrough()
	_label.add_text(_task_text)
	if _done:
		_label.pop()
	_label.add_theme_color_override("default_color", Color(0.55, 0.55, 0.55) if _done else Color(0.93, 0.93, 0.93))


func _commit_edit() -> void:
	if not _input.visible:
		return
	_input.hide()
	_label.show()
	set_task_text(_input.text)


func _on_check_toggled(value: bool) -> void:
	_done = value
	_refresh_label()
	content_changed.emit()


func _on_menu(action: int) -> void:
	match action:
		ACTION_EDIT:
			start_edit()
		ACTION_UP:
			move_requested.emit(task_id, -1)
		ACTION_DOWN:
			move_requested.emit(task_id, 1)
		ACTION_DELETE:
			remove_requested.emit(task_id)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	return (
		data.get("kind", "") == "nidolab_task"
		and int(data.get("list_id", 0)) == _handle.list_instance_id
		and String(data.get("task_id", "")) != task_id
	)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if not _can_drop_data(at_position, data):
		return
	var before: bool = at_position.y < size.y * 0.5
	reorder_requested.emit(String(data.get("task_id", "")), task_id, before)
