@tool
extends VBoxContainer

## Persistent, ordered checklist with native drag-and-drop plus keyboard fallback.

signal changed

const ROW := preload("res://addons/pixnido_panel_lab/task_row.gd")
const VERSION: int = 1
const MAX_TASKS: int = 1000
var _rows: Array[Control] = []
var _next_id: int = 1
var _restoring: bool = false
var _items_column: VBoxContainer
var _placeholder: Label


func _init() -> void:
	name = "NidoLabTasks"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var header := HBoxContainer.new()
	header.name = "TaskToolbar"
	add_child(header)

	var title := Label.new()
	title.text = "Task list"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var add := Button.new()
	add.name = "AddTask"
	add.text = "+"
	add.tooltip_text = "Add a new task"
	add.custom_minimum_size = Vector2(32, 32)
	add.pressed.connect(func() -> void: add_task())
	header.add_child(add)

	var scroll := ScrollContainer.new()
	scroll.name = "TaskScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)

	_items_column = VBoxContainer.new()
	_items_column.name = "TaskItems"
	_items_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_items_column)
	_placeholder = Label.new()
	_placeholder.text = "No tasks yet. Press + to add one."
	_placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_items_column.add_child(_placeholder)


func add_task(content: String = "New task", begin_edit: bool = false) -> void:
	if _rows.size() >= MAX_TASKS:
		push_warning("NidoLab: task limit reached.")
		return
	var id: String = "task_" + str(_next_id)
	_next_id += 1
	var row: Control = _create_row(id, content.substr(0, 500), false)
	_refresh_empty()
	_emit_changed()
	if begin_edit:
		row.call_deferred(&"start_edit")


func get_state() -> Dictionary:
	var data: Array[Dictionary] = []
	for row in _rows:
		if is_instance_valid(row):
			data.append({
				"id": String(row.get_meta(&"task_id")),
				"text": String(row.call(&"get_task_text")),
				"completed": bool(row.call(&"is_complete")),
			})
	return {"version": VERSION, "next_id": _next_id, "items": data}


func set_state(state: Dictionary) -> void:
	if int(state.get("version", VERSION)) != VERSION:
		push_warning("NidoLab: unsupported task state version.")
		return
	_restoring = true
	for row in _rows:
		if is_instance_valid(row):
			_items_column.remove_child(row)
			row.queue_free()
	_rows.clear()
	_next_id = 1
	var entries: Variant = state.get("items", [])
	var used: Dictionary = {}
	if entries is Array:
		for entry in entries:
			if not entry is Dictionary or _rows.size() >= MAX_TASKS:
				continue
			var task: Dictionary = entry
			var id: String = String(task.get("id", ""))
			if not id.begins_with("task_") or id.length() > 32 or int(id.trim_prefix("task_")) < 1 or used.has(id):
				continue
			used[id] = true
			_next_id = maxi(_next_id, int(id.trim_prefix("task_")) + 1)
			_create_row(id, String(task.get("text", "")).substr(0, 500), bool(task.get("completed", false)))
	_next_id = maxi(_next_id, int(state.get("next_id", _next_id)))
	_restoring = false
	_refresh_empty()


func reorder_task(source_id: String, target_id: String, before: bool = true) -> void:
	var source: Control = _find(source_id)
	var target: Control = _find(target_id)
	if not is_instance_valid(source) or not is_instance_valid(target) or source == target:
		return
	_rows.erase(source)
	var new_index: int = _rows.find(target) + (0 if before else 1)
	_rows.insert(new_index, source)
	_items_column.move_child(source, new_index)
	_emit_changed()


func remove_task(id: String) -> void:
	var row: Control = _find(id)
	if not is_instance_valid(row):
		return
	_rows.erase(row)
	_items_column.remove_child(row)
	row.queue_free()
	_refresh_empty()
	_emit_changed()


func set_task_complete(id: String, checked: bool) -> void:
	var row: Control = _find(id)
	if is_instance_valid(row):
		row.call(&"set_complete", checked)


func set_task_text(id: String, content: String) -> void:
	var row: Control = _find(id)
	if is_instance_valid(row):
		row.call(&"set_task_text", content)


func _create_row(id: String, content: String, checked: bool) -> Control:
	var row: Control = ROW.new()
	row.name = "TaskRow_" + id
	row.set_meta(&"task_id", id)
	row.call(&"configure", id, content, checked, get_instance_id())
	row.connect(&"content_changed", _emit_changed)
	row.connect(&"remove_requested", remove_task)
	row.connect(&"move_requested", _move_direction)
	row.connect(&"reorder_requested", reorder_task)
	_items_column.add_child(row)
	_rows.append(row)
	return row


func _find(id: String) -> Control:
	for row in _rows:
		if is_instance_valid(row) and String(row.get_meta(&"task_id")) == id:
			return row
	return null


func _move_direction(id: String, offset: int) -> void:
	var row: Control = _find(id)
	if not is_instance_valid(row):
		return
	var index: int = _rows.find(row)
	var target: int = index + offset
	if target < 0 or target >= _rows.size():
		return
	var target_id: String = String(_rows[target].get_meta(&"task_id"))
	reorder_task(id, target_id, offset < 0)


func _refresh_empty() -> void:
	_placeholder.visible = _rows.is_empty()


func _emit_changed() -> void:
	if not _restoring:
		changed.emit()
