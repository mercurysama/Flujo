@tool
extends Control

## Per-project note canvas, separate from existing image references.

signal changed

const CARD := preload("res://addons/pixnido_panel_lab/note_card.gd")
const VERSION: int = 1
const MAX_NOTES: int = 128
const MAX_TEXT: int = 10000
const MIN_SIZE: Vector2 = Vector2(160.0, 110.0)

var _items: Array[Control] = []
var _selected: Control
var _drag_item: Control
var _drag_mode: StringName = &""
var _drag_origin: Vector2
var _item_origin: Vector2
var _size_origin: Vector2
var _next_id: int = 1
var _restoring: bool = false
var _empty: Label


func _init() -> void:
	name = "NidoLabNotes"
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	_empty = Label.new()
	_empty.text = "Add a note using +"
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_empty)
	_empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var add := Button.new()
	add.name = "AddNote"
	add.text = "+"
	add.tooltip_text = "Add a text note"
	add.custom_minimum_size = Vector2(32, 32)
	add.pressed.connect(func() -> void: add_note())
	add_child(add)
	resized.connect(_clamp_all)


func add_note(content: String = "") -> void:
	if _items.size() >= MAX_NOTES:
		push_warning("NidoLab: note limit reached.")
		return
	var offset: float = float(_items.size() % 6) * 18.0
	var id: String = "note_" + str(_next_id)
	_next_id += 1
	_make_note(id, content.substr(0, MAX_TEXT), Rect2(Vector2(12 + offset, 38 + offset), Vector2(230, 160)))
	_update_empty()
	_emit_changed()


func get_state() -> Dictionary:
	var data: Array[Dictionary] = []
	for item in _items:
		if not is_instance_valid(item):
			continue
		data.append({
			"id": String(item.get_meta(&"note_id")),
			"text": String(item.call(&"get_note_text")).substr(0, MAX_TEXT),
			"x": item.position.x, "y": item.position.y,
			"w": item.size.x, "h": item.size.y,
		})
	return {"version": VERSION, "next_id": _next_id, "items": data}


func set_state(state: Dictionary) -> void:
	if int(state.get("version", VERSION)) != VERSION:
		push_warning("NidoLab: unsupported note layout version.")
		return
	_restoring = true
	_selected = null
	_drag_item = null
	for item in _items:
		if is_instance_valid(item):
			remove_child(item)
			item.queue_free()
	_items.clear()
	_next_id = 1
	var entries: Variant = state.get("items", [])
	if entries is Array:
		for entry in entries:
			if not entry is Dictionary or _items.size() >= MAX_NOTES:
				continue
			var item_data: Dictionary = entry
			var id: String = String(item_data.get("id", ""))
			if not id.begins_with("note_") or id.length() > 32 or int(id.trim_prefix("note_")) < 1:
				continue
			_next_id = maxi(_next_id, int(id.trim_prefix("note_")) + 1)
			var rect := Rect2(
				Vector2(clampf(float(item_data.get("x", 12)), 0, 100000), clampf(float(item_data.get("y", 38)), 0, 100000)),
				Vector2(clampf(float(item_data.get("w", 230)), MIN_SIZE.x, 100000), clampf(float(item_data.get("h", 160)), MIN_SIZE.y, 100000))
			)
			_make_note(id, String(item_data.get("text", "")).substr(0, MAX_TEXT), rect)
	_next_id = maxi(_next_id, int(state.get("next_id", _next_id)))
	_restoring = false
	_update_empty()


func _make_note(id: String, content: String, rect: Rect2) -> void:
	var item: Control = CARD.new()
	item.set_meta(&"note_id", id)
	item.call(&"configure", id, content)
	item.position = rect.position
	item.size = rect.size
	item.connect(&"selected", _select)
	item.connect(&"manipulation_started", _start_drag)
	item.connect(&"remove_requested", _remove)
	item.connect(&"text_edited", _emit_changed)
	add_child(item)
	_items.append(item)
	_clamp(item)


func _select(item: Control) -> void:
	if is_instance_valid(_selected) and _selected != item:
		_selected.call(&"set_selected", false)
	_selected = item
	_selected.call(&"set_selected", true)
	_items.erase(item)
	_items.append(item)
	move_child(item, get_child_count() - 1)
	_emit_changed()


func _remove(item: Control) -> void:
	if not is_instance_valid(item):
		return
	if _selected == item:
		_selected = null
	if _drag_item == item:
		_drag_item = null
	_items.erase(item)
	remove_child(item)
	item.queue_free()
	_update_empty()
	_emit_changed()


func _start_drag(item: Control, mode: StringName) -> void:
	if not is_instance_valid(item):
		return
	_select(item)
	_drag_item = item
	_drag_mode = mode
	_drag_origin = get_local_mouse_position()
	_item_origin = item.position
	_size_origin = item.size


func _input(event: InputEvent) -> void:
	if not is_instance_valid(_drag_item):
		return
	if event is InputEventMouseMotion:
		var delta: Vector2 = get_local_mouse_position() - _drag_origin
		if _drag_mode == &"move":
			_drag_item.position = _item_origin + delta
		else:
			_drag_item.size = _size_origin + delta
		_clamp(_drag_item)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var release: InputEventMouseButton = event
		if release.button_index == MOUSE_BUTTON_LEFT and not release.pressed:
			_drag_item = null
			_drag_mode = &""
			_emit_changed()
			get_viewport().set_input_as_handled()


func _clamp(item: Control) -> void:
	if size.x < 1 or size.y < 1:
		return
	item.size = Vector2(clampf(item.size.x, MIN_SIZE.x, maxf(MIN_SIZE.x, size.x)), clampf(item.size.y, MIN_SIZE.y, maxf(MIN_SIZE.y, size.y)))
	item.position = Vector2(clampf(item.position.x, 0.0, maxf(0, size.x - item.size.x)), clampf(item.position.y, 36.0, maxf(36, size.y - item.size.y)))


func _clamp_all() -> void:
	for item in _items:
		if is_instance_valid(item):
			_clamp(item)


func _update_empty() -> void:
	_empty.visible = _items.is_empty()


func _emit_changed() -> void:
	if not _restoring:
		changed.emit()
