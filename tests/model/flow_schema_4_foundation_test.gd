extends SceneTree

## DCON-001/003/004/010/012: persistent data only; controllers never enter the tree.
const GRAPH_PATH: String = "res://.godot/flujo_tests/schema_4_foundation.tres"
const SCENE_PATH: String = "res://.godot/flujo_tests/schema_4_foundation.tscn"
const BLOCK_PATH: String = "res://.godot/flujo_tests/schema_4_external_block.tres"
var _failures: Array[String] = []
var _owned_paths: Array[String] = []
var _checks: int = 0


func _init() -> void:
	_run.call_deferred()


func _check(condition: bool, context: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(context)
		push_error("[Flujo][Schema4] " + context)
	return condition


func _run() -> void:
	_test_validation()
	_test_migration()
	_test_duplication()
	_test_bindings()
	if _prepare_paths():
		_test_persistence()
	_cleanup()
	if _failures.is_empty():
		print("[Flujo] Schema 4 foundation focal passed (%d checks)" % _checks)
	quit(0 if _failures.is_empty() else 1)


func _graph(schema: int = FlowGraph.SCHEMA_VERSION_4) -> FlowGraph:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = schema
	graph.constructor = FlowConstructorDefinition.new()
	return graph


func _requirement(label: String = "Marker") -> FlowRequiredNodeDefinition:
	var requirement: FlowRequiredNodeDefinition = FlowRequiredNodeDefinition.new()
	requirement.display_name = label
	requirement.expected_node_name = StringName(label)
	requirement.user_note = "Persistent declaration only"
	return requirement


func _rich_graph(schema: int = FlowGraph.SCHEMA_VERSION_4) -> FlowGraph:
	var graph: FlowGraph = _graph(schema)
	var method: FlowMethodDefinition = FlowMethodDefinition.new()
	method.display_name = "Shared method"
	method.parameters = [null, FlowMethodParameterDefinition.new()]
	method.return_definition = FlowMethodReturnDefinition.new()
	method.blocks = [null, FlowEverythingFlowsBlock.new()]
	graph.methods = [null, method]
	var call: FlowMethodCallBlock = FlowMethodCallBlock.new()
	call.method_id = method.get_internal_id()
	var print_block: FlowPrintBlock = FlowPrintBlock.new()
	print_block.text = "Inert constructor payload"
	graph.constructor.display_name = "Preserved constructor"
	graph.constructor.user_note = "Do not reinterpret"
	graph.constructor.blocks = [null, print_block, call, null]
	var dependency: FlowDependencyDefinition = FlowDependencyDefinition.new()
	dependency.display_name = "Legacy dependency"
	dependency.required_class_name = &"Node2D"
	graph.constructor.dependencies = [null, dependency, null]
	var process: FlowProcess = FlowProcess.new()
	process.blocks = [FlowPrintBlock.new(), null]
	var timer: FlowTimerDefinition = FlowTimerDefinition.new()
	timer.interval_seconds = 7.25
	timer.repeat = true
	timer.blocks = [null, FlowEverythingFlowsBlock.new()]
	graph.processes = [process, null, timer]
	var variable: FlowVariableDefinition = FlowVariableDefinition.new()
	variable.owner_container_id = process.get_internal_id()
	graph.variables = [null, variable]
	var machine: FlowStateMachineDefinition = FlowStateMachineDefinition.new()
	var state: FlowStateDefinition = FlowStateDefinition.new()
	state.blocks = [null, FlowPrintBlock.new()]
	machine.states = [null, state]
	machine.initial_state_id = state.get_internal_id()
	graph.state_machines = [machine, null]
	if schema == FlowGraph.SCHEMA_VERSION_4:
		var optional: FlowRequiredNodeDefinition = _requirement("Optional")
		optional.required_class_name = &"Node2D"
		optional.enabled = false
		optional.required = false
		graph.constructor.requirements = [null, _requirement(), optional, null]
	return graph


## Snapshot every stored field, not just selected values or IDs.
func _snapshot(value: Variant) -> Variant:
	if value is Resource:
		var resource: Resource = value as Resource
		var data: Dictionary = {}
		for property: Dictionary in resource.get_property_list():
			var key: String = String(property.name)
			if int(property.usage) & PROPERTY_USAGE_STORAGE:
				if key == "script":
					var script: Script = resource.get_script() as Script
					data[key] = script.resource_path if script != null else ""
				else:
					data[key] = _snapshot(resource.get(key))
		return data
	if value is Array:
		var array: Array = []
		for item: Variant in value:
			array.append(_snapshot(item))
		return array
	if value is Dictionary:
		return (value as Dictionary).duplicate(true)
	return value


## Check deep independence and all stored metadata; only ID remaps/schema may differ.
func _check_copy(source: Variant, copy: Variant, new_ids: bool, path: String = "graph") -> void:
	if source is Resource:
		if not _check(copy is Resource, path + ": copied resource exists"):
			return
		var original: Resource = source as Resource
		var cloned: Resource = copy as Resource
		_check(original != cloned, path + ": independent resource")
		_check(original.get_script() == cloned.get_script(), path + ": concrete script preserved")
		for property: Dictionary in original.get_property_list():
			var key: String = String(property.name)
			if not (int(property.usage) & PROPERTY_USAGE_STORAGE) or key == "script":
				continue
			if key == "schema_version":
				continue
			if new_ids and key == "_internal_id":
				_check(cloned.get(key) != original.get(key) and FlowId.is_valid(cloned.get(key)), path + ": renewed valid ID")
			elif new_ids and key in ["method_id", "owner_container_id", "initial_state_id"]:
				continue # Exact targets are checked separately after the full map exists.
			else:
				_check_copy(original.get(key), cloned.get(key), new_ids, path + "." + key)
	elif source is Array:
		if not _check(copy is Array, path + ": copied array exists"):
			return
		var original_array: Array = source
		var cloned_array: Array = copy
		if not _check(original_array.size() == cloned_array.size(), path + ": array length preserved"):
			return
		for index: int in original_array.size():
			_check_copy(original_array[index], cloned_array[index], new_ids, "%s[%d]" % [path, index])
	else:
		_check(source == copy, path + ": literal value preserved")


func _sequence(result: FlowValidationResult) -> Array:
	var values: Array = []
	for diagnostic: FlowDiagnostic in result.diagnostics:
		values.append([diagnostic.code, diagnostic.element_path, diagnostic.related_id])
	return values


func _expect_invalid(graph: FlowGraph, expected: Array, context: String) -> void:
	var before: Variant = _snapshot(graph)
	var first: FlowValidationResult = FlowGraphValidator.validate(graph)
	var second: FlowValidationResult = FlowGraphValidator.validate(graph)
	_check(first.has_errors(), context + ": rejected")
	_check(_sequence(first) == expected, context + ": exact diagnostic sequence " + str(_sequence(first)))
	_check(_sequence(first) == _sequence(second), context + ": repeated sequence identical")
	_check(_snapshot(graph) == before, context + ": original unchanged")


func _test_validation() -> void:
	_check(not FlowGraphValidator.validate(_rich_graph()).has_errors(), "Rich schema 4 graph is valid, including Timer and method-call data")
	_check(FlowGraph.CURRENT_SCHEMA_VERSION == 1 and FlowGraph.SCHEMA_VERSION_2 == 2 and FlowGraph.SCHEMA_VERSION_3 == 3, "Existing schema numbers remain unchanged")
	var graph: FlowGraph = _graph()
	var requirement: FlowRequiredNodeDefinition = _requirement()
	graph.constructor.requirements = [null, requirement]
	var path: String = "constructor.requirements[1]"
	var requirement_id: String = requirement.get_internal_id()
	requirement.display_name = " "
	requirement.required_class_name = &""
	requirement.expected_node_name = &""
	requirement.required_properties = [null]
	_expect_invalid(graph, [
		[&"empty_display_name", path + ".display_name", requirement_id],
		[&"required_node_class_missing", path + ".required_class_name", requirement_id],
		[&"required_node_name_empty", path + ".expected_node_name", requirement_id],
		[&"required_properties_unsupported", path + ".required_properties", requirement_id],
	], "Invalid fields")
	requirement.display_name = "Marker"
	requirement.expected_node_name = &"Marker"
	requirement.required_properties.clear()
	for class_case: Array in [[&"MissingFlujoClass", &"required_node_class_missing"], [&"Resource", &"required_node_class_not_node"], [&"CanvasItem", &"required_node_class_not_instantiable"]]:
		requirement.required_class_name = class_case[0]
		_expect_invalid(graph, [[class_case[1], path + ".required_class_name", requirement_id]], "Class " + String(class_case[0]))
	requirement.required_class_name = &"Node"
	for invalid_name: String in ["Parent/Child", "..", "With:Subname"]:
		requirement.expected_node_name = StringName(invalid_name)
		_expect_invalid(graph, [[&"required_node_name_invalid", path + ".expected_node_name", requirement_id]], "Invalid expected name")
	requirement.expected_node_name = &"Marker"
	requirement._internal_id = ""
	_expect_invalid(graph, [[&"empty_internal_id", path, ""]], "Empty ID")
	requirement._internal_id = "bad-id"
	_expect_invalid(graph, [[&"invalid_internal_id_length", path, "bad-id"], [&"non_hexadecimal_internal_id", path, "bad-id"]], "Malformed ID")
	for collision_id: String in [graph.get_internal_id(), graph.constructor.get_internal_id()]:
		requirement._internal_id = collision_id
		_expect_invalid(graph, [[&"duplicate_internal_id", path, collision_id]], "Global collision")
	requirement._internal_id = requirement_id
	graph.constructor.requirements.append(requirement)
	_expect_invalid(graph, [[&"repeated_resource_instance", "constructor.requirements[2]", requirement_id]], "Repeated instance")
	graph.constructor.requirements.pop_back()
	for schema: int in [1, 2, 3]:
		graph.schema_version = schema
		var expected: Array = []
		if schema < 3:
			expected.append([&"mixed_schema_sources", "graph", ""])
		expected.append([&"requirements_incompatible_schema", "constructor.requirements", graph.constructor.get_internal_id()])
		_expect_invalid(graph, expected, "No implicit requirements in schema %d" % schema)
	graph.schema_version = FlowGraph.SCHEMA_VERSION_4
	graph.containers = [null]
	_expect_invalid(graph, [[&"mixed_schema_sources", "graph", ""]], "Schema 4 rejects legacy collection")
	for schema: int in [1, 2]:
		var legacy: FlowGraph = FlowGraph.new()
		legacy.schema_version = schema
		_check(not FlowGraphValidator.validate(legacy).has_errors(), "Empty schema %d retains previous validation" % schema)
	_check(not FlowGraphValidator.validate(_rich_graph(3)).has_errors(), "Existing schema 3 constructor, dependency, method, Timer remain valid")


func _test_migration() -> void:
	var source: FlowGraph = _rich_graph(3)
	var before: Variant = _snapshot(source)
	var rejected: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_3_to_4(source)
	_check(not rejected.is_successful() and rejected.has_errors() and rejected.migrated_graph == null, "Unconfirmed legacy migration has no candidate")
	if _check(rejected.diagnostics.size() == 1, "Confirmation has one diagnostic"):
		var diagnostic: FlowDiagnostic = rejected.diagnostics[0]
		_check([diagnostic.code, diagnostic.element_path, diagnostic.related_id] == [&"migration_confirmation_required", "constructor", source.constructor.get_internal_id()], "Exact confirmation diagnostic")
	_check(_snapshot(source) == before, "Rejected migration preserves complete source")
	var migration: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_3_to_4(source, true)
	if not _check(migration.is_successful(), "Confirmed migration succeeds"):
		return
	var candidate: FlowGraph = migration.migrated_graph
	_check(candidate.schema_version == 4 and source.schema_version == 3, "Explicit schema transition")
	if not _check(candidate.constructor != null, "Migrated constructor exists"):
		return
	_check(candidate.constructor.requirements.is_empty(), "Migration never invents requirements")
	_check_copy(source, candidate, false)
	_check(_snapshot(source) == before, "Successful migration preserves complete source")
	if _check(candidate.constructor.blocks.size() == 4, "Migrated legacy block count"):
		if _check(candidate.constructor.blocks[1] is FlowPrintBlock, "Migrated Print exists"):
			(candidate.constructor.blocks[1] as FlowPrintBlock).text = "Copy changed"
	_check(_snapshot(source) == before, "Mutating migrated data leaves source intact")
	var dependencies_only: FlowGraph = _graph(3)
	dependencies_only.constructor.dependencies = [FlowDependencyDefinition.new(), null]
	_check(FlowGraphMigrator.migrate_schema_3_to_4(dependencies_only).has_errors(), "Dependencies also require confirmation under DCON-001")
	var null_payload: FlowGraph = _graph(3)
	null_payload.constructor.blocks = [null]
	_check(FlowGraphMigrator.migrate_schema_3_to_4(null_payload).has_errors(), "Non-empty legacy payload preserves null positions and requires consent")
	_check(FlowGraphMigrator.migrate_schema_3_to_4(_graph(3)).is_successful(), "Empty constructor needs no legacy consent")
	_check(FlowGraphMigrator.migrate_schema_3_to_4(null).has_errors(), "Null migration input rejected")
	_check(FlowGraphMigrator.migrate_schema_3_to_4(_graph(4), true).has_errors(), "Wrong migration schema rejected")
	var invalid: FlowGraph = _graph(3)
	invalid._internal_id = ""
	var invalid_before: Variant = _snapshot(invalid)
	_check(FlowGraphMigrator.migrate_schema_3_to_4(invalid, true).migrated_graph == null, "Invalid source rejected before candidate")
	_check(_snapshot(invalid) == invalid_before, "Invalid source is not repaired")
	var schema_2: FlowGraph = FlowGraph.new()
	schema_2.schema_version = 2
	var process: FlowProcess = FlowProcess.new()
	process.blocks = [null, FlowPrintBlock.new()]
	schema_2.processes = [null, process]
	var schema_2_before: Variant = _snapshot(schema_2)
	var chain: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_2_to_4(schema_2)
	if not _check(chain.is_successful(), "Public 2 to 3 to 4 chain succeeds"):
		return
	_check(chain.migrated_graph.schema_version == 4, "Chain publishes schema 4 only")
	_check(chain.migrated_graph.get_internal_id() == schema_2.get_internal_id(), "Chain preserves root ID")
	_check_copy(schema_2.processes, chain.migrated_graph.processes, false, "chain.processes")
	if _check(chain.migrated_graph.constructor != null, "Chain creates constructor"):
		_check(chain.migrated_graph.constructor.requirements.is_empty() and chain.migrated_graph.constructor.blocks.is_empty() and chain.migrated_graph.constructor.dependencies.is_empty(), "Chain creates empty constructor without reinterpretation")
	_check(_snapshot(schema_2) == schema_2_before, "Chain leaves original schema 2 intact")
	_check(FlowGraphMigrator.migrate_schema_2_to_4(source).migrated_graph == null, "Chain rejects schema 3 source")


func _test_duplication() -> void:
	var source: FlowGraph = _rich_graph()
	var before: Variant = _snapshot(source)
	var copy: FlowGraph = source.duplicate_with_new_ids()
	if not _check(copy != null and copy.constructor != null, "Duplicated graph and constructor exist"):
		return
	_check(copy.schema_version == 4, "Duplicated schema remains 4")
	_check_copy(source, copy, true)
	_check(not FlowGraphValidator.validate(copy).has_errors(), "All duplicated identities remain globally unique")
	if not _check(copy.constructor.requirements.size() == 4 and copy.constructor.blocks.size() == 4 and copy.methods.size() == 2 and copy.processes.size() == 3 and copy.variables.size() == 2 and copy.state_machines.size() == 2, "Duplicated collection shapes"):
		return
	if not _check(copy.constructor.requirements[1] != null and copy.methods[1] != null and copy.processes[0] != null and copy.variables[1] != null and copy.state_machines[0] != null, "Duplicated nested resources exist"):
		return
	var call: FlowMethodCallBlock = copy.constructor.blocks[2] as FlowMethodCallBlock
	if _check(call != null, "Legacy call concrete subtype survives duplication"):
		_check(call.method_id == copy.methods[1].get_internal_id(), "Legacy call reference remaps after method IDs are known")
	_check(copy.variables[1].owner_container_id == copy.processes[0].get_internal_id(), "Variable owner still remaps")
	if _check(copy.state_machines[0].states.size() == 2 and copy.state_machines[0].states[1] != null, "Duplicated state exists"):
		_check(copy.state_machines[0].initial_state_id == copy.state_machines[0].states[1].get_internal_id(), "Initial state reference still remaps")
	copy.constructor.requirements[1].display_name = "Changed clone"
	copy.constructor.requirements[1].required_properties.append(null)
	copy.constructor.requirements.remove_at(0)
	_check(_snapshot(source) == before, "Requirement metadata and both arrays are independent")
	var isolated: FlowConstructorDefinition = source.constructor.duplicate_with_new_ids()
	_check_copy(source.constructor.requirements, isolated.requirements, true, "isolated.requirements")
	_check(_snapshot(source) == before, "Isolated constructor duplication preserves original")


func _test_bindings() -> void:
	var graph: FlowGraph = _graph()
	var requirement: FlowRequiredNodeDefinition = _requirement()
	graph.constructor.requirements = [requirement]
	var requirement_id: String = requirement.get_internal_id()
	var first: PVController = PVController.new()
	var second: PVController = PVController.new()
	first.flow_graph = graph
	second.flow_graph = graph
	var bindings: Dictionary[String, NodePath] = {requirement_id: NodePath("Marker")}
	first.requirement_bindings = bindings
	second.requirement_bindings = bindings
	first.requirement_bindings[requirement_id] = NodePath("FirstOnly")
	_check(second.requirement_bindings[requirement_id] == NodePath("Marker") and bindings[requirement_id] == NodePath("Marker"), "Assignment isolates maps even when controllers share a graph and input dictionary")
	_check(first.flow_graph == second.flow_graph, "Definition graph remains shared")
	_check(not FlowGraphValidator.validate_requirement_bindings(graph, second.requirement_bindings).has_errors(), "Binding structure valid without scene resolution")
	var before: Dictionary[String, NodePath] = first.requirement_bindings.duplicate()
	var copy: FlowGraph = graph.duplicate_with_new_ids()
	_check(copy.get("requirement_bindings") == null, "Graph does not own or duplicate scene bindings")
	_check(first.requirement_bindings == before, "Graph duplication never remaps controller bindings")
	for locator: NodePath in [NodePath(""), NodePath("/root/Marker"), NodePath("../Marker"), NodePath("Nested/Marker"), NodePath("Marker:property"), NodePath(".")]:
		var invalid: Dictionary[String, NodePath] = {requirement_id: locator}
		var a: FlowValidationResult = FlowGraphValidator.validate_requirement_bindings(graph, invalid)
		var b: FlowValidationResult = FlowGraphValidator.validate_requirement_bindings(graph, invalid)
		_check(_sequence(a) == [[&"required_node_binding_invalid", 'requirement_bindings["%s"]' % requirement_id, requirement_id]], "Exact invalid locator diagnostic: " + String(locator))
		_check(_sequence(a) == _sequence(b) and invalid[requirement_id] == locator, "Binding diagnostics deterministic and literal locator preserved")
	var absent: String = FlowId.create()
	var unknown: Dictionary[String, NodePath] = {absent: NodePath("Marker"), "": NodePath("Marker")}
	var result: FlowValidationResult = FlowGraphValidator.validate_requirement_bindings(graph, unknown)
	_check(_sequence(result) == [[&"required_node_binding_invalid", 'requirement_bindings[""]', ""], [&"required_node_binding_invalid", 'requirement_bindings["%s"]' % absent, absent]], "Unknown and empty binding IDs diagnosed in sorted key order")
	_check(unknown.size() == 2 and unknown[absent] == NodePath("Marker"), "Unknown references preserved")
	_check(FlowGraphValidator.validate_requirement_bindings(_graph(3), bindings).has_errors(), "Bindings do not grant schema 3 compatibility")
	first.free()
	second.free()


func _prepare_paths() -> bool:
	for path: String in [GRAPH_PATH, SCENE_PATH, BLOCK_PATH]:
		if not _check(not FileAccess.file_exists(path), "Refuse to overwrite an existing artifact: " + path):
			return false
	return _check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/flujo_tests")) == OK, "Create test artifact directory")


func _save(resource: Resource, path: String) -> bool:
	_owned_paths.append(path)
	return _check(ResourceSaver.save(resource, path) == OK, "Save " + path)


func _test_persistence() -> void:
	var graph: FlowGraph = _rich_graph()
	if not _save(graph, GRAPH_PATH):
		return
	var loaded: FlowGraph = ResourceLoader.load(GRAPH_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as FlowGraph
	if not _check(loaded != null, "Load independent ResourceSaver graph"):
		return
	_check(loaded.schema_version == 4, "ResourceSaver retains schema 4")
	_check_copy(graph, loaded, false)
	_check(_snapshot(graph) == _snapshot(loaded), "ResourceSaver preserves every stored field")
	var legacy: FlowGraph = _rich_graph(3)
	if not _save(legacy.constructor.blocks[1], BLOCK_PATH):
		return
	var external: FlowPrintBlock = ResourceLoader.load(BLOCK_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as FlowPrintBlock
	if not _check(external != null, "Load externally stored legacy block"):
		return
	legacy.constructor.blocks[1] = external
	var migrated: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_3_to_4(legacy, true)
	if not _check(migrated.is_successful(), "Migration accepts external legacy resources"):
		return
	_check_copy(legacy, migrated.migrated_graph, false, "external_migration")
	var root: Node = Node.new()
	root.name = &"Schema4Bindings"
	var first: PVController = PVController.new()
	first.name = &"First"
	var second: PVController = PVController.new()
	second.name = &"Second"
	root.add_child(first)
	root.add_child(second)
	first.owner = root
	second.owner = root
	first.flow_graph = graph
	second.flow_graph = graph
	var requirement_id: String = graph.constructor.requirements[1].get_internal_id()
	first.requirement_bindings = {requirement_id: NodePath("FirstMarker")}
	second.requirement_bindings = {requirement_id: NodePath("SecondMarker")}
	var packed: PackedScene = PackedScene.new()
	var packed_ok: bool = _check(packed.pack(root) == OK, "Pack two controllers sharing one graph")
	root.free()
	if not packed_ok or not _save(packed, SCENE_PATH):
		return
	var scene: PackedScene = ResourceLoader.load(SCENE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if not _check(scene != null and scene != packed, "Reload PackedScene without resource cache"):
		return
	var instance_a: Node = scene.instantiate()
	var instance_b: Node = scene.instantiate()
	if not _check(instance_a != null and instance_b != null, "Instantiate both scenes"):
		if instance_a != null:
			instance_a.free()
		if instance_b != null:
			instance_b.free()
		return
	_check_scene_bindings(instance_a, instance_b, graph, requirement_id)
	instance_a.free()
	instance_b.free()


func _check_scene_bindings(a: Node, b: Node, original: FlowGraph, requirement_id: String) -> void:
	var first_a: PVController = a.get_node_or_null("First") as PVController
	var second_a: PVController = a.get_node_or_null("Second") as PVController
	var first_b: PVController = b.get_node_or_null("First") as PVController
	var second_b: PVController = b.get_node_or_null("Second") as PVController
	if not _check(first_a != null and second_a != null and first_b != null and second_b != null, "All four persisted controllers exist"):
		return
	if not _check(first_a.flow_graph != null, "Persisted graph exists"):
		return
	_check(first_a.flow_graph == second_a.flow_graph and first_a.flow_graph == first_b.flow_graph and first_b.flow_graph == second_b.flow_graph, "PackedScene keeps shared immutable definitions")
	_check(first_a.flow_graph != original, "PackedScene load is not satisfied by original cached graph")
	_check_copy(original, first_a.flow_graph, false, "scene.graph")
	_check(_snapshot(original) == _snapshot(first_a.flow_graph), "PackedScene retains every requirement and legacy field")
	for controller: PVController in [first_a, second_a, first_b, second_b]:
		if not _check(controller.requirement_bindings.has(requirement_id), "Persisted binding keeps original requirement ID"):
			return
	_check(first_a.requirement_bindings[requirement_id] == NodePath("FirstMarker") and second_a.requirement_bindings[requirement_id] == NodePath("SecondMarker"), "Per-controller locators survive save/load")
	first_a.requirement_bindings[requirement_id] = NodePath("ChangedAfterInstantiation")
	_check(first_b.requirement_bindings[requirement_id] == NodePath("FirstMarker") and second_a.requirement_bindings[requirement_id] == NodePath("SecondMarker") and second_b.requirement_bindings[requirement_id] == NodePath("SecondMarker"), "Changing one binding cannot mutate another controller or PackedScene instance")
	_check(a.get_child_count() == 2 and b.get_child_count() == 2 and first_a.get_child_count(true) == 0, "Persistence adds no components or internal runtime nodes")
	_check(not first_a.is_inside_tree() and not first_b.is_inside_tree(), "Fixture never executes controller lifecycle")


func _cleanup() -> void:
	for path: String in _owned_paths:
		if FileAccess.file_exists(path):
			_check(DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK, "Remove owned artifact " + path)
		_check(not FileAccess.file_exists(path), "Owned artifact absent " + path)
