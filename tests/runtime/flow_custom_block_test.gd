extends Node

const GRAPH_PATH: String = "res://.godot/flujo_tests/custom_block_graph.tres"
const SCENE_PATH: String = "res://.godot/flujo_tests/custom_block_controller.tscn"
var _failures: Array[String] = []
var _events: Array[Dictionary] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_cleanup()
	_check(
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/flujo_tests")) == OK,
		"Create the scoped custom-block test directory."
	)
	_test_registry()
	_test_persistence()
	await _test_runtime()
	_cleanup()
	if _failures.is_empty():
		print("[Flujo] Custom block test passed")
		get_tree().quit(0)
	else:
		for failure: String in _failures:
			push_error(failure)
		get_tree().quit(1)


func _graph() -> FlowGraph:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var ready: FlowProcess = FlowProcess.new()
	var print_block: FlowPrintBlock = FlowBlockRegistry.create(FlowBlockRegistry.PRINT) as FlowPrintBlock
	print_block.text = "Existing Print"
	ready.blocks = [
		print_block,
		FlowBlockRegistry.create(FlowBlockRegistry.EVERYTHING_FLOWS),
		FlowBlockRegistry.create(FlowBlockRegistry.CUSTOM_HELLO),
	]
	graph.processes = [ready]
	return graph


func _test_registry() -> void:
	var type_ids: Array[StringName] = FlowBlockRegistry.creatable_type_ids()
	_check(
		type_ids == [FlowBlockRegistry.PRINT, FlowBlockRegistry.EVERYTHING_FLOWS, FlowBlockRegistry.CUSTOM_HELLO],
		"The normal authoring registry exposes Print, Everything Flows, and Custom Hello in stable order."
	)
	var print_block: FlowBlock = FlowBlockRegistry.create(FlowBlockRegistry.PRINT)
	var everything: FlowBlock = FlowBlockRegistry.create(FlowBlockRegistry.EVERYTHING_FLOWS)
	var custom: FlowBlock = FlowBlockRegistry.create(FlowBlockRegistry.CUSTOM_HELLO)
	_check(print_block is FlowPrintBlock, "The registry creates the existing Print implementation.")
	_check(everything is FlowEverythingFlowsBlock, "The registry creates the existing Everything Flows implementation.")
	_check(custom is FlowCustomHelloBlock, "The registry creates Custom Hello through the same factory path.")
	_check(custom is FlowOutputBlock, "Custom Hello implements the shared output-block contract.")
	_check(FlowBlockRegistry.create(&"missing") == null, "An unregistered block type is rejected without a fallback.")


func _test_persistence() -> void:
	var graph: FlowGraph = _graph()
	_check(not FlowGraphValidator.validate(graph).has_errors(), "The custom block uses canonical schema 3 validation.")
	var custom: FlowCustomHelloBlock = graph.processes[0].blocks[2] as FlowCustomHelloBlock
	if not _check(custom != null, "The custom fixture contains its concrete block before persistence checks."):
		return
	var custom_id: String = custom.get_internal_id()
	var copy: FlowGraph = graph.duplicate_with_new_ids()
	if _check(copy != null and copy.processes[0].blocks[2] is FlowCustomHelloBlock, "Deep duplication preserves the custom concrete type."):
		_check(copy.processes[0].blocks[2].get_internal_id() != custom_id, "Deep duplication gives Custom Hello a new stable ID.")
	_check(ResourceSaver.save(graph, GRAPH_PATH) == OK, "Save the graph containing Custom Hello.")
	var loaded: FlowGraph = ResourceLoader.load(GRAPH_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as FlowGraph
	if not _check(loaded != null and loaded.processes[0].blocks[2] is FlowCustomHelloBlock, "Reload the custom concrete type from ResourceSaver."):
		return
	_check(loaded.processes[0].blocks[2].get_internal_id() == custom_id, "Resource reload preserves the custom block ID.")
	_check(
		(loaded.processes[0].blocks[2] as FlowCustomHelloBlock).get_output_message() == FlowCustomHelloBlock.MESSAGE,
		"Resource reload preserves the custom implementation and output."
	)
	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	var packed: PackedScene = PackedScene.new()
	var packed_ok: bool = _check(packed.pack(controller) == OK, "Pack a controller containing Custom Hello.")
	controller.free()
	if not packed_ok or not _check(ResourceSaver.save(packed, SCENE_PATH) == OK, "Save the custom-block PackedScene."):
		return
	var loaded_scene: PackedScene = ResourceLoader.load(SCENE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if not _check(loaded_scene != null, "Reload the custom-block PackedScene without cache."):
		return
	var instance: PVController = loaded_scene.instantiate() as PVController
	if _check(instance != null and instance.flow_graph != null, "Instantiate the persisted custom-block controller."):
		_check(instance.flow_graph.processes[0].blocks[2] is FlowCustomHelloBlock, "PackedScene retains the custom concrete type.")
		_check(instance.flow_graph.processes[0].blocks[2].get_internal_id() == custom_id, "PackedScene retains the custom stable ID.")
	instance.free()


func _test_runtime() -> void:
	var graph: FlowGraph = _graph()
	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	controller.runtime_output.message_emitted.connect(_record)
	_events.clear()
	add_child(controller)
	await get_tree().process_frame
	if _check(_events.size() == 3, "All three output blocks execute through the normal Ready path."):
		_check(_events[0].message == "Existing Print", "Print keeps its configured output.")
		_check(_events[1].message == "Todo es Flujo; todo fluye.", "Everything Flows keeps its exact fixed output.")
		_check(_events[2].message == FlowCustomHelloBlock.MESSAGE, "Custom Hello emits its unmistakable output.")
		_check(
			_events[2].process_id == graph.processes[0].get_internal_id() \
				and _events[2].block_id == graph.processes[0].blocks[2].get_internal_id(),
			"Structured output identifies the custom container and block by stable ID."
		)
	controller.queue_free()
	await get_tree().process_frame


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
	return condition


func _cleanup() -> void:
	for path: String in [GRAPH_PATH, SCENE_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
