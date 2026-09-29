extends Node

const FIXTURE_ROOT: String = "res://tests/fixtures/external_manifests"
var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_discovery_order_and_valid_data()
	_test_diagnostics()
	_test_repeatability()
	if _failures.is_empty():
		print("[Flujo] External manifest loader test passed")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	get_tree().quit(1)


func _discover() -> FlowPackageManifestDiscoveryResult:
	return FlowPackageManifestLoader.new().discover(FIXTURE_ROOT)


func _test_discovery_order_and_valid_data() -> void:
	var result: FlowPackageManifestDiscoveryResult = _discover()
	_check(result.manifests.size() == 2, "Valid packages survive invalid package siblings.")
	if result.manifests.size() != 2:
		return
	_check(result.manifests[0].package_id == "alpha", "Packages are returned in package_id order.")
	_check(result.manifests[1].package_id == "zeta", "The later valid package remains discoverable.")
	_check(result.manifests[0].blocks.size() == 2, "The valid manifest preserves its block count.")
	if result.manifests[0].blocks.size() == 2:
		_check(result.manifests[0].blocks[0].type_id == "second", "Manifest block order is preserved at index zero.")
		_check(result.manifests[0].blocks[1].type_id == "first", "Manifest block order is preserved at index one.")
		_check(result.manifests[0].blocks[0].script_path == "blocks/second.gd", "Script metadata remains relative and unnormalized.")
		_check(result.manifests[0].blocks[0].global_type_id() == "alpha:second", "Global type IDs use package_id:type_id.")
	_check(not result.has_errors() or result.diagnostics.size() > 0, "Invalid siblings produce structured diagnostics.")


func _test_diagnostics() -> void:
	var result: FlowPackageManifestDiscoveryResult = _discover()
	_check(_has(result, &"package_manifest_version_invalid", ".manifest_version"), "Unknown manifest versions are diagnosed.")
	_check(_has(result, &"package_manifest_package_id_mismatch", ".package_id"), "Directory/package mismatches are diagnosed.")
	_check(_has(result, &"package_manifest_type_id_duplicate", ".type_id"), "Duplicate type IDs are diagnosed.")
	_check(_has(result, &"package_manifest_block_field_empty", ".display_name"), "Empty required fields are diagnosed.")
	_check(_has(result, &"package_manifest_json_invalid", "manifest.json"), "Invalid JSON is diagnosed.")
	_check(_has(result, &"package_manifest_script_path_invalid", ".script"), "Escaping script paths are diagnosed.")
	_check(_has(result, &"package_manifest_missing", "missing_manifest/manifest.json"), "Missing manifests are diagnosed.")
	_check(result.diagnostics.size() > 0, "Invalid packages produce an ordered diagnostic sequence.")


func _test_repeatability() -> void:
	var first: FlowPackageManifestDiscoveryResult = _discover()
	var second: FlowPackageManifestDiscoveryResult = _discover()
	_check(first.manifests.size() == second.manifests.size(), "Repeated discovery returns the same valid package count.")
	_check(_signature(first) == _signature(second), "Repeated discovery returns identical package and diagnostic order.")


func _signature(result: FlowPackageManifestDiscoveryResult) -> String:
	var parts: Array[String] = []
	for manifest: FlowPackageManifest in result.manifests:
		parts.append(manifest.package_id)
		for descriptor: FlowExternalBlockDescriptor in manifest.blocks:
			parts.append(descriptor.global_type_id() + "=" + descriptor.script_path + "=" + descriptor.display_name)
	for diagnostic: FlowDiagnostic in result.diagnostics:
		parts.append(String(diagnostic.code) + "@" + diagnostic.element_path + "#" + diagnostic.related_id)
	return "|".join(parts)


func _has(result: FlowPackageManifestDiscoveryResult, code: StringName, path_fragment: String) -> bool:
	for diagnostic: FlowDiagnostic in result.diagnostics:
		if diagnostic.code == code and diagnostic.element_path.contains(path_fragment):
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
