class_name FlowClassRuntimeStore
extends FlowAttributeRuntimeStore

## Registry data belongs to the supplied SceneTree, never to a static script field.
const TREE_REGISTRY: StringName = &"_flujo_class_runtime_stores"

static func acquire(tree: SceneTree, graph: FlowGraph) -> FlowStoreResult:
	if not is_instance_valid(tree) or not is_instance_valid(tree.root) or not tree.root.is_inside_tree():
		return FlowStoreResult.make(&"store_tree_unavailable")
	if Engine.is_editor_hint():
		return FlowStoreResult.make(&"store_editor_context")
	var candidate: FlowClassRuntimeStore = FlowClassRuntimeStore.new()
	var result: FlowStoreResult = candidate._initialize(graph, FlowAttributeDefinition.Storage.CLASS)
	if not result.ok:
		return result
	var registry_value: Variant = tree.get_meta(TREE_REGISTRY, {})
	if not registry_value is Dictionary:
		return FlowStoreResult.make(&"store_registry_invalid", candidate._class_id)
	var registry: Dictionary = registry_value
	if registry.has(candidate._class_id):
		if not registry[candidate._class_id] is FlowClassRuntimeStore:
			return FlowStoreResult.make(&"store_registry_invalid", candidate._class_id)
		var existing: FlowClassRuntimeStore = registry[candidate._class_id] as FlowClassRuntimeStore
		if existing == null or existing._closed:
			return FlowStoreResult.make(&"store_registry_invalid", candidate._class_id)
		if existing._slots != candidate._slots:
			return FlowStoreResult.make(&"store_definition_conflict", candidate._class_id)
		result.store = existing
		return result
	registry[candidate._class_id] = candidate
	tree.set_meta(TREE_REGISTRY, registry)
	# The root survives scene changes; its exit invalidates every retained store handle.
	tree.root.tree_exiting.connect(candidate.close, CONNECT_ONE_SHOT)
	result.store = candidate
	return result
