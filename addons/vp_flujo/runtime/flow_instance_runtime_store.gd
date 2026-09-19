class_name FlowInstanceRuntimeStore
extends FlowAttributeRuntimeStore

func initialize(graph: FlowGraph) -> FlowStoreResult:
	return _initialize(graph, FlowAttributeDefinition.Storage.INSTANCE)
