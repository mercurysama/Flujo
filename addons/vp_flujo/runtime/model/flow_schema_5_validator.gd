@tool
class_name FlowSchema5Validator
extends RefCounted

## Runs after legacy structure, sharing its global identity registry.
static func validate_structure(graph: FlowGraph, result: FlowValidationResult,
		seen_instances: Dictionary[int, String], seen_ids: Dictionary[String, String]) -> void:
	if not graph.base_class_id.is_empty() and not FlowId.is_valid(graph.base_class_id):
		FlowClassCatalog.issue(result, &"class_base_id_invalid", "base_class_id", graph.base_class_id, "Invalid base class ID.")
	if graph.base_class_id == graph.get_internal_id():
		FlowClassCatalog.issue(result, &"class_inheritance_cycle", "base_class_id", graph.base_class_id, "A class cannot inherit itself.")
	var names: Dictionary[String, bool] = {}
	for record: Dictionary in FlowSchema5Model.owned_records(graph):
		var value: Resource = record.resource
		var path: String = record.path
		if value is FlowAttributeDefinition or value is FlowReferenceDefinition or value is FlowMethodOutputDefinition:
			if not FlowGraphValidator._validate_resource_identity(value, path, result, seen_instances, seen_ids):
				continue
		if value is FlowAttributeDefinition:
			var attribute: FlowAttributeDefinition = value as FlowAttributeDefinition
			_validate_attribute(attribute, path, names, result)
			var expected_storage: int = FlowAttributeDefinition.Storage.INSTANCE if path.begins_with("constructor.attributes[") else FlowAttributeDefinition.Storage.CLASS
			if attribute.storage != expected_storage:
				FlowClassCatalog.issue(result, &"attribute_storage_owner", path + ".storage", attribute.get_internal_id(), "Storage does not match its owning collection.")
		elif value is FlowMethodOutputDefinition:
			var output: FlowMethodOutputDefinition = value as FlowMethodOutputDefinition
			FlowGraphValidator._validate_value_type(output.value_type, path + ".value_type", output.get_internal_id(), result)
			if output.display_name.strip_edges().is_empty():
				FlowClassCatalog.issue(result, &"empty_display_name", path + ".display_name", output.get_internal_id(), "Output name must not be empty.")
		elif value is FlowMethodDefinition:
			var method: FlowMethodDefinition = value as FlowMethodDefinition
			if method.return_definition != null:
				FlowClassCatalog.issue(result, &"legacy_return_in_schema_5", path + ".return_definition", method.get_internal_id(), "Schema 5 uses outputs only.")
		elif value is FlowMethodCallBlock:
			var call: FlowMethodCallBlock = value as FlowMethodCallBlock
			if not call.method_id.is_empty():
				FlowClassCatalog.issue(result, &"legacy_method_target_in_schema_5", path + ".method_id", call.get_internal_id(), "Schema 5 uses the owned method reference only.")
			if call.method_reference == null:
				FlowClassCatalog.issue(result, &"method_reference_missing", path + ".method_reference", call.get_internal_id(), "Schema 5 requires an owned method reference.")
	# Resolve only after the complete identity inventory. External targets need catalog context.
	for record: Dictionary in FlowSchema5Model.owned_records(graph):
		if record.resource is FlowReferenceDefinition:
			result.diagnostics.append_array(validate_reference(record.resource, graph, {}, record.path).diagnostics)

static func _validate_attribute(attribute: FlowAttributeDefinition, path: String,
		names: Dictionary[String, bool], result: FlowValidationResult) -> void:
	FlowGraphValidator._validate_display_name(attribute.display_name, names, result, path, attribute.get_internal_id())
	FlowGraphValidator._validate_value_type(attribute.value_type, path + ".value_type", attribute.get_internal_id(), result)
	if not FlowAttributeDefinition.Storage.values().has(attribute.storage):
		FlowClassCatalog.issue(result, &"invalid_attribute_storage", path + ".storage", attribute.get_internal_id(), "Invalid attribute storage.")
	if not FlowAttributeDefinition.Visibility.values().has(attribute.visibility):
		FlowClassCatalog.issue(result, &"invalid_visibility", path + ".visibility", attribute.get_internal_id(), "Invalid visibility.")
	if not FlowAttributeDefinition.Mutability.values().has(attribute.mutability):
		FlowClassCatalog.issue(result, &"invalid_mutability", path + ".mutability", attribute.get_internal_id(), "Invalid mutability.")
	if attribute.default_is_null and not attribute.nullable:
		FlowClassCatalog.issue(result, &"attribute_null_default_invalid", path + ".default_is_null", attribute.get_internal_id(), "A null default requires nullable.")

## Standalone reference validation also supports future owning definitions without inventing one.
static func validate_reference(reference: FlowReferenceDefinition, caller: FlowGraph,
		classes: Dictionary[String, FlowGraph] = {}, path: String = "reference") -> FlowValidationResult:
	var result: FlowValidationResult = FlowValidationResult.new()
	if reference == null or caller == null:
		FlowClassCatalog.issue(result, &"reference_missing", path, "", "Reference and caller are required.")
		return result
	var kind_matches: bool = (reference is FlowAttributeReferenceDefinition and reference.expected_kind == FlowReferenceDefinition.TargetKind.ATTRIBUTE) \
		or (reference is FlowRequirementReferenceDefinition and reference.expected_kind == FlowReferenceDefinition.TargetKind.REQUIREMENT) \
		or (reference is FlowMethodReferenceDefinition and reference.expected_kind == FlowReferenceDefinition.TargetKind.METHOD)
	if not kind_matches:
		FlowClassCatalog.issue(result, &"reference_kind_invalid", path + ".expected_kind", reference.get_internal_id(), "Concrete reference and target kind must agree.")
		return result
	for field: String in ["target_class_id", "target_id"]:
		if not FlowId.is_valid(reference.get(field)):
			FlowClassCatalog.issue(result, &"reference_id_invalid", path + "." + field, reference.get(field), "Reference IDs must be valid and explicit.")
	if result.has_errors():
		return result
	var target_class: FlowGraph = caller if reference.target_class_id == caller.get_internal_id() else classes.get(reference.target_class_id)
	if target_class == null:
		FlowClassCatalog.issue(result, &"reference_class_unresolved", path + ".target_class_id", reference.target_class_id,
			"Class resolution requires a valid catalog entry.", FlowDiagnostic.Severity.WARNING if classes.is_empty() else FlowDiagnostic.Severity.ERROR)
		return result
	var matches: Array[Resource] = []
	for record: Dictionary in FlowSchema5Model.owned_records(target_class):
		var resource: Resource = record.resource
		if String(resource.call(&"get_internal_id")) == reference.target_id:
			matches.append(resource)
	if matches.size() != 1:
		FlowClassCatalog.issue(result, &"reference_target_missing" if matches.is_empty() else &"reference_target_ambiguous",
			path + ".target_id", reference.target_id, "Target must resolve exactly once in its declaring class.")
		return result
	var target: Resource = matches[0]
	var target_matches: bool = (target is FlowAttributeDefinition and reference.expected_kind == FlowReferenceDefinition.TargetKind.ATTRIBUTE) \
		or (target is FlowRequiredNodeDefinition and reference.expected_kind == FlowReferenceDefinition.TargetKind.REQUIREMENT) \
		or (target is FlowMethodDefinition and reference.expected_kind == FlowReferenceDefinition.TargetKind.METHOD)
	if not target_matches:
		FlowClassCatalog.issue(result, &"reference_target_kind", path + ".target_id", reference.target_id, "Target has the wrong definition type.")
	elif target is FlowAttributeDefinition:
		var visibility: int = target.get("visibility")
		var same_class: bool = caller.get_internal_id() == target_class.get_internal_id()
		if (visibility == FlowAttributeDefinition.Visibility.PRIVATE and not same_class) \
				or (visibility == FlowAttributeDefinition.Visibility.PROTECTED and not same_class and not _is_descendant(caller, target_class.get_internal_id(), classes)):
			FlowClassCatalog.issue(result, &"reference_inaccessible", path + ".target_id", reference.target_id, "Target is not accessible from this declaring context.")
	return result

static func _is_descendant(graph: FlowGraph, base_id: String, classes: Dictionary[String, FlowGraph]) -> bool:
	var visited: Dictionary[String, bool] = {}
	var next_id: String = graph.base_class_id
	while not next_id.is_empty() and not visited.has(next_id):
		if next_id == base_id:
			return true
		visited[next_id] = true
		if not classes.has(next_id):
			return false
		next_id = classes[next_id].base_class_id
	return false

static func validate_catalog_context(graph: FlowGraph, classes: Dictionary[String, FlowGraph],
		result: FlowValidationResult, prefix: String) -> void:
	for record: Dictionary in FlowSchema5Model.owned_records(graph):
		if record.resource is FlowReferenceDefinition:
			var reference: FlowReferenceDefinition = record.resource
			if reference.target_class_id != graph.get_internal_id():
				result.diagnostics.append_array(validate_reference(reference, graph, classes, prefix + "." + record.path).diagnostics)
	# Inherited private slots are deliberately excluded from name conflicts.
	var next_id: String = graph.base_class_id
	var visited: Dictionary[String, bool] = {graph.get_internal_id(): true}
	while classes.has(next_id) and not visited.has(next_id):
		visited[next_id] = true
		var base: FlowGraph = classes[next_id]
		for inherited: Dictionary in FlowSchema5Model.owned_records(base):
			if not inherited.resource is FlowAttributeDefinition:
				continue
			var ancestor: FlowAttributeDefinition = inherited.resource
			if ancestor.visibility == FlowAttributeDefinition.Visibility.PRIVATE:
				continue
			for own: Dictionary in FlowSchema5Model.owned_records(graph):
				if own.resource is FlowAttributeDefinition and own.resource.display_name == ancestor.display_name:
					FlowClassCatalog.issue(result, &"inherited_attribute_conflict", prefix + "." + own.path, own.resource.get_internal_id(), "An inherited public/protected attribute cannot be implicitly overridden.")
		next_id = base.base_class_id

## Older schemas must not silently acquire new persisted semantics.
static func validate_older_boundary(graph: FlowGraph, result: FlowValidationResult) -> void:
	if not graph.base_class_id.is_empty() or not graph.class_attributes.is_empty() \
			or (graph.constructor != null and not graph.constructor.attributes.is_empty()):
		FlowClassCatalog.issue(result, &"class_data_incompatible_schema", "graph", graph.get_internal_id(), "Class data requires schema 5.")
	for record: Dictionary in FlowSchema5Model.owned_records(graph):
		var value: Resource = record.resource
		if value is FlowReferenceDefinition or value is FlowMethodOutputDefinition:
			FlowClassCatalog.issue(result, &"class_data_incompatible_schema", record.path, String(value.call(&"get_internal_id")), "References and outputs require schema 5.")
		elif value is FlowMethodDefinition:
			var method: FlowMethodDefinition = value as FlowMethodDefinition
			if not method.outputs.is_empty():
				FlowClassCatalog.issue(result, &"class_data_incompatible_schema", record.path, method.get_internal_id(), "Method class metadata requires schema 5.")
