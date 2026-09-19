@tool
class_name FlowConstructorDefinition
extends FlowBlockContainer

@export var dependencies: Array[FlowDependencyDefinition] = []
## Active only in schema 4; blocks and dependencies remain inert legacy data there.
@export_storage var requirements: Array[FlowRequiredNodeDefinition] = []
@export_storage var attributes: Array[FlowAttributeDefinition] = []

func duplicate_with_new_ids() -> FlowConstructorDefinition:
	if not attributes.is_empty():
		return FlowSchema5Model.duplicate_owned(self) as FlowConstructorDefinition
	var copy: FlowConstructorDefinition = duplicate(false) as FlowConstructorDefinition
	copy._internal_id = FlowId.create()
	copy.blocks = []
	for block: FlowBlock in blocks:
		copy.blocks.append(null if block == null else block.duplicate_with_new_id())
	copy.dependencies = []
	for dependency: FlowDependencyDefinition in dependencies:
		copy.dependencies.append(null if dependency == null else dependency.duplicate_with_new_id())
	copy.requirements = []
	for requirement: FlowRequiredNodeDefinition in requirements:
		copy.requirements.append(null if requirement == null else requirement.duplicate_with_new_id())
	return copy
