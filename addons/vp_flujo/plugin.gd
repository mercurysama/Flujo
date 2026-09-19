@tool
extends EditorPlugin

## Composition root for the classes that form the plugin.

const PV_CONTROLLER_SCRIPT := preload("res://addons/vp_flujo/runtime/pv_controller.gd")
const PV_SCENE_INSPECTOR_CLASS := preload("res://addons/vp_flujo/editor/pv_scene_inspector.gd")
const VP_FLUJO_DOCK_CLASS := preload("res://addons/vp_flujo/editor/vp_flujo_dock.gd")
const PV_CONTROLLER_INSPECTOR_PLUGIN_CLASS := preload("res://addons/vp_flujo/editor/pv_controller_inspector_plugin.gd")
const FLOW_INTERACTION_COORDINATOR_CLASS := preload("res://addons/vp_flujo/editor/flow_interaction_coordinator.gd")
const FLOW_CONTROLLER_PROVISIONER_CLASS := preload("res://addons/vp_flujo/editor/flow_controller_provisioner.gd")
const INTERACTION_SHORTCUT_PATH: String = "flujo/toggle_interaction"

var _dock
var _scene_inspector
var _controller_inspector_plugin: EditorInspectorPlugin
var _editor_selection: EditorSelection
var _dock_refresh_queued: bool = false
var _dock_controller_reference: WeakRef
var _selected_schema_3_variable_id: String = ""
var _interaction_coordinator: FlowInteractionCoordinator
var _interaction_shortcut: Shortcut
var _controller_provisioner: FlowControllerProvisioner


func _enter_tree() -> void:
	_scene_inspector = PV_SCENE_INSPECTOR_CLASS.new(PV_CONTROLLER_SCRIPT)
	_controller_inspector_plugin = PV_CONTROLLER_INSPECTOR_PLUGIN_CLASS.new()
	_controller_inspector_plugin.set_undo_redo(get_undo_redo())
	_controller_inspector_plugin.schema_3_variable_selection_changed.connect(
		_on_schema_3_variable_selection_changed
	)
	_controller_inspector_plugin.schema_3_variable_editor_focus_requested.connect(
		_on_schema_3_variable_editor_focus_requested
	)
	add_inspector_plugin(_controller_inspector_plugin)
	_dock = VP_FLUJO_DOCK_CLASS.new()
	_dock.configure(get_undo_redo())
	_dock.schema_3_variable_list_focus_requested.connect(_on_schema_3_variable_list_focus_requested)
	_dock.schema_3_delete_selection_recovery_requested.connect(_on_schema_3_delete_selection_recovery_requested)
	_dock.interaction_toggle_requested.connect(_on_interaction_toggle_requested)
	add_dock(_dock)
	var editor_settings: EditorSettings = EditorInterface.get_editor_settings()
	if editor_settings != null:
		if not editor_settings.has_shortcut(INTERACTION_SHORTCUT_PATH):
			editor_settings.add_shortcut(
				INTERACTION_SHORTCUT_PATH,
				FlowInteractionCoordinator.create_default_shortcut()
			)
		_interaction_shortcut = editor_settings.get_shortcut(INTERACTION_SHORTCUT_PATH)
	_interaction_coordinator = FLOW_INTERACTION_COORDINATOR_CLASS.new(_dock)
	_controller_provisioner = FLOW_CONTROLLER_PROVISIONER_CLASS.new(
		get_undo_redo(),
		EditorInterface.get_selection(),
		_scene_inspector
	)
	_controller_provisioner.diagnostic_reported.connect(_on_controller_provisioning_diagnostic)
	_connect_editor_signals()
	_request_dock_refresh()


func _exit_tree() -> void:
	_disconnect_editor_signals()
	if _interaction_coordinator != null:
		_interaction_coordinator.shutdown()
	_interaction_coordinator = null
	_controller_provisioner = null
	_interaction_shortcut = null
	if is_instance_valid(_controller_inspector_plugin):
		remove_inspector_plugin(_controller_inspector_plugin)
	_controller_inspector_plugin = null

	if is_instance_valid(_dock):
		remove_dock(_dock)
		_dock.queue_free()

	_dock = null
	_scene_inspector = null


func _connect_editor_signals() -> void:
	scene_changed.connect(_on_scene_changed)
	get_tree().node_added.connect(_on_scene_tree_node_added)
	get_tree().node_removed.connect(_on_scene_tree_node_removed)

	_editor_selection = EditorInterface.get_selection()
	if (
		_editor_selection != null
		and not _editor_selection.selection_changed.is_connected(_on_selection_changed)
	):
		_editor_selection.selection_changed.connect(_on_selection_changed)

	_on_selection_changed()


func _disconnect_editor_signals() -> void:
	if scene_changed.is_connected(_on_scene_changed):
		scene_changed.disconnect(_on_scene_changed)
	if get_tree().node_added.is_connected(_on_scene_tree_node_added):
		get_tree().node_added.disconnect(_on_scene_tree_node_added)
	if get_tree().node_removed.is_connected(_on_scene_tree_node_removed):
		get_tree().node_removed.disconnect(_on_scene_tree_node_removed)
	if (
		_editor_selection != null
		and _editor_selection.selection_changed.is_connected(_on_selection_changed)
	):
		_editor_selection.selection_changed.disconnect(_on_selection_changed)

	_editor_selection = null
	_dock_controller_reference = null
	_selected_schema_3_variable_id = ""
	_dock_refresh_queued = false


func _on_selection_changed() -> void:
	_update_interaction_selected_controller()
	_request_dock_refresh()


func _shortcut_input(event: InputEvent) -> void:
	if _interaction_coordinator == null or _interaction_shortcut == null:
		return
	if _is_deliberate_interaction_shortcut(event) \
			and _interaction_coordinator.get_state() == FlowInteractionCoordinator.State.GODOT:
		var controller: PVController = _ensure_controller_for_flow()
		if controller == null:
			return
		_set_dock_controller(controller)
		_set_interaction_selected_controller(controller)
	if _interaction_coordinator.handle_shortcut(event, _interaction_shortcut, get_viewport()):
		get_viewport().set_input_as_handled()


func _on_scene_changed(_scene_root: Node) -> void:
	_update_interaction_selected_controller()
	_request_dock_refresh()


func _on_scene_tree_node_added(node: Node) -> void:
	if not _is_relevant_scene_tree_change(node, _scene_inspector):
		return
	_update_interaction_selected_controller()
	_request_dock_refresh()


func _on_scene_tree_node_removed(node: Node) -> void:
	if not _is_relevant_scene_tree_change(node, _scene_inspector):
		return
	var removed_controller: PVController = _scene_inspector.find_controller(node)
	var current_controller: PVController = _dock_controller_instance()
	if is_instance_valid(_controller_inspector_plugin) and removed_controller != null:
		_controller_inspector_plugin.invalidate_controller(removed_controller)
	if current_controller != null and current_controller == removed_controller:
		_set_dock_controller(null)
		_set_interaction_selected_controller(null)
		if is_instance_valid(_dock):
			_dock.set_controller_present(false)
	_update_interaction_selected_controller()
	_request_dock_refresh()


func _process(_delta: float) -> void:
	if _interaction_coordinator != null:
		_interaction_coordinator.update_playing_scene(EditorInterface.is_playing_scene(), get_viewport())


func _request_dock_refresh() -> void:
	if _dock_refresh_queued:
		return
	_dock_refresh_queued = true
	_refresh_current_scene.call_deferred()


func _refresh_current_scene() -> void:
	_dock_refresh_queued = false
	_update_dock_visibility()


func _update_dock_visibility() -> void:
	if not is_instance_valid(_dock) or _scene_inspector == null:
		return

	var selected_nodes: Array[Node] = []
	if _editor_selection != null:
		selected_nodes = _editor_selection.get_selected_nodes()
	var scene_root: Node = EditorInterface.get_edited_scene_root()
	var controller: PVController = _controller_for_selection(selected_nodes, scene_root)
	var should_show: bool = controller != null
	_set_interaction_selected_controller(_interaction_controller_for_selection(selected_nodes))
	_set_dock_controller(controller)
	_dock.set_controller_present(should_show)


func _on_schema_3_variable_selection_changed(
	controller: PVController,
	collection: FlowGraphEditorCommands.Collection,
	variable_id: String
) -> void:
	if not is_instance_valid(controller):
		return
	if not _activate_dock_controller(controller):
		return
	if _selected_schema_3_variable_id == variable_id:
		return
	_selected_schema_3_variable_id = variable_id
	_dock.set_variable_selection(controller, collection, variable_id)


func _on_schema_3_variable_editor_focus_requested(controller: PVController, variable_id: String) -> void:
	if _activate_dock_controller(controller) and controller.flow_graph != null:
		var collection: FlowGraphEditorCommands.Collection = FlowGraphEditorCommands.Collection.VARIABLES
		for process: FlowProcess in controller.flow_graph.processes:
			if process != null and process.get_internal_id() == variable_id:
				collection = FlowGraphEditorCommands.Collection.PROCESSES
		if controller.flow_graph.constructor != null and controller.flow_graph.constructor.get_internal_id() == variable_id:
			collection = FlowGraphEditorCommands.Collection.CONSTRUCTOR
		for method: FlowMethodDefinition in controller.flow_graph.methods:
			if method != null and method.get_internal_id() == variable_id:
				collection = FlowGraphEditorCommands.Collection.METHODS
		_dock.set_variable_selection(controller, collection, variable_id)
		_dock.focus_variable_editor(controller, variable_id)


func _on_schema_3_variable_list_focus_requested(controller: PVController, variable_id: String) -> void:
	if is_instance_valid(controller) and controller == _dock_controller_instance() \
			and is_instance_valid(_controller_inspector_plugin):
		_controller_inspector_plugin.focus_schema_3_variable_list(controller, variable_id)


func _on_schema_3_delete_selection_recovery_requested(
		controller: PVController,
		collection: FlowGraphEditorCommands.Collection,
		deleted_id: String,
		replacement_id: String,
		view_title: String,
		restore_focus: bool
) -> void:
	if is_instance_valid(controller) and controller == _dock_controller_instance() \
			and is_instance_valid(_controller_inspector_plugin):
		_controller_inspector_plugin.apply_schema_3_delete_selection_recovery(
			controller,
			collection,
			deleted_id,
			replacement_id,
			view_title,
			restore_focus
		)


func _on_interaction_toggle_requested() -> void:
	if _interaction_coordinator == null:
		return
	if _interaction_coordinator.get_state() == FlowInteractionCoordinator.State.GODOT:
		var controller: PVController = _ensure_controller_for_flow()
		if controller == null:
			return
		_set_dock_controller(controller)
		_set_interaction_selected_controller(controller)
	_interaction_coordinator.toggle_flow_interaction(get_viewport())


func _is_deliberate_interaction_shortcut(event: InputEvent) -> bool:
	if not event is InputEventKey or _interaction_shortcut == null:
		return false
	var key_event: InputEventKey = event as InputEventKey
	return key_event.pressed and not key_event.echo \
		and _interaction_shortcut.matches_event(event)


func _ensure_controller_for_flow() -> PVController:
	if _controller_provisioner == null:
		return null
	var selected_nodes: Array[Node] = []
	if _editor_selection != null:
		selected_nodes = _editor_selection.get_selected_nodes()
	return _controller_provisioner.ensure_controller(
		EditorInterface.get_edited_scene_root(),
		selected_nodes,
		EditorInterface.is_playing_scene()
	)


func _on_controller_provisioning_diagnostic(message: String) -> void:
	push_warning("[Flujo] %s" % message)


## Synchronizes a valid Inspector source before applying its schema 3 selection.
func _activate_dock_controller(controller: PVController) -> bool:
	if not is_instance_valid(_dock) or not is_instance_valid(controller):
		return false
	var inspector_plugin: PVControllerInspectorPlugin = _controller_inspector_plugin as PVControllerInspectorPlugin
	if inspector_plugin != null and not inspector_plugin.is_active_controller(controller):
		return false
	if _set_dock_controller(controller):
		_dock.set_controller_present(true)
	return true


## Applies the single editor-owned controller context shared by the dock and relay.
func _set_dock_controller(controller: PVController) -> bool:
	var next_controller: PVController = controller if is_instance_valid(controller) else null
	var current_controller: PVController = _dock_controller_instance()
	if current_controller != next_controller \
			or (next_controller == null and _dock_controller_reference != null):
		_dock_controller_reference = weakref(next_controller) if next_controller != null else null
		_selected_schema_3_variable_id = ""
		_dock.set_controller(next_controller)
		_dock.set_variable_selection(next_controller, FlowGraphEditorCommands.Collection.VARIABLES, "")
		return true
	return false


func _dock_controller_instance() -> PVController:
	if _dock_controller_reference == null:
		return null
	var controller: PVController = _dock_controller_reference.get_ref() as PVController
	return controller if is_instance_valid(controller) else null


## Updates only the exact hierarchy selection used by the interaction coordinator.
func _update_interaction_selected_controller() -> void:
	var selected_nodes: Array[Node] = []
	if _editor_selection != null:
		selected_nodes = _editor_selection.get_selected_nodes()
	_set_interaction_selected_controller(_interaction_controller_for_selection(selected_nodes))


func _set_interaction_selected_controller(controller: PVController) -> void:
	if _interaction_coordinator != null:
		_interaction_coordinator.set_selected_controller(controller)


static func _interaction_controller_for_selection(selected_nodes: Array[Node]) -> PVController:
	if selected_nodes.size() != 1:
		return null
	var selected_node: Node = selected_nodes[0]
	return selected_node as PVController \
		if selected_node is PVController and selected_node.is_inside_tree() else null


func _controller_for_selection(selected_nodes: Array[Node], scene_root: Node) -> PVController:
	var controller: PVController = null
	if selected_nodes.size() == 1:
		controller = _scene_inspector.find_controller(selected_nodes[0])
	elif selected_nodes.size() > 1:
		return null
	else:
		controller = _scene_inspector.find_controller(scene_root)
	if controller == null or scene_root == null:
		return null
	return controller if controller == scene_root or scene_root.is_ancestor_of(controller) else null


static func _is_relevant_scene_tree_change(node: Node, scene_inspector) -> bool:
	return node != null and scene_inspector != null and scene_inspector.contains_controller(node)


static func _should_show_dock(
		selected_nodes: Array[Node],
		scene_root: Node,
		scene_inspector
) -> bool:
	if selected_nodes.size() == 1:
		return scene_inspector != null and scene_inspector.contains_controller(selected_nodes[0])
	if selected_nodes.size() > 1:
		return false
	return scene_inspector != null and scene_inspector.contains_controller(scene_root)
