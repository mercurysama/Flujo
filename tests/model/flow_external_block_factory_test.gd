extends Node

const FIXTURE_ROOT: String = "res://tests/fixtures/external_manifests"
var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_external_creation()
	_test_controlled_rejections()
	_test_boundaries()
	if _failures.is_empty():
		print("[Flujo] External block factory test passed")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	get_tree().quit(1)


func _test_external_creation() -> void:
	var discovery: FlowPackageManifestDiscoveryResult = FlowPackageManifestLoader.new().discover(FIXTURE_ROOT)
	var script_results: Dictionary = _script_results(discovery)
	var catalog: FlowEditorBlockCatalog = FlowEditorBlockCatalog.combine(discovery, script_results)
	var entry: FlowEditorBlockCatalogEntry = catalog.find("mixed_script:valid")
	if not _check(entry != null, "The validated external descriptor is available through the catalog."):
		return
	var factory: FlowExternalBlockFactory = FlowExternalBlockFactory.new()
	var first: FlowExternalBlockCreationResult = factory.create(entry, FIXTURE_ROOT.path_join("mixed_script"))
	var second: FlowExternalBlockCreationResult = factory.create(entry, FIXTURE_ROOT.path_join("mixed_script"))
	_check(first.block != null and not first.has_errors(), "A validated external entry creates without diagnostics.")
	_check(first.block is FlowBlock, "The external instance satisfies the FlowBlock contract.")
	if first.block != null:
		_check(first.block.get_script().resource_path.ends_with("mixed_script/valid.gd"), "The instance comes from the package script.")
		_check(first.block.display_name == "Valid", "The descriptor display name initializes the new block.")
		_check(FlowId.is_valid(first.block.get_internal_id()), "The new external block receives a stable ID.")
	_check(second.block != null and first.block != second.block, "Two creations return independent instances.")
	if first.block != null and second.block != null:
		_check(first.block.get_internal_id() != second.block.get_internal_id(), "Independent creations receive different IDs.")
		_check(first.block.display_name == second.block.display_name, "Independent creations retain the same initial display name.")


func _test_controlled_rejections() -> void:
	var discovery: FlowPackageManifestDiscoveryResult = FlowPackageManifestLoader.new().discover(FIXTURE_ROOT)
	var script_results: Dictionary = _script_results(discovery)
	var catalog: FlowEditorBlockCatalog = FlowEditorBlockCatalog.combine(discovery, script_results)
	var factory: FlowExternalBlockFactory = FlowExternalBlockFactory.new()
	var missing_entry: FlowEditorBlockCatalogEntry = FlowEditorBlockCatalogEntry.external(
		FlowExternalBlockDescriptor.new("mixed_script", "missing", "missing.gd", "Missing")
	)
	var missing: FlowExternalBlockCreationResult = factory.create(missing_entry, FIXTURE_ROOT.path_join("mixed_script"))
	_check(missing.block == null and _has(missing, &"external_script_missing"), "Unavailable external scripts are rejected without a block.")
	var integrated: FlowExternalBlockCreationResult = factory.create(catalog.entry_at(0))
	_check(integrated.block == null and _has(integrated, &"external_creation_entry_not_external"), "Integrated entries are rejected by the external factory.")
	var absent: FlowExternalBlockCreationResult = factory.create(null)
	_check(absent.block == null and _has(absent, &"external_creation_entry_missing"), "Missing entries fail deterministically.")


func _test_boundaries() -> void:
	var factory_source: String = FileAccess.get_file_as_string(
		"res://addons/vp_flujo/runtime/model/flow_external_block_factory.gd"
	)
	var executor_source: String = FileAccess.get_file_as_string(
		"res://addons/vp_flujo/runtime/flow_ready_executor.gd"
	)
	var registry_source: String = FileAccess.get_file_as_string(
		"res://addons/vp_flujo/runtime/model/flow_block_registry.gd"
	)
	_check(not factory_source.contains("FlowIfBlock"), "The factory has no IF-specific knowledge.")
	_check(not factory_source.contains("FlowBlockRegistry"), "The external factory does not depend on the integrated registry.")
	_check(not executor_source.contains("FlowExternalBlock"), "The runtime executor remains unaware of external creation.")
	_check(not registry_source.contains("FlowExternalBlock"), "The integrated registry remains unaware of external creation.")


func _script_results(discovery: FlowPackageManifestDiscoveryResult) -> Dictionary:
	var results: Dictionary = {}
	for manifest: FlowPackageManifest in discovery.manifests:
		results[manifest.package_id] = FlowExternalBlockScriptValidator.new().validate(
			manifest, FIXTURE_ROOT.path_join(manifest.package_id)
		)
	return results


func _has(result: FlowExternalBlockCreationResult, code: StringName) -> bool:
	for diagnostic: FlowDiagnostic in result.diagnostics:
		if diagnostic.code == code:
			return true
	return false


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_failures.append(message)
	return condition
