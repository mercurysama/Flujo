@tool
class_name FlowBlock
extends Resource


@export_storage var _internal_id: String = FlowId.create()

@export var display_name: String = "Block"
@export var enabled: bool = true
@export_multiline var user_note: String = ""


func get_internal_id() -> String:
	return _internal_id


## Extension hook for block-local structural validation.
func validate_structure(_context: Dictionary) -> void:
	pass


## Extension hook for remapping IDs owned by a duplicated block.
func remap_internal_references(_id_map: Dictionary[String, String]) -> void:
	pass


func get_navigation_decision(_context: FlowNavigationContext) -> FlowNavigationDecision:
	return FlowNavigationDecision.continue_execution()


func duplicate_with_new_id() -> FlowBlock:
	var copy: FlowBlock = duplicate(true) as FlowBlock
	copy._internal_id = FlowId.create()
	var id_map: Dictionary[String, String] = {}
	id_map[_internal_id] = copy.get_internal_id()
	copy.remap_internal_references(id_map)
	return copy
