extends Node

const GRAPH_PATH: String = "res://.godot/flujo_tests/ready_graph.tres"
const SCENE_PATH: String = "res://.godot/flujo_tests/ready_controller.tscn"
var _failures: Array[String] = []
var _events: Array[Dictionary] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_cleanup()
	_check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/flujo_tests")) == OK, "Create scoped test directory.")
	_test_migration_compatibility()
	_test_persistence_and_copy()
	await _test_execution()
	_test_runtime_dependencies()
	_cleanup()
	if _failures.is_empty():
		print("[Flujo] Ready runtime test passed")
		get_tree().quit(0)
	else:
		for failure: String in _failures:
			push_error(failure)
		get_tree().quit(1)


func _fixture(schema: int = FlowGraph.SCHEMA_VERSION_3) -> FlowGraph:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = schema
	if schema == FlowGraph.SCHEMA_VERSION_3:
		graph.constructor = FlowConstructorDefinition.new()
	var first: FlowProcess = FlowProcess.new()
	first.display_name = "Renamed startup"
	var print_block: FlowPrintBlock = FlowPrintBlock.new()
	print_block.text = "Configured Ready output"
	var disabled: FlowPrintBlock = FlowPrintBlock.new()
	disabled.text = "must not print"
	disabled.enabled = false
	first.blocks = [print_block, null, disabled, FlowEverythingFlowsBlock.new()]
	var second: FlowProcess = FlowProcess.new()
	var tail: FlowPrintBlock = FlowPrintBlock.new()
	tail.text = "Second process"
	second.blocks = [tail]
	var disabled_process: FlowProcess = FlowProcess.new()
	disabled_process.enabled = false
	disabled_process.blocks = [FlowEverythingFlowsBlock.new()]
	var per_frame: FlowProcess = FlowProcess.new()
	per_frame.process_type = FlowProcess.ProcessType.PROCESS
	per_frame.blocks = [FlowEverythingFlowsBlock.new()]
	graph.processes = [first, null, second, disabled_process, per_frame]
	return graph


func _test_migration_compatibility() -> void:
	# Schema 2 is only a migration fixture, never an authoring or execution target.
	var source: FlowGraph = _fixture(FlowGraph.SCHEMA_VERSION_2)
	var snapshot: String = _snapshot(source)
	var migration: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_2_to_3(source)
	if not _check(migration.is_successful(), "Existing 2-to-3 migration preserves polymorphic blocks."):
		return
	var candidate: FlowGraph = migration.migrated_graph
	if not _check(candidate != null, "Successful migration exposes a schema 3 candidate."):
		return
	_check(candidate.schema_version == FlowGraph.SCHEMA_VERSION_3, "Migration explicitly selects schema 3.")
	_check(candidate.get_internal_id() == source.get_internal_id(), "Migration preserves graph identity.")
	_verify_copy(source, candidate, true)
	_check(_snapshot(source) == snapshot, "Migration leaves schema 2 source unchanged.")


func _test_persistence_and_copy() -> void:
	var graph: FlowGraph = _fixture()
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Starter blocks share the canonical graph validator.")
	var snapshot: String = _snapshot(graph)
	var copy: FlowGraph = graph.duplicate_with_new_ids()
	if not _check(copy != null and copy != graph, "Graph duplicate exists independently."):
		return
	_check(copy.get_internal_id() != graph.get_internal_id(), "Graph duplicate gets a new ID.")
	_verify_copy(graph, copy, false)
	if not _check(copy.processes.size() == 5 and copy.processes[0] != null, "Duplicate has its first process before dereference."):
		return
	if not _check(copy.processes[0].blocks.size() == 4, "Duplicate retains the first process block collection before indexing."):
		return
	var print_copy: FlowPrintBlock = copy.processes[0].blocks[0] as FlowPrintBlock
	if not _check(print_copy != null, "Duplicate preserves Print subtype."):
		return
	print_copy.text = "changed copy"
	copy.processes[0].enabled = false
	_check(_snapshot(graph) == snapshot, "Mutating a duplicate leaves all original metadata intact.")
	if not _check(ResourceSaver.save(graph, GRAPH_PATH) == OK, "Save starter graph Resource."):
		return
	var loaded: FlowGraph = ResourceLoader.load(GRAPH_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as FlowGraph
	if not _check(loaded != null, "Load fresh starter Resource without cache."):
		return
	_verify_copy(graph, loaded, true)
	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	var packed: PackedScene = PackedScene.new()
	var packed_ok: bool = _check(packed.pack(controller) == OK, "Pack the real PVController.")
	controller.free()
	if not packed_ok or not _check(ResourceSaver.save(packed, SCENE_PATH) == OK, "Save controller PackedScene."):
		return
	var loaded_scene: PackedScene = ResourceLoader.load(SCENE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if not _check(loaded_scene != null, "Reload fresh PackedScene."):
		return
	var instance: PVController = loaded_scene.instantiate() as PVController
	if not _check(instance != null and instance.flow_graph != null, "Instance has a persisted graph."):
		if instance != null:
			instance.free()
		return
	_verify_copy(graph, instance.flow_graph, true)
	instance.free()


func _verify_copy(original: FlowGraph, copy: FlowGraph, preserve_ids: bool) -> void:
	if not _check(copy != null and copy.processes.size() == original.processes.size(), "Copied process count and null positions."):
		return
	for index: int in original.processes.size():
		var source: FlowProcess = original.processes[index]
		var target: FlowProcess = copy.processes[index]
		if source == null:
			_check(target == null, "Process null position preserved.")
			continue
		if not _check(target != null and target != source, "Copied process exists independently."):
			return
		_check((target.get_internal_id() == source.get_internal_id()) == preserve_ids, "Process ID follows migration/persistence versus duplication policy.")
		_check(target.display_name == source.display_name and target.enabled == source.enabled and target.process_type == source.process_type, "Process metadata preserved.")
		if not _check(target.blocks.size() == source.blocks.size(), "Block array length preserved."):
			return
		for block_index: int in source.blocks.size():
			var original_block: FlowBlock = source.blocks[block_index]
			var copied_block: FlowBlock = target.blocks[block_index]
			if original_block == null:
				_check(copied_block == null, "Block null position preserved.")
				continue
			if not _check(copied_block != null and copied_block != original_block, "Block is independently copied."):
				return
			_check(copied_block.get_script() == original_block.get_script(), "Concrete block subtype preserved.")
			_check((copied_block.get_internal_id() == original_block.get_internal_id()) == preserve_ids, "Block ID follows copy policy.")
			_check(copied_block.enabled == original_block.enabled, "Block activation preserved.")
			if original_block is FlowPrintBlock and _check(copied_block is FlowPrintBlock, "Print cast is safe."):
				_check((copied_block as FlowPrintBlock).text == (original_block as FlowPrintBlock).text, "Configurable Print text survives.")


func _test_execution() -> void:
	var graph: FlowGraph = _fixture()
	# Unsupported and malformed blocks precede a known good block, which must still run.
	graph.processes[0].blocks.insert(2, FlowBlock.new())
	var invalid: FlowPrintBlock = FlowPrintBlock.new()
	invalid._internal_id = ""
	invalid.text = "invalid must not print"
	graph.processes[0].blocks.insert(3, invalid)
	var snapshot: String = _snapshot(graph)
	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	controller.runtime_output.message_emitted.connect(_record)
	_events.clear()
	add_child(controller)
	await get_tree().process_frame
	if _check(_events.size() == 3, "Exactly three enabled blocks execute despite an unknown and invalid predecessor."):
		_check(_events[0].message == "Configured Ready output", "Print emits configured text first.")
		_check(_events[1].message == "Todo es Flujo; todo fluye.", "Everything Flows emits the exact fixed output second.")
		_check(_events[2].message == "Second process", "Process ordering is preserved.")
		_check(_events[0].controller == controller.get_instance_id(), "Output identifies the controller instance.")
		_check(_events[0].process_id == graph.processes[0].get_internal_id() and _events[0].block_id == graph.processes[0].blocks[0].get_internal_id(), "Output preserves stable process and block IDs.")
	remove_child(controller)
	controller.request_ready()
	add_child(controller)
	await get_tree().process_frame
	_check(_events.size() == 3, "Re-entry and request_ready cannot execute the same controller twice.")
	_check(_snapshot(graph) == snapshot, "Ready execution leaves shared graph definitions unchanged.")
	controller.queue_free()
	await get_tree().process_frame
	var disabled_controller: PVController = PVController.new()
	disabled_controller.flow_graph = graph
	disabled_controller.visual_program_enabled = false
	disabled_controller.runtime_output.message_emitted.connect(_record)
	_events.clear()
	add_child(disabled_controller)
	await get_tree().process_frame
	_check(_events.is_empty(), "Disabled visual program produces no output.")
	disabled_controller.queue_free()
	await get_tree().process_frame


func _record(controller: Node, process_id: String, block_id: String, message: String) -> void:
	_events.append({"controller": controller.get_instance_id(), "process_id": process_id, "block_id": block_id, "message": message})


func _snapshot(graph: FlowGraph) -> String:
	var values: Array = [graph.get_internal_id(), graph.schema_version]
	for process: FlowProcess in graph.processes:
		if process == null:
			values.append(null)
			continue
		values.append([process.get_internal_id(), process.display_name, process.enabled, process.process_type])
		for block: FlowBlock in process.blocks:
			values.append(null if block == null else [block.get_internal_id(), block.enabled, (block as FlowPrintBlock).text if block is FlowPrintBlock else block.display_name])
	return var_to_str(values)


func _test_runtime_dependencies() -> void:
	for path: String in ["res://addons/vp_flujo/runtime/pv_controller.gd", "res://addons/vp_flujo/runtime/flow_ready_executor.gd", "res://addons/vp_flujo/runtime/flow_runtime_output.gd", "res://addons/vp_flujo/runtime/model/flow_print_block.gd", "res://addons/vp_flujo/runtime/model/flow_everything_flows_block.gd"]:
		var source: String = FileAccess.get_file_as_string(path)
		_check(not source.is_empty() and not source.contains("EditorInterface") and not source.contains("EditorPlugin") and not source.contains("addons/vp_flujo/editor/"), "Runtime dependency boundary: " + path)


func _cleanup() -> void:
	for path: String in [GRAPH_PATH, SCENE_PATH]:
		if FileAccess.file_exists(path):
			_check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK, "Remove scoped temporary: " + path)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_failures.append(message)
	return condition
