class_name FlowFSMOperations
extends RefCounted

## Callback-scoped, machine-bound facade. Not a sandbox for arbitrary GDScript.
var _runtime: FlowFSMRuntime
var _controller: PVController
var _graph: FlowGraph
var _machine_id: String = ""
var _valid: bool = true


func _init(runtime: FlowFSMRuntime, controller: PVController,
		graph: FlowGraph, machine_id: String) -> void:
	_runtime = runtime
	_controller = controller
	_graph = graph
	_machine_id = machine_id


func invalidate() -> void:
	_valid = false


func _can_use() -> bool:
	return _valid and _runtime != null and _runtime.is_running() \
		and is_instance_valid(_controller) and _controller.can_execute_visual_program() \
		and _controller.flow_graph == _graph


func register_state(template_state_id: String, runtime_id: String = "",
		lifetime: int = FlowFSMDynamicStateRecord.Lifetime.EPHEMERAL,
		data: Dictionary = {}) -> String:
	if not _can_use():
		return ""
	return _runtime.register_state(_machine_id, template_state_id, runtime_id, lifetime, data)


func has_state(state_id: String) -> bool:
	return _can_use() and _runtime.has_state(_machine_id, state_id)


func change_state(state_id: String) -> bool:
	return _can_use() and _runtime.change_state(_machine_id, state_id)


func remove_state(state_id: String, fallback_state_id: String = "") -> bool:
	return _can_use() and _runtime.remove_state(_machine_id, state_id, fallback_state_id)


func get_state_data(state_id: String) -> Dictionary:
	if not _can_use():
		return {}
	return _runtime.get_dynamic_state_data(_machine_id, state_id)


func set_state_data(state_id: String, data: Dictionary) -> bool:
	return _can_use() and _runtime.set_dynamic_state_data(_machine_id, state_id, data)
