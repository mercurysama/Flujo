@tool
class_name FlowReadyProcessEditor
extends VBoxContainer

## Dock configuration for a stable-ID-selected Ready process or Timer.
signal block_selected(block_id: String)
signal block_activated(block_id: String)
signal block_delete_requested(block_id: String)
signal focus_requested(control_name: StringName, select_all: bool)
signal process_move_requested(direction: int)
signal process_delete_requested
signal block_details_visibility_changed(is_visible: bool)

var _commands: FlowGraphEditorCommands
var _controller: PVController
var _graph: FlowGraph
var _process_id: String
var _block_id: String
var _list: ItemList
var _details: VBoxContainer
var _details_panel: PanelContainer
var _split_host: HBoxContainer
var _list_content: VBoxContainer
var _split_block_layout: bool = false
var _block_details_open: bool = true
var _confirmation: ConfirmationDialog


func configure(
	commands: FlowGraphEditorCommands,
	controller: PVController,
	process: FlowBlockContainer,
	block_id: String,
	split_block_layout: bool = false,
	block_details_open: bool = false
) -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_commands = commands
	_controller = controller
	_graph = controller.flow_graph
	_process_id = process.get_internal_id()
	_block_id = block_id
	_split_block_layout = split_block_layout
	_block_details_open = block_details_open if split_block_layout else true
	name = &"ReadyProcessEditor"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var primary_parent: Container = self
	if _split_block_layout:
		_split_host = HBoxContainer.new()
		_split_host.name = &"FluoBlockWorkspace"
		_split_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_split_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
		add_child(_split_host)

		var list_panel := PanelContainer.new()
		list_panel.name = &"BlockListPanel"
		list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		list_panel.size_flags_stretch_ratio = 1.0
		_split_host.add_child(list_panel)

		_list_content = VBoxContainer.new()
		_list_content.name = &"BlockListContent"
		_list_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_list_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
		list_panel.add_child(_list_content)

		var flow_title := Label.new()
		flow_title.name = &"FlowPanelTitle"
		flow_title.text = "Flow"
		flow_title.add_theme_font_size_override("font_size", 16)
		_list_content.add_child(flow_title)
		primary_parent = _list_content

		_details_panel = PanelContainer.new()
		_details_panel.name = &"BlockOptionsPanel"
		_details_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_details_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_details_panel.size_flags_stretch_ratio = 1.0
		_details_panel.visible = false
		_split_host.add_child(_details_panel)

		_details = VBoxContainer.new()
		_details.name = &"BlockOptionsContent"
		_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_details_panel.add_child(_details)

	var title: Label = Label.new()
	var prefix: String = _container_label(process)
	title.text = "Type: " + prefix
	if process is FlowConstructorDefinition:
		title.text += " — once before Ready (not native _init)"
	primary_parent.add_child(title)

	var name_input: LineEdit = LineEdit.new()
	name_input.name = &"ReadyProcessName"
	name_input.text = process.display_name
	name_input.placeholder_text = "Process name"
	name_input.focus_mode = Control.FOCUS_ALL
	name_input.text_submitted.connect(_on_name_submitted)
	name_input.gui_input.connect(_on_name_input.bind(name_input, process.display_name))
	primary_parent.add_child(name_input)

	var enabled: CheckBox = CheckBox.new()
	enabled.name = &"ReadyProcessEnabled"
	enabled.text = prefix + " Enabled"
	enabled.button_pressed = process.enabled
	enabled.toggled.connect(_on_enabled.bind(""))
	primary_parent.add_child(enabled)

	if process is FlowTimerDefinition:
		var timer: FlowTimerDefinition = process as FlowTimerDefinition
		var interval_label: Label = Label.new()
		interval_label.text = "Interval (seconds)"
		primary_parent.add_child(interval_label)
		var interval: SpinBox = SpinBox.new()
		interval.name = &"TimerInterval"
		interval.min_value = 0.01
		interval.max_value = 3600.0
		interval.allow_greater = true
		interval.step = 0.01
		interval.custom_arrow_step = 1.0
		interval.value = timer.interval_seconds
		interval.get_line_edit().text = "%.2f" % timer.interval_seconds
		interval.value_changed.connect(_on_interval_changed)
		primary_parent.add_child(interval)
		call_deferred(&"_format_timer_interval", interval, timer.interval_seconds)
		var repeat_input: CheckBox = CheckBox.new()
		repeat_input.name = &"TimerRepeat"
		repeat_input.text = "Repeat"
		repeat_input.button_pressed = timer.repeat
		repeat_input.toggled.connect(_on_repeat_changed)
		primary_parent.add_child(repeat_input)

	var add_row: HBoxContainer = HBoxContainer.new()
	add_row.name = &"AddBlockActions"
	primary_parent.add_child(add_row)
	for type_id: StringName in FlowBlockRegistry.creatable_type_ids():
		_add_button(add_row, "Add " + FlowBlockRegistry.display_name_for_type(type_id), _on_add.bind(type_id))
	if process is FlowProcess:
		_add_button(add_row, "Add Call Method", _on_add_call)

	var process_actions: VBoxContainer = VBoxContainer.new()
	process_actions.name = &"ProcessActions"
	primary_parent.add_child(process_actions)
	var action_title: Label = Label.new()
	action_title.text = prefix + " actions"
	process_actions.add_child(action_title)
	if not process is FlowConstructorDefinition:
		_add_button(process_actions, "Move " + prefix + " Up", func() -> void: process_move_requested.emit(-1))
		_add_button(process_actions, "Move " + prefix + " Down", func() -> void: process_move_requested.emit(1))
		_add_button(process_actions, "Delete " + prefix, func() -> void: process_delete_requested.emit())

	_list = ItemList.new()
	_list.name = &"ReadyBlocksList"
	_list.focus_mode = Control.FOCUS_ALL
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.allow_reselect = true
	for block: FlowBlock in process.blocks:
		var index: int = _list.add_item(_block_display_name(block) if block != null else "Empty")
		_list.set_item_metadata(index, block.get_internal_id() if block != null else "")
		_list.set_item_tooltip(index, "")
		if block != null and block.get_internal_id() == _block_id:
			_list.select(index)
	_list.item_selected.connect(_on_selected)
	_list.item_activated.connect(_on_activated)
	_list.gui_input.connect(_on_block_list_input)
	primary_parent.add_child(_list)

	var font: Font = _list.get_theme_font(&"font")
	var line_height: float = font.get_height(_list.get_theme_font_size(&"font_size")) + _list.get_theme_constant(&"v_separation")
	_list.custom_minimum_size.y = line_height * 5.0 + _list.get_theme_stylebox(&"panel").get_minimum_size().y

	if not _split_block_layout:
		_details = VBoxContainer.new()
		add_child(_details)

	_render_block()


func _current() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(_controller) \
		and _controller.flow_graph == _graph and _commands.find_block_container(_controller, _process_id) != null


func _container_label(container: FlowBlockContainer) -> String:
	if container is FlowConstructorDefinition:
		return "Constructor"
	if container is FlowMethodDefinition:
		return "Method"
	return "Timer" if container is FlowTimerDefinition else "Process"


func _on_name_submitted(value: String) -> void:
	if _current():
		_commands.set_ready_property(_controller, _process_id, "", &"display_name", value)


func _on_name_input(event: InputEvent, input: LineEdit, original: String) -> void:
	if _is_escape(event) and _current():
		input.text = original
		input.accept_event()
		_list.grab_focus()


func _on_enabled(value: bool, block_id: String) -> void:
	if _current():
		_commands.set_ready_property(_controller, _process_id, block_id, &"enabled", value)


func _on_add(type_id: StringName) -> void:
	if _current():
		_block_id = _commands.add_ready_block(_controller, _process_id, type_id)
		if _block_id.is_empty():
			return
		block_selected.emit(_block_id)
		focus_requested.emit(&"ReadyPrintText" if type_id == FlowBlockRegistry.PRINT else &"ReadyBlocksList", false)


func _on_add_call() -> void:
	if _current():
		_block_id = _commands.add_method_call(_controller, _process_id)
		block_selected.emit(_block_id)
		focus_requested.emit(&"ReadyMethodTarget", false)


func _on_interval_changed(value: float) -> void:
	if _current():
		_commands.set_ready_property(_controller, _process_id, "", &"interval_seconds", value)


func _format_timer_interval(interval: SpinBox, value: float) -> void:
	if not is_instance_valid(interval) or not interval.is_inside_tree():
		return
	var input: LineEdit = interval.get_line_edit()
	if is_instance_valid(input) and input.is_inside_tree():
		input.text = "%.2f" % value


func _on_repeat_changed(value: bool) -> void:
	if _current():
		_commands.set_ready_property(_controller, _process_id, "", &"repeat", value)


func _on_selected(index: int) -> void:
	if _split_block_layout:
		commit_block_details_drafts()
	if not _select_block_index(index):
		return
	_render_block()


func _on_activated(index: int) -> void:
	if _split_block_layout:
		commit_block_details_drafts()
	if not _select_block_index(index):
		return
	block_activated.emit(_block_id)
	if _split_block_layout:
		_block_details_open = true
		block_details_visibility_changed.emit(true)
	_render_block()


func _select_block_index(index: int) -> bool:
	if not _current() or index < 0 or index >= _list.item_count:
		return false
	_block_id = _list.get_item_metadata(index) as String
	block_selected.emit(_block_id)
	return true


func navigate_block(direction: int) -> bool:
	if not _current() or _list == null or _list.item_count == 0 or direction == 0:
		return false
	if _split_block_layout:
		commit_block_details_drafts()
	var current_index: int = -1
	for index: int in _list.item_count:
		if (_list.get_item_metadata(index) as String) == _block_id:
			current_index = index
			break
	var next_index: int
	if current_index < 0:
		next_index = 0 if direction > 0 else _list.item_count - 1
	else:
		next_index = posmod(current_index + (1 if direction > 0 else -1), _list.item_count)
	_list.select(next_index)
	if not _select_block_index(next_index):
		return false
	_render_block()
	return true


func is_block_details_open() -> bool:
	return _block_details_open


func open_block_details(block_id: String) -> bool:
	if not _split_block_layout or block_id.is_empty() or _list == null:
		return false
	for index: int in _list.item_count:
		if (_list.get_item_metadata(index) as String) != block_id:
			continue
		_list.select(index)
		if not _select_block_index(index):
			return false
		_block_details_open = true
		block_details_visibility_changed.emit(true)
		_render_block()
		return true
	return false


func close_block_details() -> bool:
	if not _split_block_layout or not _block_details_open:
		return false
	_on_close_block_options()
	return true


func commit_block_details_drafts() -> bool:
	if not _split_block_layout or not _block_details_open or not _current() 			or _details == null or _block_id.is_empty():
		return false
	var changed: bool = false

	var name_input: LineEdit = _details.find_child("ReadyBlockName", true, false) as LineEdit
	if name_input != null:
		var original_name: String = name_input.get_meta(&"flusso_original_text", name_input.text) as String
		if name_input.text != original_name:
			changed = _commands.set_ready_property(
				_controller,
				_process_id,
				_block_id,
				&"display_name",
				name_input.text
			) or changed

	var print_input: TextEdit = _details.find_child("ReadyPrintText", true, false) as TextEdit
	if print_input != null:
		var original_text: String = print_input.get_meta(&"flusso_original_text", print_input.text) as String
		if print_input.text != original_text:
			changed = _commands.set_ready_property(
				_controller,
				_process_id,
				_block_id,
				&"text",
				print_input.text
			) or changed

	return changed


func cycle_block_option_focus(direction: int) -> bool:
	if not _split_block_layout or not _block_details_open or _details == null or direction == 0:
		return false
	var focusable: Array[Control] = []
	_collect_focusable_controls(_details, focusable)
	if focusable.is_empty():
		return false
	var viewport: Viewport = get_viewport()
	var owner: Control = viewport.gui_get_focus_owner() as Control if viewport != null else null
	var current_index: int = focusable.find(owner)
	var next_index: int
	if current_index < 0:
		next_index = 0 if direction > 0 else focusable.size() - 1
	else:
		next_index = posmod(current_index + (1 if direction > 0 else -1), focusable.size())
	focusable[next_index].grab_focus()
	return true


func _collect_focusable_controls(root: Node, result: Array[Control]) -> void:
	for child: Node in root.get_children():
		if child is Control:
			var control := child as Control
			if control.is_visible_in_tree() and control.focus_mode != Control.FOCUS_NONE:
				result.append(control)
		_collect_focusable_controls(child, result)


func _on_block_list_input(event: InputEvent) -> void:
	if _block_id.is_empty() or not event is InputEventKey:
		return
	var key: InputEventKey = event as InputEventKey
	if key.pressed and not key.echo and key.keycode == KEY_F2:
		_list.accept_event()
		focus_requested.emit(&"ReadyBlockName", true)


func _on_block_name_submitted(value: String, block_id: String) -> void:
	if _current() and block_id == _block_id:
		_commands.set_ready_property(_controller, _process_id, block_id, &"display_name", value)
		focus_requested.emit(&"ReadyBlocksList", false)


func _on_block_name_input(event: InputEvent, input: LineEdit, block_id: String, original: String) -> void:
	if _is_escape(event) and _current() and block_id == _block_id:
		if _split_block_layout:
			return
		input.text = original
		input.accept_event()
		focus_requested.emit(&"ReadyBlocksList", false)


func _render_block() -> void:
	for child: Node in _details.get_children():
		_details.remove_child(child)
		child.queue_free()

	var process: FlowBlockContainer = _commands.find_block_container(_controller, _process_id)
	if process == null:
		if _details_panel != null:
			_details_panel.visible = false
		return

	var selected: FlowBlock = null
	for block: FlowBlock in process.blocks:
		if block != null and block.get_internal_id() == _block_id:
			selected = block

	if _details_panel != null:
		_details_panel.visible = _block_details_open and selected != null

	if selected == null:
		return

	if _split_block_layout:
		var header := HBoxContainer.new()
		header.name = &"BlockOptionsHeader"
		_details.add_child(header)
		var options_title := Label.new()
		options_title.name = &"FlussoPanelTitle"
		options_title.text = "Flusso"
		options_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		header.add_child(options_title)
		var close_button := Button.new()
		close_button.name = &"CloseBlockOptions"
		close_button.text = "✕"
		close_button.tooltip_text = "Cerrar opciones del bloque"
		close_button.focus_mode = Control.FOCUS_ALL
		close_button.custom_minimum_size = Vector2(44.0, 44.0)
		close_button.pressed.connect(_on_close_block_options)
		header.add_child(close_button)

	var name_label: Label = Label.new()
	name_label.text = "Block Name"
	_details.add_child(name_label)
	var name_input: LineEdit = LineEdit.new()
	name_input.name = &"ReadyBlockName"
	name_input.focus_mode = Control.FOCUS_ALL
	name_input.placeholder_text = "Block name"
	name_input.tooltip_text = "Enter applies Block Name. Escape cancels the draft. F2 focuses this field from the block list."
	name_input.text = _block_display_name(selected)
	name_input.set_meta(&"flusso_original_text", name_input.text)
	name_input.text_submitted.connect(_on_block_name_submitted.bind(_block_id))
	name_input.gui_input.connect(_on_block_name_input.bind(name_input, _block_id, name_input.text))
	_details.add_child(name_input)

	var enabled: CheckBox = CheckBox.new()
	enabled.name = &"ReadyBlockEnabled"
	enabled.text = "Block Enabled"
	enabled.button_pressed = selected.enabled
	enabled.toggled.connect(_on_enabled.bind(_block_id))
	_details.add_child(enabled)

	var actions: HBoxContainer = HBoxContainer.new()
	_details.add_child(actions)
	_add_button(actions, "Move Block Up", _on_move.bind(-1))
	_add_button(actions, "Move Block Down", _on_move.bind(1))
	_add_button(actions, "Delete Block", _on_delete)

	if selected is FlowMethodCallBlock:
		_render_method_target(selected as FlowMethodCallBlock)

	if selected is FlowPrintBlock:
		var label: Label = Label.new()
		label.text = "Print text (Ctrl+Enter to apply)"
		_details.add_child(label)
		var input: TextEdit = TextEdit.new()
		input.name = &"ReadyPrintText"
		input.tooltip_text = "Enter inserts a new line. Ctrl+Enter confirms Print. Escape cancels the draft."
		input.focus_mode = Control.FOCUS_ALL
		input.text = (selected as FlowPrintBlock).text
		input.set_meta(&"flusso_original_text", input.text)
		input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		input.custom_minimum_size.y = input.get_theme_font(&"font").get_height(input.get_theme_font_size(&"font_size")) * 3.0 + input.get_theme_stylebox(&"normal").get_minimum_size().y
		_apply_themed_print_text_surface(input)
		input.gui_input.connect(_on_text_input.bind(input, _block_id, input.text))
		_details.add_child(input)


func _on_close_block_options() -> void:
	if not _split_block_layout:
		return
	commit_block_details_drafts()
	_block_details_open = false
	if _details_panel != null:
		_details_panel.visible = false
	block_details_visibility_changed.emit(false)


func _render_method_target(call: FlowMethodCallBlock) -> void:
	var label: Label = Label.new()
	label.text = "Method"
	_details.add_child(label)
	var target: OptionButton = OptionButton.new()
	target.name = &"ReadyMethodTarget"
	target.focus_mode = Control.FOCUS_ALL
	target.add_item("Select a method" if call.method_id.is_empty() else "Missing or invalid method")
	target.set_item_metadata(0, call.method_id)
	for method: FlowMethodDefinition in _graph.methods:
		if method == null:
			continue
		var index: int = target.item_count
		target.add_item(method.display_name)
		target.set_item_metadata(index, method.get_internal_id())
		if method.get_internal_id() == call.method_id:
			target.select(index)
	target.item_selected.connect(_on_method_target_selected.bind(target, call.get_internal_id()))
	target.gui_input.connect(_on_method_target_input.bind(target))
	_details.add_child(target)


func _on_method_target_input(event: InputEvent, target: OptionButton) -> void:
	if _is_escape(event) and _current() and not target.get_popup().visible:
		if _split_block_layout:
			return
		target.accept_event()
		_list.grab_focus()


func _on_method_target_selected(index: int, target: OptionButton, block_id: String) -> void:
	if _current() and block_id == _block_id and index > 0 and index < target.item_count:
		_commands.set_ready_property(_controller, _process_id, block_id, &"method_id", target.get_item_metadata(index))


func _block_display_name(block: FlowBlock) -> String:
	if not block.display_name.strip_edges().is_empty():
		return block.display_name
	var default_name: String = FlowBlockRegistry.default_display_name(block)
	return default_name if not default_name.is_empty() else "Block"


## Creates a subtle contrast from the active editor theme without imposing a fixed palette.
func _apply_themed_print_text_surface(input: TextEdit) -> void:
	var inherited: StyleBox = input.get_theme_stylebox(&"normal")
	var surface: StyleBoxFlat = inherited.duplicate() as StyleBoxFlat if inherited != null else null
	if surface == null:
		surface = StyleBoxFlat.new()
	var foreground: Color = input.get_theme_color(&"font_color")
	surface.bg_color = surface.bg_color.lerp(foreground, 0.08)
	surface.border_color = surface.border_color.lerp(foreground, 0.18)
	surface.border_width_left = maxi(1, surface.border_width_left)
	surface.border_width_top = maxi(1, surface.border_width_top)
	surface.border_width_right = maxi(1, surface.border_width_right)
	surface.border_width_bottom = maxi(1, surface.border_width_bottom)
	input.add_theme_stylebox_override(&"normal", surface)


func _on_text_input(event: InputEvent, input: TextEdit, block_id: String, original: String) -> void:
	if not _current() or block_id != _block_id or not event is InputEventKey:
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		if _split_block_layout:
			return
		input.text = original
		input.accept_event()
		_list.grab_focus()
	elif key.keycode == KEY_ENTER and key.ctrl_pressed:
		input.accept_event()
		_commands.set_ready_property(_controller, _process_id, block_id, &"text", input.text)
		focus_requested.emit(&"ReadyBlocksList", false)


func _on_move(direction: int) -> void:
	if _current():
		_commands.move_ready_block(_controller, _process_id, _block_id, direction)


func _on_delete() -> void:
	if not _current() or is_instance_valid(_confirmation):
		return
	_confirmation = ConfirmationDialog.new()
	_confirmation.name = &"ReadyBlockDeleteConfirmation"
	_confirmation.title = "Delete Block"
	_confirmation.dialog_text = "Delete the selected block?"
	_confirmation.confirmed.connect(_on_delete_confirmed.bind(_block_id))
	_confirmation.canceled.connect(_close_confirmation)
	add_child(_confirmation)
	_confirmation.popup_centered()


func _on_delete_confirmed(block_id: String) -> void:
	_close_confirmation()
	if _current() and block_id == _block_id:
		emit_signal(&"block_delete_requested", block_id)


func _close_confirmation() -> void:
	if is_instance_valid(_confirmation):
		_confirmation.hide()
		_confirmation.queue_free()
	_confirmation = null


func close_transient_interfaces() -> void:
	_close_confirmation()


func _is_escape(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE


func _add_button(parent: Control, title: String, action: Callable) -> void:
	var button: Button = Button.new()
	button.text = title
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(action)
	parent.add_child(button)
