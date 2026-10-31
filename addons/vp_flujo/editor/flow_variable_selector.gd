@tool
## Reusable keyboard/mouse/touch selector for graph-owned variables.
class_name FlowVariableSelector
extends PopupPanel


signal variable_selected(variable_id: String)
signal cancelled


const SEARCH_NAME: StringName = &"VariableSearch"
const LIST_NAME: StringName = &"VariableList"

var _search: LineEdit
var _list: ItemList
var _variables: Array[FlowVariableDefinition] = []
var _visible_variables: Array[FlowVariableDefinition] = []
var _selector_context: Dictionary = {}
var _select_current_on_next_rebuild: bool = false
var _closing_for_selection: bool = false


func _init() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	name = &"FlowVariableSelector"
	min_size = Vector2i(360, 260)
	size = Vector2i(420, 320)
	close_requested.connect(_on_close_requested)
	popup_hide.connect(_on_popup_hide)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override(&"margin_left", 10)
	margin.add_theme_constant_override(&"margin_top", 10)
	margin.add_theme_constant_override(&"margin_right", 10)
	margin.add_theme_constant_override(&"margin_bottom", 10)
	add_child(margin)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override(&"separation", 6)
	margin.add_child(content)

	var heading: Label = Label.new()
	heading.text = "Select Variable"
	content.add_child(heading)

	_search = LineEdit.new()
	_search.name = SEARCH_NAME
	_search.placeholder_text = "Search variables"
	_search.tooltip_text = "Filter compatible variables, then press Enter to select."
	_search.focus_mode = Control.FOCUS_ALL
	_search.custom_minimum_size.y = 40.0
	_search.text_changed.connect(_on_search_changed)
	_search.text_submitted.connect(_on_search_submitted)
	_search.gui_input.connect(_on_search_gui_input)
	content.add_child(_search)

	_list = ItemList.new()
	_list.name = LIST_NAME
	_list.focus_mode = Control.FOCUS_ALL
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.custom_minimum_size = Vector2(0.0, 180.0)
	_list.allow_reselect = true
	_list.item_activated.connect(_on_item_activated)
	_list.item_clicked.connect(_on_item_clicked)
	_list.gui_input.connect(_on_list_gui_input)
	content.add_child(_list)


func open_for_variables(
		variables: Array[FlowVariableDefinition],
		anchor: Rect2,
		initial_query: String = "",
		context: Dictionary = {}
) -> void:
	_closing_for_selection = false
	_variables = variables.duplicate()
	_selector_context = context.duplicate()
	_select_current_on_next_rebuild = true
	_search.text = initial_query
	_select_current_on_next_rebuild = true
	_rebuild_list(initial_query)
	var popup_position: Vector2i = Vector2i(
		int(anchor.position.x),
		int(anchor.position.y + anchor.size.y)
	)
	popup(Rect2i(popup_position, Vector2i(size)))
	_search.grab_focus()
	call_deferred(&"_focus_search")
func cancel() -> void:
	if not visible:
		cancelled.emit()
		return
	_closing_for_selection = false
	hide()


func get_variable_list() -> ItemList:
	return _list


func get_selector_context() -> Dictionary:
	return _selector_context.duplicate()


func get_current_variable_id() -> String:
	return String(_selector_context.get("current_variable_id", ""))


func get_visible_variable_ids() -> Array[String]:
	var result: Array[String] = []
	for variable: FlowVariableDefinition in _visible_variables:
		if variable != null:
			result.append(variable.get_internal_id())
	return result


func _rebuild_list(query: String) -> void:
	if _list == null:
		return
	var select_current: bool = _select_current_on_next_rebuild
	_select_current_on_next_rebuild = false
	_list.clear()
	_visible_variables.clear()
	var needle: String = query.strip_edges().to_lower()
	for variable: FlowVariableDefinition in _variables:
		if not _is_context_compatible(variable):
			continue
		var display_name: String = variable.display_name.strip_edges()
		if display_name.is_empty():
			display_name = "Variable"
		var type_name: String = FlowVariableDefinition.value_type_display_name(variable.value_type)
		var scope_name: String = "Global" if variable.scope == FlowVariableDefinition.Scope.GLOBAL else "Local"
		var searchable: String = "%s %s %s %s" % [
			display_name,
			String(variable.get_internal_id()),
			type_name,
			scope_name,
		]
		if not needle.is_empty() and not searchable.to_lower().contains(needle):
			continue
		var item_index: int = _list.item_count
		_list.add_item("%s  ·  %s  ·  %s" % [display_name, type_name, scope_name])
		_list.set_item_metadata(item_index, variable.get_internal_id())
		_list.set_item_tooltip(
			item_index,
			"Name: %s\nID: %s\nVariant/Declared Type: %s\nScope: %s" % [
				display_name,
				variable.get_internal_id(),
				type_name,
				scope_name,
			]
		)
		_visible_variables.append(variable)
	if _list.item_count > 0:
		var selected_index: int = 0
		if select_current:
			var current_id: String = get_current_variable_id()
			for visible_index: int in _visible_variables.size():
				if _visible_variables[visible_index].get_internal_id() == current_id:
					selected_index = visible_index
					break
		_list.select(selected_index)
		_list.ensure_current_is_visible()


func _on_search_changed(value: String) -> void:
	_select_current_on_next_rebuild = false
	_rebuild_list(value)


func _on_search_submitted(_value: String) -> void:
	_choose_selected_or_first()


func _on_item_activated(index: int) -> void:
	_choose_index(index)


func _on_item_clicked(index: int, _at_position: Vector2, mouse_button_index: int) -> void:
	if mouse_button_index == MOUSE_BUTTON_LEFT:
		_choose_index(index)


func _on_search_gui_input(event: InputEvent) -> void:
	if _is_history_shortcut(event):
		_search.accept_event()
	elif _is_navigation(event):
		_search.accept_event()
		_move_selection(-1 if (event as InputEventKey).keycode == KEY_UP else 1)
	elif _is_escape(event):
		_search.accept_event()
		cancel()
	elif _is_accept(event):
		_search.accept_event()
		_choose_selected_or_first()


func _on_list_gui_input(event: InputEvent) -> void:
	if _is_history_shortcut(event):
		_list.accept_event()
	elif _is_navigation(event):
		_list.accept_event()
		_move_selection(-1 if (event as InputEventKey).keycode == KEY_UP else 1)
	elif _is_escape(event):
		_list.accept_event()
		cancel()
	elif _is_accept(event):
		_list.accept_event()
		_choose_selected_or_first()


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible:
		return
	if _is_navigation(event):
		_move_selection(-1 if (event as InputEventKey).keycode == KEY_UP else 1)
		get_viewport().set_input_as_handled()
	elif _is_escape(event):
		cancel()
		get_viewport().set_input_as_handled()
	elif _is_accept(event):
		_choose_selected_or_first()
		get_viewport().set_input_as_handled()


func _choose_selected_or_first() -> void:
	if not visible or _list.item_count == 0:
		return
	var selected: PackedInt32Array = _list.get_selected_items()
	_choose_index(selected[0] if not selected.is_empty() else 0)


func _choose_index(index: int) -> void:
	if not visible:
		return
	if index < 0 or index >= _visible_variables.size():
		return
	var variable: FlowVariableDefinition = _visible_variables[index]
	if variable == null:
		return
	_closing_for_selection = true
	variable_selected.emit(variable.get_internal_id())
	hide()
	_closing_for_selection = false


func _on_close_requested() -> void:
	cancel()


func _on_popup_hide() -> void:
	if not _closing_for_selection:
		cancelled.emit()


func _focus_search() -> void:
	if visible and _search != null:
		_search.grab_focus()


func _move_selection(direction: int) -> void:
	if _list == null or _list.item_count == 0 or direction == 0:
		return
	var selected: PackedInt32Array = _list.get_selected_items()
	var current_index: int = selected[0] if not selected.is_empty() else 0
	var next_index: int = clampi(current_index + direction, 0, _list.item_count - 1)
	_list.select(next_index)
	_list.ensure_current_is_visible()


func _is_context_compatible(variable: FlowVariableDefinition) -> bool:
	if variable == null:
		return false
	var schema: FlowChipFieldSchema = _selector_context.get("schema", null) as FlowChipFieldSchema
	if schema != null and not schema.accepts_source_kind(FlowValueSource.SOURCE_KIND_VARIABLE_REF):
		return false
	var slot: FlowChipSlotDefinition = _selector_context.get("slot", null) as FlowChipSlotDefinition
	var candidate_type: Variant.Type = variable.get_declared_variant_type()
	var accepted_types: Array = _selector_context.get("accepted_value_types", []) as Array
	if not accepted_types.is_empty() and not accepted_types.has(candidate_type):
		return false
	if bool(_selector_context.get("value_type_locked", false)):
		var locked_type: Variant.Type = _selector_context.get(
			"value_type",
			Variant.Type.TYPE_NIL
		) as Variant.Type
		if locked_type != Variant.Type.TYPE_NIL and candidate_type != locked_type:
			return false
	var accepted_sources: Array = _selector_context.get("accepted_source_kinds", []) as Array
	if not accepted_sources.is_empty() \
			and not accepted_sources.has(FlowValueSource.SOURCE_KIND_VARIABLE_REF):
		return false
	if slot != null and not slot.accepts_value_type(candidate_type):
		return false
	if slot != null and not slot.accepts_source_kind(FlowValueSource.SOURCE_KIND_VARIABLE_REF):
		return false
	return true


func _is_navigation(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key: InputEventKey = event as InputEventKey
	return key.pressed and not key.echo \
		and (key.keycode == KEY_UP or key.keycode == KEY_DOWN)


func _is_escape(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key: InputEventKey = event as InputEventKey
	return key.pressed and not key.echo and key.keycode == KEY_ESCAPE


func _is_accept(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key: InputEventKey = event as InputEventKey
	return key.pressed and not key.echo \
		and (key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER)


func _is_history_shortcut(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo or not key.ctrl_pressed:
		return false
	var is_z: bool = key.keycode == KEY_Z or key.physical_keycode == KEY_Z
	var is_y: bool = key.keycode == KEY_Y or key.physical_keycode == KEY_Y
	return is_z or (is_y and not key.shift_pressed)
