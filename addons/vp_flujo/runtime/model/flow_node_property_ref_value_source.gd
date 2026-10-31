@tool
## Persistent typed reference to one property on a scene Node.
##
## requirement_id is the preferred stable semantic binding when available.
## node_path is a scene-root-relative authoring fallback used by pre-schema-4
## graphs and for editor repair when a requirement is not yet available.
class_name FlowNodePropertyRefValueSource
extends FlowValueSource


const SOURCE_KIND: StringName = FlowValueSource.SOURCE_KIND_NODE_PROPERTY_REF

@export_storage var requirement_id: String = ""
@export_storage var node_path: NodePath = NodePath()
@export_storage var node_name_hint: StringName = &""
@export_storage var property_name: StringName = &""
@export_storage var declared_value_type: Variant.Type = Variant.Type.TYPE_NIL


func _init(
		new_requirement_id: String = "",
		new_node_path: NodePath = NodePath(),
		new_node_name_hint: StringName = &"",
		new_property_name: StringName = &"",
		new_declared_value_type: Variant.Type = Variant.Type.TYPE_NIL
) -> void:
	requirement_id = new_requirement_id
	node_path = new_node_path
	node_name_hint = new_node_name_hint
	property_name = new_property_name
	declared_value_type = new_declared_value_type


func get_source_kind() -> StringName:
	return SOURCE_KIND


func get_value_type() -> Variant.Type:
	return declared_value_type


func get_preview() -> String:
	var node_label: String = String(node_name_hint)
	if node_label.is_empty():
		node_label = String(node_path)
	if node_label.is_empty() and not requirement_id.is_empty():
		node_label = "Requirement"
	if node_label.is_empty():
		node_label = "Node"
	return "$%s.%s" % [node_label, String(property_name)]


func is_valid() -> bool:
	if not FlowId.is_valid(_source_id):
		return false
	if requirement_id.is_empty() and node_path.is_empty():
		return false
	if not requirement_id.is_empty() and not FlowId.is_valid(requirement_id):
		return false
	if node_path.is_absolute():
		return false
	if String(property_name).strip_edges().is_empty():
		return false
	return FlowLiteralValueSource.is_allowed_type(declared_value_type)


func validate_structure(result: FlowValidationResult, element_path: String) -> void:
	super.validate_structure(result, element_path)
	if result == null:
		return
	if requirement_id.is_empty() and node_path.is_empty():
		_add_error(
			result,
			FlowDiagnostic.CODE_NODE_PROPERTY_LOCATOR_MISSING,
			"NodePropertyRef requires a requirement_id or a relative node_path.",
			element_path,
			_source_id
		)
	elif not requirement_id.is_empty() and not FlowId.is_valid(requirement_id):
		_add_error(
			result,
			FlowDiagnostic.CODE_NODE_PROPERTY_REQUIREMENT_ID_INVALID,
			"NodePropertyRef requirement_id is invalid.",
			element_path + ".requirement_id",
			requirement_id
		)
	if not node_path.is_empty() and node_path.is_absolute():
		_add_error(
			result,
			FlowDiagnostic.CODE_NODE_PROPERTY_PATH_INVALID,
			"NodePropertyRef node_path must be relative to the scene root.",
			element_path + ".node_path",
			_source_id
		)
	if String(property_name).strip_edges().is_empty():
		_add_error(
			result,
			FlowDiagnostic.CODE_NODE_PROPERTY_NAME_EMPTY,
			"NodePropertyRef property_name is empty.",
			element_path + ".property_name",
			_source_id
		)
	if not FlowLiteralValueSource.is_allowed_type(declared_value_type):
		_add_error(
			result,
			FlowDiagnostic.CODE_NODE_PROPERTY_TYPE_UNSUPPORTED,
			"NodePropertyRef uses an unsupported property Variant.Type.",
			element_path + ".declared_value_type",
			_source_id
		)


func resolve(context: Variant = null) -> FlowValueResult:
	var resolution_context: FlowValueResolutionContext = context as FlowValueResolutionContext
	if resolution_context == null:
		return _failure(
			FlowDiagnostic.CODE_NODE_PROPERTY_CONTEXT_MISSING,
			"NodePropertyRef requires FlowValueResolutionContext."
		)
	var node: Node = resolution_context.resolve_scene_node(requirement_id, node_path)
	if node == null:
		return _failure(
			FlowDiagnostic.CODE_NODE_PROPERTY_NODE_MISSING,
			"NodePropertyRef could not resolve its scene node."
		)
	var descriptor: Dictionary = property_descriptor(node, property_name)
	if descriptor.is_empty():
		return _failure(
			FlowDiagnostic.CODE_NODE_PROPERTY_MISSING,
			"NodePropertyRef property is missing on the resolved node."
		)
	var descriptor_type: Variant.Type = int(
		descriptor.get("type", Variant.Type.TYPE_NIL)
	) as Variant.Type
	if descriptor_type != declared_value_type:
		return _failure(
			FlowDiagnostic.CODE_NODE_PROPERTY_TYPE_MISMATCH,
			"Resolved property metadata does not match the authored Variant.Type."
		)
	var resolved_value: Variant = node.get(property_name)
	if typeof(resolved_value) != declared_value_type:
		return _failure(
			FlowDiagnostic.CODE_NODE_PROPERTY_TYPE_MISMATCH,
			"Resolved property value does not match the authored Variant.Type."
		)
	return FlowValueResult.ok(resolved_value, declared_value_type)


func duplicate_with_new_id() -> FlowValueSource:
	var copy: FlowNodePropertyRefValueSource = duplicate(false) as FlowNodePropertyRefValueSource
	copy._source_id = FlowId.create()
	return copy


static func property_descriptor(node: Node, target_property: StringName) -> Dictionary:
	if node == null or String(target_property).is_empty():
		return {}
	for descriptor: Dictionary in node.get_property_list():
		if StringName(descriptor.get("name", &"")) == target_property:
			return descriptor.duplicate(true)
	return {}


func _failure(code: StringName, message: String) -> FlowValueResult:
	return FlowValueResult.fail(
		declared_value_type,
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
