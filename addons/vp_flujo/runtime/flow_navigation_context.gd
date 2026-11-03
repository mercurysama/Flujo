class_name FlowNavigationContext
extends RefCounted

## Ephemeral context supplied while a block chooses the next runtime step.
var controller: Node
var graph: FlowGraph
var container: FlowBlockContainer
var current_block_id: String
var entry_point: StringName
var value_resolution_context: FlowValueResolutionContext
var _fsm_operations: FlowFSMOperations


func _init(
		new_controller: Node,
		new_graph: FlowGraph,
		new_container: FlowBlockContainer,
		new_current_block_id: String,
		new_entry_point: StringName,
		new_value_resolution_context: FlowValueResolutionContext = null,
		new_fsm_runtime: FlowFSMRuntime = null,
		new_fsm_machine_id: String = ""
) -> void:
	controller = new_controller
	graph = new_graph
	container = new_container
	current_block_id = new_current_block_id
	entry_point = new_entry_point
	value_resolution_context = new_value_resolution_context
	# Only the executor of a real FSM phase can supply its owning runtime.
	if new_fsm_runtime != null and controller is PVController \
			and not new_fsm_machine_id.is_empty() \
			and entry_point in [&"StateEnter", &"StateUpdate", &"StateExit"]:
		_fsm_operations = FlowFSMOperations.new(
			new_fsm_runtime, controller as PVController, graph, new_fsm_machine_id
		)


## Blocks may retain the facade, but it expires immediately after their callback.
func get_fsm_operations() -> FlowFSMOperations:
	return _fsm_operations


func invalidate_fsm_operations() -> void:
	if _fsm_operations != null:
		_fsm_operations.invalidate()
		_fsm_operations = null
