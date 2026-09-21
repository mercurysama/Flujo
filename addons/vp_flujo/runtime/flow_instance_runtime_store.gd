class_name FlowInstanceRuntimeStore
extends FlowAttributeRuntimeStore

func initialize(graph: FlowGraph, catalog: FlowClassCatalog = null) -> FlowStoreResult:
	return initialize_layout(FlowRuntimeAttributeLayout.resolve(graph, catalog))

func initialize_layout(layout: FlowRuntimeAttributeLayout) -> FlowStoreResult:
	if _initialized or _closed:
		return FlowStoreResult.make(&"store_already_initialized", _class_id)
	if layout == null:
		return FlowStoreResult.make(&"store_definition_invalid")
	var result: FlowStoreResult = layout.operation_result()
	if not result.ok:
		return result
	_initialize_slots(layout.class_id, layout.instance_slots, layout.parents)
	return result
