@tool
## Ephemeral runtime context used by FlowValueSource resolution.
class_name FlowValueResolutionContext
extends RefCounted


var graph: FlowGraph = null
var controller: PVController = null
var scene_root: Node = null
var _variable_values: Dictionary = {}
var _resolving_variable_ids: Dictionary[String, bool] = {}


func _init(
		new_graph: FlowGraph = null,
		new_controller: PVController = null,
		new_scene_root: Node = null
) -> void:
	graph = new_graph
	controller = new_controller
	scene_root = new_scene_root
	if scene_root == null and is_instance_valid(controller) and controller.is_inside_tree():
		var tree: SceneTree = controller.get_tree()
		if tree != null:
			scene_root = tree.current_scene


func set_variable_value(variable_id: String, runtime_value: Variant) -> void:
	_variable_values[variable_id] = runtime_value


func erase_variable_value(variable_id: String) -> void:
	_variable_values.erase(variable_id)


func has_variable_value(variable_id: String) -> bool:
	return _variable_values.has(variable_id)


func get_variable_value(variable_id: String) -> Variant:
	return _variable_values.get(variable_id, null)


func clear_runtime_values() -> void:
	_variable_values.clear()


func begin_variable_resolution(variable_id: String) -> bool:
	if variable_id.is_empty() or _resolving_variable_ids.has(variable_id):
		return false
	_resolving_variable_ids[variable_id] = true
	return true


func end_variable_resolution(variable_id: String) -> void:
	_resolving_variable_ids.erase(variable_id)


func is_resolving_variable(variable_id: String) -> bool:
	return _resolving_variable_ids.has(variable_id)


func set_scene_context(new_controller: PVController, new_scene_root: Node = null) -> void:
	controller = new_controller if is_instance_valid(new_controller) else null
	scene_root = new_scene_root if is_instance_valid(new_scene_root) else null
	if scene_root == null and controller != null and controller.is_inside_tree():
		var tree: SceneTree = controller.get_tree()
		if tree != null:
			scene_root = tree.current_scene


func resolve_scene_node(requirement_id: String, fallback_path: NodePath) -> Node:
	if controller != null 			and not requirement_id.is_empty() 			and controller.requirement_bindings.has(requirement_id):
		var binding: NodePath = controller.requirement_bindings[requirement_id]
		var required_node: Node = controller.get_node_or_null(binding)
		if required_node != null:
			return required_node
	if scene_root != null and not fallback_path.is_empty():
		return scene_root.get_node_or_null(fallback_path)
	return null
