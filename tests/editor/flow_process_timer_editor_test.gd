@tool
extends SceneTree

const TEMP_PATH: String = "res://.godot/flujo_tests/process_timer_editor.tscn"
const NAME_SEQUENCE_PATH: String = "res://.godot/flujo_tests/process_timer_name_sequence.tres"
const PLUGIN: Script = preload("res://addons/vp_flujo/plugin.gd")
var _failures: Array[String] = []
var _host: HBoxContainer
var _plugin: EditorPlugin
var _inspector: PVControllerInspectorPlugin
var _property: FlowGraphInspectorProperty
var _dock: VPFlujoDock
var _controller: PVController
var _history: UndoRedo
var _ready_first_block_display_name: String = ""


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	# Finish the editor startup/layout restoration before opening our fixture scene.
	await _frames()
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	await _frames()
	var fixture: PVController = PVController.new()
	fixture.name = "ProcessTimerFixture"
	fixture.flow_graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	fixture.flow_graph.constructor = FlowConstructorDefinition.new()
	var state_machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	state_machine.display_name = "Existing State Machine"
	fixture.flow_graph.state_machines = [state_machine]
	var packed: PackedScene = PackedScene.new()
	_check(packed.pack(fixture) == OK, "Pack focal scene.")
	fixture.free()
	_check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/flujo_tests")) == OK, "Create scoped test folder.")
	if not _check(ResourceSaver.save(packed, TEMP_PATH) == OK, "Save focal scene."):
		_finish()
		return
	EditorInterface.open_scene_from_path(TEMP_PATH)
	await _frames()
	_controller = EditorInterface.get_edited_scene_root() as PVController
	if not _check(_controller != null and _controller.scene_file_path == TEMP_PATH, "Edit only the temporary controller scene."):
		_finish()
		return
	var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	_history = undo_redo.get_history_undo_redo(undo_redo.get_object_history_id(_controller))
	_host = HBoxContainer.new()
	_host.size = Vector2(1100, 900)
	get_root().add_child(_host)
	_inspector = PVControllerInspectorPlugin.new()
	_inspector.set_undo_redo(undo_redo)
	_inspector._parse_property(_controller, TYPE_OBJECT, "flow_graph", PROPERTY_HINT_RESOURCE_TYPE, "FlowGraph", PROPERTY_USAGE_DEFAULT, false)
	_property = _inspector.get("_active_flow_graph_property") as FlowGraphInspectorProperty
	if not _check(_property != null, "Production Inspector creates the relay property."):
		await _cleanup()
		return
	_property.custom_minimum_size.x = 460
	_host.add_child(_property)
	_property.set_object_and_property(_controller, &"flow_graph")
	_dock = VPFlujoDock.new()
	_dock.configure(undo_redo)
	_dock.custom_minimum_size.x = 500
	_host.add_child(_dock)
	_dock.set("_controller_presence_initialized", true)
	_dock.set("_controller_present", true)
	_plugin = PLUGIN.new()
	_plugin.set("_dock", _dock)
	_plugin.set("_controller_inspector_plugin", _inspector)
	_inspector.schema_3_variable_selection_changed.connect(Callable(_plugin, &"_on_schema_3_variable_selection_changed"))
	_inspector.schema_3_variable_editor_focus_requested.connect(Callable(_plugin, &"_on_schema_3_variable_editor_focus_requested"))
	_dock.schema_3_variable_list_focus_requested.connect(Callable(_plugin, &"_on_schema_3_variable_list_focus_requested"))
	await _frames()
	_check(
		_schema_3_section_titles() == ["Processes", "Timers", "State Machines", "Variables"],
		"Schema 3 Inspector presents collections in the Process, Timer, State Machine, Variable order."
	)
	await _test_process()
	await _test_timer_and_variable()
	await _test_semantic_process_timer_names()
	await _cleanup()


func _test_process() -> void:
	if not _press(_property, "Add Process"):
		return
	await _frames()
	var list: ItemList = _list("Processes")
	if not _check(list != null and list.item_count == 1, "Process Add creates one Inspector row."):
		return
	var state_machine_list: ItemList = _list("State Machines")
	_check(
		state_machine_list != null and state_machine_list.item_count == 1 and _button(_property, "Add State Machine") != null,
		"Schema 3 Inspector retains the existing State Machines collection without adding its editor."
	)
	var process: FlowProcess = _controller.flow_graph.processes[0]
	var process_id: String = process.get_internal_id()
	_check(list.has_focus() and list.is_selected(0), "Process Add focuses and selects its row.")
	_check(_node(_property, "ReadyProcessEditor") == null and _button(_property, "Delete Process") == null, "Inspector has no process configuration or actions.")
	var panel: Control = _node(_dock, "ReadyProcessEditor") as Control
	if not _check(panel != null, "Public Add relays through Inspector plugin and main plugin to dock. " + _relay_context()):
		return
	var adds: Node = _node(panel, "AddBlockActions")
	var actions: Node = _node(panel, "ProcessActions")
	_check(adds != null and actions != null and actions.get_index() > adds.get_index(), "Process actions are grouped below Add blocks.")
	var instance_id: int = list.get_instance_id()
	list.item_selected.emit(0)
	await _frames()
	_check(_list("Processes").get_instance_id() == instance_id, "Selection keeps the Inspector list mounted.")
	list.item_activated.emit(0)
	await _frames()
	var name_input: LineEdit = _node(_dock, "ReadyProcessName") as LineEdit
	if not _check(name_input != null, "Dock exposes process name."):
		return
	_check(name_input.has_focus(), "Enter explicitly focuses process Name through the relay.")
	name_input.text_submitted.emit("Startup")
	await _frames()
	_check(process.display_name == "Startup" and process.get_internal_id() == process_id, "Process Name uses its stable ID.")
	for index: int in 3:
		if not _press(_property, "Add Process"):
			return
		await _frames()
	_check(
		_controller.flow_graph.processes[0].display_name == "Startup" \
			and _controller.flow_graph.processes[1].display_name == "Flujo" \
			and _controller.flow_graph.processes[2].display_name == "Flujo 1" \
			and _controller.flow_graph.processes[3].display_name == "Flujo 2",
		"Schema 3 Processes use their own base, 1, 2 naming sequence without renaming persisted names."
	)
	list = _list("Processes")
	if list == null:
		return
	list.select(0)
	list.item_selected.emit(0)
	await _frames()
	if not _press(_dock, "Add Print"):
		return
	await _frames()
	var input: TextEdit = _node(_dock, "ReadyPrintText") as TextEdit
	if not _check(input != null and process.blocks.size() == 1, "Print creates its configurable editor."):
		return
	_check(input.has_focus() and input.tooltip_text.contains("Ctrl+Enter"), "Add Print focuses text and explains confirmation.")
	var print_surface: StyleBoxFlat = input.get_theme_stylebox(&"normal") as StyleBoxFlat
	_check(
		input.has_theme_stylebox_override(&"normal") and print_surface != null \
			and print_surface.bg_color.a > 0.0 and print_surface.border_color.a > 0.0 \
			and print_surface.border_width_left > 0 and print_surface.border_width_top > 0,
		"Print uses a visible TextEdit surface derived from the active editor theme."
	)
	var block_id: String = process.blocks[0].get_internal_id()
	_ready_first_block_display_name = (process.blocks[0] as FlowPrintBlock).display_name
	(process.blocks[0] as FlowPrintBlock).display_name = ""
	_controller.notify_property_list_changed()
	await _frames()
	var blocks: ItemList = _node(_dock, "ReadyBlocksList") as ItemList
	var block_name: LineEdit = _node(_dock, "ReadyBlockName") as LineEdit
	if not _check(blocks != null and block_name != null, "Selected block exposes an editable Block Name field."):
		return
	_check(blocks.get_item_text(0) == "Print" and block_name.text == "Print", "A legacy unnamed Print block receives its visible default without schema migration.")
	_check(block_name.tooltip_text.contains("F2") and block_name.tooltip_text.contains("Enter"), "Block Name documents keyboard confirmation and F2.")
	block_name.text = "Named Ready Print"
	block_name.text_submitted.emit(block_name.text)
	await _frames()
	blocks = _node(_dock, "ReadyBlocksList") as ItemList
	block_name = _node(_dock, "ReadyBlockName") as LineEdit
	_check(
		(process.blocks[0] as FlowPrintBlock).display_name == "Named Ready Print" \
			and _history.get_current_action_name() == "Rename Ready Block" \
			and blocks != null and blocks.is_selected(0) and blocks.has_focus(),
		"Block Name commits through the stable block ID as a Ready-labelled scene action and restores selection."
	)
	_history.undo()
	await _frames()
	_check((process.blocks[0] as FlowPrintBlock).display_name.is_empty(), "Undo restores the legacy unnamed block value literally.")
	_history.redo()
	await _frames()
	block_name = _node(_dock, "ReadyBlockName") as LineEdit
	if not _check(block_name != null, "Block Name survives Undo/Redo rebuilds."):
		return
	block_name.text = "Discarded Ready Block Name"
	block_name.gui_input.emit(_key(KEY_ESCAPE))
	await _frames()
	blocks = _node(_dock, "ReadyBlocksList") as ItemList
	_check((process.blocks[0] as FlowPrintBlock).display_name == "Named Ready Print" and blocks != null and blocks.has_focus() and blocks.is_selected(0), "Block Name Escape discards only the draft and returns to the same block row.")
	blocks.gui_input.emit(_key(KEY_F2))
	await _frames()
	block_name = _node(_dock, "ReadyBlockName") as LineEdit
	_check(
		block_name != null and block_name.has_focus() and block_name.has_selection() \
			and block_name.get_selection_from_column() == 0 and block_name.get_selection_to_column() == block_name.text.length(),
		"F2 on the selected block focuses Block Name with its complete text selected."
	)
	input = _node(_dock, "ReadyPrintText") as TextEdit
	if not _check(input != null, "Print text remains available after Block Name editing."):
		return
	input.text = "Discarded Print text"
	input.gui_input.emit(_key(KEY_ESCAPE))
	await _frames()
	blocks = _node(_dock, "ReadyBlocksList") as ItemList
	_check((process.blocks[0] as FlowPrintBlock).text.is_empty() and blocks != null and blocks.has_focus(), "Print Escape keeps its draft local and returns to the selected block.")
	var version: int = _history.get_version()
	input.text = "Timer and Ready text"
	input.gui_input.emit(_key(KEY_ENTER, true))
	await _frames()
	blocks = _node(_dock, "ReadyBlocksList") as ItemList
	_check(blocks != null and blocks.has_focus() and blocks.is_selected(0), "Ctrl+Enter returns focus to the same block row.")
	_check(_history.get_version() == version + 1 and (process.blocks[0] as FlowPrintBlock).text == "Timer and Ready text", "Print confirms once in scene history.")
	_history.undo()
	await _frames()
	_check(process.blocks[0].get_internal_id() == block_id and (process.blocks[0] as FlowPrintBlock).text == "", "Undo preserves selected block identity.")
	_history.redo()
	await _frames()
	if not _press(_dock, "Add Everything Flows"):
		return
	await _frames()
	blocks = _node(_dock, "ReadyBlocksList") as ItemList
	if not _check(blocks != null and blocks.item_count == 2, "Everything Flows appends one row."):
		return
	_check(blocks.has_focus() and blocks.is_selected(1), "Everything Flows Add focuses its new row.")
	var everything: FlowBlock = process.blocks[1]
	_press(_dock, "Move Block Up")
	await _frames()
	blocks = _node(_dock, "ReadyBlocksList") as ItemList
	_check(process.blocks[0] == everything and blocks != null and blocks.is_selected(0), "Move retains semantic selection by ID.")
	_press(_dock, "Delete Block")
	var confirmation: ConfirmationDialog = _node(_dock, "ReadyBlockDeleteConfirmation") as ConfirmationDialog
	if not _check(confirmation != null and process.blocks.size() == 2, "Delete waits for confirmation in dock."):
		return
	confirmation.confirmed.emit()
	await _frames()
	_check(process.blocks.size() == 1, "Confirmed block removal updates model.")
	_history.undo()
	await _frames()
	blocks = _node(_dock, "ReadyBlocksList") as ItemList
	_check(blocks != null and blocks.is_selected(0) and process.blocks[0] == everything, "Delete Undo restores semantic selection.")
	_check(_count(_dock, "ReadyBlocksList") == 1, "Rebuilds never duplicate block lists.")
	for index: int in 3:
		if not _press(_property, "Add State Machine"):
			return
		await _frames()
	_check(
		_controller.flow_graph.state_machines[0].display_name == "Existing State Machine" \
			and _controller.flow_graph.state_machines[1].display_name == "Flujo" \
			and _controller.flow_graph.state_machines[2].display_name == "Flujo 1" \
			and _controller.flow_graph.state_machines[3].display_name == "Flujo 2",
		"Schema 3 State Machines use an independent base, 1, 2 sequence without renaming persisted entries."
	)


func _test_timer_and_variable() -> void:
	if not _press(_property, "Add Timer"):
		return
	await _frames()
	var list: ItemList = _list("Timers")
	if not _check(list != null and list.item_count == 1, "Timer is presented as its own filtered collection."):
		return
	_check(list.has_focus() and list.is_selected(0), "Timer Add selects and focuses its row.")
	_check(_list("Processes").item_count == 4, "Timer has only one persistent position and no duplicate Process row.")
	var timer: FlowTimerDefinition = _controller.flow_graph.processes.back() as FlowTimerDefinition
	if not _check(timer != null, "Timer is the process subtype in the same graph collection."):
		return
	_check(timer.display_name == "Flujo", "First Timer name is independent from the existing Process name.")
	var interval: SpinBox = _node(_dock, "TimerInterval") as SpinBox
	var repeat_input: CheckBox = _node(_dock, "TimerRepeat") as CheckBox
	if not _check(interval != null and repeat_input != null and _node(_property, "TimerInterval") == null, "Timer settings are exclusively in Flujo panel. " + _relay_context()):
		return
	_check(
		is_equal_approx(interval.step, 0.01),
		"Timer interval step observed %s; expected 0.01." % interval.step
	)
	_check(
		is_equal_approx(interval.custom_arrow_step, 1.0),
		"Timer interval custom arrow step observed %s; expected 1.0." % interval.custom_arrow_step
	)
	var interval_display_text: String = interval.get_line_edit().text
	_check(
		interval_display_text == "1.00",
		"Timer interval display observed '%s' after tree entry; expected '1.00'." % interval_display_text
	)
	interval.value_changed.emit(timer.interval_seconds + interval.custom_arrow_step)
	await _frames()
	_check(is_equal_approx(timer.interval_seconds, 2.0) and _history.get_current_action_name().begins_with("Edit Timer"), "Timer interval arrow-up result commits a Timer-labelled scene action.")
	interval = _node(_dock, "TimerInterval") as SpinBox
	if not _check(interval != null, "Timer interval survives its action rebuild."):
		return
	interval.value_changed.emit(timer.interval_seconds - interval.custom_arrow_step)
	await _frames()
	_check(is_equal_approx(timer.interval_seconds, 1.0) and _history.get_current_action_name().begins_with("Edit Timer"), "Timer interval arrow-down result commits a Timer-labelled scene action.")
	repeat_input = _node(_dock, "TimerRepeat") as CheckBox
	if not _check(repeat_input != null, "Repeat remains available after rebuild."):
		return
	repeat_input.toggled.emit(true)
	await _frames()
	_check(timer.interval_seconds == 1.0 and timer.repeat and _history.get_current_action_name().begins_with("Edit Timer"), "Timer fields edit the actual definition through Timer-labelled actions.")
	_check(_button(_dock, "Delete Timer") != null and _button(_dock, "Delete Process") == null, "Timer actions have unambiguous labels.")
	_press(_dock, "Move Timer Up")
	await _frames()
	_check(_history.get_current_action_name() == "Move Timer", "Timer Move uses a Timer-labelled scene action.")
	if not _press(_property, "Add Timer"):
		return
	await _frames()
	var second_timer: FlowTimerDefinition = _controller.flow_graph.processes.back() as FlowTimerDefinition
	if not _check(second_timer != null and second_timer.display_name == "Flujo 1", "Timer names advance independently from Processes using the first available suffix."):
		return
	if not _press(_property, "Add Timer"):
		return
	await _frames()
	var third_timer: FlowTimerDefinition = _controller.flow_graph.processes.back() as FlowTimerDefinition
	if not _check(third_timer != null and third_timer.display_name == "Flujo 2", "Timers use their own base, 1, 2 naming sequence."):
		return
	_press(_dock, "Delete Timer")
	var name_confirmation: ConfirmationDialog = _node(_dock, "FlowGraphDeleteConfirmation") as ConfirmationDialog
	if not _check(name_confirmation != null, "Timer name regression deletes only after confirmation."):
		return
	name_confirmation.confirmed.emit()
	await _frames()
	if not _press(_property, "Add Timer"):
		return
	await _frames()
	var replacement_timer: FlowTimerDefinition = _controller.flow_graph.processes.back() as FlowTimerDefinition
	_check(replacement_timer != null and replacement_timer.display_name == "Flujo 2", "Deleting a Timer leaves the first available Timer suffix collision-free.")
	_press(_dock, "Add Print")
	await _frames()
	var timer_block_name: LineEdit = _node(_dock, "ReadyBlockName") as LineEdit
	_check(_node(_dock, "ReadyPrintText") != null and timer_block_name != null and timer_block_name.text == "Print" and _ready_first_block_display_name == "Print" and _history.get_current_action_name() == "Add Timer Print Block", "Block names begin independently in each Ready or Timer container.")
	if timer_block_name == null:
		return
	timer_block_name.text = "Named Timer Print"
	timer_block_name.text_submitted.emit(timer_block_name.text)
	await _frames()
	_check(
		(replacement_timer.blocks[0] as FlowPrintBlock).display_name == "Named Timer Print" and _history.get_current_action_name() == "Rename Timer Block",
		"Timer Block Name uses the same stable-ID editing path with a Timer-labelled scene action."
	)
	if not _press(_dock, "Add Print"):
		return
	await _frames()
	if not _press(_dock, "Add Print"):
		return
	await _frames()
	if not _press(_dock, "Add Print"):
		return
	await _frames()
	if not _press(_dock, "Add Everything Flows"):
		return
	await _frames()
	if not _press(_dock, "Add Everything Flows"):
		return
	await _frames()
	if not _press(_dock, "Add Everything Flows"):
		return
	await _frames()
	_check(
		replacement_timer.blocks.size() == 7 \
			and replacement_timer.blocks[1].display_name == "Print" \
			and replacement_timer.blocks[2].display_name == "Print 1" \
			and replacement_timer.blocks[3].display_name == "Print 2" \
			and replacement_timer.blocks[4].display_name == "Everything Flows" \
			and replacement_timer.blocks[5].display_name == "Everything Flows 1" \
			and replacement_timer.blocks[6].display_name == "Everything Flows 2",
		"Automatic block names use independent subtype sequences inside the selected Timer container."
	)
	_press(_dock, "Delete Timer")
	var confirmation: ConfirmationDialog = _node(_dock, "FlowGraphDeleteConfirmation") as ConfirmationDialog
	if not _check(confirmation != null, "Timer Delete requires confirmation."):
		return
	confirmation.confirmed.emit()
	await _frames()
	_check(not _controller.flow_graph.processes.has(replacement_timer) and _history.get_current_action_name() == "Delete Timer", "Delete removes only selected Timer through a Timer-labelled action.")
	_history.undo()
	await _frames()
	var restored_timer_list: ItemList = _list("Timers")
	var restored_timer_id: String = _selected_list_id(restored_timer_list)
	_check(restored_timer_id == replacement_timer.get_internal_id() and _node(_dock, "TimerInterval") != null, "Undo restores Timer selection and panel context.")
	for index: int in 3:
		if not _press(_property, "Add Variable"):
			return
		await _frames()
	await _frames()
	list = _list("Variables")
	if not _check(list != null and list.item_count == 3, "Variable collection remains available."):
		return
	_check(
		_controller.flow_graph.variables[0].display_name == "Flujo" \
			and _controller.flow_graph.variables[1].display_name == "Flujo 1" \
			and _controller.flow_graph.variables[2].display_name == "Flujo 2",
		"Schema 3 Variables use an independent base, 1, 2 sequence."
	)
	list.select(0)
	list.item_selected.emit(0)
	await _frames()
	_check(_node(_dock, "VariableNameInput") != null and _node(_property, "VariableNameInput") == null, "Variables obey the same panel-only configuration rule.")
	_check(_button(_dock, "Delete Variable") != null and _button(_property, "Delete") == null, "Variable structural actions belong in panel.")


func _test_semantic_process_timer_names() -> void:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	_controller.flow_graph = graph
	_controller.notify_property_list_changed()
	await _frames()
	var commands: FlowGraphEditorCommands = FlowGraphEditorCommands.new(EditorInterface.get_editor_undo_redo())
	var first_timer_id: String = commands.add_timer(_controller)
	var second_timer_id: String = commands.add_timer(_controller)
	var first_process_id: String = _add_named_resource(commands, FlowGraphEditorCommands.Collection.PROCESSES)
	var second_process_id: String = _add_named_resource(commands, FlowGraphEditorCommands.Collection.PROCESSES)
	if not _check(
		first_timer_id != "" and second_timer_id != "" and first_process_id != "" and second_process_id != "",
		"Independent Process and Timer naming fixture creates its first four resources."
	):
		return
	_check(
		_process_names(graph, true) == ["Flujo", "Flujo 1"] \
			and _process_names(graph, false) == ["Flujo", "Flujo 1"],
		"Timer Flujo/Flujo 1 and Process Flujo/Flujo 1 use independent visible collections."
	)
	_check(_add_named_resource(commands, FlowGraphEditorCommands.Collection.METHODS) != "", "Interleave a Method without consuming Process names.")
	_check(_add_named_resource(commands, FlowGraphEditorCommands.Collection.STATE_MACHINES) != "", "Interleave a State Machine without consuming Process names.")
	_check(_add_named_resource(commands, FlowGraphEditorCommands.Collection.VARIABLES) != "", "Interleave a Variable without consuming Process names.")
	var third_timer_id: String = commands.add_timer(_controller)
	var third_process_id: String = _add_named_resource(commands, FlowGraphEditorCommands.Collection.PROCESSES)
	if not _check(third_timer_id != "" and third_process_id != "", "Interleaved fixture creates third Timer and Process."):
		return
	_check(
		_process_names(graph, true) == ["Flujo", "Flujo 1", "Flujo 2"] \
			and _process_names(graph, false) == ["Flujo", "Flujo 1", "Flujo 2"],
		"Timer Flujo 2 and Process Flujo 2 ignore Methods, State Machines, Variables, and the opposite Process subtype."
	)
	var third_process: FlowProcess = _process_by_id(graph, third_process_id)
	if not _check(third_process != null and third_process.display_name == "Flujo 2", "The third Process is identifiable before Undo/Redo."):
		return
	_history.undo()
	await _frames()
	_check(_process_by_id(graph, third_process_id) == null and _process_names(graph, false) == ["Flujo", "Flujo 1"], "Undo removes only the third Process and preserves Timer names.")
	_history.redo()
	await _frames()
	third_process = _process_by_id(graph, third_process_id)
	_check(third_process != null and third_process.display_name == "Flujo 2" and _process_names(graph, true) == ["Flujo", "Flujo 1", "Flujo 2"], "Redo restores the same Process ID and independent name sequence.")
	if not _check(ResourceSaver.save(graph, NAME_SEQUENCE_PATH) == OK, "Save independent Process and Timer names."):
		return
	var reopened: FlowGraph = ResourceLoader.load(NAME_SEQUENCE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as FlowGraph
	_check(
		reopened != null and _process_names(reopened, true) == ["Flujo", "Flujo 1", "Flujo 2"] \
			and _process_names(reopened, false) == ["Flujo", "Flujo 1", "Flujo 2"],
		"Save and reopen preserve independent Timer and Process visible names."
	)


func _add_named_resource(commands: FlowGraphEditorCommands, collection: FlowGraphEditorCommands.Collection) -> String:
	var graph: FlowGraph = _controller.flow_graph
	var values: Array = _collection_for_test(graph, collection)
	var size_before: int = values.size()
	if not commands.add_resource(_controller, collection):
		return ""
	values = _collection_for_test(graph, collection)
	var added: Resource = values[values.size() - 1] as Resource if values.size() == size_before + 1 else null
	return _test_internal_id(added)


func _collection_for_test(graph: FlowGraph, collection: FlowGraphEditorCommands.Collection) -> Array:
	match collection:
		FlowGraphEditorCommands.Collection.VARIABLES:
			return graph.variables
		FlowGraphEditorCommands.Collection.STATE_MACHINES:
			return graph.state_machines
		FlowGraphEditorCommands.Collection.METHODS:
			return graph.methods
		_:
			return graph.processes


func _process_names(graph: FlowGraph, timers: bool) -> Array[String]:
	var names: Array[String] = []
	for entry: FlowProcess in graph.processes:
		if entry != null and (entry is FlowTimerDefinition) == timers:
			names.append(entry.display_name)
	return names


func _process_by_id(graph: FlowGraph, internal_id: String) -> FlowProcess:
	for process: FlowProcess in graph.processes:
		if process != null and process.get_internal_id() == internal_id:
			return process
	return null


func _test_internal_id(resource: Resource) -> String:
	if resource is FlowBlockContainer:
		return (resource as FlowBlockContainer).get_internal_id()
	if resource is FlowVariableDefinition:
		return (resource as FlowVariableDefinition).get_internal_id()
	if resource is FlowStateMachineDefinition:
		return (resource as FlowStateMachineDefinition).get_internal_id()
	return ""


func _frames() -> void:
	for index: int in 4:
		await process_frame


func _relay_context() -> String:
	var editor: FlowGraphInspectorProperty = _dock.get_variable_editor()
	return "Controller in tree=%s; Inspector active=%s; Inspector ID=%s; plugin ID=%s; dock ID=%s; dock collection=%s; dock controller matches=%s" % [
		_controller.is_inside_tree(), _inspector.is_active_controller(_controller), _property.get("_selected_id"),
		_plugin.get("_selected_schema_3_variable_id"), editor.get("_selected_id"), editor.get("_selected_collection"),
		editor.get("_dock_controller") == _controller]


func _key(code: Key, ctrl: bool = false) -> InputEventKey:
	var key: InputEventKey = InputEventKey.new()
	key.pressed = true
	key.keycode = code
	key.ctrl_pressed = ctrl
	return key


func _node(root: Node, node_name: String) -> Node:
	return root.find_child(node_name, true, false) if root != null else null


func _button(root: Node, text: String) -> Button:
	if root is Button and (root as Button).text == text:
		return root as Button
	for child: Node in root.get_children():
		var result: Button = _button(child, text)
		if result != null:
			return result
	return null


func _press(root: Node, text: String) -> bool:
	var button: Button = _button(root, text)
	if not _check(button != null, "Public button exists: " + text):
		return false
	button.pressed.emit()
	return true


func _list(title: String) -> ItemList:
	for label: Node in _property.find_children("*", "Label", true, false):
		if (label as Label).text == title:
			for sibling: Node in label.get_parent().get_children():
				if sibling is ItemList:
					return sibling as ItemList
	return null


func _count(root: Node, node_name: String) -> int:
	return root.find_children(node_name, "", true, false).size()


func _schema_3_section_titles() -> Array[String]:
	var titles: Array[String] = []
	var content: VBoxContainer = _property.get("_content") as VBoxContainer
	if content == null:
		return titles
	for category: Node in content.get_children():
		for child: Node in category.get_children():
			if child is Label and (child as Label).text in ["Processes", "Timers", "State Machines", "Variables"]:
				titles.append((child as Label).text)
				break
	return titles


func _selected_list_id(list: ItemList) -> String:
	if list == null:
		return ""
	for index: int in list.item_count:
		if list.is_selected(index):
			var metadata: Dictionary = list.get_item_metadata(index) as Dictionary
			return metadata.get("internal_id", "") as String
	return ""


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_failures.append(message)
		push_error(message)
	return condition


func _cleanup() -> void:
	if is_instance_valid(_dock):
		_dock.set_controller(null)
	if is_instance_valid(_host):
		_host.queue_free()
	await _frames()
	if is_instance_valid(_plugin):
		_plugin.set("_dock", null)
		_plugin.set("_controller_inspector_plugin", null)
		_plugin.free()
	_inspector = null
	if is_instance_valid(_controller) and EditorInterface.get_edited_scene_root() == _controller and _controller.scene_file_path == TEMP_PATH:
		EditorInterface.save_scene()
		EditorInterface.close_scene()
	await _frames()
	_finish()


func _finish() -> void:
	for path: String in [TEMP_PATH, NAME_SEQUENCE_PATH]:
		if FileAccess.file_exists(path):
			_check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK, "Remove focal temporary file: " + path)
	if _failures.is_empty():
		print("[Flujo] Process and Timer editor focal passed")
	quit(0 if _failures.is_empty() else 1)
