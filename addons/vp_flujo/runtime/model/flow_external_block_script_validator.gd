@tool
class_name FlowExternalBlockScriptValidator
extends RefCounted

## Validates script resources without instantiating or registering external blocks.

const _FLOW_BLOCK_SCRIPT: Script = preload("res://addons/vp_flujo/runtime/model/flow_block.gd")


func validate(
		manifest: FlowPackageManifest,
		package_directory: String
) -> FlowPackageManifestScriptValidationResult:
	var result: FlowPackageManifestScriptValidationResult = FlowPackageManifestScriptValidationResult.new()
	if manifest == null:
		return result
	for index: int in manifest.blocks.size():
		var descriptor: FlowExternalBlockDescriptor = manifest.blocks[index]
		var script_path: String = package_directory.path_join(descriptor.script_path)
		var related_id: String = descriptor.global_type_id()
		var descriptor_path: String = "blocks[%d].script" % index
		if not FileAccess.file_exists(script_path):
			_issue(result, &"external_script_missing", descriptor_path, related_id,
				"Declared script file does not exist.")
			continue
		var loaded: Resource = ResourceLoader.load(script_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		if loaded == null:
			_issue(result, &"external_script_invalid", descriptor_path, related_id,
				"Declared script cannot be loaded.")
			continue
		if not loaded is Script:
			_issue(result, &"external_script_not_script", descriptor_path, related_id,
				"Declared resource is not a Script.")
			continue
		var script: Script = loaded as Script
		if not script.can_instantiate():
			_issue(result, &"external_script_invalid", descriptor_path, related_id,
				"Declared script cannot be instantiated.")
			continue
		if not _derives_from_flow_block(script):
			_issue(result, &"external_script_not_flow_block", descriptor_path, related_id,
				"Declared Script does not derive from FlowBlock.")
			continue
		result.valid_descriptors.append(descriptor)
	return result


func validate_descriptor(
		descriptor: FlowExternalBlockDescriptor,
		package_directory: String
) -> FlowPackageManifestScriptValidationResult:
	var manifest: FlowPackageManifest = FlowPackageManifest.new(descriptor.package_id if descriptor != null else "")
	if descriptor != null:
		manifest.add_block(descriptor)
	return validate(manifest, package_directory)


func _derives_from_flow_block(script: Script) -> bool:
	var candidate: Script = script
	while candidate != null:
		if candidate == _FLOW_BLOCK_SCRIPT:
			return true
		candidate = candidate.get_base_script()
	return false


static func _issue(result: FlowPackageManifestScriptValidationResult, code: StringName,
		path: String, related_id: String, message: String) -> void:
	result.add_diagnostic(FlowDiagnostic.new(code, FlowDiagnostic.Severity.ERROR, message, path, related_id))
