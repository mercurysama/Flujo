@tool
extends SceneTree

const TEMP_PATH: String = "res://.godot/flujo_tests/f4_create_controller.tscn"
const PV_SCENE_INSPECTOR_SCRIPT := preload("res://addons/vp_flujo/editor/pv_scene_inspector.gd")

var _failures: Array[String] = []
var _diagnostics: Array[String] = []
var _scene_root: Node
var _dock: VPFlujoDock


class CoordinatorTestDock extends VPFlujoDock:
	func activate_flow_interaction() -> void:
		show()
		call(&"_set_interaction_presentation", "Flow", "Leave Flow (F4)", false)


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _frames()
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	if not _create_fixture():
		await _finish()
		return
	EditorInterface.open_scene_from_path(TEMP_PATH)
	await _frames(8)
	_scene_root = EditorInterface.get_edited_scene_root()
	if not _check(_scene_root != null, "Open the F4 controller-creation fixture."):
		await _finish()
		return
	var selection: EditorSelection = EditorInterface.get_selection()
	var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	var inspector: RefCounted = PV_SCENE_INSPECTOR_SCRIPT.new(
		preload("res://addons/vp_flujo/runtime/pv_controller.gd")
	)
	var provisioner: FlowControllerProvisioner = FlowControllerProvisioner.new(
		manager,
		selection,
		inspector
	)
	provisioner.diagnostic_reported.connect(_record_diagnostic)
	selection.clear()
	selection.add_node(_scene_root)

	var controller: PVController = provisioner.ensure_controller(_scene_root, [_scene_root], false)
	await _frames(3)
	_check(controller != null and controller.get_parent() == _scene_root, "F4 provisioning creates one PVController below the selected root.")
	_check(controller != null and controller.owner == _scene_root, "The created controller belongs to the edited scene root.")
	_check(_controller_count(_scene_root) == 1, "Controller creation produces exactly one controller.")
	_check(_selected_node(selection) == controller, "Controller creation selects the new PVController.")
	if controller == null:
		await _finish()
		return
	var exact_reuse: PVController = provisioner.ensure_controller(_scene_root, [controller], false)
	_check(
		exact_reuse == controller and _selected_node(selection) == controller,
		"An exactly selected PVController is reused without changing hierarchy selection."
	)

	for _index: int in 20:
		var reused: PVController = provisioner.ensure_controller(_scene_root, [_scene_root], false)
		_check(reused == controller, "Repeated provisioning reuses the existing controller.")
	_check(_controller_count(_scene_root) == 1, "Rapid repeated requests cannot create duplicate controllers.")

	var history_id: int = manager.get_object_history_id(_scene_root)
	var history: UndoRedo = manager.get_history_undo_redo(history_id)
	_check(history != null and history.has_undo(), "The controller creation belongs to the edited scene history.")
	if history == null:
		await _finish()
		return
	history.undo()
	await _frames(3)
	_check(controller.get_parent() == null and _controller_count(_scene_root) == 0, "Undo removes the created controller only.")
	_check(_selected_node(selection) == _scene_root, "Undo returns hierarchy selection to the controller parent.")
	history.redo()
	await _frames(3)
	_check(controller.get_parent() == _scene_root and controller.owner == _scene_root, "Redo restores the same controller and scene owner.")
	_check(_selected_node(selection) == controller, "Redo selects the restored controller.")

	_dock = CoordinatorTestDock.new()
	_dock.configure(manager)
	get_root().add_child(_dock)
	_dock.show()
	_dock.set_controller(controller)
	var coordinator: FlowInteractionCoordinator = FlowInteractionCoordinator.new(_dock)
	coordinator.set_selected_controller(controller)
	var shortcut: Shortcut = FlowInteractionCoordinator.create_default_shortcut()
	var f4: InputEventKey = InputEventKey.new()
	f4.pressed = true
	f4.keycode = KEY_F4
	_check(coordinator.handle_shortcut(f4, shortcut, get_root()), "F4 enters Flow after Redo restores the controller.")
	_check(coordinator.get_state() == FlowInteractionCoordinator.State.FLOW, "The public F4 transition reaches FLOW.")
	_check(coordinator.handle_shortcut(f4, shortcut, get_root()), "A second F4 returns control to Godot.")
	_check(
		coordinator.get_state() == FlowInteractionCoordinator.State.GODOT \
			and _controller_count(_scene_root) == 1,
		"Leaving Flow never deletes the controller."
	)

	var empty_target: Node = _scene_root.get_node_or_null("EmptyTarget")
	var before_game_count: int = _controller_count(empty_target)
	var blocked: PVController = provisioner.ensure_controller(_scene_root, [empty_target], true)
	_check(blocked == null and _controller_count(empty_target) == before_game_count, "GAME blocks controller creation without mutation.")
	_check(
		_diagnostics.has("Flow interaction cannot create a PVController while the game is running."),
		"GAME blocking reports a clear deterministic diagnostic."
	)
	coordinator.update_playing_scene(true, get_root())
	_check(not coordinator.handle_shortcut(f4, shortcut, get_root()), "F4 remains unconsumed while GAME is active.")
	coordinator.shutdown()
	await _finish()


func _create_fixture() -> bool:
	var root: Node = Node.new()
	root.name = &"F4ControllerCreation"
	var empty_target: Node = Node.new()
	empty_target.name = &"EmptyTarget"
	root.add_child(empty_target)
	empty_target.owner = root
	var packed: PackedScene = PackedScene.new()
	if not _check(packed.pack(root) == OK, "Pack the F4 controller-creation fixture."):
		root.free()
		return false
	root.free()
	if not _check(
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/flujo_tests")) == OK,
		"Create the focal test directory."
	):
		return false
	return _check(ResourceSaver.save(packed, TEMP_PATH) == OK, "Save the F4 controller-creation fixture.")


func _controller_count(node: Node) -> int:
	if not is_instance_valid(node):
		return 0
	var count: int = 1 if node is PVController else 0
	for child: Node in node.get_children():
		count += _controller_count(child)
	return count


func _selected_node(selection: EditorSelection) -> Node:
	var selected: Array[Node] = selection.get_selected_nodes() if selection != null else []
	return selected[0] if selected.size() == 1 else null


func _record_diagnostic(message: String) -> void:
	_diagnostics.append(message)


func _frames(count: int = 4) -> void:
	for _index: int in count:
		await process_frame


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_failures.append(message)
		push_error(message)
	return condition


func _finish() -> void:
	if is_instance_valid(_dock):
		_dock.queue_free()
	if is_instance_valid(_scene_root) and EditorInterface.get_edited_scene_root() == _scene_root:
		EditorInterface.close_scene()
	await _frames(6)
	if FileAccess.file_exists(TEMP_PATH):
		_check(
			DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_PATH)) == OK,
			"Remove the F4 controller-creation fixture."
		)
	if _failures.is_empty():
		print("[Flujo] F4 controller creation test passed")
	quit(0 if _failures.is_empty() else 1)
