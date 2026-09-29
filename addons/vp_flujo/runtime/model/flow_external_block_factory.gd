@tool
class_name FlowExternalBlockFactory
extends RefCounted

## Creates one already validated external FlowBlock without registry integration.

func create(
		entry: FlowEditorBlockCatalogEntry,
		package_directory: String = ""
) -> FlowExternalBlockCreationResult:
	var result: FlowExternalBlockCreationResult = FlowExternalBlockCreationResult.new()
	if entry == null:
		_issue(result, &"external_creation_entry_missing", "entry", "", "Catalog entry is missing.")
		return result
	if not entry.is_external():
		_issue(result, &"external_creation_entry_not_external", "entry", entry.authoring_id,
			"Catalog entry is not external.")
		return result
	var descriptor: FlowExternalBlockDescriptor = entry.external_descriptor
	if descriptor == null or not descriptor.is_valid():
		_issue(result, &"external_creation_metadata_invalid", "entry", entry.authoring_id,
			"External catalog metadata is invalid.")
		return result
	if package_directory.is_empty():
		package_directory = FlowPackageManifestLoader.ROOT_PATH.path_join(descriptor.package_id)
	var manifest: FlowPackageManifest = FlowPackageManifest.new(descriptor.package_id)
	manifest.add_block(descriptor)
	var validation: FlowPackageManifestScriptValidationResult = FlowExternalBlockScriptValidator.new().validate(
		manifest, package_directory
	)
	if validation.has_errors() or validation.valid_descriptors.size() != 1:
		for diagnostic: FlowDiagnostic in validation.diagnostics:
			result.add_diagnostic(diagnostic)
		if validation.diagnostics.is_empty():
			_issue(result, &"external_creation_script_invalid", "entry", entry.authoring_id,
				"External script failed validation.")
		return result
	var script_path: String = package_directory.path_join(descriptor.script_path)
	var loaded: Resource = ResourceLoader.load(script_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if loaded == null or not loaded is Script:
		_issue(result, &"external_creation_script_unavailable", "entry.script", entry.authoring_id,
			"Validated external script is no longer available.")
		return result
	var candidate: Variant = (loaded as Script).new()
	if candidate == null or not candidate is FlowBlock:
		_issue(result, &"external_creation_instance_invalid", "entry.script", entry.authoring_id,
			"External script did not create a FlowBlock instance.")
		if candidate is Node:
			(candidate as Node).free()
		return result
	var block: FlowBlock = candidate as FlowBlock
	if not FlowId.is_valid(block.get_internal_id()):
		_issue(result, &"external_creation_id_invalid", "entry.script", entry.authoring_id,
			"External block did not receive a valid stable ID.")
		return result
	block.display_name = descriptor.display_name
	result.block = block
	return result


static func _issue(result: FlowExternalBlockCreationResult, code: StringName, path: String,
		related_id: String, message: String) -> void:
	result.add_diagnostic(FlowDiagnostic.new(code, FlowDiagnostic.Severity.ERROR, message, path, related_id))
