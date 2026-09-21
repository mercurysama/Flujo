class_name FlowRuntimeAttributeLayout
extends FlowValidationResult

## Detached runtime snapshot. Resources loaded by the catalog never escape resolve().
var class_id: String = ""
var class_order: Array[String] = []
var parents: Dictionary[String, String] = {}
var instance_slots: Dictionary[String, Dictionary] = {}
var class_slots: Dictionary[String, Dictionary] = {}
var _resolved: bool = false

static func resolve(graph: FlowGraph, catalog: FlowClassCatalog = null) -> FlowRuntimeAttributeLayout:
	var layout: FlowRuntimeAttributeLayout = FlowRuntimeAttributeLayout.new()
	if graph == null or graph.schema_version != FlowGraph.SCHEMA_VERSION_5:
		layout._error(&"store_schema_unsupported", "graph", "", "Runtime attributes require schema 5.")
		return layout
	layout.class_id = graph.get_internal_id()
	layout.diagnostics.assign(FlowGraphValidator.validate(graph).diagnostics)
	if layout.has_errors():
		return layout
	var classes: Dictionary[String, FlowGraph] = {}
	if catalog != null:
		var resolved: FlowClassCatalogResult = catalog.validate()
		layout.diagnostics.append_array(resolved.diagnostics)
		if layout.has_errors():
			return layout
		classes.assign(resolved.graphs)
	elif not graph.base_class_id.is_empty():
		layout._error(&"store_inheritance_unresolved", "base_class_id", graph.base_class_id, "Inheritance requires an explicit project catalog.")
		return layout
	# The supplied active definition is authoritative; ancestors come only from the catalog.
	classes[layout.class_id] = graph
	for known_id: String in classes:
		layout.parents[known_id] = classes[known_id].base_class_id
	var visited: Dictionary[String, bool] = {}
	var next_id: String = layout.class_id
	var derived_first: Array[String] = []
	while not next_id.is_empty():
		if visited.has(next_id):
			layout._error(&"class_inheritance_cycle", "base_class_id", next_id, "Runtime inheritance contains a cycle.")
			return layout
		if not classes.has(next_id):
			layout._error(&"class_base_missing", "base_class_id", next_id, "Runtime base class is missing.")
			return layout
		visited[next_id] = true
		derived_first.append(next_id)
		next_id = classes[next_id].base_class_id
	# Detect cycles before depth, including an active definition not stored in the catalog.
	if derived_first.size() - 1 > FlowClassCatalog.MAX_INHERITANCE_DEPTH:
		layout._error(&"class_inheritance_depth", "base_class_id", derived_first.back(), "Inheritance exceeds ten parent edges.")
		return layout
	derived_first.reverse()
	var seen_ids: Dictionary[String, bool] = {}
	for owner_id: String in derived_first:
		var definition: FlowGraph = classes[owner_id]
		var prefix: String = 'classes["%s"]' % owner_id
		FlowSchema5Validator.validate_catalog_context(definition, classes, layout, prefix)
		for record: Dictionary in FlowSchema5Model.owned_records(definition):
			var resource: Resource = record.resource
			var owned_id: String = String(resource.call(&"get_internal_id"))
			if seen_ids.has(owned_id):
				layout._error(FlowDiagnostic.CODE_DUPLICATE_INTERNAL_ID, prefix + "." + record.path,
					owned_id, "An owned ID occurs more than once in the runtime hierarchy.")
			seen_ids[owned_id] = true
	if layout.has_errors():
		return layout
	layout.class_order.assign(derived_first)
	for owner_id: String in layout.class_order:
		var definition: FlowGraph = classes[owner_id]
		var declared_class_slots: Dictionary[String, Dictionary] = {}
		for attribute: FlowAttributeDefinition in definition.constructor.attributes:
			if attribute != null and attribute.enabled:
				layout.instance_slots[attribute.get_internal_id()] = FlowAttributeRuntimeStore.snapshot_slot(attribute, owner_id)
		for attribute: FlowAttributeDefinition in definition.class_attributes:
			if attribute != null and attribute.enabled:
				declared_class_slots[attribute.get_internal_id()] = FlowAttributeRuntimeStore.snapshot_slot(attribute, owner_id)
		layout.class_slots[owner_id] = declared_class_slots
	layout._resolved = true
	return layout

func operation_result() -> FlowStoreResult:
	var result: FlowStoreResult = FlowStoreResult.make(&"ok", class_id)
	result.diagnostics.assign(diagnostics)
	for diagnostic: FlowDiagnostic in diagnostics:
		if diagnostic.severity == FlowDiagnostic.Severity.ERROR:
			result.ok = false
			result.code = diagnostic.code
			result.path = diagnostic.element_path
			result.related_id = diagnostic.related_id
			break
	if result.ok and not _resolved:
		result.ok = false
		result.code = &"store_definition_invalid"
	return result

func _error(code: StringName, path: String, related_id: String, message: String) -> void:
	FlowClassCatalog.issue(self, code, path, related_id, message)
