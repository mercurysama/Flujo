@tool
## One reusable visual unit for any FlowChipSegment.
class_name FlowChipControl
extends PanelContainer


signal chip_selected(segment_id: String)
signal chip_edit_requested(segment_id: String)
signal delete_requested(segment_id: String)
signal focus_previous_requested
signal focus_next_requested


var _segment: FlowChipSegment
var _label: Label
var _selected: bool = false
var _invalid: bool = false
var _editable: bool = true
var _type_locked: bool = false
var _source_kind_locked: bool = false
var _semantic_style_role: StringName = &""
var _applying_style: bool = false


var segment: FlowChipSegment:
	get:
		return _segment
	set(value):
		set_segment(value)


func _init(initial_segment: FlowChipSegment = null) -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_label)
	if initial_segment != null:
		set_segment(initial_segment)
	minimum_size_changed.connect(_on_minimum_size_changed)


func set_segment(segment: FlowChipSegment) -> void:
	_segment = segment
	_refresh()


func get_segment() -> FlowChipSegment:
	return _segment


func get_segment_id() -> String:
	return _segment.get_segment_id() if _segment != null else ""


func get_semantic_style_role() -> StringName:
	return _semantic_style_role


func is_selected() -> bool:
	return _selected


func is_invalid() -> bool:
	return _invalid


func is_editable() -> bool:
	return _editable


func is_type_locked() -> bool:
	return _type_locked


func is_source_kind_locked() -> bool:
	return _source_kind_locked


## The schema policy is supplied by FlowChipFieldEditor so the visual unit
## remains generic and does not inspect block-specific rules.
func set_editability(
		can_edit: bool,
		type_locked: bool = false,
		source_kind_locked: bool = false
) -> void:
	_editable = can_edit
	_type_locked = type_locked
	_source_kind_locked = source_kind_locked
	_refresh()


func set_selected(selected: bool) -> void:
	_selected = selected
	_apply_style()


## Public selection entry point used by editor hosts and focused keyboard paths.
func select() -> void:
	if _segment == null:
		return
	grab_focus()
	chip_selected.emit(_segment.get_segment_id())


func refresh() -> void:
	_refresh()


func _refresh() -> void:
	if _label == null:
		return
	if _segment == null:
		_label.text = ""
		tooltip_text = ""
		_semantic_style_role = &""
		_apply_style()
		return

	var descriptor: FlowChipTypeDescriptor = _segment.get_chip_type_descriptor()
	_semantic_style_role = descriptor.semantic_style_role if descriptor != null else &""
	_invalid = not _segment.is_chip_valid()
	_label.text = _segment.get_chip_label()
	tooltip_text = _format_tooltip(_segment.get_chip_tooltip_data())
	if _invalid and not tooltip_text.is_empty():
		tooltip_text += "\nStatus: unresolved"
	if not _editable:
		tooltip_text += "\nStatus: immutable"
	elif _type_locked:
		tooltip_text += "\nConstraint: type locked"
	if _source_kind_locked:
		tooltip_text += "\nConstraint: source kind locked"
	custom_minimum_size = Vector2.ZERO
	_apply_style()
	minimum_size_changed.emit()


func _apply_style() -> void:
	if _applying_style:
		return
	_applying_style = true
	FlowChipTheme.apply_chip_style(
		self,
		_semantic_style_role,
		_selected,
		_invalid,
		not _editable
	)
	_applying_style = false


func _format_tooltip(data: FlowChipTooltipData) -> String:
	if data == null:
		return ""
	var lines: Array[String] = []
	if not data.title.is_empty():
		lines.append(data.title)
	for field: Dictionary in data.fields:
		if not field.has(FlowChipTooltipData.FIELD_LABEL_KEY) \
				or not field.has(FlowChipTooltipData.FIELD_VALUE_KEY):
			continue
		lines.append("%s: %s" % [
			String(field[FlowChipTooltipData.FIELD_LABEL_KEY]),
			String(field[FlowChipTooltipData.FIELD_VALUE_KEY]),
		])
	return "\n".join(lines)


func _gui_input(event: InputEvent) -> void:
	if _segment == null:
		return
	if event is InputEventMouseButton:
		var mouse: InputEventMouseButton = event as InputEventMouseButton
		if mouse.button_index == MOUSE_BUTTON_LEFT and mouse.pressed:
			select()
			if mouse.double_click:
				chip_edit_requested.emit(_segment.get_segment_id())
			accept_event()
			return
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if _is_history_shortcut(key):
			# FlowChipFieldEditor already routed the action during _input(). This
			# child boundary only prevents a second native/editor consumer.
			accept_event()
			return
		if key.pressed and not key.echo and key.keycode == KEY_LEFT:
			focus_previous_requested.emit()
			accept_event()
			return
		if key.pressed and not key.echo and key.keycode == KEY_RIGHT:
			focus_next_requested.emit()
			accept_event()
			return
		if key.pressed and not key.echo \
				and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER):
			select()
			chip_edit_requested.emit(_segment.get_segment_id())
			accept_event()
			return
		if key.pressed and not key.echo \
				and (key.keycode == KEY_DELETE or key.keycode == KEY_BACKSPACE):
			delete_requested.emit(_segment.get_segment_id())
			accept_event()


func _is_history_shortcut(key: InputEventKey) -> bool:
	if not key.pressed or key.echo or not key.ctrl_pressed:
		return false
	var is_z: bool = key.keycode == KEY_Z or key.physical_keycode == KEY_Z
	var is_y: bool = key.keycode == KEY_Y or key.physical_keycode == KEY_Y
	return is_z or (is_y and not key.shift_pressed)


func _unhandled_key_input(event: InputEvent) -> void:
	if _segment == null or not has_focus() or not event is InputEventKey:
		return
	var key: InputEventKey = event as InputEventKey
	if key.pressed and not key.echo \
			and (key.keycode == KEY_DELETE or key.keycode == KEY_BACKSPACE):
		delete_requested.emit(_segment.get_segment_id())
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED:
		_apply_style()


func _on_minimum_size_changed() -> void:
	if _label != null:
		custom_minimum_size = _label.get_combined_minimum_size() + Vector2(12.0, 4.0)
