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
	_test_block_name_compatibility()
	_test_migration_compatibility()
	_test_persistence_and_copy()
	await _test_execution()
	_test_timer_model()
	await _test_timers()
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
	print_block.display_name = "Named Ready Print"
	print_block.text = "Configured Ready output"
	var disabled: FlowPrintBlock = FlowPrintBlock.new()
	disabled.text = "must not print"
	disabled.enabled = false
	var everything: FlowEverythingFlowsBlock = FlowEverythingFlowsBlock.new()
	everything.display_name = "Named Ready Everything"
	first.blocks = [print_block, null, disabled, everything]
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
			_check(copied_block.enabled == original_block.enabled and copied_block.display_name == original_block.display_name, "Block activation and independent visible name are preserved.")
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
	var entry_contexts: Array[StringName] = []
	controller.runtime_output.entry_message_emitted.connect(
		func(_controller: Node, _process_id: String, _block_id: String, _message: String, entry_point: StringName) -> void:
			entry_contexts.append(entry_point)
	)
	_events.clear()
	add_child(controller)
	await get_tree().process_frame
	if _check(_events.size() == 3, "Exactly three enabled blocks execute despite an unknown and invalid predecessor."):
		_check(_events[0].message == "Configured Ready output", "Print emits configured text first without resolving its visible name.")
		_check(_events[1].message == "Todo es Flujo; todo fluye.", "Everything Flows emits the exact fixed output without resolving its visible name.")
		_check(_events[2].message == "Second process", "Process ordering is preserved.")
		_check(_events[0].controller == controller.get_instance_id(), "Output identifies the controller instance.")
		_check(_events[0].process_id == graph.processes[0].get_internal_id() and _events[0].block_id == graph.processes[0].blocks[0].get_internal_id(), "Output preserves stable process and block IDs.")
		_check(entry_contexts == [&"Ready", &"Ready", &"Ready"], "Contextual output identifies every Ready message without changing the legacy signal.")
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
			values.append(null if block == null else [block.get_internal_id(), block.display_name, block.enabled, (block as FlowPrintBlock).text if block is FlowPrintBlock else ""])
	return var_to_str(values)


func _test_block_name_compatibility() -> void:
	var legacy_print: FlowPrintBlock = FlowPrintBlock.new()
	var legacy_everything: FlowEverythingFlowsBlock = FlowEverythingFlowsBlock.new()
	_check(legacy_print.display_name == "Print", "Print without an explicit stored Block Name retains its compatible visible default.")
	_check(legacy_everything.display_name == "Everything Flows", "Everything Flows without an explicit stored Block Name retains its compatible visible default.")
	legacy_print.display_name = "Duplicate Block Name"
	legacy_everything.display_name = "Duplicate Block Name"
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var process: FlowProcess = FlowProcess.new()
	process.blocks = [legacy_print, legacy_everything]
	graph.processes = [process]
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Duplicate Block Names remain valid because stable IDs, not visible names, define block identity.")


func _test_runtime_dependencies() -> void:
	for path: String in ["res://addons/vp_flujo/runtime/pv_controller.gd", "res://addons/vp_flujo/runtime/flow_ready_executor.gd", "res://addons/vp_flujo/runtime/flow_timer_runtime.gd", "res://addons/vp_flujo/runtime/flow_runtime_output.gd", "res://addons/vp_flujo/runtime/model/flow_timer_definition.gd", "res://addons/vp_flujo/runtime/model/flow_print_block.gd", "res://addons/vp_flujo/runtime/model/flow_everything_flows_block.gd"]:
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


func _timer_fixture() -> FlowGraph:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var timer: FlowTimerDefinition = FlowTimerDefinition.new()
	timer.interval_seconds = 3600.0
	timer.repeat = true
	var first: FlowPrintBlock = FlowPrintBlock.new()
	first.display_name = "Named Timer Print"
	first.text = "Timer first"
	var everything: FlowEverythingFlowsBlock = FlowEverythingFlowsBlock.new()
	everything.display_name = "Named Timer Everything"
	timer.blocks = [first, null, everything]
	graph.processes = [null, timer]
	return graph


func _test_timer_model() -> void:
	var graph: FlowGraph = _timer_fixture()
	var timer: FlowTimerDefinition = graph.processes[1] as FlowTimerDefinition
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Schema 3 Timer validates in the global process registry.")
	var copy: FlowGraph = graph.duplicate_with_new_ids()
	if not _check(copy != null and copy.processes.size() == 2, "Timer duplicate preserves process positions."):
		return
	var timer_copy: FlowTimerDefinition = copy.processes[1] as FlowTimerDefinition
	if not _check(timer_copy != null and timer_copy != timer, "Timer duplicate preserves independent subtype."):
		return
	_check(timer_copy.get_internal_id() != timer.get_internal_id(), "Timer duplicate renews global ID.")
	_check(timer_copy.repeat and timer_copy.interval_seconds == 3600.0, "Timer settings duplicate literally.")
	_verify_copy(graph, copy, false)
	timer_copy.interval_seconds = 2.0
	_check(timer.interval_seconds == 3600.0, "Mutating copied Timer does not mutate definition.")
	if not _check(ResourceSaver.save(graph, GRAPH_PATH) == OK, "Save Timer graph."):
		return
	var loaded: FlowGraph = ResourceLoader.load(GRAPH_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as FlowGraph
	if not _check(loaded != null and loaded.processes.size() == 2, "Load Timer graph without cache."):
		return
	var loaded_timer: FlowTimerDefinition = loaded.processes[1] as FlowTimerDefinition
	if not _check(loaded_timer != null, "ResourceSaver preserves Timer type."):
		return
	_check(loaded_timer.get_internal_id() == timer.get_internal_id() and loaded_timer.repeat and loaded_timer.interval_seconds == 3600.0, "ResourceSaver preserves Timer ID and settings.")
	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	var scene: PackedScene = PackedScene.new()
	var packed_ok: bool = _check(scene.pack(controller) == OK, "Pack Timer controller without runtime nodes.")
	controller.free()
	if not packed_ok or not _check(ResourceSaver.save(scene, SCENE_PATH) == OK, "Save Timer scene."):
		return
	var loaded_scene: PackedScene = ResourceLoader.load(SCENE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if not _check(loaded_scene != null, "Load Timer scene without cache."):
		return
	var instance: PVController = loaded_scene.instantiate() as PVController
	if not _check(instance != null, "Instantiate Timer controller."):
		return
	_check(instance.get_child_count(true) == 0, "Persisted controller has no scheduler or Timer nodes.")
	if _check(instance.flow_graph != null and instance.flow_graph.processes.size() == 2, "Packed Timer collection exists."):
		var restored: FlowTimerDefinition = instance.flow_graph.processes[1] as FlowTimerDefinition
		if _check(restored != null, "PackedScene preserves Timer subtype."):
			_check(restored.repeat and restored.interval_seconds == 3600.0 and restored.get_internal_id() == timer.get_internal_id(), "PackedScene preserves Timer configuration and ID.")
	instance.free()
	timer.interval_seconds = -1.0
	var first_validation: FlowValidationResult = FlowGraphValidator.validate(graph)
	var second_validation: FlowValidationResult = FlowGraphValidator.validate(graph)
	if _check(first_validation.diagnostics.size() == 1 and second_validation.diagnostics.size() == 1, "Invalid Timer produces exactly one deterministic error."):
		var diagnostic: FlowDiagnostic = first_validation.diagnostics[0]
		_check(diagnostic.code == &"invalid_timer_interval" and diagnostic.element_path == "processes[1].interval_seconds" and diagnostic.related_id == timer.get_internal_id(), "Timer error code/path/ID exact.")
		_check(second_validation.diagnostics[0].code == diagnostic.code and timer.interval_seconds == -1.0, "Validation repeats without repairing Timer.")
	var schema_2: FlowGraph = FlowGraph.new()
	schema_2.schema_version = FlowGraph.SCHEMA_VERSION_2
	schema_2.processes = [FlowTimerDefinition.new()]
	var incompatible: FlowValidationResult = FlowGraphValidator.validate(schema_2)
	_check(
		incompatible.diagnostics.size() == 1 \
			and incompatible.diagnostics[0].code == &"timer_incompatible_schema" \
			and incompatible.diagnostics[0].element_path == "processes[0]",
		"Schema 2 remains migration-only and rejects Timer definitions deterministically."
	)


func _native_timers(controller: PVController) -> Array[Timer]:
	var timers: Array[Timer] = []
	for child: Node in controller.get_children(true):
		if child is FlowTimerRuntime:
			for clock_node: Node in child.get_children(true):
				if clock_node is Timer:
					timers.append(clock_node as Timer)
	return timers


func _test_timers() -> void:
	var controller: PVController = PVController.new()
	var graph: FlowGraph = _timer_fixture()
	controller.flow_graph = graph
	var contexts: Array[StringName] = []
	controller.runtime_output.message_emitted.connect(_record)
	controller.runtime_output.entry_message_emitted.connect(func(_c: Node, _p: String, _b: String, _m: String, entry: StringName) -> void: contexts.append(entry))
	_events.clear()
	add_child(controller)
	var timers: Array[Timer] = _native_timers(controller)
	if not _check(timers.size() == 1, "Enabled Timer starts exactly one internal clock."):
		controller.queue_free()
		return
	var clock_node: Timer = timers[0]
	_check(clock_node.owner == null and not clock_node.is_stopped(), "Clock starts automatically without a persistent scene owner.")
	clock_node.timeout.emit()
	clock_node.timeout.emit()
	if _check(_events.size() == 4 and contexts.size() == 4, "Repeat produces two ordered block passes through both output APIs."):
		_check(_events[0].message == "Timer first" and _events[1].message == "Todo es Flujo; todo fluye." and _events[2].message == "Timer first", "Timer blocks run in stable order.")
		_check(contexts[0] == &"Timer" and _events[0].process_id == graph.processes[1].get_internal_id(), "Context identifies Timer and preserves old IDs.")
	controller.visual_program_enabled = false
	clock_node.timeout.emit()
	_check(_events.size() == 4 and clock_node.is_stopped(), "Program disable stops repeat and disconnects timeout.")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_native_timers(controller).is_empty(), "Program disable cleans internal clocks.")
	controller.queue_free()
	await get_tree().process_frame
	# One bounded real native timeout verifies the wiring without wall-clock sleeps.
	var once: PVController = PVController.new()
	once.flow_graph = _timer_fixture()
	var definition: FlowTimerDefinition = once.flow_graph.processes[1] as FlowTimerDefinition
	definition.repeat = false
	definition.interval_seconds = 0.001
	once.runtime_output.message_emitted.connect(_record)
	_events.clear()
	add_child(once)
	for frame: int in 300:
		if _events.size() >= 2:
			break
		await get_tree().process_frame
	_check(_events.size() == 2, "Native one-shot timeout executes once.")
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_events.size() == 2 and _native_timers(once).is_empty(), "One-shot cleans its clock and does not repeat.")
	once.queue_free()
	await get_tree().process_frame
	var detached: PVController = PVController.new()
	detached.flow_graph = _timer_fixture()
	add_child(detached)
	remove_child(detached)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_native_timers(detached).is_empty(), "Tree exit cleans all clocks.")
	detached.free()
	for invalid: bool in [false, true]:
		var inactive: PVController = PVController.new()
		inactive.flow_graph = _timer_fixture()
		var timer_definition: FlowTimerDefinition = inactive.flow_graph.processes[1] as FlowTimerDefinition
		timer_definition.enabled = invalid
		if invalid:
			timer_definition.interval_seconds = 0.0
		add_child(inactive)
		_check(_native_timers(inactive).is_empty(), "Disabled or invalid Timer creates no clock.")
		inactive.queue_free()
		await get_tree().process_frame
