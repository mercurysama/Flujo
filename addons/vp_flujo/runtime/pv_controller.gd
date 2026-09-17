@tool
class_name PVController
extends Node

## VPFlujo entry point for a scene.
## Owns per-instance Ready execution while the shared graph remains read-only.

signal visual_program_enabled_changed(is_enabled: bool)

@export var flow_graph: FlowGraph = FlowGraph.new()

var runtime_output: FlowRuntimeOutput = FlowRuntimeOutput.new()
var _ready_executed: bool = false
var _timer_runtime: FlowTimerRuntime

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
	if can_execute_visual_program():
		FlowReadyExecutor.new().execute(self, flow_graph, runtime_output)
		_start_timers()


func _enter_tree() -> void:
	if not Engine.is_editor_hint() and _ready_executed:
		_start_timers()


func _exit_tree() -> void:
	_stop_timers()


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
