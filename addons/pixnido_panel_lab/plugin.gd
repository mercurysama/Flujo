@tool
extends EditorPlugin

## Isolated experiment: never modifies Flujo's existing dock or F4 behavior.

const PANEL_DOCK_SCRIPT := preload("res://addons/pixnido_panel_lab/panel_dock.gd")

var _pixnido_dock: EditorDock
var _references_dock: EditorDock
var _toolbar: HBoxContainer
var _pixnido_button: Button
var _references_button: Button

var _pixnido_open: bool = true
var _references_open: bool = false
var _swapped: bool = false


func _enter_tree() -> void:
	_pixnido_dock = PANEL_DOCK_SCRIPT.new()
	_pixnido_dock.call(&"configure", &"pixnido", EditorDock.DOCK_SLOT_LEFT_UL)
	_pixnido_dock.connect(&"close_requested", _close_pixnido)
	add_dock(_pixnido_dock)

	_references_dock = PANEL_DOCK_SCRIPT.new()
	_references_dock.call(&"configure", &"references", EditorDock.DOCK_SLOT_RIGHT_UR)
	_references_dock.connect(&"close_requested", _close_references)
	add_dock(_references_dock)

	_build_toolbar()
	_apply_visibility.call_deferred()


func _exit_tree() -> void:
	if is_instance_valid(_toolbar):
		remove_control_from_container(EditorPlugin.CONTAINER_TOOLBAR, _toolbar)
		_toolbar.queue_free()
	_toolbar = null
	_pixnido_button = null
	_references_button = null

	if is_instance_valid(_references_dock):
		remove_dock(_references_dock)
		_references_dock.queue_free()
	_references_dock = null

	if is_instance_valid(_pixnido_dock):
		remove_dock(_pixnido_dock)
		_pixnido_dock.queue_free()
	_pixnido_dock = null


func _build_toolbar() -> void:
	_toolbar = HBoxContainer.new()
	_toolbar.name = "PixNidoPanelToolbar"

	_pixnido_button = _make_button(&"Sprite2D", "▦", "Show / hide PixNido")
	_pixnido_button.toggle_mode = true
	_pixnido_button.button_pressed = _pixnido_open
	_pixnido_button.pressed.connect(_toggle_pixnido)
	_toolbar.add_child(_pixnido_button)

	var swap_button: Button = _make_button(&"Reload", "⇄", "Swap left / right")
	swap_button.pressed.connect(_swap_sides)
	_toolbar.add_child(swap_button)

	_references_button = _make_button(&"Texture2D", "▧", "Show / hide references")
	_references_button.toggle_mode = true
	_references_button.button_pressed = _references_open
	_references_button.pressed.connect(_toggle_references)
	_toolbar.add_child(_references_button)

	add_control_to_container(EditorPlugin.CONTAINER_TOOLBAR, _toolbar)


func _make_button(icon_id: StringName, fallback: String, hint: String) -> Button:
	var button := Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_ALL
	button.tooltip_text = hint
	button.custom_minimum_size = Vector2(32, 30)

	var editor_theme: Theme = EditorInterface.get_editor_theme()
	if editor_theme != null and editor_theme.has_icon(icon_id, &"EditorIcons"):
		button.icon = editor_theme.get_icon(icon_id, &"EditorIcons")
	else:
		button.text = fallback
	return button


func _toggle_pixnido() -> void:
	_pixnido_open = not _pixnido_open
	_set_dock_visible(_pixnido_dock, _pixnido_open)
	_sync_button_states()


func _toggle_references() -> void:
	_references_open = not _references_open
	_set_dock_visible(_references_dock, _references_open)
	_sync_button_states()


func _close_pixnido() -> void:
	_pixnido_open = false
	_set_dock_visible(_pixnido_dock, false)
	_sync_button_states()


func _close_references() -> void:
	_references_open = false
	_set_dock_visible(_references_dock, false)
	_sync_button_states()


func _swap_sides() -> void:
	if not is_instance_valid(_pixnido_dock) or not is_instance_valid(_references_dock):
		return

	# EditorDock has no public live slot setter. Re-registering resets to default_slot.
	_pixnido_dock.close()
	_references_dock.close()
	remove_dock(_pixnido_dock)
	remove_dock(_references_dock)
	_swapped = not _swapped

	_pixnido_dock.default_slot = (
		EditorDock.DOCK_SLOT_RIGHT_UR if _swapped else EditorDock.DOCK_SLOT_LEFT_UL
	)
	_references_dock.default_slot = (
		EditorDock.DOCK_SLOT_LEFT_UL if _swapped else EditorDock.DOCK_SLOT_RIGHT_UR
	)

	add_dock(_pixnido_dock)
	add_dock(_references_dock)
	_apply_visibility.call_deferred()


func _apply_visibility() -> void:
	if not is_instance_valid(_pixnido_dock) or not is_instance_valid(_references_dock):
		return
	_set_dock_visible(_references_dock, _references_open)
	_set_dock_visible(_pixnido_dock, _pixnido_open)
	_sync_button_states()


func _set_dock_visible(dock: EditorDock, should_show: bool) -> void:
	if not is_instance_valid(dock):
		return
	if should_show:
		dock.make_visible()
	else:
		dock.close()


func _sync_button_states() -> void:
	if is_instance_valid(_pixnido_button):
		_pixnido_button.button_pressed = _pixnido_open
	if is_instance_valid(_references_button):
		_references_button.button_pressed = _references_open
