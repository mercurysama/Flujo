@tool
## Persistent reference to one scene Node as an Object-valued Flow source.
##
## NodeRef is not a Literal. It stores semantic identity and resolves to the
## live Node through FlowValueResolutionContext.
class_name FlowNodeRefValueSource
extends FlowValueSource


const SOURCE_KIND: StringName = FlowValueSource.SOURCE_KIND_NODE_REF
const PRODUCED_TYPE: Variant.Type = Variant.Type.TYPE_OBJECT

@export_storage var requirement_id: String = ""
@export_storage var node_path: NodePath = NodePath()
@export_storage var node_name_hint: StringName = &""
@export_storage var node_class_hint: StringName = &"Node"


func _init(
		new_requirement_id: String = "",
		new_node_path: NodePath = NodePath(),
		new_node_name_hint: StringName = &"",
		new_node_class_hint: StringName = &"Node"
) -> void:
	requirement_id = new_requirement_id
	node_path = new_node_path
	node_name_hint = new_node_name_hint
	node_class_hint = new_node_class_hint


func get_source_kind() -> StringName:
	return SOURCE_KIND


func get_value_type() -> Variant.Type:
	return PRODUCED_TYPE


func get_preview() -> String:
	var label: String = String(node_name_hint)
	if label.is_empty():
		label = String(node_path)
	if label.is_empty() and not requirement_id.is_empty():
		label = "Requirement"
	if label.is_empty():
		label = "Node"
	return "$" + label


func has_locator() -> bool:
	return not requirement_id.is_empty() or not node_path.is_empty()


func is_valid() -> bool:
	if not FlowId.is_valid(_source_id):
		return false
	if not requirement_id.is_empty() and not FlowId.is_valid(requirement_id):
		return false
	if node_path.is_absolute():
		return false
	return not String(node_class_hint).strip_edges().is_empty()


func validate_structure(result: FlowValidationResult, element_path: String) -> void:
	super.validate_structure(result, element_path)
	if result == null:
		return
	if not has_locator():
		result.add_diagnostic(FlowDiagnostic.new(
			FlowDiagnostic.CODE_NODE_REF_LOCATOR_MISSING,
			FlowDiagnostic.Severity.WARNING,
			"NodeRef is structurally valid but not bound to a scene Node yet.",
			element_path,
			_source_id
		))
	elif not requirement_id.is_empty() and not FlowId.is_valid(requirement_id):
		_add_error(
			result,
			FlowDiagnostic.CODE_NODE_REF_REQUIREMENT_ID_INVALID,
			"NodeRef requirement_id is invalid.",
			element_path + ".requirement_id",
			requirement_id
		)
	if not node_path.is_empty() and node_path.is_absolute():
		_add_error(
			result,
			FlowDiagnostic.CODE_NODE_REF_PATH_INVALID,
			"NodeRef node_path must be relative to the scene root.",
			element_path + ".node_path",
			_source_id
		)
	if String(node_class_hint).strip_edges().is_empty():
		_add_error(
			result,
			FlowDiagnostic.CODE_NODE_REF_CLASS_MISMATCH,
			"NodeRef class hint cannot be empty.",
			element_path + ".node_class_hint",
			_source_id
		)


func validate_against_graph(
		result: FlowValidationResult,
		element_path: String,
		graph: FlowGraph
) -> void:
	if result == null or graph == null or requirement_id.is_empty():
		return
	var found: bool = false
	if graph.constructor != null:
		for requirement: FlowRequiredNodeDefinition in graph.constructor.requirements:
			if requirement != null and requirement.get_internal_id() == requirement_id:
				found = true
				break
	if not found:
		_add_error(
			result,
			FlowDiagnostic.CODE_NODE_REF_REQUIREMENT_MISSING,
			"NodeRef requirement_id is missing from the active FlowGraph.",
			element_path + ".requirement_id",
			requirement_id
		)


func resolve(context: Variant = null) -> FlowValueResult:
	if not has_locator():
		return _failure(
			FlowDiagnostic.CODE_NODE_REF_LOCATOR_MISSING,
			"NodeRef is not bound to a scene Node."
		)
	var resolution_context: FlowValueResolutionContext = context as FlowValueResolutionContext
	if resolution_context == null:
		return _failure(
			FlowDiagnostic.CODE_NODE_REF_CONTEXT_MISSING,
			"NodeRef requires FlowValueResolutionContext."
		)
	var node: Node = resolution_context.resolve_scene_node(requirement_id, node_path)
	if node == null:
		return _failure(
			FlowDiagnostic.CODE_NODE_REF_NODE_MISSING,
			"NodeRef could not resolve its scene node."
		)
	if not String(node_class_hint).is_empty() 			and not node.is_class(String(node_class_hint)):
		return _failure(
			FlowDiagnostic.CODE_NODE_REF_CLASS_MISMATCH,
			"Resolved Node class does not match the authored class hint."
		)
	return FlowValueResult.ok(node, PRODUCED_TYPE)


static func placeholder(expected_class_name: StringName = &"Node") -> FlowNodeRefValueSource:
	return FlowNodeRefValueSource.new(
		"",
		NodePath(),
		&"Node",
		expected_class_name
	)


func duplicate_with_new_id() -> FlowValueSource:
	var copy: FlowNodeRefValueSource = duplicate(false) as FlowNodeRefValueSource
	copy._source_id = FlowId.create()
	return copy


func _failure(code: StringName, message: String) -> FlowValueResult:
	return FlowValueResult.fail(
		PRODUCED_TYPE,
		FlowDiagnostic.new(
			code,
			FlowDiagnostic.Severity.ERROR,
			message,
			"value_source",
			_source_id
		)
	)


static func _add_error(
		result: FlowValidationResult,
		code: StringName,
		message: String,
		path: String,
		related_id: String = ""
) -> void:
	result.add_diagnostic(FlowDiagnostic.new(
		code,
		FlowDiagnostic.Severity.ERROR,
		message,
		path,
		related_id
	))
