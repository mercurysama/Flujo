@tool
class_name FlowEditorBlockCatalog
extends RefCounted

## Ephemeral authoring availability. It never creates or registers blocks.

var _entries: Array[FlowEditorBlockCatalogEntry] = []


static func combine(
		discovery: FlowPackageManifestDiscoveryResult,
		script_results: Dictionary
) -> FlowEditorBlockCatalog:
	var catalog: FlowEditorBlockCatalog = FlowEditorBlockCatalog.new()
	for type_id: StringName in FlowBlockRegistry.creatable_type_ids():
		catalog._append_unique(FlowEditorBlockCatalogEntry.integrated(
			type_id, FlowBlockRegistry.display_name_for_type(type_id)
		))
	if discovery == null:
		return catalog
	for manifest: FlowPackageManifest in discovery.manifests:
		var script_result: FlowPackageManifestScriptValidationResult = script_results.get(manifest.package_id) as FlowPackageManifestScriptValidationResult
		if script_result == null:
			continue
		for descriptor: FlowExternalBlockDescriptor in script_result.valid_descriptors:
			catalog._append_unique(FlowEditorBlockCatalogEntry.external(descriptor))
	return catalog


func entries() -> Array[FlowEditorBlockCatalogEntry]:
	return _entries.duplicate()


func size() -> int:
	return _entries.size()


func entry_at(index: int) -> FlowEditorBlockCatalogEntry:
	if index < 0 or index >= _entries.size():
		return null
	return _entries[index]


func find(authoring_id: String) -> FlowEditorBlockCatalogEntry:
	for entry: FlowEditorBlockCatalogEntry in _entries:
		if entry.authoring_id == authoring_id:
			return entry
	return null


func _append_unique(entry: FlowEditorBlockCatalogEntry) -> void:
	if entry == null or entry.authoring_id.is_empty() or find(entry.authoring_id) != null:
		return
	_entries.append(entry)
