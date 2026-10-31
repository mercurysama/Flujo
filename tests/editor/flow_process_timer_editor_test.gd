@tool
extends SceneTree

const TEMP_PATH: String = "res://.godot/flujo_tests/process_timer_editor.tscn"
const NAME_SEQUENCE_PATH: String = "res://.godot/flujo_tests/process_timer_name_sequence.tres"
var _failures: Array[String] = []
var _host: Control
var _inspector: PVControllerInspectorPlugin
var _property: FlowGraphInspectorProperty
var _drawer: FluoDrawer
var _fluo_property: FlowGraphInspectorProperty
var _controller: PVController
var _history: UndoRedo
var _ready_first_block_display_name: String = ""
var _inspector_activated_container_id: String = ""


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
	_host = Control.new()
	_host.size = Vector2(1700, 900)
	get_root().add_child(_host)
	_inspector = PVControllerInspectorPlugin.new()
	_inspector.set_undo_redo(undo_redo)
	_inspector._parse_property(_controller, TYPE_OBJECT, "flow_graph", PROPERTY_HINT_RESOURCE_TYPE, "FlowGraph", PROPERTY_USAGE_DEFAULT, false)
	_property = _inspector.get("_active_flow_graph_property") as FlowGraphInspectorProperty
	if not _check(_property != null, "Production Inspector creates the relay property."):
		await _cleanup()
		return
	_property.custom_minimum_size.x = 460
	_property.position = Vector2.ZERO
	_property.size = Vector2(460, 900)
	_host.add_child(_property)
	_property.set_object_and_property(_controller, &"flow_graph")
	_drawer = FluoDrawer.new()
	_drawer.configure(undo_redo)
	_drawer.custom_minimum_size.x = 620
	_host.add_child(_drawer)
	_drawer.set_controller(_controller)
	_drawer.open()
	_fluo_property = _drawer.find_child("FluoFlowEditor", true, false) as FlowGraphInspectorProperty
	_fluo_property.schema_3_container_navigation_changed.connect(
		_on_fluo_container_navigation_changed
	)
	_inspector.schema_3_container_activated.connect(_on_inspector_container_activated)
	_inspector.schema_3_variable_selection_changed.connect(_on_inspector_variable_selection_changed)
	_inspector.schema_3_variable_editor_focus_requested.connect(_on_inspector_variable_focus_requested)
	_drawer.schema_3_variable_list_focus_requested.connect(_on_fluo_variable_list_focus_requested)
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
	var auto_focused_process_name: LineEdit = _node(_fluo_property, "ReadyProcessName") as LineEdit
	_check(list.is_selected(0), "Process Add selects its new Inspector row by stable ID.")
	_check(
		auto_focused_process_name != null and auto_focused_process_name.has_focus(),
		"Process Add deliberately relays keyboard focus to the selected Process editor."
	)
	_drawer.set_variable_selection(
		_controller,
		FlowGraphEditorCommands.Collection.PROCESSES,
		process_id
	)
	await _frames()
	var fluo_list_panel: PanelContainer = _node(_fluo_property, "BlockListPanel") as PanelContainer
	var fluo_options_panel: PanelContainer = _node(_fluo_property, "BlockOptionsPanel") as PanelContainer
	_check(fluo_list_panel != null, "Fluo renders the block list in its left internal panel.")
	_check(fluo_options_panel != null and not fluo_options_panel.visible, "Fluo block options start hidden.")
	_fluo_property.focus_flow_entry()
	await _frames()
	var empty_flow_adds: HBoxContainer = _node(_fluo_property, "AddBlockActions") as HBoxContainer
	var empty_flow_first_add: Button = null
	if empty_flow_adds != null and empty_flow_adds.get_child_count() > 0:
		empty_flow_first_add = empty_flow_adds.get_child(0) as Button
	_check(
		empty_flow_first_add != null and empty_flow_first_add.has_focus(),
		"Opening Flow without blocks focuses its first Add block button."
	)
	_check(list.is_selected(0), "Opening Fluo preserves the Inspector Process selection while keyboard focus moves into Flow.")
	_check(_node(_property, "ReadyProcessEditor") == null and _button(_property, "Delete Process") == null, "Inspector has no process configuration or actions.")
	var panel: Control = _node(_fluo_property, "ReadyProcessEditor") as Control
	if not _check(panel != null, "Inspector selection reaches the Fluo drawer. " + _relay_context()):
		return
	var adds: Node = _node(panel, "AddBlockActions")
	var actions: Node = _node(panel, "ProcessActions")
	_check(adds != null and actions != null and actions.get_index() > adds.get_index(), "Process actions are grouped below Add blocks.")
	var instance_id: int = list.get_instance_id()
	list.item_selected.emit(0)
	await _frames()
	_check(_list("Processes").get_instance_id() == instance_id, "Selection keeps the Inspector list mounted.")
	_inspector_activated_container_id = ""
	list.item_activated.emit(0)
	await _frames()
	_check(
		_inspector_activated_container_id == process_id,
		"Double-click activation of the existing Process row requests the Fluo drawer."
	)
	_check(
		_node(_property, "InspectorBlocksList") == null,
		"Inspector does not add a duplicate Blocks section."
	)
	_drawer.focus_variable_editor(_controller, process_id)
	await _frames()
	var name_input: LineEdit = _node(_fluo_property, "ReadyProcessName") as LineEdit
	if not _check(name_input != null, "Fluo exposes process name."):
		return
	_check(name_input.has_focus(), "Explicit Fluo focus reaches process Name.")
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
	if not _press(_fluo_property, "Add Print"):
		return
	await _frames()
	var input: TextEdit = _node(_fluo_property, "ReadyPrintText") as TextEdit
	if not _check(input != null and process.blocks.size() == 1, "Print creates its configurable editor."):
		return
	_drawer.refresh_controller()
	await _frames()
	_fluo_property.focus_flow_entry()
	await _frames()
	_check(_node(_property, "InspectorBlocksList") == null, "Inspector remains limited to its existing container rows.")
	var fluo_blocks: ItemList = _node(_fluo_property, "ReadyBlocksList") as ItemList
	fluo_options_panel = _node(_fluo_property, "BlockOptionsPanel") as PanelContainer
	if not _check(fluo_blocks != null and fluo_blocks.item_count == 1, "Fluo sees the same live block model as Flow."):
		return
	_check(
		fluo_blocks.has_focus() and fluo_blocks.is_selected(0),
		"Opening Flow with blocks focuses and selects its first block."
	)
	_check(fluo_options_panel != null and not fluo_options_panel.visible, "Selecting a process does not open block options.")
	fluo_blocks.item_activated.emit(0)
	await _frames()
	fluo_options_panel = _node(_fluo_property, "BlockOptionsPanel") as PanelContainer
	_check(fluo_options_panel != null and fluo_options_panel.visible, "Activating a block opens the right configuration panel.")
	var flow_title: Label = _node(_fluo_property, "FlowPanelTitle") as Label
	var flusso_title: Label = _node(_fluo_property, "FlussoPanelTitle") as Label
	_check(flow_title != null and flow_title.text == "Flow", "Fluo left panel is titled Flow.")
	_check(flusso_title != null and flusso_title.text == "Flusso", "Fluo right configuration panel is titled Flusso.")
	_check(_node(fluo_options_panel, "ReadyBlockName") != null, "Flusso contains the selected block options.")
	var fluo_options_close: Button = _node(fluo_options_panel, "CloseBlockOptions") as Button
	_check(fluo_options_close != null and fluo_options_close.text == "✕", "Fluo right panel exposes its own close X.")
	_check(fluo_options_close != null and fluo_options_close.custom_minimum_size.x >= 44.0 and fluo_options_close.custom_minimum_size.y >= 44.0, "Block options close X keeps an Android-friendly touch target.")
	if fluo_options_close != null:
		fluo_options_close.pressed.emit()
	_check(fluo_options_panel != null and not fluo_options_panel.visible, "The right-panel X closes only block options.")
	_check(
		fluo_blocks.has_focus() and fluo_blocks.is_selected(0),
		"Closing Flusso returns focus to the selected Flow block."
	)
	fluo_blocks.item_activated.emit(0)
	await _frames()
	fluo_options_panel = _node(_fluo_property, "BlockOptionsPanel") as PanelContainer
	_check(fluo_options_panel != null and fluo_options_panel.visible, "Block options can reopen after using their close X.")
	var fluo_block_name: LineEdit = _node(fluo_options_panel, "ReadyBlockName") as LineEdit
	var fluo_block_enabled: CheckBox = _node(fluo_options_panel, "ReadyBlockEnabled") as CheckBox
	var fluo_print_text: TextEdit = _node(fluo_options_panel, "ReadyPrintText") as TextEdit
	if fluo_block_name != null and fluo_block_enabled != null:
		fluo_block_name.grab_focus()
		_check(_fluo_property.cycle_ready_block_option_focus(1), "Alt+AvPag navigation can advance through block-option controls.")
		_check(fluo_block_enabled.has_focus(), "Forward option navigation moves from Block Name to Block Enabled.")
		_check(_fluo_property.cycle_ready_block_option_focus(-1), "Reverse option navigation can move backward through block-option controls.")
		_check(fluo_block_name.has_focus(), "Reverse option navigation returns to Block Name.")
		fluo_block_enabled.toggled.emit(false)
		await _frames()
		_check(not process.blocks[0].enabled, "Flusso checkbox configuration applies immediately.")
		fluo_options_panel = _node(_fluo_property, "BlockOptionsPanel") as PanelContainer
		fluo_block_name = _node(fluo_options_panel, "ReadyBlockName") as LineEdit
		fluo_print_text = _node(fluo_options_panel, "ReadyPrintText") as TextEdit
	if fluo_block_name != null and fluo_print_text != null:
		fluo_block_name.text = "Live From Flusso"
		fluo_block_name.text_changed.emit(fluo_block_name.text)
		fluo_print_text.text = "Live Flusso text"
		fluo_print_text.text_changed.emit()
	_check(
		(process.blocks[0] as FlowPrintBlock).display_name == "Live From Flusso" 			and (process.blocks[0] as FlowPrintBlock).text == "Live Flusso text",
		"Flusso updates Block Name and Print text immediately before any close action."
	)
	var revert_button: Button = _button(fluo_options_panel, "Revertir")
	_check(revert_button != null, "Flusso exposes a Revertir button.")
	if revert_button != null:
		revert_button.pressed.emit()
	await _frames()
	_check(
		(process.blocks[0] as FlowPrintBlock).display_name == "Print" 			and (process.blocks[0] as FlowPrintBlock).text.is_empty() 			and process.blocks[0].enabled,
		"Revertir restores text and non-text configuration from the Flusso opening snapshot."
	)
	fluo_options_panel = _node(_fluo_property, "BlockOptionsPanel") as PanelContainer
	_check(fluo_options_panel != null and fluo_options_panel.visible, "Revertir keeps Flusso open.")
	fluo_block_name = _node(fluo_options_panel, "ReadyBlockName") as LineEdit
	fluo_print_text = _node(fluo_options_panel, "ReadyPrintText") as TextEdit
	if fluo_block_name != null and fluo_print_text != null:
		fluo_block_name.text = "Persistent From Flusso"
		fluo_block_name.text_changed.emit(fluo_block_name.text)
		fluo_print_text.text = "Persistent Flusso text"
		fluo_print_text.text_changed.emit()
	_check(_fluo_property.close_ready_block_details(), "Escape-level action closes Flusso without deciding whether edits persist.")
	await _frames()
	_check(
		(process.blocks[0] as FlowPrintBlock).display_name == "Persistent From Flusso" 			and (process.blocks[0] as FlowPrintBlock).text == "Persistent Flusso text",
		"Closing Flusso does not change or roll back already-live configuration."
	)
	_history.undo()
	_history.undo()
	await _frames()
	_check(
		(process.blocks[0] as FlowPrintBlock).display_name == "Print" 			and (process.blocks[0] as FlowPrintBlock).text.is_empty(),
		"Undo cleanup restores the focal block after the persistence regression."
	)
	fluo_options_panel = _node(_fluo_property, "BlockOptionsPanel") as PanelContainer
	_check(fluo_options_panel != null and not fluo_options_panel.visible, "Closing block details leaves the Fluo list surface available.")
	_check(not _fluo_property.close_ready_block_details(), "A second Escape-level action finds no right panel and can fall through to closing Fluo.")
	fluo_blocks = _node(_fluo_property, "ReadyBlocksList") as ItemList
	fluo_blocks.item_activated.emit(0)
	await _frames()
	input = _node(_fluo_property, "ReadyPrintText") as TextEdit
	_check(input != null and input.tooltip_text.contains("Changes are saved immediately") and input.tooltip_text.contains("Revertir"), "Fluo Print input remains available with live-edit guidance after Flusso persistence.")
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
	var blocks: ItemList = _node(_fluo_property, "ReadyBlocksList") as ItemList
	var block_name: LineEdit = _node(_fluo_property, "ReadyBlockName") as LineEdit
	if not _check(blocks != null and block_name != null, "Selected block exposes an editable Block Name field."):
		return
	_check(blocks.get_item_text(0) == "Print" and block_name.text == "Print", "A legacy unnamed Print block receives its visible default without schema migration.")
	_check(block_name.tooltip_text.contains("Changes are saved immediately") and block_name.tooltip_text.contains("Revertir"), "Flusso Block Name documents live editing and Revertir.")
	block_name.text = "Named Ready Print"
	block_name.text_changed.emit(block_name.text)
	await _frames()
	blocks = _node(_fluo_property, "ReadyBlocksList") as ItemList
	block_name = _node(_fluo_property, "ReadyBlockName") as LineEdit
	_check(
		(process.blocks[0] as FlowPrintBlock).display_name == "Named Ready Print" \
			and _history.get_current_action_name().begins_with("Edit Flusso") \
			and blocks != null and blocks.is_selected(0),
		"Flusso Block Name edits live through the stable block ID and keeps selection."
	)
	_history.undo()
	await _frames()
	_check((process.blocks[0] as FlowPrintBlock).display_name.is_empty(), "Undo restores the legacy unnamed block value literally.")
	_history.redo()
	await _frames()
	block_name = _node(_fluo_property, "ReadyBlockName") as LineEdit
	if not _check(block_name != null, "Block Name survives Undo/Redo rebuilds."):
		return
	block_name.text = "Persistent Ready Block Name"
	block_name.text_changed.emit(block_name.text)
	await _frames()
	blocks = _node(_fluo_property, "ReadyBlocksList") as ItemList
	_check((process.blocks[0] as FlowPrintBlock).display_name == "Persistent Ready Block Name" and blocks != null and blocks.is_selected(0), "Flusso Block Name remains live before the panel closes.")
	_check(_fluo_property.close_ready_block_details(), "Closing Flusso provides the Escape-level boundary for live Block Name edits.")
	await _frames()
	blocks = _node(_fluo_property, "ReadyBlocksList") as ItemList
	_check((process.blocks[0] as FlowPrintBlock).display_name == "Persistent Ready Block Name" and blocks != null and blocks.has_focus() and blocks.is_selected(0), "Closing Flusso preserves the live Block Name and returns to the same Flow row.")
	blocks.item_activated.emit(0)
	await _frames()
	var reopened_options: PanelContainer = _node(_fluo_property, "BlockOptionsPanel") as PanelContainer
	_check(reopened_options != null and reopened_options.visible, "Flow activation reopens Flusso for the same stable block ID.")

	blocks.gui_input.emit(_key(KEY_F2))
	await _frames()
	block_name = _node(_fluo_property, "ReadyBlockName") as LineEdit
	_check(
		block_name != null and block_name.has_focus() and block_name.has_selection() \
			and block_name.get_selection_from_column() == 0 and block_name.get_selection_to_column() == block_name.text.length(),
		"F2 on the selected block focuses Block Name with its complete text selected."
	)
	input = _node(_fluo_property, "ReadyPrintText") as TextEdit
	if not _check(input != null, "Print text remains available after Block Name editing."):
		return
	input.text = "Live Print text"
	input.text_changed.emit()
	await _frames()
	blocks = _node(_fluo_property, "ReadyBlocksList") as ItemList
	_check((process.blocks[0] as FlowPrintBlock).text == "Live Print text" and blocks != null and blocks.is_selected(0), "Flusso Print text edits apply immediately to the selected stable block.")
	_check(_fluo_property.close_ready_block_details(), "Closing Flusso leaves live Print text in the model.")
	await _frames()
	_check((process.blocks[0] as FlowPrintBlock).text == "Live Print text", "Closing Flusso does not roll back live Print text.")
	_history.undo()
	await _frames()
	_check(process.blocks[0].get_internal_id() == block_id and (process.blocks[0] as FlowPrintBlock).text == "", "Undo preserves selected block identity and restores live Print text.")
	_history.redo()
	await _frames()
	_check((process.blocks[0] as FlowPrintBlock).text == "Live Print text", "Redo restores live Print text without changing block identity.")
	if not _press(_fluo_property, "Add Everything Flows"):
		return
	await _frames()
	blocks = _node(_fluo_property, "ReadyBlocksList") as ItemList
	if not _check(blocks != null and blocks.item_count == 2, "Everything Flows appends one row."):
		return
	_check(blocks.has_focus() and blocks.is_selected(1), "Everything Flows Add focuses its new row.")
	_drawer.refresh_controller()
	await _frames()
	fluo_blocks = _node(_fluo_property, "ReadyBlocksList") as ItemList
	_check(fluo_blocks != null and fluo_blocks.item_count == 2, "Fluo refresh keeps both blocks visible.")
	fluo_blocks.select(0)
	fluo_blocks.item_selected.emit(0)
	_check(_fluo_property.navigate_ready_block(1), "Ctrl+AvPag navigation advances to the next Flow block.")
	_check(
		_selected_ready_block_id(fluo_blocks) == process.blocks[1].get_internal_id(),
		"Ctrl+AvPag selects the next block by stable ID (actual=%s expected=%s)." % [
			_selected_ready_block_id(fluo_blocks), process.blocks[1].get_internal_id()
		]
	)
	_check(fluo_blocks.has_focus(), "Flow regains keyboard focus after changing blocks.")
	fluo_blocks.item_activated.emit(1)
	await _frames()
	_check(_fluo_property.close_ready_block_details(), "Escape-level close can close Flusso while the second Flow block is selected.")
	await _frames()
	fluo_blocks = _node(_fluo_property, "ReadyBlocksList") as ItemList
	_check(
		fluo_blocks != null and fluo_blocks.has_focus() 			and _selected_ready_block_id(fluo_blocks) == process.blocks[1].get_internal_id(),
		"Closing Flusso restores keyboard focus to the same selected Flow block after rebuild."
	)
	fluo_blocks.item_activated.emit(1)
	await _frames()
	fluo_blocks = _node(_fluo_property, "ReadyBlocksList") as ItemList
	_check(_fluo_property.navigate_ready_block(1), "A second Ctrl+AvPag navigation still works without restoring focus manually.")
	_check(_selected_ready_block_id(fluo_blocks) == process.blocks[0].get_internal_id(), "Block navigation is circular.")
	_check(fluo_blocks.has_focus(), "Repeated Flow navigation keeps keyboard focus on the block list.")
	_check(_fluo_property.close_ready_block_details(), "Close Flusso before testing keyboard activation from Flow.")
	await _frames()
	fluo_blocks = _node(_fluo_property, "ReadyBlocksList") as ItemList
	fluo_blocks.select(1)
	fluo_blocks.item_selected.emit(1)
	fluo_blocks.grab_focus()
	fluo_blocks.item_activated.emit(1)
	await _frames()
	fluo_options_panel = _node(_fluo_property, "BlockOptionsPanel") as PanelContainer
	_check(fluo_options_panel != null and fluo_options_panel.visible, "Activating the selected Flow block opens Flusso.")
	var everything: FlowBlock = process.blocks[1]
	_press(_fluo_property, "Move Block Up")
	await _frames()
	blocks = _node(_fluo_property, "ReadyBlocksList") as ItemList
	_check(process.blocks[0] == everything and blocks != null and blocks.is_selected(0), "Move retains semantic selection by ID.")
	_press(_fluo_property, "Delete Block")
	var confirmation: ConfirmationDialog = _node(_fluo_property, "ReadyBlockDeleteConfirmation") as ConfirmationDialog
	if not _check(confirmation != null and process.blocks.size() == 2, "Delete waits for confirmation in Flow."):
		return
	confirmation.confirmed.emit()
	await _frames()
	_check(process.blocks.size() == 1, "Confirmed block removal updates model.")
	_history.undo()
	await _frames()
	blocks = _node(_fluo_property, "ReadyBlocksList") as ItemList
	_check(blocks != null and blocks.is_selected(0) and process.blocks[0] == everything, "Delete Undo restores semantic selection.")
	_check(_count(_fluo_property, "ReadyBlocksList") == 1, "Rebuilds never duplicate block lists.")
	_drawer.set_variable_selection(
		_controller,
		FlowGraphEditorCommands.Collection.PROCESSES,
		process_id
	)
	_check(_fluo_property.navigate_process(1), "Plain AvPag navigation advances to the next Inspector Process.")
	await _frames()
	_check(
		(_fluo_property.get("_selected_id") as String) == _controller.flow_graph.processes[1].get_internal_id(),
		"Inspector-level Page navigation updates Fluo's container context by stable ID."
	)
	var inspector_processes: ItemList = _list("Processes")
	_check(
		inspector_processes != null and inspector_processes.is_selected(1),
		"Inspector redraws its visible selection to the Process reached by Page navigation."
	)
	fluo_blocks = _node(_fluo_property, "ReadyBlocksList") as ItemList
	var navigated_flow_adds: HBoxContainer = _node(_fluo_property, "AddBlockActions") as HBoxContainer
	var navigated_first_add: Button = null
	if navigated_flow_adds != null and navigated_flow_adds.get_child_count() > 0:
		navigated_first_add = navigated_flow_adds.get_child(0) as Button
	_check(
		(fluo_blocks != null and fluo_blocks.item_count > 0 and fluo_blocks.has_focus()) \
			or (fluo_blocks != null and fluo_blocks.item_count == 0 \
				and navigated_first_add != null and navigated_first_add.has_focus()),
		"After Inspector-level Page navigation, Flow focuses its first block or first Add button according to container contents."
	)
	_check(_fluo_property.navigate_process(-1), "Plain RePag navigation returns to the previous Inspector Process.")
	await _frames()
	_check(
		(_fluo_property.get("_selected_id") as String) == process_id,
		"Inspector-level Page navigation is reversible."
	)
	inspector_processes = _list("Processes")
	_check(
		inspector_processes != null and inspector_processes.is_selected(0),
		"Inspector redraws back to the previous Process on reverse Page navigation."
	)
	fluo_options_panel = _node(_fluo_property, "BlockOptionsPanel") as PanelContainer
	_check(fluo_options_panel != null and not fluo_options_panel.visible, "Changing Inspector Process closes stale Flusso options.")

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
	var interval: SpinBox = _node(_fluo_property, "TimerInterval") as SpinBox
	var repeat_input: CheckBox = _node(_fluo_property, "TimerRepeat") as CheckBox
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
	interval = _node(_fluo_property, "TimerInterval") as SpinBox
	if not _check(interval != null, "Timer interval survives its action rebuild."):
		return
	interval.value_changed.emit(timer.interval_seconds - interval.custom_arrow_step)
	await _frames()
	_check(is_equal_approx(timer.interval_seconds, 1.0) and _history.get_current_action_name().begins_with("Edit Timer"), "Timer interval arrow-down result commits a Timer-labelled scene action.")
	repeat_input = _node(_fluo_property, "TimerRepeat") as CheckBox
	if not _check(repeat_input != null, "Repeat remains available after rebuild."):
		return
	repeat_input.toggled.emit(true)
	await _frames()
	_check(timer.interval_seconds == 1.0 and timer.repeat and _history.get_current_action_name().begins_with("Edit Timer"), "Timer fields edit the actual definition through Timer-labelled actions.")
	_check(_button(_fluo_property, "Delete Timer") != null and _button(_fluo_property, "Delete Process") == null, "Timer actions have unambiguous labels.")
	_press(_fluo_property, "Move Timer Up")
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
	_press(_fluo_property, "Delete Timer")
	var name_confirmation: ConfirmationDialog = _node(_fluo_property, "FlowGraphDeleteConfirmation") as ConfirmationDialog
	if not _check(name_confirmation != null, "Timer name regression deletes only after confirmation."):
		return
	name_confirmation.confirmed.emit()
	await _frames()
	if not _press(_property, "Add Timer"):
		return
	await _frames()
	var replacement_timer: FlowTimerDefinition = _controller.flow_graph.processes.back() as FlowTimerDefinition
	_check(replacement_timer != null and replacement_timer.display_name == "Flujo 2", "Deleting a Timer leaves the first available Timer suffix collision-free.")
	_press(_fluo_property, "Add Print")
	await _frames()
	var timer_block_name: LineEdit = _node(_fluo_property, "ReadyBlockName") as LineEdit
	_check(_node(_fluo_property, "ReadyPrintText") != null and timer_block_name != null and timer_block_name.text == "Print" and _ready_first_block_display_name == "Print" and _history.get_current_action_name() == "Add Timer Print Block", "Block names begin independently in each Ready or Timer container.")
	if timer_block_name == null:
		return
	timer_block_name.text = "Named Timer Print"
	timer_block_name.text_submitted.emit(timer_block_name.text)
	await _frames()
	_check(
		(replacement_timer.blocks[0] as FlowPrintBlock).display_name == "Named Timer Print" and _history.get_current_action_name() == "Rename Timer Block",
		"Timer Block Name uses the same stable-ID editing path with a Timer-labelled scene action."
	)
	if not _press(_fluo_property, "Add Print"):
		return
	await _frames()
	if not _press(_fluo_property, "Add Print"):
		return
	await _frames()
	if not _press(_fluo_property, "Add Print"):
		return
	await _frames()
	if not _press(_fluo_property, "Add Everything Flows"):
		return
	await _frames()
	if not _press(_fluo_property, "Add Everything Flows"):
		return
	await _frames()
	if not _press(_fluo_property, "Add Everything Flows"):
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
	_press(_fluo_property, "Delete Timer")
	var confirmation: ConfirmationDialog = _node(_fluo_property, "FlowGraphDeleteConfirmation") as ConfirmationDialog
	if not _check(confirmation != null, "Timer Delete requires confirmation."):
		return
	confirmation.confirmed.emit()
	await _frames()
	_check(not _controller.flow_graph.processes.has(replacement_timer) and _history.get_current_action_name() == "Delete Timer", "Delete removes only selected Timer through a Timer-labelled action.")
	_history.undo()
	await _frames()
	var restored_timer_list: ItemList = _list("Timers")
	var restored_timer_id: String = _selected_list_id(restored_timer_list)
	_check(restored_timer_id == replacement_timer.get_internal_id() and _node(_fluo_property, "TimerInterval") != null, "Undo restores Timer selection and panel context.")
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
	_check(_node(_fluo_property, "VariableNameInput") != null and _node(_property, "VariableNameInput") == null, "Variables obey the same panel-only configuration rule.")
	_check(_button(_fluo_property, "Delete Variable") != null and _button(_property, "Delete") == null, "Variable structural actions belong in panel.")


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
	return "Controller in tree=%s; Inspector active=%s; Inspector ID=%s; Fluo ID=%s; Fluo collection=%s" % [
		_controller.is_inside_tree(), _inspector.is_active_controller(_controller), _property.get("_selected_id"),
		_fluo_property.get("_selected_id"), _fluo_property.get("_selected_collection")]


func _on_fluo_container_navigation_changed(
	controller: PVController,
	collection: FlowGraphEditorCommands.Collection,
	container_id: String
) -> void:
	_inspector.sync_schema_3_container_selection(
		controller,
		collection,
		container_id
	)


func _on_inspector_container_activated(
	_controller_arg: PVController,
	_collection: FlowGraphEditorCommands.Collection,
	container_id: String
) -> void:
	_inspector_activated_container_id = container_id


func _on_inspector_variable_selection_changed(
	controller: PVController,
	collection: FlowGraphEditorCommands.Collection,
	variable_id: String
) -> void:
	if not _inspector.is_active_controller(controller):
		return
	_drawer.set_variable_selection(controller, collection, variable_id)
	if _selection_context_owns_focus(controller):
		_drawer.focus_variable_editor(controller, variable_id)


func _on_inspector_variable_focus_requested(controller: PVController, variable_id: String) -> void:
	if not _inspector.is_active_controller(controller):
		return
	_drawer.set_variable_selection(
		controller,
		_collection_for_id(controller, variable_id),
		variable_id
	)
	_drawer.focus_variable_editor(controller, variable_id)


func _on_fluo_variable_list_focus_requested(controller: PVController, variable_id: String) -> void:
	if _inspector.is_active_controller(controller):
		_inspector.focus_schema_3_variable_list(controller, variable_id)


func _collection_for_id(controller: PVController, variable_id: String) -> FlowGraphEditorCommands.Collection:
	if controller == null or controller.flow_graph == null:
		return FlowGraphEditorCommands.Collection.VARIABLES
	if controller.flow_graph.constructor != null \
			and controller.flow_graph.constructor.get_internal_id() == variable_id:
		return FlowGraphEditorCommands.Collection.CONSTRUCTOR
	for process: FlowProcess in controller.flow_graph.processes:
		if process != null and process.get_internal_id() == variable_id:
			return FlowGraphEditorCommands.Collection.PROCESSES
	for method: FlowMethodDefinition in controller.flow_graph.methods:
		if method != null and method.get_internal_id() == variable_id:
			return FlowGraphEditorCommands.Collection.METHODS
	return FlowGraphEditorCommands.Collection.VARIABLES


func _selection_context_owns_focus(controller: PVController) -> bool:
	if _inspector.owns_focus(controller):
		return true
	var viewport: Viewport = _property.get_viewport() if _property != null else null
	var focus_owner: Control = viewport.gui_get_focus_owner() as Control if viewport != null else null
	if not is_instance_valid(focus_owner):
		return true
	return _drawer != null and (_drawer == focus_owner or _drawer.is_ancestor_of(focus_owner))


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


func _selected_ready_block_id(list: ItemList) -> String:
	if list == null:
		return ""
	var selected: PackedInt32Array = list.get_selected_items()
	if selected.size() != 1:
		return ""
	return list.get_item_metadata(selected[0]) as String


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
	if is_instance_valid(_drawer):
		_drawer.set_controller(null)
	if is_instance_valid(_host):
		_host.queue_free()
	await _frames()
	_drawer = null
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
