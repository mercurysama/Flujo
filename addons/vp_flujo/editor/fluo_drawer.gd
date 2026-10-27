@tool
class_name FluoDrawer
extends Control

## Contextual editor surface shown over the Godot editor.
## It owns no FlowGraph state: it presents the same live PVController model
## through its own FlowGraphInspectorProperty view.

signal schema_3_variable_list_focus_requested(controller: PVController, variable_id: String)
signal schema_3_delete_selection_recovery_requested(
	controller: PVController,
	collection: FlowGraphEditorCommands.Collection,
	deleted_id: String,
	replacement_id: String,
	view_title: String,
	restore_focus: bool
)

const DRAWER_WIDTH_RATIO: float = 0.46

var _backdrop: Control
var _drawer_panel: PanelContainer
var _content: VBoxContainer
var _side_switch: CheckButton
var _editor_scroll: ScrollContainer
var _editor_scroll_content: VBoxContainer
var _variable_editor: FlowGraphInspectorProperty

var _focus_reference: WeakRef
var _controller_reference: WeakRef
var _is_open: bool = false
var _right_side: bool = false


func _init() -> void:
	name = "FluoDrawer"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)
	_build_interface()
	visible = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_apply_side_layout()


func configure(undo_redo: EditorUndoRedoManager) -> void:
	if _variable_editor != null:
		return

	_variable_editor = FlowGraphInspectorProperty.new()
	_variable_editor.name = &"FluoFlowEditor"
	_variable_editor.configure(undo_redo)
	_variable_editor.configure_for_fluo()
	_variable_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_variable_editor.size_flags_vertical = Control.SIZE_SHRINK_BEGIN

	_variable_editor.schema_3_variable_list_focus_requested.connect(
		_on_variable_editor_list_focus_requested
	)
	_variable_editor.schema_3_delete_selection_recovery_requested.connect(
		_on_delete_selection_recovery_requested
	)

	_editor_scroll_content.add_child(_variable_editor)
	_variable_editor.set_dock_controller(_controller_instance())


func set_controller(controller: PVController) -> void:
	var next_controller: PVController = controller if is_instance_valid(controller) else null
	var current_controller: PVController = _controller_instance()

	if current_controller == next_controller \
			and (next_controller != null or _controller_reference == null):
		return

	_disconnect_controller(current_controller)
	_controller_reference = weakref(next_controller) if next_controller != null else null
	_connect_controller(next_controller)

	if _variable_editor != null:
		_variable_editor.set_dock_controller(next_controller)


func set_variable_selection(
	controller: PVController,
	collection: FlowGraphEditorCommands.Collection,
	variable_id: String
) -> void:
	if _variable_editor != null:
		_variable_editor.set_dock_variable_selection(controller, collection, variable_id)


func refresh_controller() -> void:
	if _variable_editor != null:
		_variable_editor.refresh_dock_controller()


func open_container(
	controller: PVController,
	collection: FlowGraphEditorCommands.Collection,
	container_id: String
) -> void:
	set_controller(controller)
	if _variable_editor != null:
		_variable_editor.close_ready_block_details()
		_variable_editor.set_dock_variable_selection(controller, collection, container_id)
		_variable_editor.focus_flow_entry()
	open()


func open_block(
	controller: PVController,
	collection: FlowGraphEditorCommands.Collection,
	container_id: String,
	block_id: String
) -> void:
	set_controller(controller)
	if _variable_editor != null:
		_variable_editor.open_ready_block_details(controller, collection, container_id, block_id)
	open()


func open() -> void:
	if _is_open:
		return
	_remember_focus()
	_is_open = true
	show()
	move_to_front()


func close() -> void:
	var focus_target: Control = _control_from_reference(_focus_reference)
	_focus_reference = null
	_is_open = false

	if _variable_editor != null:
		_variable_editor.close_ready_block_details()
		_variable_editor.close_transient_interfaces()

	hide()

	if _can_restore_focus(focus_target):
		focus_target.grab_focus()


func is_open() -> bool:
	return _is_open


func is_right_side() -> bool:
	return _right_side


func set_right_side(enabled: bool) -> void:
	_right_side = enabled
	if _side_switch != null and _side_switch.button_pressed != enabled:
		_side_switch.set_pressed_no_signal(enabled)
	_apply_side_layout()


func _build_interface() -> void:
	if _backdrop != null or _drawer_panel != null:
		return

	_backdrop = Control.new()
	_backdrop.name = "Backdrop"
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.gui_input.connect(_on_backdrop_gui_input)
	add_child(_backdrop)

	_drawer_panel = PanelContainer.new()
	_drawer_panel.name = "DrawerPanel"
	_drawer_panel.anchor_top = 0.0
	_drawer_panel.anchor_bottom = 1.0
	_drawer_panel.offset_top = 0.0
	_drawer_panel.offset_bottom = 0.0
	_drawer_panel.custom_minimum_size = Vector2.ZERO
	_drawer_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_drawer_panel.focus_mode = Control.FOCUS_NONE
	_drawer_panel.z_index = 1

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.08, 0.10, 0.94)
	_drawer_panel.add_theme_stylebox_override("panel", panel_style)

	_content = VBoxContainer.new()
	_content.name = &"FluoContent"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_drawer_panel.add_child(_content)

	var header := HBoxContainer.new()
	header.name = &"FluoHeader"
	header.custom_minimum_size = Vector2(0.0, 48.0)
	_content.add_child(header)

	_side_switch = CheckButton.new()
	_side_switch.name = &"FluoSideSwitch"
	_side_switch.text = "Derecha"
	_side_switch.tooltip_text = "Apagado: izquierda. Encendido: derecha."
	_side_switch.focus_mode = Control.FOCUS_ALL
	_side_switch.button_pressed = false
	_side_switch.toggled.connect(_on_side_switch_toggled)
	header.add_child(_side_switch)

	var title := Label.new()
	title.name = &"FluoTitle"
	title.text = "Fluo"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_button := Button.new()
	close_button.name = &"CloseFluoButton"
	close_button.text = "✕"
	close_button.tooltip_text = "Cerrar Fluo"
	close_button.focus_mode = Control.FOCUS_ALL
	close_button.custom_minimum_size = Vector2(44.0, 44.0)
	close_button.pressed.connect(close)
	header.add_child(close_button)

	_editor_scroll = ScrollContainer.new()
	_editor_scroll.name = &"FluoEditorScroll"
	_editor_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_editor_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_editor_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(_editor_scroll)

	_editor_scroll_content = VBoxContainer.new()
	_editor_scroll_content.name = &"FluoEditorScrollContent"
	_editor_scroll_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor_scroll_content.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_editor_scroll.add_child(_editor_scroll_content)

	add_child(_drawer_panel)
	_apply_side_layout()


func _apply_side_layout() -> void:
	if _drawer_panel == null:
		return

	if _right_side:
		_drawer_panel.anchor_left = 1.0 - DRAWER_WIDTH_RATIO
		_drawer_panel.anchor_right = 1.0
	else:
		_drawer_panel.anchor_left = 0.0
		_drawer_panel.anchor_right = DRAWER_WIDTH_RATIO

	_drawer_panel.anchor_top = 0.0
	_drawer_panel.anchor_bottom = 1.0
	_drawer_panel.offset_left = 0.0
	_drawer_panel.offset_top = 0.0
	_drawer_panel.offset_right = 0.0
	_drawer_panel.offset_bottom = 0.0


func _input(event: InputEvent) -> void:
	if not _is_open or not event is InputEventKey:
		return

	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return

	if key_event.keycode == KEY_ESCAPE:
		if _variable_editor != null and _variable_editor.close_ready_block_details():
			_mark_input_handled()
			return
		close()
		_mark_input_handled()
		return

	if key_event.keycode != KEY_PAGEUP and key_event.keycode != KEY_PAGEDOWN:
		return
	if not _focus_is_inside_drawer():
		return

	var direction: int = -1 if key_event.keycode == KEY_PAGEUP else 1
	var handled: bool = false

	# Ctrl+PageUp/PageDown belongs to Flow block navigation while Fluo is open.
	# Consume it even from text fields so Godot cannot reuse the shortcut.
	if key_event.ctrl_pressed and not key_event.alt_pressed:
		if _variable_editor != null:
			handled = _variable_editor.navigate_ready_block(direction)
		_mark_input_handled()
		return

	if key_event.alt_pressed:
		if key_event.shift_pressed:
			direction *= -1
		if _variable_editor != null:
			handled = _variable_editor.cycle_ready_block_option_focus(direction)
	elif not _focus_is_text_editing():
		if _variable_editor != null:
			# Plain PageUp/PageDown moves one level out: between the
			# Inspector container rows represented by the current Fluo view.
			handled = _variable_editor.navigate_process(direction)

	if handled:
		_mark_input_handled()


func _mark_input_handled() -> void:
	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _focus_is_inside_drawer() -> bool:
	var viewport: Viewport = get_viewport()
	if viewport == null or _drawer_panel == null:
		return false
	var focus_owner: Control = viewport.gui_get_focus_owner() as Control
	return is_instance_valid(focus_owner) \
		and (focus_owner == _drawer_panel or _drawer_panel.is_ancestor_of(focus_owner))


func _focus_is_text_editing() -> bool:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return false
	var focus_owner: Control = viewport.gui_get_focus_owner() as Control
	return focus_owner is LineEdit or focus_owner is TextEdit


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if not _is_open or not event is InputEventMouseButton:
		return

	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	_backdrop.accept_event()

	if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		close()


func _on_side_switch_toggled(enabled: bool) -> void:
	_right_side = enabled
	_apply_side_layout()


func _on_variable_editor_list_focus_requested(
	controller: PVController,
	variable_id: String
) -> void:
	emit_signal(&"schema_3_variable_list_focus_requested", controller, variable_id)


func _on_delete_selection_recovery_requested(
	controller: PVController,
	collection: FlowGraphEditorCommands.Collection,
	deleted_id: String,
	replacement_id: String,
	view_title: String,
	restore_focus: bool
) -> void:
	emit_signal(
		&"schema_3_delete_selection_recovery_requested",
		controller,
		collection,
		deleted_id,
		replacement_id,
		view_title,
		restore_focus
	)


func _connect_controller(controller: PVController) -> void:
	if controller == null:
		return

	if not controller.property_list_changed.is_connected(_on_controller_property_list_changed):
		controller.property_list_changed.connect(_on_controller_property_list_changed)

	if controller.is_inside_tree() and not controller.tree_exited.is_connected(_on_controller_tree_exited):
		controller.tree_exited.connect(_on_controller_tree_exited, CONNECT_ONE_SHOT)


func _disconnect_controller(controller: PVController) -> void:
	if controller == null:
		return

	if controller.property_list_changed.is_connected(_on_controller_property_list_changed):
		controller.property_list_changed.disconnect(_on_controller_property_list_changed)

	if controller.tree_exited.is_connected(_on_controller_tree_exited):
		controller.tree_exited.disconnect(_on_controller_tree_exited)


func _on_controller_property_list_changed() -> void:
	refresh_controller()


func _on_controller_tree_exited() -> void:
	var controller := _controller_instance()
	if controller != null:
		_disconnect_controller(controller)

	_controller_reference = null

	if _variable_editor != null:
		_variable_editor.set_dock_controller(null)


func _controller_instance() -> PVController:
	if _controller_reference == null:
		return null

	var controller: PVController = _controller_reference.get_ref() as PVController
	return controller if is_instance_valid(controller) else null


func _remember_focus() -> void:
	_focus_reference = null

	var viewport: Viewport = get_viewport()
	if viewport == null:
		return

	var focus_owner: Control = viewport.gui_get_focus_owner() as Control
	if _can_restore_focus(focus_owner):
		_focus_reference = weakref(focus_owner)


func _control_from_reference(reference: WeakRef) -> Control:
	if reference == null:
		return null

	var candidate: Control = reference.get_ref() as Control
	return candidate if is_instance_valid(candidate) else null


func _can_restore_focus(control: Control) -> bool:
	return is_instance_valid(control) \
		and control != self \
		and not is_ancestor_of(control) \
		and control.is_inside_tree() \
		and control.is_visible_in_tree() \
		and control.focus_mode != Control.FOCUS_NONE
