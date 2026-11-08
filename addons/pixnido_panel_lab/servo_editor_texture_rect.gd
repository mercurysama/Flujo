@tool
extends TextureRect

## Editor-running adapter for ServoWebView. The upstream texture adapter is
## designed for scene runtime, so this independent script is marked @tool.
## Deliberately type the browser as Node to keep the native addon optional.

const RESIZE_SETTLE_FRAMES: int = 10
const EXTERNAL_SHADER: String = "res://addons/godot_servo/servo_external_canvas.gdshader"
const CURSORS_HELPER: String = "res://addons/godot_servo/cursors.gd"

var browser: Node
var _bound: Texture2D
var _resize_countdown: int = 0


func _ready() -> void:
	if not is_instance_valid(browser):
		push_warning("PixNido: a Servo browser must be assigned to the texture.")
		return
	browser.connect(&"frame_updated", _update_texture)
	browser.connect(&"ime_requested", _on_ime_requested)
	browser.connect(&"cursor_changed", _on_cursor_changed)
	gui_input.connect(_forward_input)
	mouse_exited.connect(_on_pointer_left)
	resized.connect(_on_resized)
	_on_resized()


func _exit_tree() -> void:
	if is_instance_valid(browser):
		if browser.is_connected(&"frame_updated", _update_texture):
			browser.disconnect(&"frame_updated", _update_texture)
		if browser.is_connected(&"ime_requested", _on_ime_requested):
			browser.disconnect(&"ime_requested", _on_ime_requested)
		if browser.is_connected(&"cursor_changed", _on_cursor_changed):
			browser.disconnect(&"cursor_changed", _on_cursor_changed)


func _process(_delta: float) -> void:
	if _resize_countdown <= 0 or not is_instance_valid(browser):
		return
	_resize_countdown -= 1
	if _resize_countdown == 0 and size.x >= 1.0 and size.y >= 1.0:
		browser.call(&"set_view_size_px", Vector2i(size))
		_bound = null


func _on_resized() -> void:
	_resize_countdown = RESIZE_SETTLE_FRAMES


func _to_view_pixels(local: Vector2) -> Vector2:
	if size.x < 1.0 or size.y < 1.0 or not is_instance_valid(browser):
		return Vector2.ZERO
	var view: Vector2i = browser.get(&"view_size")
	return local * (Vector2(view) / size)


func _forward_input(event: InputEvent) -> void:
	if not is_instance_valid(browser):
		return
	if event is InputEventKey:
		browser.call(&"feed_input", event, Vector2.ZERO)
		accept_event()
		return
	var point := Vector2.ZERO
	if event is InputEventMouse:
		point = (event as InputEventMouse).position
	elif event is InputEventScreenTouch:
		point = (event as InputEventScreenTouch).position
	elif event is InputEventScreenDrag:
		point = (event as InputEventScreenDrag).position
	else:
		return
	browser.call(&"feed_input", event, _to_view_pixels(point))


func _on_pointer_left() -> void:
	if is_instance_valid(browser):
		browser.call(&"notify_pointer_left")


func _on_ime_requested(caret: Rect2, _multiline: bool) -> void:
	if not is_instance_valid(browser):
		return
	var view: Vector2i = browser.get(&"view_size")
	if view.x <= 0 or view.y <= 0:
		return
	var bottom_left: Vector2 = caret.position + Vector2(0.0, caret.size.y)
	var screen_point: Vector2 = global_position + bottom_left * (size / Vector2(view))
	browser.set(&"ime_anchor", screen_point)


func _on_cursor_changed(shape: String) -> void:
	if not ResourceLoader.exists(CURSORS_HELPER):
		return
	var helper: Script = load(CURSORS_HELPER) as Script
	if helper != null:
		mouse_default_cursor_shape = int(helper.call(&"godot_shape", shape)) as Control.CursorShape


func _update_texture() -> void:
	if not is_instance_valid(browser):
		return
	var current: Texture2D = browser.call(&"get_texture") as Texture2D
	if current == null or current == _bound:
		return
	_bound = current
	texture = current
	flip_v = bool(browser.call(&"is_texture_flipped_v"))
	if bool(browser.call(&"needs_external_sampler")):
		if ResourceLoader.exists(EXTERNAL_SHADER):
			var shader: Shader = load(EXTERNAL_SHADER) as Shader
			if shader != null:
				var shader_material := ShaderMaterial.new()
				shader_material.shader = shader
				shader_material.set_shader_parameter("servo_texture", current)
				material = shader_material
	else:
		material = null
