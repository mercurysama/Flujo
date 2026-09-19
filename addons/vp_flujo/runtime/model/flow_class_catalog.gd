@tool
class_name FlowClassCatalog
extends Resource

const MAX_INHERITANCE_DEPTH: int = 10
@export_storage var entries: Array[FlowClassCatalogEntry] = []

## No cached resolution: every call returns a fresh, read-only validation snapshot.
func validate() -> FlowClassCatalogResult:
	var result: FlowClassCatalogResult = FlowClassCatalogResult.new()
	var counts: Dictionary[String, int] = {}
	for entry: FlowClassCatalogEntry in entries:
		if entry != null:
			counts[entry.class_id] = counts.get(entry.class_id, 0) + 1
	for index: int in entries.size():
		var entry: FlowClassCatalogEntry = entries[index]
		var path: String = "entries[%d]" % index
		if entry == null:
			issue(result, &"class_catalog_entry_invalid", path, "", "Catalog entries must not be null.")
			continue
		if not FlowId.is_valid(entry.class_id):
			issue(result, &"class_catalog_id_invalid", path + ".class_id", entry.class_id, "Invalid class ID.")
			continue
		if counts[entry.class_id] != 1:
			issue(result, &"class_catalog_id_duplicate", path + ".class_id", entry.class_id, "Ambiguous class ID.")
			continue
		var graph: FlowGraph = _resolve(entry, path, result)
		if graph != null:
			result.graphs[entry.class_id] = graph
	var cyclic_class_ids: Dictionary[String, bool] = _validate_cycles(result)
	for index: int in entries.size():
		var entry: FlowClassCatalogEntry = entries[index]
		if entry == null or not result.graphs.has(entry.class_id):
			continue
		var graph: FlowGraph = result.graphs[entry.class_id]
		var path: String = "entries[%d]" % index
		_validate_lineage(graph, path, result, cyclic_class_ids)
		var local: FlowValidationResult = FlowGraphValidator.validate(graph)
		for diagnostic: FlowDiagnostic in local.diagnostics:
			result.add_diagnostic(FlowDiagnostic.new(diagnostic.code, diagnostic.severity, diagnostic.message,
				path + ".graph." + diagnostic.element_path, diagnostic.related_id))
		FlowSchema5Validator.validate_catalog_context(graph, result.graphs, result, path + ".graph")
	return result

static func is_project_graph_path(path: String) -> bool:
	return path.begins_with("res://") and path.length() > 6 \
		and path == path.simplify_path() and not path.contains("\\") \
		and not path.contains("::") and not path.begins_with("res://addons/vp_flujo/")

static func _resolve(entry: FlowClassCatalogEntry, path: String, result: FlowClassCatalogResult) -> FlowGraph:
	var uid: int = ResourceUID.text_to_id(entry.graph_uid)
	if uid == ResourceUID.INVALID_ID or ResourceUID.id_to_text(uid) != entry.graph_uid:
		issue(result, &"class_catalog_uid_invalid", path + ".graph_uid", entry.class_id, "Expected a canonical uid:// locator.")
		return null
	if not is_project_graph_path(entry.graph_path):
		issue(result, &"class_catalog_path_invalid", path + ".graph_path", entry.class_id, "Expected a standalone project res:// locator.")
		return null
	var uid_path: String = ResourceUID.get_id_path(uid) if ResourceUID.has_id(uid) else ""
	var uid_exists: bool = is_project_graph_path(uid_path) and ResourceLoader.exists(uid_path)
	var path_exists: bool = ResourceLoader.exists(entry.graph_path)
	if uid_exists and path_exists and uid_path != entry.graph_path:
		issue(result, &"class_catalog_locator_conflict", path, entry.class_id, "UID and path locate different resources.")
		return null
	if not uid_exists and not path_exists:
		issue(result, &"class_catalog_graph_missing", path, entry.class_id, "Neither locator resolves a project resource.")
		return null
	if not uid_exists or not path_exists:
		issue(result, &"class_catalog_locator_stale", path + (".graph_uid" if not uid_exists else ".graph_path"),
			entry.class_id, "One locator is stale; the other is used without repair.", FlowDiagnostic.Severity.WARNING)
	var resolved_path: String = uid_path if uid_exists else entry.graph_path
	var loaded: Resource = ResourceLoader.load(resolved_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if not loaded is FlowGraph:
		issue(result, &"class_catalog_graph_type", path, entry.class_id, "Resolved resource is not a FlowGraph.")
		return null
	var graph: FlowGraph = loaded as FlowGraph
	if graph.get_internal_id() != entry.class_id:
		issue(result, &"class_catalog_id_mismatch", path, entry.class_id, "Resolved graph does not have the catalog class ID.")
		return null
	if graph.schema_version != FlowGraph.SCHEMA_VERSION_5:
		issue(result, &"class_catalog_schema_invalid", path, entry.class_id, "Class catalog requires schema 5 graphs.")
		return null
	return graph

## Detect cycles before depth so a long cycle is never mislabeled as excessive depth.
## Entry order and each class's single base edge make diagnostics stable.
func _validate_cycles(result: FlowClassCatalogResult) -> Dictionary[String, bool]:
	var colors: Dictionary[String, int] = {}
	var cyclic: Dictionary[String, bool] = {}
	var paths: Dictionary[String, String] = {}
	for index: int in entries.size():
		var entry: FlowClassCatalogEntry = entries[index]
		if entry != null and result.graphs.has(entry.class_id):
			paths[entry.class_id] = "entries[%d]" % index
	for entry: FlowClassCatalogEntry in entries:
		if entry == null or not result.graphs.has(entry.class_id) or colors.get(entry.class_id, 0) != 0:
			continue
		var chain: Array[String] = []
		var chain_positions: Dictionary[String, int] = {}
		var current_id: String = entry.class_id
		while not current_id.is_empty() and result.graphs.has(current_id):
			var color: int = colors.get(current_id, 0)
			if color == 1:
				var cycle_start: int = chain_positions.get(current_id, 0)
				for cycle_index: int in range(cycle_start, chain.size()):
					cyclic[chain[cycle_index]] = true
				var closing_id: String = chain.back()
				issue(result, &"class_inheritance_cycle", paths[closing_id] + ".base_class_id",
					current_id, "Inheritance contains a cycle.")
				break
			if color == 2:
				break
			colors[current_id] = 1
			chain_positions[current_id] = chain.size()
			chain.append(current_id)
			current_id = result.graphs[current_id].base_class_id
		for class_id: String in chain:
			colors[class_id] = 2
	return cyclic


static func _validate_lineage(graph: FlowGraph, path: String, result: FlowClassCatalogResult,
		cyclic_class_ids: Dictionary[String, bool]) -> void:
	var visited: Dictionary[String, bool] = {graph.get_internal_id(): true}
	var next_id: String = graph.base_class_id
	var depth: int = 0
	while not next_id.is_empty():
		if cyclic_class_ids.has(next_id) or visited.has(next_id):
			return
		visited[next_id] = true
		if not result.graphs.has(next_id):
			issue(result, &"class_base_missing", path + ".base_class_id", next_id, "Base is missing, invalid or ambiguous.")
			return
		depth += 1
		if depth > MAX_INHERITANCE_DEPTH:
			issue(result, &"class_inheritance_depth", path + ".base_class_id", next_id, "Inheritance exceeds ten parent edges.")
			return
		next_id = result.graphs[next_id].base_class_id

static func issue(result: FlowValidationResult, code: StringName, path: String, related_id: String,
		message: String, severity: FlowDiagnostic.Severity = FlowDiagnostic.Severity.ERROR) -> void:
	result.add_diagnostic(FlowDiagnostic.new(code, severity, message, path, related_id))
