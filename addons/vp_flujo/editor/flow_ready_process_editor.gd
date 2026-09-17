@tool
class_name FlowReadyProcessEditor
extends VBoxContainer

## A small Inspector surface for one existing Ready process. All writes go through commands.
signal block_selected(block_id: String)

var _commands: FlowGraphEditorCommands
var _controller: PVController
var _graph: FlowGraph
var _process_id: String
var _block_id: String
var _list: ItemList
var _details: VBoxContainer
var _confirmation: ConfirmationDialog


func configure(commands: FlowGraphEditorCommands, controller: PVController, process: FlowProcess, block_id: String) -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_commands = commands
	_controller = controller
	_graph = controller.flow_graph
	_process_id = process.get_internal_id()
	_block_id = block_id
	name = &"ReadyProcessEditor"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title: Label = Label.new()
	title.text = "Ready — runs once"
	add_child(title)
	var name_input: LineEdit = LineEdit.new()
	name_input.name = &"ReadyProcessName"
	name_input.text = process.display_name
	name_input.placeholder_text = "Process name"
	name_input.focus_mode = Control.FOCUS_ALL
	name_input.text_submitted.connect(_on_name_submitted)
	name_input.gui_input.connect(_on_name_input.bind(name_input, process.display_name))
	add_child(name_input)
	var enabled: CheckBox = CheckBox.new()
	enabled.name = &"ReadyProcessEnabled"
	enabled.text = "Process Enabled"
	enabled.button_pressed = process.enabled
	enabled.toggled.connect(_on_enabled.bind(""))
	add_child(enabled)
	var add_row: HBoxContainer = HBoxContainer.new()
	add_child(add_row)
	_add_button(add_row, "Add Print", _on_add.bind(true))
	_add_button(add_row, "Add Everything Flows", _on_add.bind(false))
	_list = ItemList.new()
	_list.name = &"ReadyBlocksList"
	_list.focus_mode = Control.FOCUS_ALL
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.allow_reselect = true
	for block: FlowBlock in process.blocks:
		var index: int = _list.add_item(block.display_name if block != null else "Empty")
		_list.set_item_metadata(index, block.get_internal_id() if block != null else "")
		_list.set_item_tooltip(index, "")
		if block != null and block.get_internal_id() == _block_id:
			_list.select(index)
	_list.item_selected.connect(_on_selected)
	add_child(_list)
	var font: Font = _list.get_theme_font(&"font")
	var line_height: float = font.get_height(_list.get_theme_font_size(&"font_size")) + _list.get_theme_constant(&"v_separation")
	_list.custom_minimum_size.y = line_height * 5.0 + _list.get_theme_stylebox(&"panel").get_minimum_size().y
	_details = VBoxContainer.new()
	add_child(_details)
	_render_block()


func _current() -> bool:
	return is_inside_tree() and not is_queued_for_deletion() and is_instance_valid(_controller) \
		and _controller.flow_graph == _graph and _commands.find_ready_process(_controller, _process_id) != null


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


func _on_add(print_block: bool) -> void:
	if _current():
		_block_id = _commands.add_ready_block(_controller, _process_id, print_block)
		block_selected.emit(_block_id)


func _on_selected(index: int) -> void:
	if not _current() or index < 0 or index >= _list.item_count:
		return
	_block_id = _list.get_item_metadata(index) as String
	block_selected.emit(_block_id)
	_render_block()


func _render_block() -> void:
	for child: Node in _details.get_children():
		_details.remove_child(child)
		child.queue_free()
	var process: FlowProcess = _commands.find_ready_process(_controller, _process_id)
	if process == null:
		return
	var selected: FlowBlock = null
	for block: FlowBlock in process.blocks:
		if block != null and block.get_internal_id() == _block_id:
			selected = block
	if selected == null:
		return
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
	if selected is FlowPrintBlock:
		var label: Label = Label.new()
		label.text = "Print text (Ctrl+Enter to apply)"
		_details.add_child(label)
		var input: TextEdit = TextEdit.new()
		input.name = &"ReadyPrintText"
		input.focus_mode = Control.FOCUS_ALL
		input.text = (selected as FlowPrintBlock).text
		input.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		input.custom_minimum_size.y = input.get_theme_font(&"font").get_height(input.get_theme_font_size(&"font_size")) * 3.0 + input.get_theme_stylebox(&"normal").get_minimum_size().y
		input.gui_input.connect(_on_text_input.bind(input, _block_id, input.text))
		_details.add_child(input)


func _on_text_input(event: InputEvent, input: TextEdit, block_id: String, original: String) -> void:
	if not _current() or block_id != _block_id or not event is InputEventKey:
		return
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo:
		return
	if key.keycode == KEY_ESCAPE:
		input.text = original
		input.accept_event()
		_list.grab_focus()
	elif key.keycode == KEY_ENTER and key.ctrl_pressed:
		input.accept_event()
		_commands.set_ready_property(_controller, _process_id, block_id, &"text", input.text)


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
		_commands.delete_ready_block(_controller, _process_id, block_id)


func _close_confirmation() -> void:
	if is_instance_valid(_confirmation):
		_confirmation.hide()
		_confirmation.queue_free()
	_confirmation = null


func _is_escape(event: InputEvent) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE


func _add_button(parent: Control, title: String, action: Callable) -> void:
	var button: Button = Button.new()
	button.text = title
	button.focus_mode = Control.FOCUS_ALL
	button.pressed.connect(action)
	parent.add_child(button)
