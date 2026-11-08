@tool
extends VBoxContainer

## Optional HTML5 host. The native godot-servo addon is installed separately.
## Importantly, this script never statically references ServoWebView.

signal source_changed(new_source: String)

const DEFAULT_SOURCE: String = "https://pixnido.pages.dev/"
const SERVO_SCRIPT_PATH: String = "res://addons/godot_servo/servo_texture_rect.gd"
const SERVO_CURSORS_PATH: String = "res://addons/godot_servo/cursors.gd"

var _source_field: LineEdit
var _open_button: Button
var _status: Label
var _view_area: Control
var _viewer: TextureRect
var _browser: Node


func _init() -> void:
	name = "PixNidoHTML5Host"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 5)
	_build_ui()


func _ready() -> void:
	_apply_icon(_open_button, &"Play", "▶")


func set_source(source: String) -> void:
	if is_instance_valid(_source_field):
		_source_field.text = source


func get_source() -> String:
	return _source_field.text.strip_edges() if is_instance_valid(_source_field) else DEFAULT_SOURCE


func _build_ui() -> void:
	var address_row := HBoxContainer.new()
	address_row.name = "BrowserAddress"
	add_child(address_row)

	_source_field = LineEdit.new()
	_source_field.name = "PixNidoSource"
	_source_field.text = DEFAULT_SOURCE
	_source_field.placeholder_text = "https:// or res://.../index.html"
	_source_field.tooltip_text = "PixNido HTML5 address (remote HTTPS or project-local HTML)"
	_source_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_source_field.clear_button_enabled = true
	_source_field.text_changed.connect(_source_edited)
	_source_field.text_submitted.connect(_on_source_submitted)
	address_row.add_child(_source_field)

	_open_button = Button.new()
	_open_button.name = "OpenPixNido"
	_open_button.flat = true
	_open_button.tooltip_text = "Open PixNido HTML5 (requires godot-servo)"
	_open_button.custom_minimum_size = Vector2(30.0, 30.0)
	_open_button.pressed.connect(_open_source)
	address_row.add_child(_open_button)

	_status = Label.new()
	_status.name = "BrowserStatus"
	_status.text = "Select Open to load PixNido. Native godot-servo is optional."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_status)

	_view_area = Control.new()
	_view_area.name = "WebSurface"
	_view_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_view_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_view_area.custom_minimum_size = Vector2(160.0, 140.0)
	_view_area.clip_contents = true
	add_child(_view_area)


func _apply_icon(button: Button, icon_id: StringName, fallback: String) -> void:
	var editor_theme: Theme = EditorInterface.get_editor_theme()
	if editor_theme != null and editor_theme.has_icon(icon_id, &"EditorIcons"):
		button.icon = editor_theme.get_icon(icon_id, &"EditorIcons")
	else:
		button.text = fallback


func _source_edited(value: String) -> void:
	source_changed.emit(value)


func _on_source_submitted(_value: String) -> void:
	_open_source()


func _open_source() -> void:
	var source: String = get_source()
	var target_url: String = _validated_url(source)
	if target_url.is_empty():
		return
	if not ClassDB.class_exists(&"ServoWebView"):
		_set_status("godot-servo is not installed. Install its GDExtension first; no network request was made.", true)
		return
	if not ResourceLoader.exists(SERVO_SCRIPT_PATH) or not ResourceLoader.exists(SERVO_CURSORS_PATH):
		_set_status("The godot-servo TextureRect adapter is missing. Copy the complete addons/godot_servo/ folder.", true)
		return

	# Loading the adapter only after native registration prevents parse failures
	# when users open this experimental plugin without installing godot-servo.
	var adapter: Script = load(SERVO_SCRIPT_PATH) as Script
	if adapter == null:
		_set_status("Could not load the godot-servo TextureRect adapter.", true)
		return
	var native_object: Object = ClassDB.instantiate(&"ServoWebView")
	if not native_object is Node:
		_set_status("Could not create the native ServoWebView.", true)
		if native_object != null:
			native_object.free()
		return

	_clear_current_browser()

	var browser: Node = native_object as Node
	browser.name = "PixNidoServoWebView"
	var initial_width: int = maxi(320, roundi(_view_area.size.x))
	var initial_height: int = maxi(240, roundi(_view_area.size.y))
	browser.set(&"view_size", Vector2i(initial_width, initial_height))
	browser.set(&"url", target_url)

	var viewer := TextureRect.new()
	viewer.name = "PixNidoServoTexture"
	viewer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	viewer.stretch_mode = TextureRect.STRETCH_SCALE
	viewer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewer.mouse_filter = Control.MOUSE_FILTER_STOP
	viewer.focus_mode = Control.FOCUS_ALL
	viewer.set_script(adapter)
	viewer.set(&"browser", browser)

	_view_area.add_child(viewer)
	viewer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view_area.add_child(browser)
	viewer.gui_input.connect(_on_viewer_input.bind(viewer))
	_viewer = viewer
	_browser = browser
	_set_status("PixNido loaded; test drawing and keyboard/touch input in Godot.", false)


func _validated_url(source: String) -> String:
	if source.begins_with("https://"):
		return source
	if source.begins_with("res://") and source.get_extension().to_lower() == "html":
		if not FileAccess.file_exists(source):
			_set_status("Local HTML page not found: " + source, true)
			return ""
		var absolute: String = ProjectSettings.globalize_path(source)
		return "file:///" + absolute.replace("\\", "/").trim_prefix("/")
	_set_status("Use an HTTPS URL or a project-local res://.../index.html page.", true)
	return ""


func _on_viewer_input(event: InputEvent, viewer: TextureRect) -> void:
	if not is_instance_valid(viewer):
		return
	if event is InputEventMouseButton:
		var click: InputEventMouseButton = event as InputEventMouseButton
		if click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
			viewer.grab_focus()


func _clear_current_browser() -> void:
	# Servo's multiple simultaneous views are not validated; free the old view
	# before installing a replacement, instead of queueing an overlapping view.
	if is_instance_valid(_viewer):
		_viewer.free()
	_viewer = null
	if is_instance_valid(_browser):
		_browser.free()
	_browser = null


func _exit_tree() -> void:
	_clear_current_browser()


func _set_status(message: String, failure: bool) -> void:
	_status.text = message
	if failure:
		push_warning("PixNido Panel Lab: " + message)
