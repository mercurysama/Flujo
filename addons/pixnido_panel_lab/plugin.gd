@tool
extends EditorPlugin

## Isolated experiment: never modifies Flujo's existing dock or F4 behavior.

const PANEL_DOCK_SCRIPT := preload("res://addons/pixnido_panel_lab/panel_dock.gd")
const FOCUS_WORKSPACE_SCRIPT := preload("res://addons/pixnido_panel_lab/focus_workspace.gd")
const LAYOUT_SECTION: String = "PixNidoPanelLab"

var _pixnido_dock: EditorDock
var _references_dock: EditorDock
var _toolbar: HBoxContainer
var _pixnido_button: Button
var _references_button: Button
var _focus_button: Button
var _focus_workspace: Control

var _pixnido_open: bool = true
var _references_open: bool = false
var _swapped: bool = false
var _registered_swapped: bool = false
var _reference_state: Dictionary = {"version": 1, "next_id": 1, "items": []}
var _notes_state: Dictionary = {"version": 1, "next_id": 1, "items": []}
var _tasks_state: Dictionary = {"version": 1, "next_id": 1, "items": []}
var _references_tab: int = 0
var _pixnido_source: String = "https://pixnido.pages.dev/"
var _pixnido_export_directory: String = "res://assets/sprites/"


func _get_window_layout(configuration: ConfigFile) -> void:
	configuration.set_value(LAYOUT_SECTION, "pixnido_open", _pixnido_open)
	configuration.set_value(LAYOUT_SECTION, "references_open", _references_open)
	configuration.set_value(LAYOUT_SECTION, "swapped", _swapped)
	if is_instance_valid(_references_dock):
		_reference_state = _references_dock.call(&"get_references_state")
		var extras: Dictionary = _references_dock.call(&"get_references_extras")
		_notes_state = extras.get("notes", _notes_state)
		_tasks_state = extras.get("tasks", _tasks_state)
		_references_tab = int(extras.get("tab", _references_tab))
	configuration.set_value(LAYOUT_SECTION, "reference_images", _reference_state)
	configuration.set_value(LAYOUT_SECTION, "reference_notes", _notes_state)
	configuration.set_value(LAYOUT_SECTION, "reference_tasks", _tasks_state)
	configuration.set_value(LAYOUT_SECTION, "references_tab", _references_tab)
	if is_instance_valid(_pixnido_dock):
		_pixnido_source = String(_pixnido_dock.call(&"get_pixnido_source"))
	configuration.set_value(LAYOUT_SECTION, "pixnido_source", _pixnido_source)
	if is_instance_valid(_pixnido_dock):
		_pixnido_export_directory = String(_pixnido_dock.call(&"get_pixnido_export_directory"))
	configuration.set_value(LAYOUT_SECTION, "pixnido_export_directory", _pixnido_export_directory)


func _set_window_layout(configuration: ConfigFile) -> void:
	_pixnido_open = bool(configuration.get_value(LAYOUT_SECTION, "pixnido_open", true))
	_references_open = bool(configuration.get_value(LAYOUT_SECTION, "references_open", false))
	_swapped = bool(configuration.get_value(LAYOUT_SECTION, "swapped", false))
	_pixnido_source = String(configuration.get_value(LAYOUT_SECTION, "pixnido_source", "https://pixnido.pages.dev/"))
	_pixnido_export_directory = String(configuration.get_value(LAYOUT_SECTION, "pixnido_export_directory", "res://assets/sprites/"))
	if is_instance_valid(_pixnido_dock):
		_pixnido_dock.call(&"set_pixnido_source", _pixnido_source)
		_pixnido_dock.call(&"set_pixnido_export_directory", _pixnido_export_directory)
	var saved_images: Variant = configuration.get_value(LAYOUT_SECTION, "reference_images", {})
	if saved_images is Dictionary:
		_reference_state = saved_images
	var saved_notes: Variant = configuration.get_value(LAYOUT_SECTION, "reference_notes", _notes_state)
	if saved_notes is Dictionary:
		_notes_state = saved_notes
	var saved_tasks: Variant = configuration.get_value(LAYOUT_SECTION, "reference_tasks", _tasks_state)
	if saved_tasks is Dictionary:
		_tasks_state = saved_tasks
	_references_tab = clampi(int(configuration.get_value(LAYOUT_SECTION, "references_tab", _references_tab)), 0, 2)
	if is_instance_valid(_references_dock):
		_references_dock.call(&"set_references_state", _reference_state)
		_references_dock.call(&"set_references_extras", {"notes": _notes_state, "tasks": _tasks_state, "tab": _references_tab})
	if is_instance_valid(_pixnido_dock) and is_instance_valid(_references_dock):
		_apply_registered_sides()
		_apply_visibility.call_deferred()


func _shortcut_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if not key_event.ctrl_pressed or not key_event.alt_pressed:
		return
	if key_event.shift_pressed or key_event.meta_pressed:
		return
	match key_event.keycode:
		KEY_P:
			_toggle_pixnido()
		KEY_R:
			_toggle_references()
		KEY_I:
			_swap_sides()
		KEY_N:
			_toggle_focus_workspace()
		_:
			return
	get_viewport().set_input_as_handled()


func _enter_tree() -> void:
	_pixnido_dock = PANEL_DOCK_SCRIPT.new()
	_pixnido_dock.call(&"configure", &"pixnido", EditorDock.DOCK_SLOT_LEFT_UL)
	_pixnido_dock.connect(&"close_requested", _close_pixnido)
	_pixnido_dock.connect(&"pixnido_source_changed", _on_pixnido_source_changed)
	_pixnido_dock.connect(&"pixnido_export_directory_changed", _on_pixnido_export_directory_changed)
	_pixnido_dock.call(&"set_pixnido_source", _pixnido_source)
	_pixnido_dock.call(&"set_pixnido_export_directory", _pixnido_export_directory)
	_pixnido_dock.call(&"set_slide_side", false)
	add_dock(_pixnido_dock)

	_references_dock = PANEL_DOCK_SCRIPT.new()
	_references_dock.call(&"configure", &"references", EditorDock.DOCK_SLOT_RIGHT_UR)
	_references_dock.connect(&"close_requested", _close_references)
	_references_dock.connect(&"references_changed", _on_references_changed)
	_references_dock.call(&"set_references_state", _reference_state)
	_references_dock.call(&"set_references_extras", {"notes": _notes_state, "tasks": _tasks_state, "tab": _references_tab})
	_references_dock.call(&"set_slide_side", true)
	add_dock(_references_dock)

	_build_toolbar()
	_apply_visibility.call_deferred()


func _exit_tree() -> void:
	_leave_focus_workspace(false)
	if is_instance_valid(_toolbar):
		remove_control_from_container(EditorPlugin.CONTAINER_TOOLBAR, _toolbar)
		_toolbar.queue_free()
	_toolbar = null
	_pixnido_button = null
	_references_button = null
	_focus_button = null

	if is_instance_valid(_references_dock):
		_references_dock.call(&"cancel_motion")
		remove_dock(_references_dock)
		_references_dock.queue_free()
	_references_dock = null

	if is_instance_valid(_pixnido_dock):
		_pixnido_dock.call(&"cancel_motion")
		remove_dock(_pixnido_dock)
		_pixnido_dock.queue_free()
	_pixnido_dock = null


func _on_pixnido_export_directory_changed() -> void:
	queue_save_layout()


func _on_pixnido_source_changed() -> void:
	queue_save_layout()


func _on_references_changed() -> void:
	queue_save_layout()


func _build_toolbar() -> void:
	_toolbar = HBoxContainer.new()
	_toolbar.name = "PixNidoPanelToolbar"

	_pixnido_button = _make_button(&"Sprite2D", "▦", "Open PixNido with References in NidoLab (Ctrl+Alt+P)")
	_pixnido_button.toggle_mode = true
	_pixnido_button.button_pressed = _pixnido_open
	_pixnido_button.pressed.connect(_toggle_pixnido)
	_toolbar.add_child(_pixnido_button)

	var swap_button: Button = _make_button(&"Reload", "⇄", "Swap left / right (Ctrl+Alt+I)")
	swap_button.pressed.connect(_swap_sides)
	_toolbar.add_child(swap_button)

	_references_button = _make_button(&"Texture2D", "▧", "Open References independently (Ctrl+Alt+R)")
	_references_button.toggle_mode = true
	_references_button.button_pressed = _references_open
	_references_button.pressed.connect(_toggle_references)
	_toolbar.add_child(_references_button)

	_focus_button = _make_button(&"DistractionFree", "▣", "Open NidoLab focus workspace (Ctrl+Alt+N)")
	_focus_button.toggle_mode = true
	_focus_button.button_pressed = false
	_focus_button.pressed.connect(_toggle_focus_workspace)
	_toolbar.add_child(_focus_button)

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
	if is_instance_valid(_focus_workspace):
		_pixnido_open = not _pixnido_open
		_focus_workspace.call(&"set_pane_visibility", &"pixnido", _pixnido_open)
	else:
		# Calling PixNido launches both fixed-width panes in focus mode.
		_pixnido_open = true
		_references_open = true
		_enter_focus_workspace()
	_sync_button_states()
	queue_save_layout()


func _toggle_references() -> void:
	if is_instance_valid(_focus_workspace):
		_references_open = not _references_open
		_focus_workspace.call(&"set_pane_visibility", &"references", _references_open)
	else:
		# References can be summoned without PixNido or native Servo.
		_pixnido_open = false
		_references_open = true
		_enter_focus_workspace()
	_sync_button_states()
	queue_save_layout()


func _close_pixnido() -> void:
	_pixnido_open = false
	if is_instance_valid(_focus_workspace):
		_focus_workspace.call(&"set_pane_visibility", &"pixnido", false)
	else:
		_set_dock_visible(_pixnido_dock, false)
	_sync_button_states()
	queue_save_layout()


func _close_references() -> void:
	_references_open = false
	if is_instance_valid(_focus_workspace):
		_focus_workspace.call(&"set_pane_visibility", &"references", false)
	else:
		_set_dock_visible(_references_dock, false)
	_sync_button_states()
	queue_save_layout()


func _swap_sides() -> void:
	if not is_instance_valid(_pixnido_dock) or not is_instance_valid(_references_dock):
		return
	_swapped = not _swapped
	if is_instance_valid(_focus_workspace):
		_focus_workspace.call(&"set_swapped", _swapped)
	else:
		_apply_registered_sides()
	queue_save_layout()


func _toggle_focus_workspace() -> void:
	if is_instance_valid(_focus_workspace):
		_leave_focus_workspace()
	else:
		_pixnido_open = true
		_references_open = true
		_enter_focus_workspace()
		queue_save_layout()


func _enter_focus_workspace() -> void:
	if is_instance_valid(_focus_workspace):
		return
	if not is_instance_valid(_pixnido_dock) or not is_instance_valid(_references_dock):
		return
	var editor_root: Control = EditorInterface.get_base_control()
	if not is_instance_valid(editor_root):
		push_warning("NidoLab: cannot access the Godot editor root.")
		return
	var pix: Control = _pixnido_dock.call(&"get_workspace_body")
	var references: Control = _references_dock.call(&"get_workspace_body")
	if not is_instance_valid(pix) or not is_instance_valid(references):
		push_warning("NidoLab: editor panel content is not ready.")
		return

	var workspace: Control = FOCUS_WORKSPACE_SCRIPT.new()
	workspace.connect(&"exit_requested", _leave_focus_workspace)
	workspace.connect(&"pane_visibility_changed", _on_focus_pane_visibility_changed)
	workspace.connect(&"swap_requested", _swap_sides)
	workspace.connect(&"add_reference_requested", _on_focus_add_reference)
	editor_root.add_child(workspace)
	workspace.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not bool(workspace.call(&"attach_contents", pix, references, _pixnido_open, _references_open, _swapped)):
		workspace.queue_free()
		push_warning("NidoLab: unable to enter focus workspace.")
		return
	_focus_workspace = workspace
	workspace.move_to_front()
	workspace.grab_focus()
	_sync_button_states()


func _leave_focus_workspace(restore_editor: bool = true) -> void:
	if not is_instance_valid(_focus_workspace):
		return
	var workspace: Control = _focus_workspace
	_focus_workspace = null
	workspace.call(&"restore_contents")
	workspace.queue_free()
	if restore_editor and is_inside_tree():
		_apply_registered_sides()
		_apply_visibility.call_deferred()
		queue_save_layout()
	_sync_button_states()


func _on_focus_pane_visibility_changed(panel: StringName, opening: bool) -> void:
	if panel == &"pixnido":
		_pixnido_open = opening
	elif panel == &"references":
		_references_open = opening
	_sync_button_states()
	queue_save_layout()


func _on_focus_add_reference() -> void:
	if is_instance_valid(_references_dock):
		_references_dock.call(&"add_to_current_reference_tab")


func _apply_registered_sides() -> void:
	if _registered_swapped == _swapped:
		return
	if not is_instance_valid(_pixnido_dock) or not is_instance_valid(_references_dock):
		return
	# Changing slots requires re-registering. User-dragged placements may reset.
	_pixnido_dock.call(&"cancel_motion")
	_references_dock.call(&"cancel_motion")
	_pixnido_dock.close()
	_references_dock.close()
	remove_dock(_pixnido_dock)
	remove_dock(_references_dock)
	_pixnido_dock.default_slot = (
		EditorDock.DOCK_SLOT_RIGHT_UR if _swapped else EditorDock.DOCK_SLOT_LEFT_UL
	)
	_references_dock.default_slot = (
		EditorDock.DOCK_SLOT_LEFT_UL if _swapped else EditorDock.DOCK_SLOT_RIGHT_UR
	)
	_pixnido_dock.call(&"set_slide_side", _swapped)
	_references_dock.call(&"set_slide_side", not _swapped)
	add_dock(_pixnido_dock)
	add_dock(_references_dock)
	_registered_swapped = _swapped
	_apply_visibility.call_deferred()

func _apply_visibility() -> void:
	# Godot's editor splitters may still be calculating dragger controls in
	# _enter_tree/_set_window_layout. Do not close a new dock until after layout.
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree():
		return
	if not is_instance_valid(_pixnido_dock) or not is_instance_valid(_references_dock):
		return
	_set_dock_visible(_references_dock, _references_open, false)
	_set_dock_visible(_pixnido_dock, _pixnido_open, false)
	_sync_button_states()


func _set_dock_visible(dock: EditorDock, should_show: bool, animated: bool = true) -> void:
	if not is_instance_valid(dock):
		return
	if should_show:
		dock.call(&"show_panel", animated)
	else:
		dock.call(&"hide_panel", animated)

func _sync_button_states() -> void:
	if is_instance_valid(_pixnido_button):
		_pixnido_button.button_pressed = _pixnido_open
	if is_instance_valid(_references_button):
		_references_button.button_pressed = _references_open
	if is_instance_valid(_focus_button):
		_focus_button.button_pressed = is_instance_valid(_focus_workspace)
