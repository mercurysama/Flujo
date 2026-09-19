@tool
class_name PVController
extends Node

## VPFlujo entry point for a scene.
## Owns per-instance Ready execution while the shared graph remains read-only.

signal visual_program_enabled_changed(is_enabled: bool)

@export var flow_graph: FlowGraph = FlowGraph.new()
## Schema 4 scene-local data only; resolution and runtime verification are deferred.
@export_storage var requirement_bindings: Dictionary[String, NodePath] = {}:
	set(value):
		# PackedScene instances and controllers must not share a mutable binding map.
		requirement_bindings = value.duplicate()

var runtime_output: FlowRuntimeOutput = FlowRuntimeOutput.new()
var _ready_executed: bool = false
var _timer_runtime: FlowTimerRuntime
## Transient schema 5 state. These fields are deliberately not exported.
var instance_runtime_store: FlowInstanceRuntimeStore
var class_runtime_store: FlowClassRuntimeStore
var runtime_store_result: FlowStoreResult

var visual_program_enabled: bool = true:
	set(value):
		if visual_program_enabled == value:
			return
		visual_program_enabled = value
		if not value:
			_stop_timers()
		visual_program_enabled_changed.emit(value)


func can_execute_visual_program() -> bool:
	return visual_program_enabled and is_inside_tree()


func _ready() -> void:
	if Engine.is_editor_hint() or _ready_executed:
		return
	_ready_executed = true
	if flow_graph != null and flow_graph.schema_version == FlowGraph.SCHEMA_VERSION_5:
		return
	if can_execute_visual_program():
		FlowReadyExecutor.new().execute(self, flow_graph, runtime_output, &"Constructor")
	if can_execute_visual_program():
		FlowReadyExecutor.new().execute(self, flow_graph, runtime_output)
		_start_timers()


func _enter_tree() -> void:
	if not Engine.is_editor_hint() and flow_graph != null and flow_graph.schema_version == FlowGraph.SCHEMA_VERSION_5:
		_initialize_attribute_stores()
		return
	if not Engine.is_editor_hint() and _ready_executed:
		_start_timers()


func _exit_tree() -> void:
	if instance_runtime_store != null:
		instance_runtime_store.close()
	instance_runtime_store = null
	class_runtime_store = null
	runtime_store_result = null
	_stop_timers()


func _initialize_attribute_stores() -> void:
	var candidate: FlowInstanceRuntimeStore = FlowInstanceRuntimeStore.new()
	runtime_store_result = candidate.initialize(flow_graph)
	if not runtime_store_result.ok:
		return
	runtime_store_result = FlowClassRuntimeStore.acquire(get_tree(), flow_graph)
	if not runtime_store_result.ok:
		candidate.close()
		return
	instance_runtime_store = candidate
	class_runtime_store = runtime_store_result.store as FlowClassRuntimeStore


func _start_timers() -> void:
	if Engine.is_editor_hint() or not can_execute_visual_program() or is_instance_valid(_timer_runtime):
		return
	_timer_runtime = FlowTimerRuntime.new()
	add_child(_timer_runtime, false, Node.INTERNAL_MODE_BACK)
	_timer_runtime.start(self)


func _stop_timers() -> void:
	if is_instance_valid(_timer_runtime):
		_timer_runtime.stop()
		_timer_runtime.queue_free()
	_timer_runtime = null
