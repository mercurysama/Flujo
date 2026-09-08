@tool
class_name FlowConstructorDefinition
extends FlowBlockContainer

@export var dependencies: Array[FlowDependencyDefinition] = []

func duplicate_with_new_ids() -> FlowConstructorDefinition:
	var copy: FlowConstructorDefinition = duplicate(false) as FlowConstructorDefinition
	copy._internal_id = FlowId.create()
	copy.blocks = []
	for block: FlowBlock in blocks:
		copy.blocks.append(null if block == null else block.duplicate_with_new_id())
	copy.dependencies = []
	for dependency: FlowDependencyDefinition in dependencies:
		copy.dependencies.append(null if dependency == null else dependency.duplicate_with_new_id())
	return copy
