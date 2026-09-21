extends SceneTree

## FOBJ-001/002/003/005/009: public runtime APIs and a real portable catalog.
## Added for the validation handoff; do not treat parse-only checking as test execution.
const TEMP_DIR: String = "res://.godot/flujo_tests/inherited_attribute_stores"
var _failures: Array[String] = []
var _paths: Array[String] = []
var _uids: Array[int] = []
var _checks: int = 0

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	if not _check(not DirAccess.dir_exists_absolute(TEMP_DIR), "Do not overwrite existing focal artifacts"):
		_finish()
		return
	if not _check(DirAccess.make_dir_recursive_absolute(TEMP_DIR) == OK, "Create isolated focal directory"):
		_finish()
		return
	_test_visibility_matrix()
	await _test_three_levels()
	_test_rejections()
	_cleanup()
	_finish()

func _test_visibility_matrix() -> void:
	for inherited_visibility: int in FlowAttributeDefinition.Visibility.values():
		for own_visibility: int in FlowAttributeDefinition.Visibility.values():
			var base: FlowGraph = _graph()
			var derived: FlowGraph = _graph(base.get_internal_id())
			var first: FlowAttributeDefinition = _attribute(base, "Same", inherited_visibility)
			var second: FlowAttributeDefinition = _attribute(derived, "Same", own_visibility)
			var catalog: FlowClassCatalog = _catalog([base, derived])
			if catalog == null:
				return
			var before: Variant = _snapshot(derived)
			var layout: FlowRuntimeAttributeLayout = FlowRuntimeAttributeLayout.resolve(derived, catalog)
			var allowed: bool = inherited_visibility == FlowAttributeDefinition.Visibility.PRIVATE \
				or own_visibility == FlowAttributeDefinition.Visibility.PRIVATE
			var context: String = "Visibility pair %d→%d" % [inherited_visibility, own_visibility]
			_check(layout.has_errors() != allowed, context + " obeys symmetric PRIVATE exception")
			_check(_snapshot(derived) == before, context + " preserves definitions")
			if allowed:
				var store: FlowInstanceRuntimeStore = FlowInstanceRuntimeStore.new()
				if not _check(store.initialize_layout(layout).ok, context + " initializes independent ID slots"):
					return
				_check(store.read(first.get_internal_id(), base.get_internal_id()).ok, context + " keeps base slot accessible to its declarer")
				_check(store.read(second.get_internal_id(), derived.get_internal_id()).ok, context + " keeps derived slot accessible to its declarer")
				store.close()
			else:
				_check(_has(layout, &"inherited_attribute_conflict", second.get_internal_id()), context + " reports nonprivate conflict")
				_check(_sequence(layout).has("inherited_attribute_conflict|entries[1].graph.constructor.attributes[0]|%s|%d" % [second.get_internal_id(), FlowDiagnostic.Severity.ERROR]), context + " exact conflict code/path/ID/severity")
				_check(_sequence(layout) == _sequence(FlowRuntimeAttributeLayout.resolve(derived, catalog)), context + " deterministic diagnostics")

func _test_three_levels() -> void:
	var base: FlowGraph = _graph()
	var middle: FlowGraph = _graph(base.get_internal_id())
	var leaf: FlowGraph = _graph(middle.get_internal_id())
	var outsider: FlowGraph = _graph()
	var public_slot: FlowAttributeDefinition = _attribute(base, "Public", FlowAttributeDefinition.Visibility.PUBLIC)
	var protected_slot: FlowAttributeDefinition = _attribute(base, "Protected", FlowAttributeDefinition.Visibility.PROTECTED)
	var private_slot: FlowAttributeDefinition = _attribute(base, "Private", FlowAttributeDefinition.Visibility.PRIVATE)
	var middle_slot: FlowAttributeDefinition = _attribute(middle, "Middle", FlowAttributeDefinition.Visibility.PROTECTED)
	var leaf_slot: FlowAttributeDefinition = _attribute(leaf, "Leaf", FlowAttributeDefinition.Visibility.PRIVATE)
	var shared: FlowAttributeDefinition = _attribute(base, "Shared", FlowAttributeDefinition.Visibility.PROTECTED, true)
	var shared_private: FlowAttributeDefinition = _attribute(base, "SharedPrivate", FlowAttributeDefinition.Visibility.PRIVATE, true)
	var shadow: FlowAttributeDefinition = _attribute(leaf, "Shared", FlowAttributeDefinition.Visibility.PRIVATE, true)
	var readonly_slot: FlowAttributeDefinition = _attribute(base, "Readonly", FlowAttributeDefinition.Visibility.PUBLIC)
	readonly_slot.mutability = FlowAttributeDefinition.Mutability.READONLY
	var const_slot: FlowAttributeDefinition = _attribute(base, "Const", FlowAttributeDefinition.Visibility.PUBLIC)
	const_slot.mutability = FlowAttributeDefinition.Mutability.CONST
	var nullable_slot: FlowAttributeDefinition = _attribute(base, "Nullable", FlowAttributeDefinition.Visibility.PUBLIC)
	nullable_slot.nullable = true
	nullable_slot.default_is_null = true
	base.constructor.attributes.insert(1, null)
	var catalog: FlowClassCatalog = _catalog([leaf, outsider, base, middle])
	if catalog == null:
		return
	var before: Variant = _snapshot(base)
	var layout: FlowRuntimeAttributeLayout = FlowRuntimeAttributeLayout.resolve(leaf, catalog)
	if not _check(not layout.has_errors(), "Three-level catalog resolves without errors"):
		return
	_check(layout.class_order == [base.get_internal_id(), middle.get_internal_id(), leaf.get_internal_id()], "Effective order is base→derived, not catalog order")
	_check(layout.instance_slots.keys() == [public_slot.get_internal_id(), protected_slot.get_internal_id(), private_slot.get_internal_id(), readonly_slot.get_internal_id(), const_slot.get_internal_id(), nullable_slot.get_internal_id(), middle_slot.get_internal_id(), leaf_slot.get_internal_id()], "Ordered instance slots skip structural nulls, not base-private declarations")
	if not _check(layout.instance_slots.has(private_slot.get_internal_id()), "Expected base-private metadata exists"):
		return
	_check(layout.instance_slots[private_slot.get_internal_id()].declaring_class_id == base.get_internal_id(), "Base-private slot retains declaring class ID")
	_check(not _has_resource_or_node(layout.instance_slots) and not _has_resource_or_node(layout.class_slots) and not _has_resource_or_node(layout.parents), "Layout retains only detached values and IDs")

	var first: PVController = PVController.new()
	var second: PVController = PVController.new()
	var parent_controller: PVController = PVController.new()
	first.flow_graph = leaf
	second.flow_graph = leaf
	parent_controller.flow_graph = base
	var controllers: Array[PVController] = [first, second, parent_controller]
	for controller: PVController in controllers:
		if not _check(controller.prepare_attribute_stores(catalog).ok, "Prepare catalog before controller tree entry"):
			for owned: PVController in controllers:
				owned.free()
			return
	var scene: Node = Node.new()
	for controller: PVController in controllers:
		scene.add_child(controller)
	get_root().add_child(scene)
	await process_frame
	var ready: bool = true
	for controller: PVController in controllers:
		if not _check(controller.runtime_store_result != null, "Controller records initialization result"):
			ready = false
		elif not _check(controller.runtime_store_result.ok and controller.instance_runtime_store != null and controller.class_runtime_store != null, "Controller initializes inherited stores"):
			ready = false
	if not ready:
		scene.queue_free()
		await process_frame
		return
	var instance_store: FlowInstanceRuntimeStore = first.instance_runtime_store
	var shared_store: FlowClassRuntimeStore = first.class_runtime_store
	var base_id: String = base.get_internal_id()
	var leaf_id: String = leaf.get_internal_id()
	var outside_id: String = outsider.get_internal_id()
	_check(instance_store.read(public_slot.get_internal_id(), outside_id).ok, "PUBLIC accepts unrelated requester")
	_check(instance_store.read(protected_slot.get_internal_id(), leaf_id).ok, "PROTECTED accepts descendant through two edges")
	_check(instance_store.read(protected_slot.get_internal_id(), outside_id).code == &"attribute_inaccessible", "PROTECTED rejects unrelated requester")
	_check(instance_store.read(private_slot.get_internal_id(), leaf_id).code == &"attribute_inaccessible", "Base PRIVATE is not inherited access")
	_check(instance_store.read(private_slot.get_internal_id(), base_id).ok, "Base requester reads its PRIVATE storage in the derived instance")
	_check(instance_store.read(middle_slot.get_internal_id(), base_id).code == &"attribute_inaccessible", "Ancestor cannot read descendant PROTECTED")
	_check(instance_store.read(leaf_slot.get_internal_id(), base_id).code == &"attribute_inaccessible", "Ancestor cannot read descendant PRIVATE")
	_check(instance_store.read(public_slot.get_internal_id(), "malformed").code == &"attribute_requester_invalid", "Malformed requester is rejected")
	_check(instance_store.write(public_slot.get_internal_id(), 42, leaf_id).ok, "Inherited INSTANCE write succeeds")
	_check(second.instance_runtime_store.read(public_slot.get_internal_id()).value == 7, "Sibling controller retains independent INSTANCE value")
	_check(parent_controller.instance_runtime_store.read(public_slot.get_internal_id()).value == 7, "Base controller retains independent INSTANCE value")
	_check(instance_store.write(public_slot.get_internal_id(), 1.0, leaf_id).code == &"attribute_type_incompatible", "Inherited exact type rule remains")
	_check(instance_store.write(public_slot.get_internal_id(), null, leaf_id).code == &"attribute_null_not_allowed", "Inherited nonnull rule remains")
	_check(instance_store.read(public_slot.get_internal_id()).value == 42, "Rejected writes preserve previous value")
	_check(instance_store.reset(public_slot.get_internal_id()).value == 7, "Inherited reset restores detached default")
	_check(instance_store.write(nullable_slot.get_internal_id(), null).ok, "Inherited nullable write accepts null")
	_check(instance_store.reset(nullable_slot.get_internal_id()).value == null, "Inherited nullable reset preserves null default")
	_check(instance_store.write(readonly_slot.get_internal_id(), 9, base_id).code == &"attribute_readonly", "Declaring requester cannot bypass READONLY")
	_check(instance_store.reset(const_slot.get_internal_id(), base_id).code == &"attribute_const", "Declaring requester cannot bypass CONST")
	_check(instance_store.read(FlowId.create()).code == &"attribute_missing", "Unknown attribute ID remains deterministic")
	_check(instance_store.write(private_slot.get_internal_id(), 55, leaf_id).code == &"attribute_inaccessible", "Inaccessible write rejected")
	_check(instance_store.reset(private_slot.get_internal_id(), leaf_id).code == &"attribute_inaccessible", "Inaccessible reset rejected")
	_check(instance_store.read(private_slot.get_internal_id(), base_id).value == 7, "Access rejection does not mutate base-private value")

	_check(shared_store.write(shared.get_internal_id(), 81, leaf_id).ok, "Derived CLASS write routes to base declarer")
	_check(parent_controller.class_runtime_store.read(shared.get_internal_id()).value == 81, "Base controller sees inherited CLASS write")
	_check(second.class_runtime_store.read(shared.get_internal_id()).value == 81, "Other derived controller shares declaring slot")
	_check(shared_store.write(shadow.get_internal_id(), 26).ok, "Homonymous private CLASS slot remains independent")
	_check(parent_controller.class_runtime_store.read(shared.get_internal_id()).value == 81, "Shadow write does not alias base value")
	_check(shared_store.reset(shared.get_internal_id(), outside_id).code == &"attribute_inaccessible", "CLASS reset enforces requester context")
	_check(shared_store.read(shared.get_internal_id()).value == 81, "Rejected CLASS reset preserves state")
	_check(shared_store.reset(shared.get_internal_id(), leaf_id).value == 7, "CLASS reset reaches declaring store")
	_check(shared_store.read(shadow.get_internal_id()).value == 26, "CLASS reset does not reset homonym")
	_check(shared_store.read(shared_private.get_internal_id()).code == &"attribute_inaccessible", "Omitted requester never impersonates base class")
	_check(shared_store.read(shared_private.get_internal_id(), base_id).ok, "Base requester can access inherited CLASS-private slot")
	_check(_snapshot(base) == before, "Runtime operations never mutate persistent base")
	_check(not _has_resource_or_node(instance_store.get("_slots")) and not _has_resource_or_node(shared_store.get("_values")), "Stores do not retain Node or Resource values")
	shared_store.write(shared.get_internal_id(), 91)
	scene.queue_free()
	await process_frame
	await process_frame
	_check(instance_store.read(public_slot.get_internal_id()).code == &"store_closed", "Controller exit closes inherited INSTANCE store")
	_check(shared_store.read(shared.get_internal_id()).value == 91, "Inherited CLASS state survives absence of controllers")
	var reacquired: FlowStoreResult = FlowClassRuntimeStore.acquire(self, leaf, catalog)
	_check(reacquired.ok and reacquired.store == shared_store, "Reacquisition preserves derived handle and declaring values")
	var conflict: FlowGraph = leaf.duplicate(true) as FlowGraph
	if _check(conflict != null, "Conflict graph duplicated"):
		if not _check(conflict.class_attributes.size() == 1, "Conflict fixture retains exactly one CLASS attribute"):
			return
		if not _check(conflict.class_attributes[0] != null, "Conflict CLASS attribute exists"):
			return
		conflict.class_attributes[0].int_value = 900
		var rejected: FlowStoreResult = FlowClassRuntimeStore.acquire(self, conflict, catalog)
		_check(rejected.code == &"store_definition_conflict", "Conflicting CLASS snapshot rejects atomically")
		_check(shared_store.read(shared.get_internal_id()).value == 91 and shared_store.read(shadow.get_internal_id()).value == 26, "Rejected acquisition preserves every existing class value")

func _test_rejections() -> void:
	var base: FlowGraph = _graph()
	var leaf: FlowGraph = _graph(base.get_internal_id())
	var first: FlowAttributeDefinition = _attribute(base, "First", FlowAttributeDefinition.Visibility.PRIVATE)
	var second: FlowAttributeDefinition = _attribute(leaf, "Second", FlowAttributeDefinition.Visibility.PRIVATE)
	second._internal_id = first.get_internal_id()
	var catalog: FlowClassCatalog = _catalog([base, leaf])
	if catalog == null:
		return
	var before: Variant = _snapshot(leaf)
	var collision: FlowRuntimeAttributeLayout = FlowRuntimeAttributeLayout.resolve(leaf, catalog)
	_check(_has(collision, FlowDiagnostic.CODE_DUPLICATE_INTERNAL_ID, first.get_internal_id()), "Duplicate ID across classes rejects even private slots")
	_check(_sequence(collision).has('duplicate_internal_id|classes["%s"].constructor.attributes[0]|%s|%d' % [leaf.get_internal_id(), first.get_internal_id(), FlowDiagnostic.Severity.ERROR]), "Duplicate has exact declaring path, code and stable related ID")
	_check(collision.instance_slots.is_empty() and collision.class_slots.is_empty(), "Invalid hierarchy publishes no partial layout")
	_check(_sequence(collision) == _sequence(FlowRuntimeAttributeLayout.resolve(leaf, catalog)), "Duplicate diagnostics repeat exactly")
	_check(_snapshot(leaf) == before, "Collision rejection preserves original ID")
	var missing: FlowGraph = _graph(FlowId.create())
	var empty: FlowClassCatalog = FlowClassCatalog.new()
	_check(_has(FlowRuntimeAttributeLayout.resolve(missing, empty), &"class_base_missing", missing.base_class_id), "Missing base separate from cycle/depth")
	_check(_has(FlowRuntimeAttributeLayout.resolve(missing), &"store_inheritance_unresolved", missing.base_class_id), "No catalog does not silently omit base")
	var cycle_a: FlowGraph = _graph()
	var cycle_b: FlowGraph = _graph(cycle_a.get_internal_id())
	cycle_a.base_class_id = cycle_b.get_internal_id()
	var cycle_catalog: FlowClassCatalog = _catalog([cycle_a, cycle_b])
	if cycle_catalog == null:
		return
	_check(_has(FlowRuntimeAttributeLayout.resolve(cycle_a, cycle_catalog), &"class_inheritance_cycle"), "A→B→A cycle rejected through catalog")
	var chain: Array[FlowGraph] = [_graph()]
	for depth: int in range(1, 12):
		chain.append(_graph(chain.back().get_internal_id()))
		if depth == 10 or depth == 11:
			var chain_catalog: FlowClassCatalog = _catalog(chain)
			if chain_catalog == null:
				return
			var layout: FlowRuntimeAttributeLayout = FlowRuntimeAttributeLayout.resolve(chain.back(), chain_catalog)
			_check(not layout.has_errors() if depth == 10 else _has(layout, &"class_inheritance_depth"), "Ten edges accepted, eleven rejected: %d" % depth)
	var locator_graph: FlowGraph = _graph()
	var other: FlowGraph = _graph()
	var locators: FlowClassCatalog = _catalog([locator_graph, other])
	if locators == null:
		return
	if not _check(locators.entries.size() == 2, "Locator fixture has two entries"):
		return
	if not _check(locators.entries[0] != null and locators.entries[1] != null, "Locator entries exist"):
		return
	var original_path: String = locators.entries[0].graph_path
	locators.entries[0].graph_path = locators.entries[1].graph_path
	_check(_has(FlowRuntimeAttributeLayout.resolve(locator_graph, locators), &"class_catalog_locator_conflict"), "UID/path conflict is not silently repaired")
	locators.entries[0].graph_path = original_path
	locators.entries[0].graph_uid = ResourceUID.id_to_text(ResourceUID.create_id())
	var stale: FlowRuntimeAttributeLayout = FlowRuntimeAttributeLayout.resolve(locator_graph, locators)
	_check(not stale.has_errors() and _has(stale, &"class_catalog_locator_stale"), "Path fallback preserves deterministic warning")
	for schema: int in [FlowGraph.CURRENT_SCHEMA_VERSION, FlowGraph.SCHEMA_VERSION_2, FlowGraph.SCHEMA_VERSION_3, FlowGraph.SCHEMA_VERSION_4]:
		var old: FlowGraph = _graph()
		old.schema_version = schema
		_check(FlowRuntimeAttributeLayout.resolve(old).operation_result().code == &"store_schema_unsupported", "Resolver does not reinterpret schema %d" % schema)

func _graph(base_id: String = "") -> FlowGraph:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_5
	graph.constructor = FlowConstructorDefinition.new()
	graph.base_class_id = base_id
	return graph

func _attribute(graph: FlowGraph, visible_name: String, visibility: FlowAttributeDefinition.Visibility,
		class_storage: bool = false) -> FlowAttributeDefinition:
	var attribute: FlowAttributeDefinition = FlowAttributeDefinition.new()
	attribute.display_name = visible_name
	attribute.visibility = visibility
	attribute.value_type = FlowVariableDefinition.ValueType.INT
	attribute.int_value = 7
	attribute.storage = FlowAttributeDefinition.Storage.CLASS if class_storage else FlowAttributeDefinition.Storage.INSTANCE
	if class_storage:
		graph.class_attributes.append(attribute)
	else:
		graph.constructor.attributes.append(attribute)
	return attribute

func _catalog(graphs: Array[FlowGraph]) -> FlowClassCatalog:
	var catalog: FlowClassCatalog = FlowClassCatalog.new()
	for graph: FlowGraph in graphs:
		var path: String = TEMP_DIR.path_join("class_%d.tres" % _paths.size())
		_paths.append(path)
		if not _check(ResourceSaver.save(graph, path) == OK, "Save catalog fixture " + path):
			return null
		var uid: int = ResourceUID.create_id()
		ResourceUID.add_id(uid, path)
		_uids.append(uid)
		var entry: FlowClassCatalogEntry = FlowClassCatalogEntry.new()
		entry.class_id = graph.get_internal_id()
		entry.graph_uid = ResourceUID.id_to_text(uid)
		entry.graph_path = path
		catalog.entries.append(entry)
	return catalog

func _has(result: FlowValidationResult, code: StringName, related_id: String = "") -> bool:
	for diagnostic: FlowDiagnostic in result.diagnostics:
		if diagnostic.code == code and (related_id.is_empty() or diagnostic.related_id == related_id):
			return true
	return false

func _sequence(result: FlowValidationResult) -> Array[String]:
	var sequence: Array[String] = []
	for diagnostic: FlowDiagnostic in result.diagnostics:
		sequence.append("%s|%s|%s|%d" % [diagnostic.code, diagnostic.element_path, diagnostic.related_id, diagnostic.severity])
	return sequence

func _snapshot(value: Variant) -> Variant:
	if value is Resource:
		var fields: Dictionary = {}
		for property: Dictionary in value.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_STORAGE and property.name != &"script":
				fields[property.name] = _snapshot(value.get(property.name))
		return fields
	if value is Array:
		var items: Array = []
		for item: Variant in value:
			items.append(_snapshot(item))
		return items
	return value

func _has_resource_or_node(value: Variant) -> bool:
	if value is Resource or value is Node or value is Callable:
		return true
	if value is Dictionary:
		for key: Variant in value:
			if _has_resource_or_node(value[key]):
				return true
	return false

func _cleanup() -> void:
	for uid: int in _uids:
		ResourceUID.remove_id(uid)
	for path: String in _paths:
		if FileAccess.file_exists(path):
			_check(DirAccess.remove_absolute(path) == OK, "Remove owned catalog fixture " + path)
	_check(DirAccess.remove_absolute(TEMP_DIR) == OK, "Remove owned empty temporary directory")

func _check(condition: bool, context: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(context)
		push_error("[Flujo][InheritedAttributes] " + context)
	return condition

func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Inherited attribute stores focal passed (%d checks)" % _checks)
	quit(0 if _failures.is_empty() else 1)
