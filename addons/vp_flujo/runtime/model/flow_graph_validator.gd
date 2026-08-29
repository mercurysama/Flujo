## Validates a schema 1 FlowGraph deterministically without modifying its model tree.
class_name FlowGraphValidator
extends RefCounted


## Validates a graph and returns all structured diagnostics in traversal order.
static func validate(graph: FlowGraph) -> FlowValidationResult:
	var result: FlowValidationResult = FlowValidationResult.new()
	if graph == null:
		_add_error(
			result,
			FlowDiagnostic.CODE_NULL_GRAPH,
			"FlowGraph is null.",
			"graph"
		)
		return result

	var seen_instances: Dictionary[int, String] = {}
	var seen_ids: Dictionary[String, String] = {}
	_validate_resource_identity(graph, "graph", result, seen_instances, seen_ids)

	if graph.schema_version != FlowGraph.CURRENT_SCHEMA_VERSION:
		_add_error(
			result,
			FlowDiagnostic.CODE_UNSUPPORTED_SCHEMA_VERSION,
			"Unsupported FlowGraph schema version: %d." % graph.schema_version,
			"graph"
		)

	for container_index: int in graph.containers.size():
		var container: FlowBlockContainer = graph.containers[container_index]
		if container == null:
			continue

		var container_path: String = "containers[%d]" % container_index
		if not _validate_resource_identity(
				container,
				container_path,
				result,
				seen_instances,
				seen_ids
		):
			continue

		if container.get_script() != FlowProcess and container.get_script() != FlowStateDefinition:
			_add_error(
				result,
				FlowDiagnostic.CODE_UNMIGRATABLE_CONTAINER_TYPE,
				"Container type cannot be migrated to FlowGraph schema 2.",
				container_path,
				container.get_internal_id()
			)

		for block_index: int in container.blocks.size():
			var block: FlowBlock = container.blocks[block_index]
			if block == null:
				continue

			_validate_resource_identity(
				block,
				"%s.blocks[%d]" % [container_path, block_index],
				result,
				seen_instances,
				seen_ids
			)

	return result


static func _validate_resource_identity(
		resource: Resource,
		element_path: String,
		result: FlowValidationResult,
		seen_instances: Dictionary[int, String],
		seen_ids: Dictionary[String, String]
) -> bool:
	var instance_id: int = resource.get_instance_id()
	if seen_instances.has(instance_id):
		_add_error(
			result,
			FlowDiagnostic.CODE_REPEATED_RESOURCE_INSTANCE,
			"Resource instance is already used at %s." % seen_instances[instance_id],
			element_path,
			_get_internal_id(resource)
		)
		return false

	seen_instances[instance_id] = element_path
	var internal_id: String = _get_internal_id(resource)
	_validate_internal_id(internal_id, element_path, result)

	if not internal_id.is_empty():
		if seen_ids.has(internal_id):
			_add_error(
				result,
				FlowDiagnostic.CODE_DUPLICATE_INTERNAL_ID,
				"Internal ID is already used at %s." % seen_ids[internal_id],
				element_path,
				internal_id
			)
		else:
			seen_ids[internal_id] = element_path

	return true


static func _validate_internal_id(
		internal_id: String,
		element_path: String,
		result: FlowValidationResult
) -> void:
	if internal_id.is_empty():
		_add_error(
			result,
			FlowDiagnostic.CODE_EMPTY_INTERNAL_ID,
			"Internal ID is empty.",
			element_path
		)
		return

	if internal_id.length() != 32:
		_add_error(
			result,
			FlowDiagnostic.CODE_INVALID_INTERNAL_ID_LENGTH,
			"Internal ID must contain exactly 32 characters.",
			element_path,
			internal_id
		)

	for character_index: int in internal_id.length():
		if "0123456789abcdef".find(internal_id.substr(character_index, 1).to_lower()) == -1:
			_add_error(
				result,
				FlowDiagnostic.CODE_NON_HEXADECIMAL_INTERNAL_ID,
				"Internal ID must contain only hexadecimal characters.",
				element_path,
				internal_id
			)
			break


static func _get_internal_id(resource: Resource) -> String:
	if resource is FlowGraph:
		return (resource as FlowGraph).get_internal_id()
	if resource is FlowBlockContainer:
		return (resource as FlowBlockContainer).get_internal_id()
	if resource is FlowBlock:
		return (resource as FlowBlock).get_internal_id()
	return ""


static func _add_error(
		result: FlowValidationResult,
		code: StringName,
		message: String,
		element_path: String,
		related_id: String = ""
) -> void:
	result.add_diagnostic(FlowDiagnostic.new(
		code,
		FlowDiagnostic.Severity.ERROR,
		message,
		element_path,
		related_id
	))
