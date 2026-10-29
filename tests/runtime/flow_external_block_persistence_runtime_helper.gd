extends SceneTree


const TEMP_SCENE_PATH: String = "res://.godot/flujo_tests/external_block_persistence_runtime.tscn"
const EXTERNAL_SCRIPT_PATH: String = "res://tests/fixtures/manual_block_sdk/manual_output/block.gd"
const PERSISTED_MESSAGE: String = "Persisted external message"
const RUNTIME_PRODUCTION_PATHS: Array[String] = [
	"res://addons/vp_flujo/runtime/pv_controller.gd",
	"res://addons/vp_flujo/runtime/flow_ready_executor.gd",
	"res://addons/vp_flujo/runtime/flow_runtime_output.gd",
	"res://addons/vp_flujo/runtime/flow_timer_runtime.gd",
	"res://addons/vp_flujo/runtime/flow_navigation_context.gd",
	"res://addons/vp_flujo/runtime/flow_navigation_decision.gd",
	"res://addons/vp_flujo/runtime/model/flow_block.gd",
	"res://addons/vp_flujo/runtime/model/flow_block_container.gd",
	"res://addons/vp_flujo/runtime/model/flow_graph.gd",
	"res://addons/vp_flujo/runtime/model/flow_graph_validator.gd",
	"res://addons/vp_flujo/runtime/model/flow_output_block.gd",
	"res://addons/vp_flujo/runtime/model/flow_process.gd",
	"res://addons/vp_flujo/runtime/model/flow_validation_result.gd",
]
const FORBIDDEN_RUNTIME_REFERENCES: Array[String] = [
	"FlowEditorBlockAuthoringContext",
	"FlowEditorBlockCatalog",
	"FlowExternalBlockFactory",
	"FlowPackageManifestLoader",
	"EditorInterface",
	"EditorPlugin",
	"EditorFileSystem",
	"EditorUndoRedoManager",
	"addons/vp_flujo/editor/",
]


var _failures: Array[String] = []
var _events: Array[Dictionary] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_runtime_dependency_boundary()
	var packed: PackedScene = ResourceLoader.load(
		TEMP_SCENE_PATH,
		"",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as PackedScene
	if not _check(packed != null, "Runtime loads the saved external-block scene without editor discovery."):
		_finish()
		return
	var controller: PVController = packed.instantiate() as PVController
	if not _check(controller != null and controller.flow_graph != null, "Runtime receives the persisted PVController and FlowGraph."):
		_finish()
		return
	var process: FlowProcess = controller.flow_graph.processes[0] if controller.flow_graph.processes.size() == 1 else null
	var block: FlowBlock = process.blocks[1] if process != null and process.blocks.size() == 2 else null
	_check(process != null and block != null and block is FlowOutputBlock, "Runtime receives the persisted external FlowOutputBlock in its authored process/order.")
	if block == null:
		_finish()
		return
	_check(block.get_script() != null and block.get_script().resource_path == EXTERNAL_SCRIPT_PATH, "Runtime receives the attached external script resource.")
	controller.runtime_output.message_emitted.connect(_record)
	_events.clear()
	get_root().add_child(controller)
	await process_frame
	if _check(_events.size() == 1, "The reloaded external block executes once through normal Ready startup."):
		_check(_events[0]["message"] == PERSISTED_MESSAGE, "The external FlowOutputBlock reaches the generic output boundary with its persisted message.")
		_check(_events[0]["process_id"] == process.get_internal_id(), "Runtime output identifies the persisted process by FlowId.")
		_check(_events[0]["block_id"] == block.get_internal_id(), "Runtime output identifies the persisted external block by FlowId.")
	controller.queue_free()
	await process_frame
	_finish()


func _test_runtime_dependency_boundary() -> void:
	for path: String in RUNTIME_PRODUCTION_PATHS:
		var source: String = FileAccess.get_file_as_string(path)
		_check(not source.is_empty(), "Runtime production source is readable: " + path)
		for forbidden: String in FORBIDDEN_RUNTIME_REFERENCES:
			_check(not source.contains(forbidden), "Runtime production source has no editor/authoring dependency " + forbidden + ": " + path)


func _record(controller: Node, process_id: String, block_id: String, message: String) -> void:
	_events.append({
		"controller": controller.get_instance_id(),
		"process_id": process_id,
		"block_id": block_id,
		"message": message,
	})


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_failures.append(message)
		push_error(message)
	return condition


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] External block persistence runtime test passed")
	quit(0 if _failures.is_empty() else 1)
