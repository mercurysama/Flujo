extends Node

const FIXTURE_ROOT: String = "res://tests/fixtures/external_manifests"
var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_integrated_only()
	_test_external_combination_and_order()
	_test_invalid_external_entries_excluded()
	_test_registry_boundary()
	if _failures.is_empty():
		print("[Flujo] Editor block catalog test passed")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	get_tree().quit(1)


func _test_integrated_only() -> void:
	var catalog: FlowEditorBlockCatalog = FlowEditorBlockCatalog.combine(
		FlowPackageManifestDiscoveryResult.new(), {}
	)
	_check(catalog.size() == 3, "An empty discovery result exposes the three integrated blocks.")
	if catalog.size() != 3:
		return
	_check(catalog.entry_at(0).authoring_id == "print", "Print remains first in integrated order.")
	_check(catalog.entry_at(1).authoring_id == "everything_flows", "Everything Flows remains second in integrated order.")
	_check(catalog.entry_at(2).authoring_id == "custom_hello", "Custom Hello remains third in integrated order.")
	_check(catalog.entry_at(0).is_integrated(), "Integrated entries identify their origin.")
	_check(catalog.find("missing") == null, "Unknown authoring IDs are not synthesized.")


func _test_external_combination_and_order() -> void:
	var discovery: FlowPackageManifestDiscoveryResult = FlowPackageManifestLoader.new().discover(FIXTURE_ROOT)
	var script_results: Dictionary = _script_results(discovery)
	var catalog: FlowEditorBlockCatalog = FlowEditorBlockCatalog.combine(discovery, script_results)
	_check(catalog.size() == 7, "Integrated blocks plus valid external descriptors are combined.")
	if catalog.size() != 7:
		return
	_check(catalog.entry_at(3).authoring_id == "alpha:second", "First external package follows integrated blocks.")
	_check(catalog.entry_at(4).authoring_id == "alpha:first", "Alpha preserves manifest block order.")
	_check(catalog.entry_at(5).authoring_id == "mixed_script:valid", "Mixed package keeps only its valid script descriptor.")
	_check(catalog.entry_at(6).authoring_id == "zeta:zeta_block", "Later package follows earlier package entries.")
	_check(catalog.entry_at(3).is_external(), "External entries identify their origin.")
	_check(catalog.find("alpha:second").external_descriptor.script_path == "blocks/second.gd", "External entries retain creation metadata.")
	_check(catalog.find("alpha:print") == null and catalog.find("zeta:print") == null,
		"Package namespaces prevent collisions between same type IDs in different packages.")


func _test_invalid_external_entries_excluded() -> void:
	var discovery: FlowPackageManifestDiscoveryResult = FlowPackageManifestLoader.new().discover(FIXTURE_ROOT)
	var catalog: FlowEditorBlockCatalog = FlowEditorBlockCatalog.combine(discovery, _script_results(discovery))
	_check(catalog.find("mixed_script:missing") == null, "Missing external scripts are excluded from authoring availability.")
	_check(catalog.find("mixed_script:node") == null, "Non-FlowBlock scripts are excluded from authoring availability.")
	_check(catalog.find("invalid_duplicate:same") == null, "Metadata-invalid packages are excluded.")
	_check(catalog.find("invalid_traversal:escape") == null, "Traversal-invalid packages are excluded.")


func _test_registry_boundary() -> void:
	var registry_source: String = FileAccess.get_file_as_string(
		"res://addons/vp_flujo/runtime/model/flow_block_registry.gd"
	)
	_check(not registry_source.contains("FlowExternal"), "FlowBlockRegistry contains no external catalog references.")
	_check(not registry_source.contains("flow_packages"), "FlowBlockRegistry is not a package manager.")
	_check(not registry_source.contains("FlowIfBlock"), "FlowBlockRegistry contains no IF-specific branch.")
	var external_entry: FlowEditorBlockCatalogEntry = FlowEditorBlockCatalogEntry.external(
		FlowExternalBlockDescriptor.new("pkg", "type", "block.gd", "External")
	)
	_check(external_entry.authoring_id == "pkg:type" and external_entry.external_descriptor != null,
		"External catalog entries carry only the descriptor needed for future creation.")


func _script_results(discovery: FlowPackageManifestDiscoveryResult) -> Dictionary:
	var results: Dictionary = {}
	for manifest: FlowPackageManifest in discovery.manifests:
		results[manifest.package_id] = FlowExternalBlockScriptValidator.new().validate(
			manifest, FIXTURE_ROOT.path_join(manifest.package_id)
		)
	return results


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
