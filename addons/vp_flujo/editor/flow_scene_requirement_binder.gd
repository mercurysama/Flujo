@tool
## Editor-only bridge between a direct scene child and schema-4 Requirement data.
class_name FlowSceneRequirementBinder
extends RefCounted


var _undo_redo: EditorUndoRedoManager


func _init(undo_redo: EditorUndoRedoManager) -> void:
	_undo_redo = undo_redo


func ensure_requirement(controller: PVController, node: Node) -> String:
	if not is_instance_valid(controller) or not is_instance_valid(node):
		return ""
	if node.get_parent() != controller:
		return ""
	var graph: FlowGraph = controller.flow_graph
	if graph == null or graph.schema_version not in [
		FlowGraph.SCHEMA_VERSION_4,
		FlowGraph.SCHEMA_VERSION_5,
	]:
		return ""
	var binding_path: NodePath = NodePath(String(node.name))
	var existing_id: String = _requirement_id_for_binding(controller, binding_path)
	if not existing_id.is_empty():
		return existing_id
	if _undo_redo == null:
		return ""

	var constructor: FlowConstructorDefinition = graph.constructor
	var constructor_was_missing: bool = constructor == null
	if constructor == null:
		constructor = FlowConstructorDefinition.new()

	var requirement: FlowRequiredNodeDefinition = FlowRequiredNodeDefinition.new()
	requirement.display_name = String(node.name)
	requirement.expected_node_name = node.name
	requirement.required_class_name = node.get_class()
	requirement.required = true

	var before_requirements: Array[FlowRequiredNodeDefinition] = []
	if not constructor_was_missing:
		before_requirements.assign(constructor.requirements)
	var after_requirements: Array[FlowRequiredNodeDefinition] = before_requirements.duplicate()
	after_requirements.append(requirement)
	var before_bindings: Dictionary[String, NodePath] = controller.requirement_bindings.duplicate()
	var after_bindings: Dictionary[String, NodePath] = before_bindings.duplicate()
	after_bindings[requirement.get_internal_id()] = binding_path

	_undo_redo.create_action("Bind Scene Node Requirement")
	if constructor_was_missing:
		_undo_redo.add_do_property(graph, &"constructor", constructor)
		_undo_redo.add_undo_property(graph, &"constructor", null)
	_undo_redo.add_do_property(constructor, &"requirements", after_requirements)
	_undo_redo.add_undo_property(constructor, &"requirements", before_requirements)
	_undo_redo.add_do_property(controller, &"requirement_bindings", after_bindings)
	_undo_redo.add_undo_property(controller, &"requirement_bindings", before_bindings)
	_undo_redo.commit_action()
	return requirement.get_internal_id()


static func _requirement_id_for_binding(
		controller: PVController,
		binding_path: NodePath
) -> String:
	if controller == null:
		return ""
	var keys: Array[String] = controller.requirement_bindings.keys()
	keys.sort()
	for requirement_id: String in keys:
		if controller.requirement_bindings[requirement_id] == binding_path:
			return requirement_id
	return ""
