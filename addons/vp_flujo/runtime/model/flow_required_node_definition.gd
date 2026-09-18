@tool
## Schema 4 declaration only. It neither resolves nor creates scene nodes.
class_name FlowRequiredNodeDefinition
extends Resource

@export_storage var _internal_id: String = FlowId.create()
@export var display_name: String = "Required Node"
@export var enabled: bool = true
@export_multiline var user_note: String = ""
@export var required_class_name: StringName = &"Node"
@export var expected_node_name: StringName = &"Component"
@export var required: bool = true
## Reserved ordered nullable slots; every non-empty collection is currently invalid.
@export_storage var required_properties: Array[Resource] = []


func get_internal_id() -> String:
	return _internal_id


func duplicate_with_new_id() -> FlowRequiredNodeDefinition:
	var copy: FlowRequiredNodeDefinition = duplicate(true) as FlowRequiredNodeDefinition
	copy._internal_id = FlowId.create()
	return copy
