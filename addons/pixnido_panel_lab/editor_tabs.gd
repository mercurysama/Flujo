@tool
extends TabContainer

## NidoLab editor registry: PixNido is the first tab, future editors are added
## independently. Reparent this entire TabContainer in Focus mode, not its
## children, so browser instances and editor state remain intact.

signal active_editor_changed(editor_id: StringName)

const PIXNIDO_HOST := preload("res://addons/pixnido_panel_lab/pixnido_servo_host.gd")
const PIXNIDO_ID: StringName = &"pixnido"

var _editor_ids: Array[StringName] = []
var _editor_controls: Dictionary = {}
var _icons: Dictionary = {}
var _tooltips: Dictionary = {}
var _pixnido_host: Control


func _init() -> void:
	name = "NidoLabEditorTabs"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs_visible = true
	_pixnido_host = PIXNIDO_HOST.new()
	_pixnido_host.name = "PixNidoEditor"
	register_editor(PIXNIDO_ID, _pixnido_host, &"Sprite2D", "PixNido — pixel art editor")
	current_tab = 0
	tab_changed.connect(_on_tab_changed)


func _ready() -> void:
	for index in range(_editor_ids.size()):
		_apply_icon(index)


func register_editor(editor_id: StringName, content: Control, icon_id: StringName, tooltip: String) -> bool:
	if editor_id.is_empty() or _editor_controls.has(editor_id):
		return false
	if not is_instance_valid(content) or content.get_parent() != null:
		return false
	_editor_ids.append(editor_id)
	_editor_controls[editor_id] = content
	_icons[editor_id] = icon_id
	_tooltips[editor_id] = tooltip
	add_child(content)
	var index: int = _editor_ids.size() - 1
	set_tab_title(index, "")
	set_tab_tooltip(index, tooltip)
	if is_inside_tree():
		_apply_icon(index)
	return true


func get_pixnido_host() -> Control:
	return _pixnido_host


func get_active_editor_id() -> StringName:
	if current_tab < 0 or current_tab >= _editor_ids.size():
		return PIXNIDO_ID
	return _editor_ids[current_tab]


func set_active_editor_id(editor_id: StringName) -> void:
	var index: int = _editor_ids.find(editor_id)
	if index >= 0:
		current_tab = index


func get_registered_ids() -> Array[StringName]:
	return _editor_ids.duplicate()


func _on_tab_changed(_index: int) -> void:
	active_editor_changed.emit(get_active_editor_id())


func _apply_icon(index: int) -> void:
	var editor_id: StringName = _editor_ids[index]
	var icon_name: StringName = _icons[editor_id]
	var icon: Texture2D
	if Engine.is_editor_hint():
		var theme: Theme = EditorInterface.get_editor_theme()
		if theme != null and theme.has_icon(icon_name, &"EditorIcons"):
			icon = theme.get_icon(icon_name, &"EditorIcons")
	if icon == null:
		icon = _fallback_icon()
	set_tab_icon(index, icon)
	set_tab_title(index, "")
	set_tab_tooltip(index, String(_tooltips[editor_id]))


func _fallback_icon() -> Texture2D:
	var pixels := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.TRANSPARENT)
	for y in range(2, 14):
		for x in range(2, 14):
			if x == 2 or x == 13 or y == 2 or y == 13:
				pixels.set_pixel(x, y, Color(0.75, 0.85, 0.96))
			elif (x + y) % 4 < 2:
				pixels.set_pixel(x, y, Color(0.25, 0.55, 0.9))
	return ImageTexture.create_from_image(pixels)
