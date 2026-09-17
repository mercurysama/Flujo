@tool
class_name PVController
extends Node

## VPFlujo entry point for a scene.
## Owns per-instance Ready execution while the shared graph remains read-only.

signal visual_program_enabled_changed(is_enabled: bool)

@export var flow_graph: FlowGraph = FlowGraph.new()

var runtime_output: FlowRuntimeOutput = FlowRuntimeOutput.new()
var _ready_executed: bool = false

var visual_program_enabled: bool = true:
	set(value):
		if visual_program_enabled == value:
			return
		visual_program_enabled = value
		visual_program_enabled_changed.emit(value)


func can_execute_visual_program() -> bool:
	return visual_program_enabled and is_inside_tree()


func _ready() -> void:
	if Engine.is_editor_hint() or _ready_executed:
		return
	_ready_executed = true
	if can_execute_visual_program():
		FlowReadyExecutor.new().execute(self, flow_graph, runtime_output)
