extends Node

const FIXTURE_ROOT: String = "res://tests/fixtures/external_manifests"
var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_mixed_package()
	_test_valid_descriptor_is_not_instantiated()
	if _failures.is_empty():
		print("[Flujo] External block script validator test passed")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	get_tree().quit(1)


func _test_mixed_package() -> void:
	var discovery: FlowPackageManifestDiscoveryResult = FlowPackageManifestLoader.new().discover(FIXTURE_ROOT)
	var manifest: FlowPackageManifest = _manifest(discovery, "mixed_script")
	if not _check(manifest != null, "The mixed script fixture is metadata-valid before script validation."):
		return
	var result: FlowPackageManifestScriptValidationResult = FlowExternalBlockScriptValidator.new().validate(
		manifest, FIXTURE_ROOT.path_join("mixed_script")
	)
	_check(result.valid_descriptors.size() == 1, "Only the FlowBlock-derived fixture is accepted.")
	if result.valid_descriptors.size() == 1:
		_check(result.valid_descriptors[0].type_id == "valid", "Valid descriptor remains in authored order.")
	_check(_has(result, &"external_script_missing", 1), "Missing scripts receive a deterministic diagnostic.")
	_check(_has(result, &"external_script_not_script", 2), "Non-Script resources receive a deterministic diagnostic.")
	_check(_has(result, &"external_script_invalid", 3), "Invalid scripts receive a deterministic diagnostic.")
	_check(_has(result, &"external_script_not_flow_block", 4), "Non-FlowBlock scripts receive a deterministic diagnostic.")
	_check(result.diagnostics.size() == 4, "Each invalid descriptor is diagnosed without stopping later descriptors.")
	_check(result.diagnostics[0].related_id == "mixed_script:missing", "Diagnostics retain the stable global descriptor ID.")
	_check(result.diagnostics[3].element_path == "blocks[4].script", "Diagnostic paths identify the exact descriptor field.")


func _test_valid_descriptor_is_not_instantiated() -> void:
	var discovery: FlowPackageManifestDiscoveryResult = FlowPackageManifestLoader.new().discover(FIXTURE_ROOT)
	var manifest: FlowPackageManifest = _manifest(discovery, "mixed_script")
	var result: FlowPackageManifestScriptValidationResult = FlowExternalBlockScriptValidator.new().validate(
		manifest, FIXTURE_ROOT.path_join("mixed_script")
	)
	_check(result.valid_descriptors.size() == 1, "Validation can be repeated without retaining script instances.")
	_check(result.has_errors(), "The mixed package remains invalid only through diagnostics.")


func _manifest(result: FlowPackageManifestDiscoveryResult, package_id: String) -> FlowPackageManifest:
	for manifest: FlowPackageManifest in result.manifests:
		if manifest.package_id == package_id:
			return manifest
	return null


func _has(result: FlowPackageManifestScriptValidationResult, code: StringName, block_index: int) -> bool:
	for diagnostic: FlowDiagnostic in result.diagnostics:
		if diagnostic.code == code and diagnostic.element_path == "blocks[%d].script" % block_index:
			return true
	return false


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_failures.append(message)
	return condition
