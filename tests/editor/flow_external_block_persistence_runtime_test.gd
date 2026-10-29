@tool
extends SceneTree


const MANUAL_FIXTURE_ROOT: String = "res://tests/fixtures/manual_block_sdk"
const AUTHORING_ID: String = "manual_output:output"
const EXTERNAL_SCRIPT_PATH: String = "res://tests/fixtures/manual_block_sdk/manual_output/block.gd"
const TEMP_DIR_PATH: String = "res://.godot/flujo_tests"
const TEMP_SCENE_PATH: String = TEMP_DIR_PATH + "/external_block_persistence_runtime.tscn"
const RUNTIME_HELPER_PATH: String = "res://tests/runtime/flow_external_block_persistence_runtime_helper.gd"
const PERSISTED_DISPLAY_NAME: String = "Persisted Manual Output"
const PERSISTED_MESSAGE: String = "Persisted external message"
const AUTHORING_CONTEXT_SCRIPT: Script = preload(
	"res://addons/vp_flujo/editor/flow_editor_block_authoring_context.gd"
)


var _failures: Array[String] = []
var _host: Control
var _property: FlowGraphInspectorProperty
var _controller: PVController
var _process: FlowProcess


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _frames()
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	_remove_artifact()
	_prepare_initial_scene()
	await _open_initial_scene()
	var expected: Dictionary = {}
	if is_instance_valid(_controller):
		expected = await _create_through_d3_and_save()
	await _release_editor_scene()
	if not expected.is_empty():
		_verify_reloaded_scene(expected)
		_run_runtime_focal()
	_remove_artifact()
	_finish()


func _prepare_initial_scene() -> void:
	_check(
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_DIR_PATH)) == OK,
		"Create the scoped Phase E persistence directory."
	)
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var process: FlowProcess = FlowProcess.new()
	process.display_name = "Persisted Ready Process"
	process.blocks = [null]
	graph.processes = [process]
	var controller: PVController = PVController.new()
	controller.name = "ExternalPersistenceController"
	controller.flow_graph = graph
	var packed: PackedScene = PackedScene.new()
	var pack_status: Error = packed.pack(controller)
	_check(pack_status == OK, "Pack the temporary controller scene before editor authoring.")
	controller.free()
	if pack_status != OK:
		return
	_check(
		ResourceSaver.save(packed, TEMP_SCENE_PATH) == OK,
		"Save the temporary controller scene through the project PackedScene boundary."
	)


func _open_initial_scene() -> void:
	if not FileAccess.file_exists(ProjectSettings.globalize_path(TEMP_SCENE_PATH)):
		return
	EditorInterface.open_scene_from_path(TEMP_SCENE_PATH)
	await _frames()
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	await _frames()
	_controller = EditorInterface.get_edited_scene_root() as PVController
	_check(
		_controller != null and _controller.scene_file_path == TEMP_SCENE_PATH,
		"The focal edits only the disposable external-block scene."
	)
	if _controller == null or _controller.flow_graph == null:
		return
	_check(
		_controller.flow_graph.schema_version == FlowGraph.SCHEMA_VERSION_3,
		"The temporary scene opens with the schema 3 graph required by the Ready path."
	)
	_process = _controller.flow_graph.processes[0] if _controller.flow_graph.processes.size() == 1 else null
	_check(_process != null, "The temporary scene contains its selected Ready process.")


func _create_through_d3_and_save() -> Dictionary:
	var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if not _check(undo_redo != null, "Editor undo/redo manager is available for the D3 command path."):
		return {}
	if not _check(_process != null and _controller != null, "D3 authoring starts with a live selected process."):
		return {}
	var context: RefCounted = AUTHORING_CONTEXT_SCRIPT.new(MANUAL_FIXTURE_ROOT) as RefCounted
	_host = Control.new()
	_host.name = "ExternalPersistenceRuntimeFocal"
	_host.size = Vector2(1200.0, 900.0)
	get_root().add_child(_host)
	_property = FlowGraphInspectorProperty.new()
	_property.configure(undo_redo, context)
	_property.configure_for_fluo()
	_property.size = Vector2(900.0, 800.0)
	_host.add_child(_property)
	_property.set_dock_controller(_controller)
	_property.set_dock_variable_selection(
		_controller,
		FlowGraphEditorCommands.Collection.PROCESSES,
		_process.get_internal_id()
	)
	await _frames()

	var editor: FlowReadyProcessEditor = _editor()
	var manual_button: Button = _authoring_button(editor, AUTHORING_ID)
	_check(manual_button != null, "D3 Flow Add exposes manual_output:output from the fixture catalog.")
	if manual_button == null:
		return {}
	manual_button.pressed.emit()
	await _frames()
	_process = _controller.flow_graph.processes[0] if _controller.flow_graph.processes.size() == 1 else null
	var external_block: FlowBlock = _process.blocks[1] if _process != null and _process.blocks.size() == 2 else null
	_check(external_block != null, "The authoring ID creates the external block after the existing null position.")
	if external_block == null:
		return {}
	var flow_id: String = external_block.get_internal_id()
	var script_path: String = external_block.get_script().resource_path
	_check(external_block is FlowOutputBlock, "The D3-created block is a normal FlowOutputBlock.")
	_check(script_path == EXTERNAL_SCRIPT_PATH, "The D3-created block attaches the fixture script.")
	_check(
		external_block.get(&"message") as String == "Hello from the manual SDK",
		"The D3-created block starts with the fixture's default exported message."
	)
	_check(FlowId.is_valid(flow_id), "The D3-created external block has a persistent FlowId.")

	var list: ItemList = _node(_editor(), "ReadyBlocksList") as ItemList
	_check(list != null and list.item_count == 2, "Flow preserves the existing null row and the new external row.")
	if list == null:
		return {}
	list.item_activated.emit(1)
	await _frames()
	var options: PanelContainer = _node(_property, "BlockOptionsPanel") as PanelContainer
	_check(options != null and options.visible, "The same D3-created block opens in generic Flusso.")
	if options == null:
		return {}

	var name_input: LineEdit = _node(options, "ReadyBlockName") as LineEdit
	_check(name_input != null, "Generic Flusso exposes the external block display-name control.")
	if name_input != null:
		name_input.text = PERSISTED_DISPLAY_NAME
		name_input.text_changed.emit(name_input.text)
	await _frames()
	options = _node(_property, "BlockOptionsPanel") as PanelContainer
	var enabled: CheckBox = _node(options, "ReadyBlockEnabled") as CheckBox
	_check(enabled != null, "Generic Flusso exposes the external block enabled control.")
	if enabled != null:
		enabled.toggled.emit(false)
	await _frames()
	options = _node(_property, "BlockOptionsPanel") as PanelContainer
	enabled = _node(options, "ReadyBlockEnabled") as CheckBox
	_check(enabled != null, "Generic Flusso can reopen the external enabled control after a live edit.")
	if enabled != null:
		enabled.toggled.emit(true)
	await _frames()

	# The external exported field is deliberately not a Flusso-owned property.
	external_block = _process.blocks[1]
	# Keep the final persisted activation explicit after the live-control rebuilds.
	external_block.display_name = PERSISTED_DISPLAY_NAME
	external_block.enabled = true
	external_block.set(&"message", PERSISTED_MESSAGE)
	_check(external_block.display_name == PERSISTED_DISPLAY_NAME, "The focal sets a meaningful external display name before save.")
	_check(external_block.enabled, "The focal sets the external enabled state intentionally before save.")
	_check(String(external_block.get(&"message")) == PERSISTED_MESSAGE, "The focal sets a meaningful external exported message before save.")

	var graph_id: String = _controller.flow_graph.get_internal_id()
	var process_id: String = _process.get_internal_id()
	EditorInterface.save_scene()
	await _frames()
	_check(
		FileAccess.file_exists(ProjectSettings.globalize_path(TEMP_SCENE_PATH)),
		"EditorInterface.save_scene writes the temporary persistence artifact."
	)
	return {
		"graph_id": graph_id,
		"process_id": process_id,
		"flow_id": flow_id,
		"script_path": script_path,
		"display_name": PERSISTED_DISPLAY_NAME,
		"enabled": true,
		"message": PERSISTED_MESSAGE,
	}


func _release_editor_scene() -> void:
	if is_instance_valid(_host):
		_host.queue_free()
	await _frames()
	_host = null
	_property = null
	if is_instance_valid(_controller) and EditorInterface.get_edited_scene_root() == _controller:
		EditorInterface.close_scene()
		await _frames()
	_controller = null
	_process = null


func _verify_reloaded_scene(expected: Dictionary) -> void:
	var packed: PackedScene = ResourceLoader.load(
		TEMP_SCENE_PATH,
		"",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as PackedScene
	if not _check(packed != null, "Reload the saved external-block scene from disk."):
		return
	var loaded_controller: PVController = packed.instantiate() as PVController
	if not _check(loaded_controller != null, "Instantiate the reloaded controller scene."):
		return
	var graph: FlowGraph = loaded_controller.flow_graph
	_check(graph != null, "Reloaded controller retains its FlowGraph.")
	if graph == null:
		loaded_controller.free()
		return
	_check(graph.get_internal_id() == expected["graph_id"], "Reload preserves graph identity by FlowId.")
	_check(graph.processes.size() == 1 and graph.processes[0] != null, "Reload preserves the owning process container.")
	if graph.processes.size() != 1 or graph.processes[0] == null:
		loaded_controller.free()
		return
	var process: FlowProcess = graph.processes[0]
	_check(process.get_internal_id() == expected["process_id"], "Reload preserves process identity by FlowId.")
	_check(process.process_type == FlowProcess.ProcessType.READY, "Reload preserves the Ready process type.")
	_check(process.blocks.size() == 2 and process.blocks[0] == null, "Reload preserves block position and the deliberate null order slot.")
	if process.blocks.size() != 2:
		loaded_controller.free()
		return
	var block: FlowBlock = process.blocks[1]
	_check(block != null and block is FlowBlock and block is FlowOutputBlock, "Reload retains a normal external FlowBlock in the graph.")
	if block == null:
		loaded_controller.free()
		return
	_check(block.get_internal_id() == expected["flow_id"], "Reload preserves the external block FlowId.")
	_check(block.get_script() != null and block.get_script().resource_path == expected["script_path"], "Reload preserves the concrete external script path.")
	_check(not (block is FlowPrintBlock), "Reload does not substitute a built-in Print fallback.")
	_check(block.display_name == expected["display_name"], "Reload preserves the custom external display name.")
	_check(block.enabled == expected["enabled"], "Reload preserves the external enabled state.")
	_check(String(block.get(&"message")) == expected["message"], "Reload preserves the external exported message.")
	loaded_controller.free()


func _run_runtime_focal() -> void:
	var output: Array[String] = []
	var arguments: PackedStringArray = [
		"--headless",
		"--path",
		ProjectSettings.globalize_path("res://"),
		"--script",
		RUNTIME_HELPER_PATH,
	]
	var exit_code: int = OS.execute(OS.get_executable_path(), arguments, output, true)
	var transcript: String = "\n".join(output)
	_check(exit_code == 0, "The reloaded external block runtime helper exits successfully. Output: " + transcript)
	_check(
		transcript.contains("[Flujo] External block persistence runtime test passed"),
		"The runtime helper reaches the canonical Ready output boundary. Output: " + transcript
	)


func _remove_artifact() -> void:
	var absolute_path: String = ProjectSettings.globalize_path(TEMP_SCENE_PATH)
	if FileAccess.file_exists(absolute_path):
		_check(DirAccess.remove_absolute(absolute_path) == OK, "Remove the disposable Phase E persistence artifact.")


func _editor() -> FlowReadyProcessEditor:
	return _property.find_child("ReadyProcessEditor", true, false) as FlowReadyProcessEditor if _property != null else null


func _authoring_button(editor: FlowReadyProcessEditor, authoring_id: String) -> Button:
	if editor == null:
		return null
	var add_row: HBoxContainer = _node(editor, "AddBlockActions") as HBoxContainer
	if add_row == null:
		return null
	for child: Node in add_row.get_children():
		if child is Button and child.get_meta(&"authoring_id", "") == authoring_id:
			return child as Button
	return null


func _node(root: Node, node_name: String) -> Node:
	if root == null:
		return null
	if root.name == node_name:
		return root
	return root.find_child(node_name, true, false)


func _frames(count: int = 4) -> void:
	for _index: int in count:
		await process_frame


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_failures.append(message)
		push_error(message)
	return condition


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] External block persistence/runtime editor test passed")
	quit(0 if _failures.is_empty() else 1)
