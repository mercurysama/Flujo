@tool
class_name FlowControllerProvisioner
extends RefCounted

## Resolves or creates the one scene controller needed to enter Flow interaction.

signal diagnostic_reported(message: String)

var _undo_redo: EditorUndoRedoManager
var _selection: EditorSelection
var _scene_inspector: RefCounted
var _creation_in_progress: bool = false


func _init(
		undo_redo: EditorUndoRedoManager,
		selection: EditorSelection,
		scene_inspector: RefCounted
) -> void:
	_undo_redo = undo_redo
	_selection = selection
	_scene_inspector = scene_inspector


## Returns a usable existing controller or atomically creates one for the selected target.
func ensure_controller(
		scene_root: Node,
		selected_nodes: Array[Node],
		is_playing_scene: bool
) -> PVController:
	if is_playing_scene:
		_report("Flow interaction cannot create a PVController while the game is running.")
		return null
	if not is_instance_valid(scene_root) or not scene_root.is_inside_tree():
		_report("Flow interaction requires an editable open scene.")
		return null
	if selected_nodes.size() > 1:
		_report("Select a single scene node before entering Flow interaction.")
		return null
	var target: Node = scene_root
	if selected_nodes.size() == 1:
		target = selected_nodes[0]
	if not is_instance_valid(target) \
			or (target != scene_root and not scene_root.is_ancestor_of(target)):
		_report("The selected node does not belong to the edited scene.")
		return null
	var existing: PVController = _find_controller(target)
	if existing != null:
		if selected_nodes.size() != 1 or selected_nodes[0] != existing:
			_select(existing)
		return existing
	if not _is_editable_target(scene_root, target):
		_report("The selected scene branch is not editable; PVController was not created.")
		return null
	if _creation_in_progress:
		_report("PVController creation is already pending.")
		return null
	if _undo_redo == null or _selection == null:
		_report("The editor Undo/Redo context is unavailable.")
		return null
	_creation_in_progress = true
	var controller: PVController = PVController.new()
	controller.name = &"PVController"
	_undo_redo.create_action(
		"Create PVController",
		UndoRedo.MERGE_DISABLE,
		scene_root,
		false,
		true
	)
	_undo_redo.add_do_method(self, &"_attach_controller", target, controller, scene_root)
	_undo_redo.add_undo_method(self, &"_detach_controller", target, controller)
	_undo_redo.add_do_reference(controller)
	_undo_redo.commit_action()
	_creation_in_progress = false
	return controller if controller.get_parent() == target else null


func _attach_controller(parent: Node, controller: PVController, scene_root: Node) -> void:
	if not is_instance_valid(parent) or not is_instance_valid(controller) \
			or not is_instance_valid(scene_root) or controller.get_parent() != null:
		return
	parent.add_child(controller, true)
	controller.owner = scene_root
	_select(controller)


func _detach_controller(parent: Node, controller: PVController) -> void:
	if not is_instance_valid(parent) or not is_instance_valid(controller) \
			or controller.get_parent() != parent:
		return
	_select(parent)
	controller.owner = null
	parent.remove_child(controller)


func _select(node: Node) -> void:
	if _selection == null or not is_instance_valid(node) or not node.is_inside_tree():
		return
	_selection.clear()
	_selection.add_node(node)
	EditorInterface.inspect_object(node)


func _find_controller(node: Node) -> PVController:
	if _scene_inspector == null or not _scene_inspector.has_method(&"find_controller"):
		return null
	var controller: PVController = _scene_inspector.call(&"find_controller", node) as PVController
	return controller if is_instance_valid(controller) and controller.is_inside_tree() else null


## A nested scene instance accepts children only when Godot marks that instance editable.
func _is_editable_target(scene_root: Node, target: Node) -> bool:
	if target == scene_root:
		return true
	var cursor: Node = target
	while cursor != null and cursor != scene_root:
		if not cursor.scene_file_path.is_empty():
			return scene_root.is_editable_instance(cursor)
		cursor = cursor.get_parent()
	return cursor == scene_root


func _report(message: String) -> void:
	diagnostic_reported.emit(message)
