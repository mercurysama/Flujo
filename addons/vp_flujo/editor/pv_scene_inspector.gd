@tool
extends RefCounted

## Service that locates PVController and its derived classes.

var _controller_script: Script


func _init(controller_script: Script) -> void:
	_controller_script = controller_script


func contains_controller(scene_root: Node) -> bool:
	return find_controller(scene_root) != null


## Returns the first controller in the supplied selection or scene subtree.
func find_controller(scene_root: Node) -> PVController:
	if scene_root == null:
		return null
	if _node_is_controller(scene_root):
		return scene_root as PVController

	for child: Node in scene_root.get_children():
		var controller: PVController = find_controller(child)
		if controller != null:
			return controller

	return null


func _node_is_controller(node: Node) -> bool:
	var candidate_script := node.get_script() as Script

	while candidate_script != null:
		if candidate_script == _controller_script:
			return true
		candidate_script = candidate_script.get_base_script()

	return false
