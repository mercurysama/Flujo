@tool
## Editor-only snapshot and creation boundary for integrated and external blocks.
extends RefCounted


const AUTHORING_ENTRY_MISSING: StringName = &"editor_authoring_entry_missing"
const INTEGRATED_CREATION_FAILED: StringName = &"integrated_block_creation_failed"
const FLOW_EDITOR_BLOCK_CREATION_RESULT_SCRIPT: Script = preload(
	"res://addons/vp_flujo/editor/flow_editor_block_creation_result.gd"
)


var package_root: String = FlowPackageManifestLoader.ROOT_PATH
var _catalog: FlowEditorBlockCatalog
var _diagnostics: Array[FlowDiagnostic] = []


func _init(root_path: String = FlowPackageManifestLoader.ROOT_PATH) -> void:
	package_root = root_path
	refresh()


## Rebuilds the ephemeral snapshot through discovery, script validation and catalog projection.
func refresh() -> void:
	_diagnostics.clear()
	var discovery: FlowPackageManifestDiscoveryResult = FlowPackageManifestLoader.new().discover(package_root)
	_diagnostics.append_array(discovery.diagnostics)

	var script_results: Dictionary = {}
	var script_validator: FlowExternalBlockScriptValidator = FlowExternalBlockScriptValidator.new()
	for manifest: FlowPackageManifest in discovery.manifests:
		var package_directory: String = package_root.path_join(manifest.package_id)
		var validation: FlowPackageManifestScriptValidationResult = script_validator.validate(
			manifest,
			package_directory
		)
		script_results[manifest.package_id] = validation
		_diagnostics.append_array(validation.diagnostics)

	_catalog = FlowEditorBlockCatalog.combine(discovery, script_results)


func get_catalog() -> FlowEditorBlockCatalog:
	return _catalog


func get_entries() -> Array[FlowEditorBlockCatalogEntry]:
	return _catalog.entries() if _catalog != null else []


func get_diagnostics() -> Array[FlowDiagnostic]:
	return _diagnostics.duplicate()


## Creates only after resolving the stable authoring key in this snapshot.
func create_block(authoring_id: String):
	var result = FLOW_EDITOR_BLOCK_CREATION_RESULT_SCRIPT.new()
	result.authoring_id = authoring_id
	if _catalog == null:
		_add_diagnostic(result, AUTHORING_ENTRY_MISSING, "authoring_id", authoring_id,
			"The authoring catalog is unavailable.")
		return result

	var entry: FlowEditorBlockCatalogEntry = _catalog.find(authoring_id)
	if entry == null:
		_add_diagnostic(result, AUTHORING_ENTRY_MISSING, "authoring_id", authoring_id,
			"The authoring entry is no longer available.")
		return result

	if entry.is_integrated():
		result.block = FlowBlockRegistry.create(entry.integrated_type_id)
		if result.block == null:
			_add_diagnostic(result, INTEGRATED_CREATION_FAILED, "authoring_id", authoring_id,
				"The integrated block could not be created.")
		return result

	if entry.is_external():
		var descriptor: FlowExternalBlockDescriptor = entry.external_descriptor
		var package_directory: String = package_root.path_join(descriptor.package_id) \
			if descriptor != null else package_root
		var external_result: FlowExternalBlockCreationResult = FlowExternalBlockFactory.new().create(
			entry,
			package_directory
		)
		result.block = external_result.block
		result.diagnostics.append_array(external_result.diagnostics)
		return result

	_add_diagnostic(result, AUTHORING_ENTRY_MISSING, "authoring_id", authoring_id,
		"The authoring entry has an unsupported origin.")
	return result


static func _add_diagnostic(
		result,
		code: StringName,
		path: String,
		related_id: String,
		message: String
) -> void:
	result.diagnostics.append(FlowDiagnostic.new(
		code,
		FlowDiagnostic.Severity.ERROR,
		message,
		path,
		related_id
	))
