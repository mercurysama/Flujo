extends SceneTree

const TEMP_DIR: String = "res://.godot/flujo_tests/schema_5_foundation"
var _failures: Array[String] = []
var _paths: Array[String] = []
var _uids: Array[int] = []
var _checks: int = 0
var _messages: int = 0

func _init() -> void:
	_run.call_deferred()

func _check(condition: bool, context: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(context)
		push_error("[Flujo][Schema5] " + context)
	return condition

func _run() -> void:
	_test_structure()
	_test_references()
	_test_migration()
	_test_duplication()
	_test_boundaries()
	if _check(not DirAccess.dir_exists_absolute(TEMP_DIR), "Focal must not overwrite an existing temporary directory"):
		if _check(DirAccess.make_dir_recursive_absolute(TEMP_DIR) == OK, "Create owned temporary directory"):
			_test_persistence()
			_test_catalog()
			_cleanup()
	if _failures.is_empty():
		print("[Flujo] Schema 5 foundation focal passed (%d checks)" % _checks)
	quit(0 if _failures.is_empty() else 1)

func _graph(schema: int = FlowGraph.SCHEMA_VERSION_5) -> FlowGraph:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = schema
	if schema >= FlowGraph.SCHEMA_VERSION_3:
		graph.constructor = FlowConstructorDefinition.new()
	return graph

func _attribute(name_value: String, storage: FlowAttributeDefinition.Storage) -> FlowAttributeDefinition:
	var attribute: FlowAttributeDefinition = FlowAttributeDefinition.new()
	attribute.display_name = name_value
	attribute.storage = storage
	attribute.user_note = "Persistent defaults, not runtime values"
	attribute.bool_value = true
	attribute.int_value = -29
	attribute.float_value = 8.125
	attribute.string_value = "Two\nlines 🌊"
	attribute.vector2_value = Vector2(-2.5, 7.25)
	attribute.vector3_value = Vector3(1, -2, 3)
	attribute.color_value = Color(0.1, 0.3, 0.7, 0.5)
	return attribute

func _rich(schema: int = FlowGraph.SCHEMA_VERSION_5) -> FlowGraph:
	var graph: FlowGraph = _graph(schema)
	var method: FlowMethodDefinition = FlowMethodDefinition.new()
	method.parameters = [null, FlowMethodParameterDefinition.new()]
	method.blocks = [FlowEverythingFlowsBlock.new(), null]
	if schema == FlowGraph.SCHEMA_VERSION_5:
		method.outputs = [FlowMethodOutputDefinition.new(), null]
		for value_type: int in FlowVariableDefinition.ValueType.values():
			var instance_attribute: FlowAttributeDefinition = _attribute("Instance%d" % value_type, FlowAttributeDefinition.Storage.INSTANCE)
			instance_attribute.value_type = value_type as FlowVariableDefinition.ValueType
			graph.constructor.attributes.append(instance_attribute)
			graph.constructor.attributes.append(null)
			var class_attribute: FlowAttributeDefinition = _attribute("Class%d" % value_type, FlowAttributeDefinition.Storage.CLASS)
			class_attribute.value_type = value_type as FlowVariableDefinition.ValueType
			graph.class_attributes.append(class_attribute)
		graph.class_attributes.append(null)
	else:
		method.return_definition = FlowMethodReturnDefinition.new()
	graph.methods = [null, method]
	var call: FlowMethodCallBlock = FlowMethodCallBlock.new()
	if schema == FlowGraph.SCHEMA_VERSION_5:
		call.method_reference = FlowMethodReferenceDefinition.new()
		call.method_reference.target_class_id = graph.get_internal_id()
		call.method_reference.target_id = method.get_internal_id()
	else:
		call.method_id = method.get_internal_id()
	var process: FlowProcess = FlowProcess.new()
	process.blocks = [null, call, FlowPrintBlock.new()]
	var timer: FlowTimerDefinition = FlowTimerDefinition.new()
	timer.blocks = [FlowEverythingFlowsBlock.new(), null]
	graph.processes = [process, null, timer]
	graph.variables = [FlowVariableDefinition.new(), null]
	graph.constructor.blocks = [FlowPrintBlock.new(), null]
	graph.constructor.dependencies = [null, FlowDependencyDefinition.new()]
	graph.constructor.requirements = [FlowRequiredNodeDefinition.new(), null]
	return graph

func _sequence(result: FlowValidationResult) -> Array[String]:
	var sequence: Array[String] = []
	for diagnostic: FlowDiagnostic in result.diagnostics:
		sequence.append("%s|%s|%s|%d" % [diagnostic.code, diagnostic.element_path, diagnostic.related_id, diagnostic.severity])
	return sequence

func _has(result: FlowValidationResult, code: StringName, path: String = "", related_id: String = "") -> bool:
	for diagnostic: FlowDiagnostic in result.diagnostics:
		if diagnostic.code == code and (path.is_empty() or diagnostic.element_path == path) \
				and (related_id.is_empty() or diagnostic.related_id == related_id):
			return true
	return false

func _snapshot(value: Variant, visited: Dictionary = {}) -> Variant:
	if value is Resource:
		var resource: Resource = value
		if visited.has(resource.get_instance_id()):
			return {"repeated": resource.get_instance_id()}
		visited[resource.get_instance_id()] = true
		var data: Dictionary = {"instance": resource.get_instance_id()}
		for property: Dictionary in resource.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_STORAGE and property.name != &"script":
				data[property.name] = _snapshot(resource.get(property.name), visited)
		return data
	if value is Array:
		var data: Array = []
		for item: Variant in value:
			data.append(_snapshot(item, visited))
		return data
	return value

func _test_structure() -> void:
	_check(not FlowGraphValidator.validate(_graph()).has_errors(), "Minimum schema 5 valid")
	var graph: FlowGraph = _rich()
	_check(not FlowGraphValidator.validate(graph).has_errors(), "All seven typed INSTANCE/CLASS defaults valid")
	for visibility: int in FlowAttributeDefinition.Visibility.values():
		for mutability: int in FlowAttributeDefinition.Mutability.values():
			graph.class_attributes[0].visibility = visibility as FlowAttributeDefinition.Visibility
			graph.class_attributes[0].mutability = mutability as FlowAttributeDefinition.Mutability
			_check(not FlowGraphValidator.validate(graph).has_errors(), "Declared visibility/mutability valid")
	var attribute: FlowAttributeDefinition = graph.class_attributes[0]
	attribute.default_is_null = true
	var before: Variant = _snapshot(graph)
	var first: FlowValidationResult = FlowGraphValidator.validate(graph)
	_check(_has(first, &"attribute_null_default_invalid", "class_attributes[0].default_is_null", attribute.get_internal_id()), "Exact null-default diagnostic")
	_check(_sequence(first) == _sequence(FlowGraphValidator.validate(graph)), "Validation repeat is deterministic")
	_check(before == _snapshot(graph), "Validation never mutates invalid defaults")
	attribute.nullable = true
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Explicit nullable default accepted")
	attribute.set("value_type", 7)
	attribute.set("visibility", -1)
	attribute.set("mutability", 3)
	attribute.set("storage", 7)
	first = FlowGraphValidator.validate(graph)
	_check(_has(first, &"invalid_value_type", "class_attributes[0].value_type", attribute.get_internal_id()), "Invalid canonical type diagnosed")
	_check(_has(first, &"invalid_visibility") and _has(first, &"invalid_mutability") and _has(first, &"invalid_attribute_storage"), "Invalid enum members preserved and diagnosed")
	_check(attribute.value_type == 7 and attribute.visibility == -1 and attribute.mutability == 3 and attribute.storage == 7, "Invalid enum values preserved")
	graph = _rich()
	graph.class_attributes[0]._internal_id = graph.methods[1].get_internal_id()
	_check(_has(FlowGraphValidator.validate(graph), &"duplicate_internal_id", "class_attributes[0]", graph.methods[1].get_internal_id()), "Attributes share global method identity registry")
	graph.class_attributes[1] = graph.class_attributes[0]
	_check(_has(FlowGraphValidator.validate(graph), &"repeated_resource_instance", "class_attributes[1]"), "Repeated attribute instance diagnosed")

func _test_references() -> void:
	var graph: FlowGraph = _rich()
	var reference: FlowAttributeReferenceDefinition = FlowAttributeReferenceDefinition.new()
	reference.target_class_id = graph.get_internal_id()
	reference.target_id = graph.class_attributes[0].get_internal_id()
	_check(not FlowSchema5Validator.validate_reference(reference, graph).has_errors(), "Attribute target resolves by class and ID")
	reference.target_id = graph.methods[1].get_internal_id()
	_check(_has(FlowSchema5Validator.validate_reference(reference, graph), &"reference_target_kind", "reference.target_id", reference.target_id), "Wrong-kind target diagnosed")
	reference.target_id = FlowId.create()
	_check(_has(FlowSchema5Validator.validate_reference(reference, graph), &"reference_target_missing", "reference.target_id", reference.target_id), "Missing target preserved")
	reference.target_id = "malformed"
	_check(_has(FlowSchema5Validator.validate_reference(reference, graph), &"reference_id_invalid"), "Malformed reference diagnosed")
	reference.target_class_id = ""
	_check(_has(FlowSchema5Validator.validate_reference(reference, graph), &"reference_id_invalid", "reference.target_class_id"), "Empty class never implicitly means current class")
	var required_reference: FlowRequirementReferenceDefinition = FlowRequirementReferenceDefinition.new()
	required_reference.target_class_id = graph.get_internal_id()
	required_reference.target_id = graph.constructor.requirements[0].get_internal_id()
	_check(not FlowSchema5Validator.validate_reference(required_reference, graph).has_errors(), "Requirement reference resolves definition, never Node")
	graph.constructor.requirements.append(graph.constructor.requirements[0])
	_check(_has(FlowSchema5Validator.validate_reference(required_reference, graph), &"reference_target_ambiguous"), "Repeated target is ambiguous, never first-match")
	var parent: FlowGraph = _rich()
	var child: FlowGraph = _graph()
	child.base_class_id = parent.get_internal_id()
	var classes: Dictionary[String, FlowGraph] = {parent.get_internal_id(): parent, child.get_internal_id(): child}
	reference.target_class_id = parent.get_internal_id()
	reference.target_id = parent.class_attributes[0].get_internal_id()
	parent.class_attributes[0].visibility = FlowAttributeDefinition.Visibility.PRIVATE
	_check(_has(FlowSchema5Validator.validate_reference(reference, child, classes), &"reference_inaccessible"), "Private slot inaccessible to child")
	parent.class_attributes[0].visibility = FlowAttributeDefinition.Visibility.PROTECTED
	_check(not FlowSchema5Validator.validate_reference(reference, child, classes).has_errors(), "Protected slot accessible to descendant")
	var unrelated: FlowGraph = _graph()
	_check(_has(FlowSchema5Validator.validate_reference(reference, unrelated, classes), &"reference_inaccessible"), "Protected slot inaccessible to unrelated class")

func _test_migration() -> void:
	var source: FlowGraph = _rich(FlowGraph.SCHEMA_VERSION_4)
	var before: Variant = _snapshot(source)
	var migration: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_4_to_5(source)
	if not _check(migration.is_successful(), "4→5 migration succeeds"):
		return
	var copy: FlowGraph = migration.migrated_graph
	_check(before == _snapshot(source), "4→5 source unmodified")
	if not _check(copy.constructor != null and copy.methods.size() == 2 and copy.methods[1] != null, "Migrated constructor/method structure"):
		return
	_check(copy.constructor.attributes.is_empty() and copy.class_attributes.is_empty() and copy.base_class_id.is_empty(), "New collections start empty, no base")
	_check(copy.methods[1].return_definition == null and copy.methods[1].outputs.size() == 1, "Schema 5 has only outputs")
	if not _check(copy.methods[1].outputs.size() == 1 and copy.methods[1].outputs[0] != null, "First migrated output exists"):
		return
	_check(copy.methods[1].outputs[0].get_internal_id() == source.methods[1].return_definition.get_internal_id(), "Return ID preserved")
	_check(copy.methods[1].outputs[0].value_type == source.methods[1].return_definition.value_type, "Return type preserved")
	_check(copy.variables[0] != source.variables[0] and copy.variables[0].get_internal_id() == source.variables[0].get_internal_id(), "Variables copied without conversion")
	_check(copy.constructor.blocks.size() == 2 and copy.constructor.blocks[1] == null and copy.constructor.dependencies[0] == null, "Legacy order and null preserved")
	var call: FlowMethodCallBlock = copy.processes[0].blocks[1] as FlowMethodCallBlock
	if not _check(call != null and call.method_reference != null, "Call migrated to owned reference"):
		return
	_check(call.method_id.is_empty() and call.method_reference.target_id == source.methods[1].get_internal_id() and call.method_reference.target_class_id == source.get_internal_id(), "Migration reference has explicit class and method ID")
	source.methods[1]._internal_id = "bad"
	before = _snapshot(source)
	_check(not FlowGraphMigrator.migrate_schema_4_to_5(source).is_successful(), "Invalid source migration rejects")
	_check(before == _snapshot(source), "Rejected migration preserves source")
	var schema3: FlowGraph = _rich(FlowGraph.SCHEMA_VERSION_3)
	schema3.constructor.requirements = []
	before = _snapshot(schema3)
	_check(not FlowGraphMigrator.migrate_schema_3_to_5(schema3).is_successful(), "Legacy blocks/dependencies require confirmation through chain")
	_check(FlowGraphMigrator.migrate_schema_3_to_5(schema3, true).is_successful(), "Confirmed 3→4→5 succeeds")
	_check(before == _snapshot(schema3), "3→4→5 never mutates source")
	schema3.constructor.blocks = []
	_check(not FlowGraphMigrator.migrate_schema_3_to_5(schema3).is_successful(), "Dependencies alone require confirmation")
	var schema2: FlowGraph = _graph(FlowGraph.SCHEMA_VERSION_2)
	schema2.processes = [FlowProcess.new(), null]
	before = _snapshot(schema2)
	migration = FlowGraphMigrator.migrate_schema_2_to_5(schema2)
	_check(migration.is_successful(), "Public 2→3→4→5 succeeds")
	_check(before == _snapshot(schema2), "Full chain preserves schema 2")

func _test_duplication() -> void:
	var graph: FlowGraph = _rich()
	graph.base_class_id = FlowId.create()
	var before: Variant = _snapshot(graph)
	var copy: FlowGraph = graph.duplicate_with_new_ids()
	if not _check(copy != null, "Schema 5 duplication returns graph"):
		return
	_check(before == _snapshot(graph), "Duplication preserves original")
	_check(copy.base_class_id == graph.base_class_id, "External base preserved literally")
	var original_records: Array[Dictionary] = FlowSchema5Model.owned_records(graph)
	var copied_records: Array[Dictionary] = FlowSchema5Model.owned_records(copy)
	if not _check(original_records.size() == copied_records.size(), "Deep copy preserves ownership/order"):
		return
	var ids: Dictionary[String, bool] = {}
	for index: int in original_records.size():
		var original: Resource = original_records[index].resource
		var copied: Resource = copied_records[index].resource
		_check(original != copied, "Independent resource at " + original_records[index].path)
		var copied_id: String = String(copied.call(&"get_internal_id"))
		_check(original.call(&"get_internal_id") != copied_id and FlowId.is_valid(copied_id), "Fresh valid ID at " + original_records[index].path)
		_check(not ids.has(copied_id), "Unique copy ID at " + original_records[index].path)
		ids[copied_id] = true
	var call: FlowMethodCallBlock = copy.processes[0].blocks[1] as FlowMethodCallBlock
	if not _check(call != null and call.method_reference != null, "Copied method reference exists"):
		return
	_check(call.method_reference.target_id == copy.methods[1].get_internal_id() and call.method_reference.target_class_id == copy.get_internal_id(), "Forward reference remapped after complete map")
	_check(copy.constructor.attributes[1] == null and copy.class_attributes[7] == null and copy.methods[1].outputs[1] == null, "All null slots preserved")
	copy.constructor.attributes[0].string_value = "Changed"
	copy.methods[1].outputs[0].display_name = "Changed"
	copy.variables[0].int_value = 99
	_check(before == _snapshot(graph), "Nested mutations do not affect original")
	var original_call: FlowMethodCallBlock = graph.processes[0].blocks[1] as FlowMethodCallBlock
	original_call.method_reference.target_class_id = FlowId.create()
	original_call.method_reference.target_id = FlowId.create()
	copy = graph.duplicate_with_new_ids()
	call = copy.processes[0].blocks[1] as FlowMethodCallBlock
	_check(call.method_reference.target_id == original_call.method_reference.target_id and call.method_reference.target_class_id == original_call.method_reference.target_class_id, "External/unknown target remains literal")

func _test_boundaries() -> void:
	for schema: int in [1, 2, 3, 4]:
		var graph: FlowGraph = _graph(schema)
		_check(not FlowGraphValidator.validate(graph).has_errors(), "Old minimal schema %d remains valid" % schema)
		graph.class_attributes = [null]
		_check(_has(FlowGraphValidator.validate(graph), &"class_data_incompatible_schema"), "Older schema rejects even null-only new collection")
	var graph: FlowGraph = _graph(6)
	_check(_has(FlowGraphValidator.validate(graph), &"unsupported_schema_version"), "Unknown version is later than 5")
	graph = _rich()
	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	var output: FlowRuntimeOutput = FlowRuntimeOutput.new()
	output.message_emitted.connect(_on_output)
	for entry: StringName in [&"Constructor", &"Ready", &"Timer"]:
		FlowReadyExecutor.new().execute(controller, graph, output, entry)
	_check(_messages == 0, "Schema 5 never executes through existing executor")
	controller.free()

func _on_output(_controller: Node, _process: String, _block: String, _message: String) -> void:
	_messages += 1

func _save(resource: Resource, name_value: String) -> String:
	var path: String = TEMP_DIR + "/" + name_value
	_paths.append(path)
	if not _check(ResourceSaver.save(resource, path) == OK, "Save " + name_value):
		return ""
	return path

func _test_persistence() -> void:
	var graph: FlowGraph = _rich()
	var path: String = _save(graph, "graph.tres")
	if path.is_empty():
		return
	var loaded: FlowGraph = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as FlowGraph
	if not _check(loaded != null and loaded != graph, "ResourceSaver independent load"):
		return
	_check_persisted(graph, loaded)
	var root: Node = Node.new()
	var a: PVController = PVController.new()
	var b: PVController = PVController.new()
	root.add_child(a)
	root.add_child(b)
	a.owner = root
	b.owner = root
	a.flow_graph = graph
	b.flow_graph = graph
	var requirement_id: String = graph.constructor.requirements[0].get_internal_id()
	a.requirement_bindings = {requirement_id: NodePath("One")}
	b.requirement_bindings = {requirement_id: NodePath("Two")}
	var scene: PackedScene = PackedScene.new()
	var packed: bool = _check(scene.pack(root) == OK, "Pack two-controller scene")
	root.free()
	if not packed:
		return
	path = _save(scene, "bindings.tscn")
	if path.is_empty():
		return
	var loaded_scene: PackedScene = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as PackedScene
	if not _check(loaded_scene != null, "Load PackedScene"):
		return
	var first: Node = loaded_scene.instantiate()
	var second: Node = loaded_scene.instantiate()
	if not _check(first != null and second != null, "Instantiate both scenes"):
		if first != null: first.free()
		if second != null: second.free()
		return
	if _check(first.get_child_count() == 2 and second.get_child_count() == 2, "PackedScene controller count"):
		var a_copy: PVController = first.get_child(0) as PVController
		var b_copy: PVController = first.get_child(1) as PVController
		var other: PVController = second.get_child(0) as PVController
		if _check(a_copy != null and b_copy != null and other != null, "PackedScene controller types"):
			_check(a_copy.flow_graph == b_copy.flow_graph, "Definitions remain shared")
			_check_persisted(graph, a_copy.flow_graph)
			_check(a_copy.requirement_bindings[requirement_id] == NodePath("One") and b_copy.requirement_bindings[requirement_id] == NodePath("Two"), "Per-controller bindings persist")
			a_copy.requirement_bindings[requirement_id] = NodePath("Changed")
			_check(b_copy.requirement_bindings[requirement_id] == NodePath("Two") and other.requirement_bindings[requirement_id] == NodePath("One"), "Bindings independent across controllers and instances")
	first.free()
	second.free()
	var reference: FlowAttributeReferenceDefinition = FlowAttributeReferenceDefinition.new()
	reference.target_class_id = graph.get_internal_id()
	reference.target_id = graph.class_attributes[0].get_internal_id()
	path = _save(reference, "reference.tres")
	if not path.is_empty():
		var ref_copy: FlowAttributeReferenceDefinition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as FlowAttributeReferenceDefinition
		if _check(ref_copy != null, "Typed reference ResourceSaver subtype"):
			_check(ref_copy.get_internal_id() == reference.get_internal_id() and ref_copy.target_id == reference.target_id and ref_copy.target_class_id == reference.target_class_id, "Reference identity/targets preserved")

func _check_persisted(original: FlowGraph, loaded: FlowGraph) -> void:
	if not _check(loaded != null, "Persisted graph present"):
		return
	_check(not FlowGraphValidator.validate(loaded).has_errors(), "Loaded schema 5 validates")
	var expected: Array[Dictionary] = FlowSchema5Model.owned_records(original)
	var actual: Array[Dictionary] = FlowSchema5Model.owned_records(loaded)
	if not _check(expected.size() == actual.size(), "Persisted ownership count"):
		return
	for index: int in expected.size():
		var source: Resource = expected[index].resource
		var target: Resource = actual[index].resource
		_check(expected[index].path == actual[index].path and source.call(&"get_internal_id") == target.call(&"get_internal_id"), "Persisted ID and position: " + expected[index].path)
		if source is FlowAttributeDefinition:
			for field: String in ["display_name", "enabled", "user_note", "storage", "visibility", "mutability", "value_type", "nullable", "default_is_null", "bool_value", "int_value", "float_value", "string_value", "vector2_value", "vector3_value", "color_value"]:
				_check(source.get(field) == target.get(field), "Persisted active/inactive attribute field " + field)
	_check(loaded.constructor.attributes.size() == 14 and loaded.constructor.attributes[1] == null and loaded.methods[0] == null, "Persistence preserves explicit null positions")

func _entry(graph: FlowGraph, name_value: String) -> FlowClassCatalogEntry:
	var path: String = _save(graph, name_value)
	if path.is_empty():
		return null
	var uid: int = ResourceUID.create_id()
	ResourceUID.add_id(uid, path)
	_uids.append(uid)
	var entry: FlowClassCatalogEntry = FlowClassCatalogEntry.new()
	entry.class_id = graph.get_internal_id()
	entry.graph_uid = ResourceUID.id_to_text(uid)
	entry.graph_path = path
	return entry

func _test_catalog() -> void:
	var catalog: FlowClassCatalog = FlowClassCatalog.new()
	var root_graph: FlowGraph = _graph()
	var root_entry: FlowClassCatalogEntry = _entry(root_graph, "class_0.tres")
	if not _check(root_entry != null, "Root catalog fixture"):
		return
	catalog.entries = [root_entry]
	_check(not catalog.validate().has_errors(), "UID/path catalog resolves valid graph")
	var original_uid: String = root_entry.graph_uid
	root_entry.graph_uid = ResourceUID.id_to_text(ResourceUID.create_id())
	var resolved: FlowClassCatalogResult = catalog.validate()
	_check(not resolved.has_errors() and _has(resolved, &"class_catalog_locator_stale", "entries[0].graph_uid", root_entry.class_id), "Unavailable UID falls back with warning")
	_check(root_entry.graph_uid != original_uid, "Fallback does not silently repair UID")
	root_entry.graph_uid = original_uid
	var original_path: String = root_entry.graph_path
	root_entry.graph_path = TEMP_DIR + "/missing.tres"
	resolved = catalog.validate()
	_check(not resolved.has_errors() and _has(resolved, &"class_catalog_locator_stale", "entries[0].graph_path", root_entry.class_id), "Stale path uses UID with warning")
	root_entry.graph_uid = ResourceUID.id_to_text(ResourceUID.create_id())
	_check(_has(catalog.validate(), &"class_catalog_graph_missing"), "Both missing diagnosed")
	root_entry.graph_uid = original_uid
	root_entry.graph_path = original_path
	var other: FlowClassCatalogEntry = _entry(_graph(), "other.tres")
	if not _check(other != null, "Other catalog fixture"):
		return
	root_entry.graph_path = other.graph_path
	_check(_has(catalog.validate(), &"class_catalog_locator_conflict", "entries[0]", root_entry.class_id), "Conflicting working locators reject")
	root_entry.graph_path = original_path
	catalog.entries.append(root_entry)
	_check(_has(catalog.validate(), &"class_catalog_id_duplicate"), "Duplicate entries reject, never first-match")
	catalog.entries = [root_entry, null]
	_check(_has(catalog.validate(), &"class_catalog_entry_invalid"), "Null entry rejected")
	catalog.entries = [root_entry]
	root_entry.graph_path = "res://folder/../bad.tres"
	_check(_has(catalog.validate(), &"class_catalog_path_invalid"), "Noncanonical path rejected")
	root_entry.graph_path = original_path
	root_entry.graph_uid = "bad"
	_check(_has(catalog.validate(), &"class_catalog_uid_invalid"), "Malformed UID rejected")
	root_entry.graph_uid = original_uid
	var previous_id: String = root_graph.get_internal_id()
	for depth: int in range(1, 12):
		var derived: FlowGraph = _graph()
		derived.base_class_id = previous_id
		var entry: FlowClassCatalogEntry = _entry(derived, "class_%d.tres" % depth)
		if not _check(entry != null, "Inheritance fixture %d" % depth):
			return
		catalog.entries.append(entry)
		previous_id = derived.get_internal_id()
		resolved = catalog.validate()
		_check(not resolved.has_errors() if depth <= 10 else _has(resolved, &"class_inheritance_depth"), "Inheritance depth %d" % depth)
	var before: Variant = _snapshot(catalog)
	_check(_sequence(resolved) == _sequence(catalog.validate()) and before == _snapshot(catalog), "Catalog validation deterministic and nonmutating")
	var cycle_a: FlowGraph = _graph()
	var cycle_b: FlowGraph = _graph()
	cycle_a.base_class_id = cycle_b.get_internal_id()
	cycle_b.base_class_id = cycle_a.get_internal_id()
	var cycle_catalog: FlowClassCatalog = FlowClassCatalog.new()
	cycle_catalog.entries = [_entry(cycle_a, "cycle_a.tres"), _entry(cycle_b, "cycle_b.tres")]
	var cycle_result: FlowClassCatalogResult = cycle_catalog.validate()
	_check(_has(cycle_result, &"class_inheritance_cycle", "entries[1].base_class_id", cycle_a.get_internal_id()), "A→B→A cycle rejected deterministically")
	_check(not _has(cycle_result, &"class_inheritance_depth"), "Cycle is not mislabeled as excessive depth")
	var cycle_catalog_path: String = _save(cycle_catalog, "cycle_catalog.tres")
	if not cycle_catalog_path.is_empty():
		var loaded_cycle_catalog: FlowClassCatalog = ResourceLoader.load(cycle_catalog_path, "", ResourceLoader.CACHE_MODE_IGNORE) as FlowClassCatalog
		if _check(loaded_cycle_catalog != null, "Reload cycle catalog"):
			_check(_sequence(cycle_result) == _sequence(loaded_cycle_catalog.validate()), "Cycle diagnostics match before and after catalog persistence")
	var self_cycle: FlowGraph = _graph()
	self_cycle.base_class_id = self_cycle.get_internal_id()
	var self_catalog: FlowClassCatalog = FlowClassCatalog.new()
	self_catalog.entries = [_entry(self_cycle, "self_cycle.tres")]
	_check(_has(self_catalog.validate(), &"class_inheritance_cycle", "entries[0].base_class_id", self_cycle.get_internal_id()), "A→A self-cycle rejected")
	var missing_base: FlowGraph = _graph()
	missing_base.base_class_id = FlowId.create()
	var missing_catalog: FlowClassCatalog = FlowClassCatalog.new()
	missing_catalog.entries = [_entry(missing_base, "missing_base.tres")]
	var missing_result: FlowClassCatalogResult = missing_catalog.validate()
	_check(_has(missing_result, &"class_base_missing", "entries[0].base_class_id", missing_base.base_class_id), "Missing base rejected separately")
	_check(not _has(missing_result, &"class_inheritance_cycle") and not _has(missing_result, &"class_inheritance_depth"), "Missing base is neither cycle nor depth")
	var catalog_path: String = _save(catalog, "catalog.tres")
	if not catalog_path.is_empty():
		var loaded: FlowClassCatalog = ResourceLoader.load(catalog_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as FlowClassCatalog
		if _check(loaded != null and loaded.entries.size() == catalog.entries.size(), "Catalog persists ordered entries"):
			_check(loaded.entries[0].class_id == root_entry.class_id and loaded.entries[0].graph_uid == original_uid and loaded.entries[0].graph_path == original_path, "All three entry fields persist together")

func _cleanup() -> void:
	for uid: int in _uids:
		ResourceUID.remove_id(uid)
	for path: String in _paths:
		if FileAccess.file_exists(path):
			_check(DirAccess.remove_absolute(path) == OK, "Remove owned temporary " + path.get_file())
	_check(DirAccess.remove_absolute(TEMP_DIR) == OK, "Remove empty owned temporary directory")
