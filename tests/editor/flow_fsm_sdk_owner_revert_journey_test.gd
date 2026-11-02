@tool
extends SceneTree

## Potok 7F-1D2B: SDK typed edit/Revertir and ownership changes.
const SDK_ROOT: String = "res://tests/fixtures/property_descriptors"
const AUTHORING: Script = preload("res://addons/vp_flujo/editor/flow_editor_block_authoring_context.gd")
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	for i: int in 5:
		await process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	var context: RefCounted = AUTHORING.new(SDK_ROOT) as RefCounted
	var creation: Object = context.call(&"create_block", "manual_output:output") as Object
	if not _check(creation != null and bool(creation.call(&"is_successful")), "SDK authoring factory works"):
		quit(1)
		return
	var sdk: FlowBlock = creation.get("block") as FlowBlock
	var host := Control.new()
	host.size = Vector2(1100, 770)
	get_root().add_child(host)
	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var first := FlowStateDefinition.new()
	first.enter_blocks = [null, sdk]
	var machine := FlowStateMachineDefinition.new()
	machine.states = [first]
	machine.initial_state_id = first.get_internal_id()
	var second_machine := FlowStateMachineDefinition.new()
	var second_state := FlowStateDefinition.new()
	second_machine.states = [second_state]
	second_machine.initial_state_id = second_state.get_internal_id()
	graph.state_machines = [machine, second_machine]
	var owner := PVController.new()
	owner.flow_graph = graph
	host.add_child(owner)
	var other_graph := FlowGraph.new()
	other_graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	other_graph.constructor = FlowConstructorDefinition.new()
	var foreign_state := FlowStateDefinition.new()
	var foreign_machine := FlowStateMachineDefinition.new()
	foreign_machine.states = [foreign_state]
	foreign_machine.initial_state_id = foreign_state.get_internal_id()
	other_graph.state_machines = [foreign_machine]
	var foreign := PVController.new()
	foreign.flow_graph = other_graph
	host.add_child(foreign)
	var drawer := FluoDrawer.new()
	EditorInterface.get_base_control().add_child(drawer)
	drawer.configure(manager)
	var editor: FlowGraphInspectorProperty = drawer.find_child(
		"FluoFlowEditor", true, false) as FlowGraphInspectorProperty
	editor.configure(manager, context)
	drawer.open_container(owner, FlowGraphEditorCommands.Collection.STATE_MACHINES,
		machine.get_internal_id())
	await _frames(6)
	var list: ItemList = drawer.find_child(
		"PotokPhaseEnterBlocksList", true, false) as ItemList
	if not _check(list != null, "Enter list exists"):
		await _finish(drawer, host)
		return
	list.select(1)
	list.item_selected.emit(1)
	list.item_activated.emit(1)
	await _frames(5)
	var message: TextEdit = drawer.find_child(
		"PotokPhaseGenericmessage", true, false) as TextEdit
	var flag: CheckBox = drawer.find_child(
		"PotokPhaseGenericboolean_value", true, false) as CheckBox
	var ranged: SpinBox = drawer.find_child(
		"PotokPhaseGenericranged_int", true, false) as SpinBox
	var revert: Button = drawer.find_child(
		"PotokPhaseBlockRevert", true, false) as Button
	if not _check(message != null and flag != null and ranged != null and revert != null,
			"Existing generic Flusso presents typed SDK descriptors and Revertir"):
		await _finish(drawer, host)
		return
	var original_message: String = String(sdk.get(&"message"))
	var original_int: int = int(sdk.get(&"ranged_int"))
	var version: UndoRedo = manager.get_history_undo_redo(manager.get_object_history_id(owner))
	message.text = "changed by SDK Flusso"
	message.text_changed.emit()
	flag.button_pressed = false
	flag.toggled.emit(false)
	ranged.value = 8.0
	ranged.value_changed.emit(8.0)
	_check(String(sdk.get(&"message")) == "changed by SDK Flusso"
		and not bool(sdk.get(&"boolean_value"))
		and int(sdk.get(&"ranged_int")) == 8,
		"Three typed edits reach only their exact SDK resource")
	var before: int = version.get_version()
	revert.pressed.emit()
	await _frames(5)
	_check(version.get_version() == before + 1
		and String(sdk.get(&"message")) == original_message
		and bool(sdk.get(&"boolean_value"))
		and int(sdk.get(&"ranged_int")) == original_int,
		"Revertir restores SDK snapshot in one UndoRedo action")
	version.undo()
	_check(String(sdk.get(&"message")) == "changed by SDK Flusso"
		and int(sdk.get(&"ranged_int")) == 8
		and not bool(sdk.get(&"boolean_value")),
		"Undo of Revertir restores typed edited SDK values")
	version.redo()
	_check(String(sdk.get(&"message")) == original_message
		and int(sdk.get(&"ranged_int")) == original_int,
		"Redo restores SDK session snapshot")
	# Capture one authenticated descriptor, then change the owning machine.
	var property_descriptor: FlowBlockPropertyDescriptor = null
	var result: FlowBlockPropertyCatalogResult = context.call(
		&"describe_block_properties", sdk
	) as FlowBlockPropertyCatalogResult
	if result != null:
		for item: FlowBlockPropertyDescriptor in result.descriptors:
			if item != null and item.property_name == &"message":
				property_descriptor = item
	if not _check(property_descriptor != null, "SDK message descriptor available"):
		await _finish(drawer, host)
		return
	var old_button: Button = drawer.find_child(
		"PotokPhaseEnterDuplicate", true, false) as Button
	var original_version: int = version.get_version()
	drawer.open_container(owner, FlowGraphEditorCommands.Collection.STATE_MACHINES,
		second_machine.get_internal_id())
	# The previous Flusso callback and structural button retain the first machine ID.
	editor.call(&"_potok_phase_generic_apply",
		"stale machine", property_descriptor, machine.get_internal_id(),
		first.get_internal_id(), &"enter", sdk.get_internal_id(), weakref(owner))
	if is_instance_valid(old_button):
		old_button.pressed.emit()
	await _frames(5)
	_check(String(sdk.get(&"message")) == original_message
		and version.get_version() == original_version
		and first.enter_blocks.size() == 2 and second_state.enter_blocks.is_empty(),
		"Changing machine rejects stale SDK editor and structural signals")
	var old_owner_version: int = version.get_version()
	drawer.open_container(foreign, FlowGraphEditorCommands.Collection.STATE_MACHINES,
		foreign_machine.get_internal_id())
	editor.call(&"_potok_phase_generic_apply",
		"stale controller", property_descriptor, machine.get_internal_id(),
		first.get_internal_id(), &"enter", sdk.get_internal_id(), weakref(owner))
	if is_instance_valid(old_button):
		old_button.pressed.emit()
	await _frames(5)
	_check(version.get_version() == old_owner_version
		and String(sdk.get(&"message")) == original_message
		and first.enter_blocks.size() == 2
		and foreign_state.enter_blocks.is_empty(),
		"Changing PVController invalidates old descriptor and button callbacks")
	_check(not FlowGraphValidator.validate(graph).has_errors()
		and not FlowGraphValidator.validate(other_graph).has_errors()
		and first.enter_blocks[0] == null
		and first.enter_blocks[1] == sdk,
		"Both isolated graphs and authored null slot remain valid")
	await _finish(drawer, host)

func _frames(n: int) -> void:
	for i: int in n:
		await process_frame

func _check(ok: bool, label: String) -> bool:
	if not ok:
		failures.append(label)
		push_error("[Flujo] Potok 7F-1D2B: " + label)
	return ok

func _finish(drawer: FluoDrawer, host: Control) -> void:
	drawer.close()
	drawer.set_controller(null)
	drawer.queue_free()
	host.queue_free()
	await _frames(4)
	if failures.is_empty():
		print("[Flujo] Potok 7F-1D2B SDK typed Revertir and cross-owner isolation passed")
	quit(0 if failures.is_empty() else 1)
