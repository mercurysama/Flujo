@tool
extends SceneTree

## Potok 7F-1C1E: native Fluo with external SDK descriptors + saved scene.
const SDK_ROOT: String = "res://tests/fixtures/property_descriptors"
const AUTHORING_SCRIPT: Script = preload(
	"res://addons/vp_flujo/editor/flow_editor_block_authoring_context.gd"
)
const TMP_DIR: String = "res://.godot/flujo_tests"
const SAVE_PATH: String = TMP_DIR + "/potok_7f1c1e_sdk_roundtrip.tscn"

var failures: Array[String] = []
var host: Control
var drawer: FluoDrawer
var editor: FlowGraphInspectorProperty
var controller: PVController
var graph: FlowGraph
var state: FlowStateDefinition
var machine: FlowStateMachineDefinition
var external: FlowBlock
var ready: FlowProcess


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for i: int in 5:
		await process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if not _check(manager != null, "Editor UndoRedo manager is present"):
		quit(1)
		return
	var context: RefCounted = AUTHORING_SCRIPT.new(SDK_ROOT) as RefCounted
	var creation: Object = context.call(&"create_block", "manual_output:output") as Object
	if not _check(creation != null and bool(creation.call(&"is_successful")),
			"Real external SDK package creates its block"):
		quit(1)
		return
	external = creation.get("block") as FlowBlock
	if not _check(external != null, "External SDK block is a FlowBlock"):
		quit(1)
		return
	host = Control.new()
	host.name = "Potok7F1C1ESDKHost"
	host.size = Vector2(1100, 770)
	get_root().add_child(host)
	graph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	state = FlowStateDefinition.new()
	state.enter_blocks = [null, external]
	state.blocks = [FlowPrintBlock.new()]
	state.exit_blocks = [FlowPrintBlock.new()]
	machine = FlowStateMachineDefinition.new()
	machine.states = [state]
	machine.initial_state_id = state.get_internal_id()
	graph.state_machines = [machine]
	ready = FlowProcess.new()
	graph.processes = [ready]
	controller = PVController.new()
	controller.name = "Controller"
	controller.flow_graph = graph
	host.add_child(controller)
	controller.owner = host
	_check(not FlowGraphValidator.validate(graph).has_errors(),
		"SDK seed validates without changing runtime/schema")
	drawer = FluoDrawer.new()
	EditorInterface.get_base_control().add_child(drawer)
	drawer.configure(manager)
	editor = drawer.find_child("FluoFlowEditor", true, false) as FlowGraphInspectorProperty
	if not _check(editor != null, "Only existing FluoFlowEditor is used"):
		await _finish()
		return
	editor.configure(manager, context)
	drawer.open_container(controller, FlowGraphEditorCommands.Collection.STATE_MACHINES,
		machine.get_internal_id())
	await _frames(6)
	var list: ItemList = drawer.find_child(
		"PotokPhaseEnterBlocksList", true, false) as ItemList
	if not _check(list != null and list.item_count == 2 and list.is_item_disabled(0),
			"Native Enter list preserves null slot and exact external block"):
		await _finish()
		return
	list.select(1)
	list.item_selected.emit(1)
	list.item_activated.emit(1)
	await _frames(5)
	var msg: TextEdit = drawer.find_child(
		"PotokPhaseGenericmessage", true, false) as TextEdit
	var flag: CheckBox = drawer.find_child(
		"PotokPhaseGenericboolean_value", true, false) as CheckBox
	var range_input: SpinBox = drawer.find_child(
		"PotokPhaseGenericranged_int", true, false) as SpinBox
	var enum_input: OptionButton = drawer.find_child(
		"PotokPhaseGenericenum_value", true, false) as OptionButton
	if not _check(msg != null and flag != null and range_input != null
			and enum_input != null, "SDK metadata produces expected typed Flusso controls"):
		await _finish()
		return
	var history: UndoRedo = manager.get_history_undo_redo(
		manager.get_object_history_id(controller))
	var block_id: String = external.get_internal_id()
	var unchanged_ready: int = ready.blocks.size()
	msg.text = "SDK edited through Flusso"
	msg.text_changed.emit()
	_check(String(external.get("message")) == "SDK edited through Flusso",
		"External multiline edit reaches its owned phase block")
	flag.button_pressed = false
	flag.toggled.emit(false)
	_check(not bool(external.get("boolean_value")),
		"External Boolean edit accepted")
	var previous_int: int = int(external.get("ranged_int"))
	range_input.value = 7.0
	range_input.value_changed.emit(7.0)
	_check(int(external.get("ranged_int")) == 7,
		"External ranged integer edit accepted")
	enum_input.select(0)
	enum_input.item_selected.emit(0)
	_check(int(external.get("enum_value")) == 0,
		"External enum edit accepted using catalog metadata")
	history.undo()
	_check(int(external.get("enum_value")) == 1,
		"Undo restores external enum")
	history.redo()
	_check(int(external.get("enum_value")) == 0,
		"Redo restores external enum")
	var session: Dictionary = editor.get("_potok_phase_block_session")
	_check((session.get("values", {}) as Dictionary).has(&"message"),
		"Session captured SDK multiline field")
	var original_sid: String = state.get_internal_id()
	var original_mid: String = machine.get_internal_id()
	_check(state.enter_blocks[0] == null and state.enter_blocks[1] == external
		and external.get_internal_id() == block_id
		and state.blocks.size() == 1 and state.exit_blocks.size() == 1
		and ready.blocks.size() == unchanged_ready,
		"All other phase arrays, null slots and Ready stay isolated")
	drawer.close()
	await _frames(3)
	_check(String(external.get("message")) == "SDK edited through Flusso",
		"Closing drawer does not roll back accepted SDK edits")
	_check(DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(TMP_DIR)) == OK, "Temporary scene directory exists")
	var packed := PackedScene.new()
	var packed_ok: bool = packed.pack(host) == OK
	_check(packed_ok, "PVController scene packs after external edit")
	var saved: bool = packed_ok and ResourceSaver.save(
		packed, ProjectSettings.globalize_path(SAVE_PATH)) == OK
	_check(saved, "Edited SDK scene saves to temporary .tscn")
	if saved:
		var loaded: PackedScene = ResourceLoader.load(
			SAVE_PATH, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE
		) as PackedScene
		if _check(loaded != null, "Edited SDK scene reopens"):
			var reloaded: Node = loaded.instantiate()
			if _check(reloaded != null, "Saved scene instantiates"):
				var reopened: PVController = reloaded.get_node_or_null("Controller") as PVController
				if _check(reopened != null and reopened.flow_graph != null,
						"Saved PVController still owns a valid FlowGraph"):
					var machines: Array[FlowStateMachineDefinition] = reopened.flow_graph.state_machines
					if _check(machines.size() == 1 and machines[0].get_internal_id() == original_mid,
							"Machine keeps authored ID"):
						var states: Array[FlowStateDefinition] = machines[0].states
						if _check(states.size() == 1 and states[0].get_internal_id() == original_sid,
								"State keeps authored ID"):
							var blocks: Array[FlowBlock] = states[0].enter_blocks
							_check(blocks.size() == 2 and blocks[0] == null
								and blocks[1] != null and blocks[1].get_internal_id() == block_id,
								"Original external block ID and deliberate null survive")
							if blocks.size() == 2 and blocks[1] != null:
								_check(String(blocks[1].get("message")) == "SDK edited through Flusso"
									and not bool(blocks[1].get("boolean_value"))
									and int(blocks[1].get("ranged_int")) == 7
									and int(blocks[1].get("enum_value")) == 0,
									"All SDK scalar values survive real scene roundtrip")
							_check(states[0].blocks.size() == 1
								and states[0].exit_blocks.size() == 1,
								"Update and Exit remain intact after reload")
					_check(not FlowGraphValidator.validate(reopened.flow_graph).has_errors(),
						"Reopened SDK graph validates")
				reloaded.free()
	await _finish()


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _check(ok: bool, message: String) -> bool:
	if not ok:
		failures.append(message)
		push_error("[Flujo] Potok 7F-1C1E SDK: " + message)
	return ok


func _finish() -> void:
	if drawer != null:
		drawer.close()
		drawer.set_controller(null)
		drawer.queue_free()
	if host != null:
		host.queue_free()
	await _frames(4)
	var path: String = ProjectSettings.globalize_path(SAVE_PATH)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	if failures.is_empty():
		print("[Flujo] Potok 7F-1C1E external SDK UI and scene roundtrip passed")
	quit(0 if failures.is_empty() else 1)
