@tool
class_name FlowStateTransitionDefinition
extends Resource

## Stable authored edge, owned by exactly one source state.
enum Trigger { CONDITION, EVENT }

@export_storage var _internal_id: String = FlowId.create()
@export var display_name: String = "Transition"
@export var enabled: bool = true
@export var target_state_id: String = ""
@export var trigger: Trigger = Trigger.CONDITION
@export var condition: FlowValueSource
@export var event_name: StringName = &""
@export var priority: int = 0
@export_multiline var user_note: String = ""


func get_internal_id() -> String:
	return _internal_id


func duplicate_with_new_id() -> FlowStateTransitionDefinition:
	var copy: FlowStateTransitionDefinition = duplicate(false) as FlowStateTransitionDefinition
	copy._internal_id = FlowId.create()
	copy.condition = condition.duplicate_with_new_id() if condition != null else null
	return copy
