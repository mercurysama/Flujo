@tool
class_name FluoDrawer
extends Control

## Editor-only shell for the contextual Fluo surface.
##
## The drawer deliberately owns no model state. Its only transient state is
## visibility and a weak reference to the control that had focus before it was
## opened.

const DRAWER_WIDTH: float = 320.0

var _backdrop: Control
var _drawer_panel: PanelContainer
var _focus_reference: WeakRef
var _is_open: bool = false


func _init() -> void:
	name = "FluoDrawer"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_process_input(true)
	_build_interface()
	visible = false


func _ready() -> void:
	# The parent size is available only after the control enters the tree.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


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
	_drawer_panel.anchor_left = 1.0
	_drawer_panel.anchor_top = 0.0
	_drawer_panel.anchor_right = 1.0
	_drawer_panel.anchor_bottom = 1.0
	_drawer_panel.offset_left = -DRAWER_WIDTH
	_drawer_panel.offset_top = 0.0
	_drawer_panel.offset_right = 0.0
	_drawer_panel.offset_bottom = 0.0
	_drawer_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_drawer_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_drawer_panel.custom_minimum_size = Vector2(DRAWER_WIDTH, 0.0)
	_drawer_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_drawer_panel.focus_mode = Control.FOCUS_NONE
	_drawer_panel.z_index = 1
	add_child(_drawer_panel)


## Opens Fluo without changing or owning any editor data.
func open() -> void:
	if _is_open:
		return
	_remember_focus()
	_is_open = true
	show()
	move_to_front()


## Closes Fluo and restores the previous focus only when it is still usable.
func close() -> void:
	var focus_target: Control = _control_from_reference(_focus_reference)
	_focus_reference = null
	_is_open = false
	hide()
	if _can_restore_focus(focus_target):
		focus_target.grab_focus()


func is_open() -> bool:
	return _is_open


func _input(event: InputEvent) -> void:
	if not _is_open or not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo or key_event.keycode != KEY_ESCAPE:
		return
	close()
	var viewport: Viewport = get_viewport()
	if viewport != null:
		viewport.set_input_as_handled()


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if not _is_open or not event is InputEventMouseButton:
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	_backdrop.accept_event()
	if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		close()


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
