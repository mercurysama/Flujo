@tool
extends VBoxContainer

## Optional HTML5 host. The native godot-servo addon is installed separately.
## Importantly, this script never statically references ServoWebView.

signal source_changed(new_source: String)
signal export_directory_changed

const DEFAULT_SOURCE: String = "https://pixnido.pages.dev/"
const SERVO_SCRIPT_PATH: String = "res://addons/godot_servo/servo_texture_rect.gd"
const SERVO_CURSORS_PATH: String = "res://addons/godot_servo/cursors.gd"
const EXPORT_BRIDGE_PATH: String = "res://addons/pixnido_panel_lab/pixnido_export_bridge.js"
const WRITER := preload("res://addons/pixnido_panel_lab/sprite_export_writer.gd")
const CHUNK_SIZE: int = 8192
const MAX_LENGTH: int = 44739248
const MAX_PARTS: int = 5462
const TIMEOUT_MS: int = 120000

var _source_field: LineEdit
var _open_button: Button
var _save_button: Button
var _folder_button: Button
var _folder_dialog: EditorFileDialog
var _export_directory: String = "res://assets/sprites/"
var _transfer_token: String = ""
var _last_progress_at: int = 0
var _expected_length: int = -1
var _expected_parts: int = -1
var _length_received: int = 0
var _received: PackedStringArray = PackedStringArray()
var _stem: String = ""
var _mime: String = ""
var _destination_snapshot: String = ""
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
	_apply_icon(_save_button, &"Save", "↓")
	_apply_icon(_folder_button, &"Folder", "▱")


func _process(_delta: float) -> void:
	if not _transfer_token.is_empty() and Time.get_ticks_msec() - _last_progress_at > TIMEOUT_MS:
		_abort_transfer("Export timed out without writing any file.")


func set_source(source: String) -> void:
	if is_instance_valid(_source_field):
		_source_field.text = source


func get_source() -> String:
	return _source_field.text.strip_edges() if is_instance_valid(_source_field) else DEFAULT_SOURCE


func get_export_directory() -> String:
	return _export_directory


func set_export_directory(directory: String) -> void:
	if WRITER.valid_directory(directory):
		_export_directory = directory
		if is_instance_valid(_folder_button):
			_folder_button.tooltip_text = "Output folder: " + directory


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

	_save_button = Button.new()
	_save_button.name = "SaveSpriteInGodot"
	_save_button.flat = true
	_save_button.focus_mode = Control.FOCUS_ALL
	_save_button.tooltip_text = "Save PixNido export preview inside the Godot project"
	_save_button.custom_minimum_size = Vector2(30, 30)
	_save_button.pressed.connect(_request_export)
	address_row.add_child(_save_button)

	_folder_button = Button.new()
	_folder_button.name = "SpriteOutputFolder"
	_folder_button.flat = true
	_folder_button.focus_mode = Control.FOCUS_ALL
	_folder_button.tooltip_text = "Output folder: res://assets/sprites/"
	_folder_button.custom_minimum_size = Vector2(30, 30)
	_folder_button.pressed.connect(_choose_directory)
	address_row.add_child(_folder_button)

	_folder_dialog = EditorFileDialog.new()
	_folder_dialog.name = "SpriteFolderPicker"
	_folder_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	_folder_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_folder_dialog.dir_selected.connect(_on_directory_selected)
	add_child(_folder_dialog)

	_status = Label.new()
	_status.name = "BrowserStatus"
	_status.text = "Open PixNido, export a PNG/WebP preview, then click Save. Default: res://assets/sprites/"
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


func _choose_directory() -> void:
	_folder_dialog.current_dir = "res://"
	_folder_dialog.popup_centered_ratio(0.7)


func _on_directory_selected(directory: String) -> void:
	if not WRITER.valid_directory(directory):
		_set_status("Select a directory inside the Godot project.", true)
		return
	set_export_directory(directory)
	export_directory_changed.emit()
	_set_status("Destination: " + directory, false)


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

	browser.connect(&"load_finished", _on_browser_loaded)
	browser.connect(&"bridge_event", _on_bridge_event)
	browser.connect(&"crashed", _on_browser_crashed)
	_view_area.add_child(viewer)
	viewer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view_area.add_child(browser)
	viewer.gui_input.connect(_on_viewer_input.bind(viewer))
	_viewer = viewer
	_browser = browser
	_set_status("PixNido loaded; test drawing and keyboard/touch input in Godot.", false)


func _on_browser_loaded() -> void:
	if not is_instance_valid(_browser):
		return
	var script: String = FileAccess.get_file_as_string(EXPORT_BRIDGE_PATH)
	if script.is_empty():
		_set_status("Export bridge script could not be read.", true)
		return
	_browser.call(&"evaluate_javascript", script)
	_set_status("PixNido loaded. Export a sprite there, then click Save to " + _export_directory, false)


func _request_export() -> void:
	if not is_instance_valid(_browser):
		_set_status("Open PixNido and export an image first.", true)
		return
	if not _transfer_token.is_empty():
		_set_status("Another sprite is currently transferring.", true)
		return
	if not WRITER.valid_directory(_export_directory):
		_set_status("Choose an output directory inside this Godot project.", true)
		return
	var crypto := Crypto.new()
	_transfer_token = Marshalls.raw_to_base64(crypto.generate_random_bytes(16))
	_last_progress_at = Time.get_ticks_msec()
	_expected_length = -1
	_expected_parts = -1
	_length_received = 0
	_received.clear()
	_stem = ""
	_mime = ""
	_destination_snapshot = _export_directory
	var token_js: String = JSON.stringify(_transfer_token)
	var js: String = "if(window.__pixnidoGodotExportV1){window.__pixnidoGodotExportV1.start(" + token_js + ");}else if(window.godot){window.godot.emit('pixnido.export.error',{token:" + token_js + ",message:'Export bridge not ready; reload PixNido.'});}"
	_browser.call(&"evaluate_javascript", js)
	_set_status("Transferring PixNido export preview…", false)


func _on_bridge_event(name: String, message: String) -> void:
	if _transfer_token.is_empty() or not name.begins_with("pixnido.export."):
		return
	var decoded: Variant = JSON.parse_string(message)
	if not decoded is Dictionary:
		return
	var packet: Dictionary = decoded
	if String(packet.get("token", "")) != _transfer_token:
		return
	match name:
		"pixnido.export.error":
			_abort_transfer(String(packet.get("message", "Export failed.")))
		"pixnido.export.begin":
			if _expected_parts != -1:
				_abort_transfer("Repeated export start was rejected.")
				return
			var length: int = int(packet.get("length", -1))
			var count: int = int(packet.get("count", -1))
			var mime: String = String(packet.get("mime", ""))
			if length < 1 or length > MAX_LENGTH or count < 1 or count > MAX_PARTS or count != ceili(float(length) / float(CHUNK_SIZE)):
				_abort_transfer("Invalid image size or fragment count.")
				return
			if mime != "image/png" and mime != "image/webp":
				_abort_transfer("Only PNG and WebP exports are supported.")
				return
			_expected_length = length
			_expected_parts = count
			_stem = String(packet.get("stem", "sprite"))
			_mime = mime
			_request_chunk(0)
		"pixnido.export.chunk":
			if _expected_parts < 1:
				return
			var index: int = int(packet.get("index", -1))
			var chunk: String = String(packet.get("data", ""))
			if index != _received.size() or chunk.is_empty() or chunk.length() > CHUNK_SIZE or _length_received + chunk.length() > _expected_length:
				_abort_transfer("Invalid or out-of-order export fragment.")
				return
			_received.append(chunk)
			_length_received += chunk.length()
			_last_progress_at = Time.get_ticks_msec()
			_request_chunk(_received.size())
		"pixnido.export.end":
			if _expected_parts < 1 or _received.size() != _expected_parts or _length_received != _expected_length:
				_abort_transfer("Export was incomplete. Nothing was written.")
				return
			var encoded: String = "".join(_received)
			var result: Dictionary = WRITER.write_base64(encoded, _mime, _stem, _destination_snapshot)
			_reset_transfer()
			if bool(result.get("ok", false)):
				var filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
				if filesystem != null:
					filesystem.scan()
				_set_status("Saved: " + String(result.get("path", "")), false)
			else:
				_set_status(String(result.get("message", "Unable to save the sprite.")), true)


func _request_chunk(index: int) -> void:
	if not is_instance_valid(_browser):
		return
	var script: String = "window.__pixnidoGodotExportV1 && window.__pixnidoGodotExportV1.next(" + JSON.stringify(_transfer_token) + "," + str(index) + ");"
	_browser.call_deferred(&"evaluate_javascript", script)


func _abort_transfer(message: String) -> void:
	if is_instance_valid(_browser) and not _transfer_token.is_empty():
		var script: String = "window.__pixnidoGodotExportV1 && window.__pixnidoGodotExportV1.cancel(" + JSON.stringify(_transfer_token) + ");"
		_browser.call_deferred(&"evaluate_javascript", script)
	_reset_transfer()
	_set_status(message, true)


func _reset_transfer() -> void:
	_transfer_token = ""
	_expected_length = -1
	_expected_parts = -1
	_length_received = 0
	_received.clear()
	_stem = ""
	_mime = ""
	_destination_snapshot = ""


func _on_browser_crashed(reason: String) -> void:
	_reset_transfer()
	_set_status("Servo browser crashed: " + reason, true)


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
	_reset_transfer()
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
