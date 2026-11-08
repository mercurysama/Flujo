@tool
extends Control

## Per-project reference image canvas. File bytes remain at their original paths.

signal changed

const ITEM_SCRIPT := preload("res://addons/pixnido_panel_lab/reference_item.gd")
const STATE_VERSION: int = 1
const MAX_IMAGE_BYTES: int = 32 * 1024 * 1024
const MAX_TEXTURE_EDGE: int = 4096
const MIN_ITEM_SIZE: Vector2 = Vector2(96.0, 80.0)

var _items: Array[Control] = []
var _empty: Label
var _next_id: int = 1
var _selected: Control
var _drag_item: Control
var _drag_mode: StringName = &""
var _start_pointer: Vector2
var _start_position: Vector2
var _start_size: Vector2
var _restoring: bool = false


func _init() -> void:
	name = "ReferenceCanvas"
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(180.0, 140.0)

	_empty = Label.new()
	_empty.name = "EmptyMessage"
	_empty.text = "Add reference images using +"
	_empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_empty)
	_empty.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(_clamp_all_items)


func add_paths(paths: PackedStringArray) -> void:
	var added: bool = false
	for raw_path in paths:
		var path: String = _normalize_path(raw_path)
		if not _is_image_path(path):
			push_warning("PixNido Panel Lab: Unsupported reference: " + raw_path)
			continue
		var image_id: String = "ref_" + str(_next_id)
		_next_id += 1
		var offset: float = float(_items.size() % 5) * 18.0
		var rect := Rect2(Vector2(12.0 + offset, 12.0 + offset), Vector2(210.0, 160.0))
		_create_item(image_id, path, rect)
		added = true

	if added:
		_update_empty()
		_changed()


func get_layout_state() -> Dictionary:
	var entries: Array[Dictionary] = []
	for item in _items:
		if not is_instance_valid(item):
			continue
		entries.append({
			"id": String(item.get_meta(&"reference_id", "")),
			"path": String(item.get_meta(&"source_path", "")),
			"x": item.position.x,
			"y": item.position.y,
			"w": item.size.x,
			"h": item.size.y,
		})
	return {"version": STATE_VERSION, "next_id": _next_id, "items": entries}


func set_layout_state(state: Dictionary) -> void:
	if int(state.get("version", STATE_VERSION)) != STATE_VERSION:
		push_warning("PixNido Panel Lab: Unknown reference layout version.")
		return
	_restoring = true
	_drag_item = null
	_selected = null
	for item in _items:
		remove_child(item)
		item.queue_free()
	_items.clear()
	_next_id = 1

	var serialized: Variant = state.get("items", [])
	if serialized is Array:
		for record in serialized:
			if not record is Dictionary:
				continue
			var entry: Dictionary = record
			var image_id: String = str(entry.get("id", ""))
			var path: String = str(entry.get("path", ""))
			if image_id.is_empty() or not _is_image_path(path):
				continue
			var rect := Rect2(
				Vector2(float(entry.get("x", 0.0)), float(entry.get("y", 0.0))),
				Vector2(float(entry.get("w", 210.0)), float(entry.get("h", 160.0)))
			)
			_create_item(image_id, path, rect)

	_next_id = maxi(_next_id, int(state.get("next_id", 1)))
	for item in _items:
		var current_id: String = str(item.get_meta(&"reference_id", ""))
		if current_id.begins_with("ref_"):
			_next_id = maxi(_next_id, int(current_id.trim_prefix("ref_")) + 1)
	_update_empty()
	_restoring = false
	_clamp_all_items()


func _create_item(image_id: String, path: String, dimensions: Rect2) -> void:
	var item: Control = ITEM_SCRIPT.new()
	item.name = "ImageReference_" + image_id
	item.set_meta(&"reference_id", image_id)
	item.set_meta(&"source_path", path)
	item.position = dimensions.position
	item.size = Vector2(maxf(dimensions.size.x, MIN_ITEM_SIZE.x), maxf(dimensions.size.y, MIN_ITEM_SIZE.y))
	add_child(item)

	var texture: Texture2D = _read_texture(path)
	item.call(&"configure", image_id, path, texture)
	item.connect(&"selected", _select_item)
	item.connect(&"remove_requested", _remove_item)
	item.connect(&"manipulation_started", _start_drag)
	_items.append(item)
	_clamp_item(item)
	if not _restoring:
		_select_item(item)


func _normalize_path(path: String) -> String:
	if path.begins_with("res://"):
		return path
	return ProjectSettings.localize_path(path)


func _is_image_path(path: String) -> bool:
	var ext: String = path.get_extension().to_lower()
	return ext in ["png", "jpg", "jpeg", "webp", "bmp"]


func _read_texture(path: String) -> Texture2D:
	var disk_path: String = ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	if not FileAccess.file_exists(disk_path):
		push_warning("PixNido Panel Lab: Reference file not found: " + path)
		return null
	var file: FileAccess = FileAccess.open(disk_path, FileAccess.READ)
	if file == null:
		push_warning("PixNido Panel Lab: Cannot read reference: " + path)
		return null
	var file_size: int = file.get_length()
	file.close()
	if file_size > MAX_IMAGE_BYTES:
		push_warning("PixNido Panel Lab: Reference exceeds 32 MiB: " + path)
		return null

	var image := Image.new()
	var result: Error = image.load(disk_path)
	if result != OK or image.is_empty():
		push_warning("PixNido Panel Lab: Unsupported or corrupted image: " + path)
		return null
	var longest: int = maxi(image.get_width(), image.get_height())
	if longest > MAX_TEXTURE_EDGE:
		var scale: float = float(MAX_TEXTURE_EDGE) / float(longest)
		image.resize(maxi(1, roundi(image.get_width() * scale)), maxi(1, roundi(image.get_height() * scale)), Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(image)


func _select_item(item: Control) -> void:
	if not is_instance_valid(item):
		return
	if is_instance_valid(_selected) and _selected != item:
		_selected.call(&"set_selected", false)
	_selected = item
	item.call(&"set_selected", true)
	_items.erase(item)
	_items.append(item)
	move_child(item, get_child_count() - 1)
	_changed()


func _remove_item(item: Control) -> void:
	if not is_instance_valid(item):
		return
	if _drag_item == item:
		_drag_item = null
	if _selected == item:
		_selected = null
	_items.erase(item)
	remove_child(item)
	item.queue_free()
	_update_empty()
	_changed()


func _start_drag(item: Control, mode: StringName) -> void:
	if not is_instance_valid(item):
		return
	_select_item(item)
	_drag_item = item
	_drag_mode = mode
	_start_pointer = get_local_mouse_position()
	_start_position = item.position
	_start_size = item.size


func _input(event: InputEvent) -> void:
	if not is_instance_valid(_drag_item):
		return
	if event is InputEventMouseMotion:
		var delta: Vector2 = get_local_mouse_position() - _start_pointer
		if _drag_mode == &"move":
			_drag_item.position = _start_position + delta
		elif _drag_mode == &"resize":
			_drag_item.size = _start_size + delta
		_clamp_item(_drag_item)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click.button_index == MOUSE_BUTTON_LEFT and not click.pressed:
			_drag_item = null
			_drag_mode = &""
			_changed()
			get_viewport().set_input_as_handled()


func _clamp_item(item: Control) -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var max_size := Vector2(maxf(size.x, MIN_ITEM_SIZE.x), maxf(size.y, MIN_ITEM_SIZE.y))
	item.size = Vector2(
		clampf(item.size.x, MIN_ITEM_SIZE.x, max_size.x),
		clampf(item.size.y, MIN_ITEM_SIZE.y, max_size.y)
	)
	item.position = Vector2(
		clampf(item.position.x, 0.0, maxf(0.0, size.x - item.size.x)),
		clampf(item.position.y, 0.0, maxf(0.0, size.y - item.size.y))
	)


func _clamp_all_items() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	for item in _items:
		if is_instance_valid(item):
			_clamp_item(item)


func _update_empty() -> void:
	_empty.visible = _items.is_empty()


func _changed() -> void:
	if not _restoring:
		changed.emit()
