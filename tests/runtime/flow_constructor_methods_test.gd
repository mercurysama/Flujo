extends SceneTree

const TEMP_PATH: String = "res://.godot/flujo_tests/constructor_methods_focal.tres"
const SCENE_PATH: String = "res://.godot/flujo_tests/constructor_methods_focal.tscn"
var _failures: Array[String] = []
var _events: Array[Dictionary] = []


func _init() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_failures.append(message)
		push_error(message)
	return condition


func _print_block(message: String) -> FlowPrintBlock:
	var block: FlowPrintBlock = FlowPrintBlock.new()
	block.text = message
	return block


func _call(method_id: String) -> FlowMethodCallBlock:
	var block: FlowMethodCallBlock = FlowMethodCallBlock.new()
	block.method_id = method_id
	return block


func _record(_controller: Node, container_id: String, block_id: String, message: String,
		entry_point: StringName, method_id: String, call_id: String) -> void:
	_events.append({"container": container_id, "block": block_id, "message": message,
		"entry": entry_point, "method": method_id, "call": call_id})


func _messages() -> Array[String]:
	var messages: Array[String] = []
	for event: Dictionary in _events:
		messages.append(event.message)
	return messages


func _run() -> void:
	var controller: PVController = PVController.new()
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	graph.constructor.blocks = [_print_block("constructor"), null]
	var method: FlowMethodDefinition = FlowMethodDefinition.new()
	method.display_name = "Flujo"
	method.blocks = [_print_block("method"), null, FlowEverythingFlowsBlock.new()]
	graph.methods = [null, method]
	var process: FlowProcess = FlowProcess.new()
	var call: FlowMethodCallBlock = _call(method.get_internal_id())
	process.blocks = [_print_block("before"), call, _print_block("after")]
	var timer: FlowTimerDefinition = FlowTimerDefinition.new()
	timer.interval_seconds = 3600.0
	timer.blocks = [_call(method.get_internal_id())]
	graph.processes = [process, null, timer]
	controller.flow_graph = graph
	controller.runtime_output.contextual_message_emitted.connect(_record)
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Schema 3 fixture is valid without schema changes.")
	get_root().add_child(controller)
	_check(_messages() == ["constructor", "before", "method", "Todo es Flujo; todo fluye.", "after"], "Constructor precedes Ready and calls return to the next ordered block.")
	if _check(_events.size() == 5, "Startup emits exactly five structured messages."):
		_check(_events[0].container == graph.constructor.get_internal_id() and _events[0].entry == &"Constructor", "Constructor output carries its container identity.")
		_check(_events[2].container == process.get_internal_id() and _events[2].method == method.get_internal_id() and _events[2].call == call.get_internal_id(), "Method output retains entry identity plus method and call IDs.")
	controller.request_ready()
	get_root().remove_child(controller)
	get_root().add_child(controller)
	_check(_events.size() == 5, "Constructor and Ready do not repeat on request_ready/re-entry.")
	await process_frame
	_events.clear()
	var scheduler: FlowTimerRuntime = controller.get("_timer_runtime") as FlowTimerRuntime
	if _check(scheduler != null, "Controller creates its Timer scheduler."):
		var timers: Array[Node] = scheduler.get_children(true)
		if _check(timers.size() == 1 and timers[0] is Timer, "One transient Timer can be driven without waiting."):
			(timers[0] as Timer).timeout.emit()
	_check(_messages() == ["method", "Todo es Flujo; todo fluye."], "Timer calls the same method blocks in order.")
	if _check(_events.size() == 2, "Timer produces two messages."):
		_check(_events[0].entry == &"Timer" and _events[0].container == timer.get_internal_id(), "Timer method output identifies the Timer entry.")
	method.display_name = "Renamed method"
	_check(call.method_id == method.get_internal_id(), "Renaming a method preserves the call target ID.")
	_events.clear()
	FlowReadyExecutor.new().execute(controller, graph, controller.runtime_output)
	_check(_messages() == ["before", "method", "Todo es Flujo; todo fluye.", "after"], "Renamed method is still executable by ID.")
	method.enabled = false
	_events.clear()
	FlowReadyExecutor.new().execute(controller, graph, controller.runtime_output)
	_check(_messages() == ["before", "after"], "Disabled method is skipped without stopping Ready.")
	method.enabled = true
	graph.methods = []
	_events.clear()
	FlowReadyExecutor.new().execute(controller, graph, controller.runtime_output)
	_check(_messages() == ["before", "after"] and call.method_id == method.get_internal_id(), "Deleted target is diagnosed and preserved while later blocks run.")
	graph.methods = [null, method]
	call.method_id = process.get_internal_id()
	_events.clear()
	FlowReadyExecutor.new().execute(controller, graph, controller.runtime_output)
	_check(_messages() == ["before", "after"], "Wrong-kind target does not stop later blocks.")
	call.method_id = method.get_internal_id()
	method.blocks.append(_call(method.get_internal_id()))
	graph.constructor.blocks.append(_call(method.get_internal_id()))
	_events.clear()
	FlowReadyExecutor.new().execute(controller, graph, controller.runtime_output, &"Constructor")
	FlowReadyExecutor.new().execute(controller, graph, controller.runtime_output)
	_check(_messages() == ["constructor", "before", "method", "Todo es Flujo; todo fluye.", "after"], "Constructor and method calls are not executable; stored recursion cannot recurse.")
	method.blocks.pop_back()
	graph.constructor.blocks.pop_back()
	method.return_definition = FlowMethodReturnDefinition.new()
	_events.clear()
	FlowReadyExecutor.new().execute(controller, graph, controller.runtime_output)
	_check(_messages() == ["before", "after"], "Return declarations do not silently acquire runtime semantics.")
	method.return_definition = null
	method.parameters.append(FlowMethodParameterDefinition.new())
	_events.clear()
	FlowReadyExecutor.new().execute(controller, graph, controller.runtime_output)
	_check(_messages() == ["before", "after"], "Parameters are explicitly outside the executable method subset.")
	method.parameters.clear()
	_persistence(controller, graph, method, call)
	controller.queue_free()
	await process_frame
	await process_frame
	for path: String in [TEMP_PATH, SCENE_PATH]:
		if FileAccess.file_exists(path):
			_check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK, "Remove exact focal artifact: " + path)
	if _failures.is_empty():
		print("[Flujo] Constructor and Methods runtime focal passed")
	quit(0 if _failures.is_empty() else 1)


func _persistence(controller: PVController, graph: FlowGraph, method: FlowMethodDefinition, call: FlowMethodCallBlock) -> void:
	if not _check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/flujo_tests")) == OK, "Create scoped persistence directory."):
		return
	if not _check(ResourceSaver.save(graph, TEMP_PATH) == OK, "Save schema 3 Constructor and Methods graph."):
		return
	var loaded: FlowGraph = ResourceLoader.load(TEMP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as FlowGraph
	if not _check(loaded != null and loaded != graph, "Reload independent graph."):
		return
	if not _check(loaded.constructor != null and loaded.methods.size() == 2 and loaded.processes.size() == 3, "Reloaded graph retains structure and null positions."):
		return
	if not _check(loaded.methods[1] != null and loaded.processes[0] != null and loaded.processes[0].blocks.size() == 3, "Reloaded method and call container exist."):
		return
	var loaded_call: FlowMethodCallBlock = loaded.processes[0].blocks[1] as FlowMethodCallBlock
	_check(loaded_call != null and loaded_call.method_id == call.method_id and loaded_call.get_internal_id() == call.get_internal_id(), "Call subtype, ID and target survive ResourceSaver.")
	_check(loaded.methods[1].get_internal_id() == method.get_internal_id() and loaded.methods[1].display_name == method.display_name and loaded.methods[0] == null, "Method name, ID and order survive persistence.")
	_check(loaded.constructor.get_internal_id() == graph.constructor.get_internal_id(), "Constructor identity survives persistence.")
	var packed: PackedScene = PackedScene.new()
	if not _check(packed.pack(controller) == OK and ResourceSaver.save(packed, SCENE_PATH) == OK, "Pack and save controller definitions without internal runtime nodes."):
		return
	var scene: PackedScene = ResourceLoader.load(SCENE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if not _check(scene != null, "Reload PackedScene."):
		return
	var instance: PVController = scene.instantiate() as PVController
	if not _check(instance != null and instance.flow_graph != null, "Instantiate persisted controller."):
		return
	_check(instance.flow_graph.schema_version == 3 and instance.flow_graph.constructor != null and instance.flow_graph.methods.size() == 2, "PackedScene retains schema 3 constructor/method structure.")
	if instance.flow_graph.methods.size() == 2 and instance.flow_graph.methods[1] != null:
		_check(instance.flow_graph.methods[1].get_internal_id() == method.get_internal_id(), "PackedScene retains method ID.")
	_check(instance.get_child_count(true) == 0, "Runtime nodes are not persisted.")
	instance.free()
