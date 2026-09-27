class_name FlowNavigationContext
extends RefCounted

## Ephemeral context supplied while a block chooses the next runtime step.
var controller: Node
var graph: FlowGraph
var container: FlowBlockContainer
var current_block_id: String
var entry_point: StringName


func _init(
		new_controller: Node,
		new_graph: FlowGraph,
		new_container: FlowBlockContainer,
		new_current_block_id: String,
		new_entry_point: StringName) -> void:
	controller = new_controller
	graph = new_graph
	container = new_container
	current_block_id = new_current_block_id
	entry_point = new_entry_point
