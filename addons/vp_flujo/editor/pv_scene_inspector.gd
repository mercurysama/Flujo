@tool
extends RefCounted

## Servicio que conoce cómo localizar PVController y sus clases derivadas.

var _controller_script: Script


func _init(controller_script: Script) -> void:
	_controller_script = controller_script


func contains_controller(scene_root: Node) -> bool:
	if scene_root == null:
		return false
	if _node_is_controller(scene_root):
		return true

	for child in scene_root.get_children():
		if contains_controller(child):
			return true

	return false


func _node_is_controller(node: Node) -> bool:
	var candidate_script := node.get_script() as Script

	while candidate_script != null:
		if candidate_script == _controller_script:
			return true
		candidate_script = candidate_script.get_base_script()

	return false

