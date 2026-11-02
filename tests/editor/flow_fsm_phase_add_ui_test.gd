@tool
extends SceneTree

## Potok 7F-1B: real Fluo phase Add buttons, catalog and keyboard selection.
const SDK_ROOT: String = "res://tests/fixtures/manual_block_sdk"
const AUTHORING_SCRIPT: Script = preload(
	"res://addons/vp_flujo/editor/flow_editor_block_authoring_context.gd"
)
var failures: Array[String] = []
var _host: Control
var _drawer: FluoDrawer
var _editor: FlowGraphInspectorProperty
var _controller: PVController
var _graph: FlowGraph
var _machine: FlowStateMachineDefinition
var _first: FlowStateDefinition
var _second: FlowStateDefinition
var _ready: FlowProcess
var _history: UndoRedo


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for _i: int in 5:
		await process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if not _check(manager != null, "Godot EditorUndoRedoManager exists"):
		quit(1)
		return
	_host = Control.new()
	_host.name = "Potok7F1BHost"
	_host.size = Vector2(1100, 770)
	get_root().add_child(_host)
	_graph = FlowGraph.new()
	_graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	_graph.constructor = FlowConstructorDefinition.new()
	_first = FlowStateDefinition.new()
	_first.display_name = "A"
	var sentinel := FlowPrintBlock.new()
	sentinel.display_name = "Existing Enter"
	_first.enter_blocks = [null, sentinel]
	var update_seed := FlowPrintBlock.new()
	update_seed.display_name = "Print"
	_first.blocks = [update_seed]
	_second = FlowStateDefinition.new()
	_second.display_name = "B"
	_machine = FlowStateMachineDefinition.new()
	_machine.states = [_first, _second]
	_machine.initial_state_id = _first.get_internal_id()
	var empty_machine := FlowStateMachineDefinition.new()
	_graph.state_machines = [_machine, empty_machine]
	_ready = FlowProcess.new()
	_graph.processes = [_ready]
	_controller = PVController.new()
	_controller.name = "Controller"
	_controller.flow_graph = _graph
	_host.add_child(_controller)
	_history = manager.get_history_undo_redo(manager.get_object_history_id(_controller))
	_check(not FlowGraphValidator.validate(_graph).has_errors(),
		"Seed graph with null phase slot, sibling state and Ready is valid")

	_drawer = FluoDrawer.new()
	EditorInterface.get_base_control().add_child(_drawer)
	_drawer.configure(manager)
	_editor = _drawer.find_child("FluoFlowEditor", true, false) as FlowGraphInspectorProperty
	if not _check(_editor != null, "Original Fluo editor exists"):
		await _finish()
		return
	var context: RefCounted = AUTHORING_SCRIPT.new(SDK_ROOT) as RefCounted
	_editor.configure(manager, context)
	_drawer.open_container(
		_controller, FlowGraphEditorCommands.Collection.STATE_MACHINES,
		_machine.get_internal_id()
	)
	await _frames(6)
	if not _check(_drawer.is_open() and _state_id() == _first.get_internal_id()
			and _editor.get("_authoring_context") == context,
			"Real Fluo uses same injected catalog and selects original state"):
		await _finish()
		return

	var expected_ids: Array[String] = [
		"print", "everything_flows", "custom_hello", "manual_output:output"
	]
	var expected_names: Array[String] = [
		"Print", "Everything Flows", "Custom Hello", "Manual Output"
	]
	for phase: String in ["Enter", "Update", "Exit"]:
		var list: ItemList = _phase_list(phase)
		var row: HFlowContainer = _phase_actions(phase)
		_check(_drawer.find_child("PotokPhase" + phase, true, false) != null
			and list != null and row != null and row.get_child_count() == 4,
			phase + " renders a native list and one authoring action per catalog entry")
		if row != null:
			for i: int in expected_ids.size():
				var button: Button = row.get_child(i) as Button
				_check(button != null and button.text == "Add " + expected_names[i]
					and button.get_meta(&"authoring_id", "") == expected_ids[i]
					and button.get_meta(&"phase", "") == phase.to_lower(),
					phase + " catalogs exact authoring ID " + expected_ids[i])
	_check(_phase_list("Enter").item_count == 2
		and _phase_list("Enter").is_item_disabled(0)
		and String((_phase_list("Enter").get_item_metadata(0) as Dictionary).get("id", "")) == ""
		and String((_phase_list("Enter").get_item_metadata(1) as Dictionary).get("id", "")) == sentinel.get_internal_id(),
		"Null Enter slot stays a disabled Empty row; surviving block keeps stable ID")
	_check(_phase_list("Exit").item_count == 1
		and _phase_list("Exit").is_item_disabled(0)
		and _button("Exit", "manual_output:output") != null,
		"Empty Exit phase shows only disabled Empty row yet keeps Add available")
	_check(_count_named("PotokPhaseEnterAddActions") == 1
		and _count_named("PotokPhaseUpdateAddActions") == 1
		and _count_named("PotokPhaseExitAddActions") == 1
		and _drawer.find_child("ReadyBlocksList", true, false) == null,
		"Exactly one per-phase authoring surface, with no duplicate Ready/Inspector list")

	var enter_button: Button = _button("Enter", "print")
	if _check(enter_button != null, "Enter built-in catalog button exists"):
		enter_button.grab_focus()
		enter_button.pressed.emit()
		await _frames(6)
	var enter_block: FlowBlock = _first.enter_blocks.back()
	var enter_id: String = enter_block.get_internal_id() if enter_block != null else ""
	_check(not enter_id.is_empty() and _first.enter_blocks.size() == 3
		and _first.enter_blocks[0] == null and _first.enter_blocks[1] == sentinel
		and _first.blocks.size() == 1 and _first.exit_blocks.is_empty()
		and _selected_phase_block_id() == enter_id,
		"Enter Add appends one block and keeps exact phase ID selection")
	_check(_selected_phase() == &"enter" and _selected_row_id("Enter") == enter_id
		and _phase_list("Enter").has_focus(),
		"Enter Add rebuild selects appended block ID and focuses new native Flow list")
	_check(_phase_list("Enter").item_count == 3
		and _phase_list("Enter").is_item_disabled(0),
		"Add never normalizes an authored deliberate null slot")

	var update_button: Button = _button("Update", "print")
	if _check(update_button != null, "Update builtin button exists"):
		update_button.grab_focus()
		update_button.pressed.emit()
		await _frames(6)
	var update_id: String = _first.blocks[1].get_internal_id() if _first.blocks.size() == 2 else ""
	_check(not update_id.is_empty() and _first.blocks[1].display_name != update_seed.display_name
		and _first.enter_blocks.back() == enter_block and _first.exit_blocks.is_empty(),
		"Update Add uses inherited array and phase-local naming without touching Enter")
	_check(_selected_phase() == &"update" and _selected_row_id("Update") == update_id
		and _phase_list("Update").has_focus(),
		"Update Add restores real keyboard focus to correct native list")

	var exit_button: Button = _button("Exit", "manual_output:output")
	if _check(exit_button != null, "Exit external catalog button exists"):
		exit_button.grab_focus()
		exit_button.pressed.emit()
		await _frames(6)
	var external: FlowBlock = _first.exit_blocks[0] if _first.exit_blocks.size() == 1 else null
	var external_id: String = external.get_internal_id() if external != null else ""
	_check(external != null and external.get_script().resource_path.ends_with(
		"/tests/fixtures/manual_block_sdk/manual_output/block.gd"
	) and _first.blocks.size() == 2 and _first.enter_blocks.back() == enter_block,
		"External Exit Add preserves package script and all sibling phase contents")
	_check(_selected_phase() == &"exit" and _selected_row_id("Exit") == external_id
		and _phase_list("Exit").has_focus(),
		"External Exit Add selects its exact stable ID and restores Flow focus")
	_history.undo()
	await _frames(6)
	_check(_first.exit_blocks.is_empty() and _selected_phase_block_id().is_empty()
		and _phase_list("Exit").is_item_disabled(0),
		"Undo external Exit Add clears stale selection and keeps empty phase Add available")
	_history.redo()
	await _frames(6)
	_check(_first.exit_blocks.size() == 1 and _first.exit_blocks[0] == external
		and _selected_row_id("Exit") == external_id,
		"Redo restores exact external resource with stable item metadata ID")
	var saved_enter: FlowBlock = enter_block
	var saved_exit: FlowBlock = external

	# Native selection on a per-phase ItemList tracks the selected resource by ID.
	var enter_list: ItemList = _phase_list("Enter")
	enter_list.grab_focus()
	enter_list.select(1)
	enter_list.item_selected.emit(1)
	_check(_selected_phase() == &"enter"
		and _selected_phase_block_id() == sentinel.get_internal_id()
		and _first.enter_blocks[1] == sentinel,
		"Native phase list selection is read-only and tracks original block by ID")
	enter_list.select(2)
	enter_list.item_selected.emit(2)
	_check(_selected_phase_block_id() == enter_id,
		"Selecting another phase block updates the exact authored ID")

	# A stale button from the old state is allowed to emit before its deferred free:
	# current state ownership guard must prevent editing the previously selected one.
	var stale_button: Button = _button("Enter", "print")
	var state_list: ItemList = _drawer.find_child("PotokStateList", true, false) as ItemList
	if _check(stale_button != null and state_list != null, "State navigation and former Add button exist"):
		state_list.select(1)
		state_list.item_selected.emit(1)
		stale_button.pressed.emit()
		await _frames(6)
		_check(_state_id() == _second.get_internal_id()
			and _second.enter_blocks.is_empty() and _first.enter_blocks.size() == 3,
			"Stale Add signal from prior state cannot edit either authored state")
		_check(_phase_list("Enter") != null and _button("Enter", "print") != null
			and _phase_list("Enter").item_count == 1,
			"New selected state renders independent empty phase Add UI")

	var b_button: Button = _button("Exit", "custom_hello")
	if _check(b_button != null, "Sibling state owns independent catalog actions"):
		b_button.grab_focus()
		b_button.pressed.emit()
		await _frames(6)
		_check(_second.exit_blocks.size() == 1 and _first.exit_blocks[0] == saved_exit
			and _first.enter_blocks.back() == saved_enter
			and _selected_row_id("Exit") == _second.exit_blocks[0].get_internal_id(),
			"Sibling state Add changes only its own exit array and active Flow selection")

	_drawer.open_container(_controller,
		FlowGraphEditorCommands.Collection.STATE_MACHINES,
		_graph.state_machines[1].get_internal_id())
	await _frames(6)
	_check(_drawer.find_child("PotokPhaseEnterAddActions", true, false) == null
		and _drawer.find_child("PotokPhaseUpdateBlocksList", true, false) == null
		and _drawer.find_child("PotokStateList", true, false) != null,
		"Truly empty machine has no phantom phase actions or fabricated state")
	_drawer.open_container(_controller,
		FlowGraphEditorCommands.Collection.STATE_MACHINES, _machine.get_internal_id())
	await _frames(6)
	_check(_selected_phase_block_id().is_empty()
		and _first.enter_blocks.size() == 3
		and _first.exit_blocks.size() == 1
		and _ready.blocks.is_empty()
		and not FlowGraphValidator.validate(_graph).has_errors(),
		"Machine switching clears transient block selection without graph mutation")
	await _finish()


func _phase_actions(name: String) -> HFlowContainer:
	return _drawer.find_child("PotokPhase" + name + "AddActions", true, false) as HFlowContainer


func _phase_list(name: String) -> ItemList:
	return _drawer.find_child("PotokPhase" + name + "BlocksList", true, false) as ItemList


func _button(phase: String, authoring_id: String) -> Button:
	var row: HFlowContainer = _phase_actions(phase)
	if row == null:
		return null
	for candidate: Node in row.get_children():
		var btn: Button = candidate as Button
		if btn != null and btn.get_meta(&"authoring_id", "") == authoring_id:
			return btn
	return null


func _selected_row_id(phase: String) -> String:
	var list: ItemList = _phase_list(phase)
	if list == null or list.get_selected_items().is_empty():
		return ""
	var index: int = list.get_selected_items()[0]
	return String((list.get_item_metadata(index) as Dictionary).get("id", ""))


func _state_id() -> String:
	return String(_editor.get("_potok_selected_state_id"))


func _selected_phase() -> StringName:
	return _editor.get("_potok_selected_phase") as StringName


func _selected_phase_block_id() -> String:
	return String(_editor.get("_potok_selected_phase_block_id"))


func _count_named(name: String) -> int:
	var found: int = 0
	for child: Node in _drawer.find_children(name, "", true, false):
		found += 1
	return found


func _frames(n: int) -> void:
	for _i: int in n:
		await process_frame


func _check(ok: bool, message: String) -> bool:
	if not ok:
		failures.append(message)
		push_error("[Flujo] Potok 7F-1B: " + message)
	return ok


func _finish() -> void:
	if _drawer != null:
		_drawer.close()
		_drawer.set_controller(null)
		_drawer.queue_free()
	if _host != null:
		_host.queue_free()
	await _frames(4)
	if failures.is_empty():
		print("[Flujo] Potok 7F-1B native three-phase Add and Flow selection passed")
	quit(0 if failures.is_empty() else 1)
