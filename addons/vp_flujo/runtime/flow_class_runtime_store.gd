class_name FlowClassRuntimeStore
extends FlowAttributeRuntimeStore

## Registry data belongs to the supplied SceneTree, never to a static script field.
const TREE_REGISTRY: StringName = &"_flujo_class_runtime_stores"

static func acquire(tree: SceneTree, graph: FlowGraph, catalog: FlowClassCatalog = null) -> FlowStoreResult:
	return acquire_layout(tree, FlowRuntimeAttributeLayout.resolve(graph, catalog))

static func acquire_layout(tree: SceneTree, layout: FlowRuntimeAttributeLayout) -> FlowStoreResult:
	if not is_instance_valid(tree) or not is_instance_valid(tree.root) or not tree.root.is_inside_tree():
		return FlowStoreResult.make(&"store_tree_unavailable")
	if Engine.is_editor_hint():
		return FlowStoreResult.make(&"store_editor_context")
	if layout == null:
		return FlowStoreResult.make(&"store_definition_invalid")
	var result: FlowStoreResult = layout.operation_result()
	if not result.ok:
		return result
	var registry_value: Variant = tree.get_meta(TREE_REGISTRY, {})
	if not registry_value is Dictionary:
		return FlowStoreResult.make(&"store_registry_invalid", layout.class_id)
	var registry: Dictionary = registry_value
	var pending: Dictionary[String, FlowClassRuntimeStore] = {}
	var effective: Dictionary[String, Dictionary] = {}
	# Complete preflight before touching registry entries, values, signals or access contexts.
	for owner_id: String in layout.class_order:
		var declared: Dictionary = layout.class_slots[owner_id]
		for attribute_id: String in declared:
			effective[attribute_id] = declared[attribute_id]
		if registry.has(owner_id):
			if not registry[owner_id] is FlowClassRuntimeStore:
				return FlowStoreResult.make(&"store_registry_invalid", owner_id)
			var existing: FlowClassRuntimeStore = registry[owner_id] as FlowClassRuntimeStore
			if existing._closed:
				return FlowStoreResult.make(&"store_registry_invalid", owner_id)
			if existing._slots != effective:
				return FlowStoreResult.make(&"store_definition_conflict", owner_id)
			for known_id: String in layout.parents:
				if existing._parents.has(known_id) and existing._parents[known_id] != layout.parents[known_id]:
					return FlowStoreResult.make(&"store_definition_conflict", known_id)
			pending[owner_id] = existing
		else:
			var candidate: FlowClassRuntimeStore = FlowClassRuntimeStore.new()
			candidate._initialize_slots(owner_id, effective, layout.parents)
			# Inherited CLASS slots route to their original storage; no duplicate values.
			for attribute_id: String in effective:
				var declaring_id: String = effective[attribute_id].declaring_class_id
				if declaring_id != owner_id:
					candidate._owners[attribute_id] = pending[declaring_id]
					candidate._values.erase(attribute_id)
			pending[owner_id] = candidate
	for owner_id: String in layout.class_order:
		var store: FlowClassRuntimeStore = pending[owner_id]
		store._parents.merge(layout.parents)
		if not registry.has(owner_id):
			registry[owner_id] = store
			# The root survives scene changes; teardown closes retained handles too.
			tree.root.tree_exiting.connect(store.close, CONNECT_ONE_SHOT)
	tree.set_meta(TREE_REGISTRY, registry)
	result.store = pending[layout.class_id]
	return result
