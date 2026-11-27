@tool
extends EditorPlugin

## Composition root for the classes that form the plugin.

const PV_CONTROLLER_SCRIPT := preload("res://addons/vp_flujo/runtime/pv_controller.gd")
const PV_SCENE_INSPECTOR_CLASS := preload("res://addons/vp_flujo/editor/pv_scene_inspector.gd")
const FLUO_DRAWER_CLASS := preload("res://addons/vp_flujo/editor/fluo_drawer.gd")
const FLOW_SCENE_NODE_PANEL_CLASS := preload(
	"res://addons/vp_flujo/editor/flow_scene_node_panel.gd"
)
const PV_CONTROLLER_INSPECTOR_PLUGIN_CLASS := preload("res://addons/vp_flujo/editor/pv_controller_inspector_plugin.gd")
const FLOW_INTERACTION_COORDINATOR_CLASS := preload("res://addons/vp_flujo/editor/flow_interaction_coordinator.gd")
const FLOW_CONTROLLER_PROVISIONER_CLASS := preload("res://addons/vp_flujo/editor/flow_controller_provisioner.gd")
const STRUCTURED_DOCUMENT_HARNESS_CLASS := preload(
	"res://addons/vp_flujo/editor/flow_structured_document_editor_harness.gd"
)
const FLUXUS_DRAWER_CLASS := preload("res://addons/vp_flujo/editor/fluxus_drawer.gd")
const PRAVAH_DRAWER_CLASS := preload("res://addons/vp_flujo/editor/pravah_drawer.gd")
const NAGARE_DRAWER_CLASS := preload("res://addons/vp_flujo/editor/nagare_drawer.gd")
const INTERACTION_SHORTCUT_PATH: String = "flujo/toggle_interaction"
const FLUXUS_SHORTCUT_PATH: String = "flujo/toggle_fluxus"
const PRAVAH_SHORTCUT_PATH: String = "flujo/toggle_pravah"
const NAGARE_SHORTCUT_PATH: String = "flujo/toggle_nagare"
const STRUCTURED_DOCUMENT_HARNESS_MENU_ITEM: String = "Open Structured Document Harness"

var _scene_inspector
var _controller_inspector_plugin: EditorInspectorPlugin
var _editor_selection: EditorSelection
var _context_refresh_queued: bool = false
var _controller_reference: WeakRef
var _selected_schema_3_variable_id: String = ""
var _interaction_coordinator: FlowInteractionCoordinator
var _interaction_shortcut: Shortcut
var _fluxus_shortcut: Shortcut
var _pravah_shortcut: Shortcut
var _nagare_shortcut: Shortcut
var _controller_provisioner: FlowControllerProvisioner
var _fluo_drawer: FluoDrawer
var _scene_node_panel: FlowSceneNodePanel
var _fluxus_drawer: FluxusDrawer
var _pravah_drawer: PravahDrawer
var _nagare_drawer: NagareDrawer
var _fluxus_toolbar_button: Button
var _pravah_toolbar_button: Button
var _nagare_toolbar_button: Button
var _structured_document_harness: FlowStructuredDocumentEditorHarness


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
	_controller_inspector_plugin.schema_3_container_activated.connect(
		_on_fluo_container_open_requested
	)
	add_inspector_plugin(_controller_inspector_plugin)
	_mount_fluo_drawer()
	_mount_scene_node_panel()
	_mount_fluxus_pravah_drawers()
	_mount_fluxus_toolbar_button()
	_mount_pravah_toolbar_button()
	_mount_nagare_toolbar_button()
	add_tool_menu_item("Open Fluo", Callable(self, &"_on_fluo_open_requested"))
	add_tool_menu_item("Open Node Panel", Callable(self, &"_on_scene_node_panel_requested"))
	add_tool_menu_item(
		STRUCTURED_DOCUMENT_HARNESS_MENU_ITEM,
		Callable(self, &"_on_structured_document_harness_requested")
	)
	var editor_settings: EditorSettings = EditorInterface.get_editor_settings()
	if editor_settings != null:
		if not editor_settings.has_shortcut(INTERACTION_SHORTCUT_PATH):
			editor_settings.add_shortcut(
				INTERACTION_SHORTCUT_PATH,
				FlowInteractionCoordinator.create_default_shortcut()
			)
		_interaction_shortcut = editor_settings.get_shortcut(INTERACTION_SHORTCUT_PATH)
		if not editor_settings.has_shortcut(FLUXUS_SHORTCUT_PATH):
			editor_settings.add_shortcut(
				FLUXUS_SHORTCUT_PATH,
				_create_default_fluxus_shortcut()
			)
		_fluxus_shortcut = editor_settings.get_shortcut(FLUXUS_SHORTCUT_PATH)
		if not editor_settings.has_shortcut(PRAVAH_SHORTCUT_PATH):
			editor_settings.add_shortcut(
				PRAVAH_SHORTCUT_PATH,
				_create_default_pravah_shortcut()
			)
		_pravah_shortcut = editor_settings.get_shortcut(PRAVAH_SHORTCUT_PATH)
		if not editor_settings.has_shortcut(NAGARE_SHORTCUT_PATH):
			editor_settings.add_shortcut(
				NAGARE_SHORTCUT_PATH,
				_create_default_nagare_shortcut()
			)
		_nagare_shortcut = editor_settings.get_shortcut(NAGARE_SHORTCUT_PATH)
	_interaction_coordinator = FLOW_INTERACTION_COORDINATOR_CLASS.new(_fluo_drawer)
	_controller_provisioner = FLOW_CONTROLLER_PROVISIONER_CLASS.new(
		get_undo_redo(),
		EditorInterface.get_selection(),
		_scene_inspector
	)
	_controller_provisioner.diagnostic_reported.connect(_on_controller_provisioning_diagnostic)
	_connect_editor_signals()
	_request_context_refresh()


func _exit_tree() -> void:
	_disconnect_editor_signals()
	if _interaction_coordinator != null:
		_interaction_coordinator.shutdown()
	_interaction_coordinator = null
	_dispose_nagare_toolbar_button()
	_dispose_pravah_toolbar_button()
	_dispose_fluxus_toolbar_button()
	_dispose_fluxus_pravah_drawers()
	_dispose_nagare_drawer()
	_dispose_structured_document_harness()
	_dispose_scene_node_panel()
	_dispose_fluo_drawer()
	_controller_provisioner = null
	_interaction_shortcut = null
	_fluxus_shortcut = null
	_pravah_shortcut = null
	_nagare_shortcut = null
	if is_instance_valid(_controller_inspector_plugin):
		remove_inspector_plugin(_controller_inspector_plugin)
	_controller_inspector_plugin = null
	remove_tool_menu_item("Open Fluo")
	remove_tool_menu_item("Open Node Panel")
	remove_tool_menu_item(STRUCTURED_DOCUMENT_HARNESS_MENU_ITEM)
	_scene_inspector = null


func _mount_fluo_drawer() -> void:
	if is_instance_valid(_fluo_drawer):
		return
	var editor_base_control: Control = EditorInterface.get_base_control()
	if not is_instance_valid(editor_base_control):
		return
	_fluo_drawer = FLUO_DRAWER_CLASS.new() as FluoDrawer
	if not is_instance_valid(_fluo_drawer):
		_fluo_drawer = null
		return

	_fluo_drawer.configure(get_undo_redo())
	_fluo_drawer.schema_3_variable_list_focus_requested.connect(
		_on_schema_3_variable_list_focus_requested
	)
	_fluo_drawer.schema_3_container_navigation_changed.connect(
		_on_fluo_container_navigation_changed
	)
	_fluo_drawer.schema_3_delete_selection_recovery_requested.connect(
		_on_schema_3_delete_selection_recovery_requested
	)

	editor_base_control.add_child(_fluo_drawer)
	_fluo_drawer.set_controller(_controller_instance())
	_fluo_drawer.side_changed.connect(_on_fluo_side_changed)
	var editor_settings: EditorSettings = EditorInterface.get_editor_settings()
	if editor_settings != null:
		var right_side: bool = false
		if editor_settings.has_setting("flujo/fluo/right_side"):
			right_side = bool(editor_settings.get_setting("flujo/fluo/right_side"))
		_fluo_drawer.set_right_side(right_side)


func _mount_scene_node_panel() -> void:
	if is_instance_valid(_scene_node_panel):
		return
	var editor_base_control: Control = EditorInterface.get_base_control()
	if not is_instance_valid(editor_base_control):
		return
	_scene_node_panel = FLOW_SCENE_NODE_PANEL_CLASS.new() as FlowSceneNodePanel
	if _scene_node_panel == null:
		return
	editor_base_control.add_child(_scene_node_panel)
	_scene_node_panel.set_controller(_controller_instance())
	if is_instance_valid(_fluo_drawer):
		_scene_node_panel.set_opposite_to_fluo(_fluo_drawer.is_right_side())


func _dispose_scene_node_panel() -> void:
	var panel: FlowSceneNodePanel = _scene_node_panel
	_scene_node_panel = null
	if not is_instance_valid(panel):
		return
	panel.close()
	if panel.get_parent() != null:
		panel.get_parent().remove_child(panel)
	panel.free()


func _on_scene_node_panel_requested() -> void:
	if not is_instance_valid(_scene_node_panel):
		return
	_update_controller_context()
	_scene_node_panel.set_controller(_controller_instance())
	_scene_node_panel.open()


func _on_fluo_side_changed(right_side: bool) -> void:
	var editor_settings: EditorSettings = EditorInterface.get_editor_settings()
	if editor_settings != null:
		editor_settings.set_setting("flujo/fluo/right_side", right_side)
	if is_instance_valid(_scene_node_panel):
		_scene_node_panel.set_opposite_to_fluo(right_side)


func _dispose_fluo_drawer() -> void:
	var drawer: FluoDrawer = _fluo_drawer
	_fluo_drawer = null
	if not is_instance_valid(drawer):
		return
	drawer.close()
	var parent: Node = drawer.get_parent()
	if parent != null:
		parent.remove_child(drawer)
	drawer.free()


func _on_fluo_open_requested() -> void:
	if is_instance_valid(_fluo_drawer):
		_update_controller_context()
		_fluo_drawer.open()


func _on_structured_document_harness_requested() -> void:
	if is_instance_valid(_structured_document_harness):
		_structured_document_harness.popup_centered()
		return
	_structured_document_harness = STRUCTURED_DOCUMENT_HARNESS_CLASS.new() as FlowStructuredDocumentEditorHarness
	var editor_base_control: Control = EditorInterface.get_base_control()
	if not is_instance_valid(editor_base_control) or _structured_document_harness == null:
		_structured_document_harness = null
		return
	editor_base_control.add_child(_structured_document_harness)
	_structured_document_harness.configure(get_undo_redo())
	_structured_document_harness.popup_centered()


func _dispose_structured_document_harness() -> void:
	var harness: FlowStructuredDocumentEditorHarness = _structured_document_harness
	_structured_document_harness = null
	if not is_instance_valid(harness):
		return
	if harness.get_parent() != null:
		harness.get_parent().remove_child(harness)
	harness.free()


func _on_fluo_container_open_requested(
	controller: PVController,
	collection: FlowGraphEditorCommands.Collection,
	container_id: String
) -> void:
	if not is_instance_valid(_fluo_drawer) or not is_instance_valid(controller):
		return
	_fluo_drawer.open_container(controller, collection, container_id)


func _on_fluo_block_open_requested(
	controller: PVController,
	collection: FlowGraphEditorCommands.Collection,
	container_id: String,
	block_id: String
) -> void:
	if not is_instance_valid(_fluo_drawer) or not is_instance_valid(controller):
		return
	_fluo_drawer.open_block(controller, collection, container_id, block_id)


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
	_controller_reference = null
	_selected_schema_3_variable_id = ""
	_context_refresh_queued = false


func _on_selection_changed() -> void:
	_update_interaction_selected_controller()
	_request_context_refresh()


func _shortcut_input(event: InputEvent) -> void:
	if _is_fluxus_shortcut(event):
		toggle_fluxus()
		var viewport: Viewport = get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		return
	if _is_pravah_shortcut(event):
		toggle_pravah()
		var viewport: Viewport = get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		return
	if _is_nagare_shortcut(event):
		toggle_nagare()
		var viewport: Viewport = get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		return
	if _interaction_coordinator == null or _interaction_shortcut == null:
		return
	if _is_deliberate_interaction_shortcut(event) \
			and _interaction_coordinator.get_state() == FlowInteractionCoordinator.State.GODOT:
		var controller: PVController = _ensure_controller_for_flow()
		if controller == null:
			return
		_set_controller(controller)
		_set_interaction_selected_controller(controller)
	if _interaction_coordinator.handle_shortcut(event, _interaction_shortcut, get_viewport()):
		get_viewport().set_input_as_handled()


func _is_fluxus_shortcut(event: InputEvent) -> bool:
	if not event is InputEventKey or _fluxus_shortcut == null:
		return false
	var key_event: InputEventKey = event as InputEventKey
	return key_event.pressed and not key_event.echo \
		and _fluxus_shortcut.matches_event(event)


func _is_pravah_shortcut(event: InputEvent) -> bool:
	if not event is InputEventKey or _pravah_shortcut == null:
		return false
	var key_event: InputEventKey = event as InputEventKey
	return key_event.pressed and not key_event.echo \
		and _pravah_shortcut.matches_event(event)


func _is_nagare_shortcut(event: InputEvent) -> bool:
	if not event is InputEventKey or _nagare_shortcut == null:
		return false
	var key_event: InputEventKey = event as InputEventKey
	return key_event.pressed and not key_event.echo \
		and _nagare_shortcut.matches_event(event)


static func _create_default_fluxus_shortcut() -> Shortcut:
	var shortcut: Shortcut = Shortcut.new()
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_F
	event.ctrl_pressed = true
	event.alt_pressed = true
	event.shift_pressed = false
	event.meta_pressed = false
	shortcut.events = [event]
	return shortcut


static func _create_default_pravah_shortcut() -> Shortcut:
	var shortcut: Shortcut = Shortcut.new()
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_P
	event.ctrl_pressed = true
	event.alt_pressed = true
	event.shift_pressed = false
	event.meta_pressed = false
	shortcut.events = [event]
	return shortcut


static func _create_default_nagare_shortcut() -> Shortcut:
	var shortcut: Shortcut = Shortcut.new()
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_N
	event.ctrl_pressed = true
	event.alt_pressed = true
	event.shift_pressed = false
	event.meta_pressed = false
	shortcut.events = [event]
	return shortcut


func _on_scene_changed(_scene_root: Node) -> void:
	_update_interaction_selected_controller()
	_request_context_refresh()


func _on_scene_tree_node_added(node: Node) -> void:
	if not _is_relevant_scene_tree_change(node, _scene_inspector):
		return
	_update_interaction_selected_controller()
	_request_context_refresh()


func _on_scene_tree_node_removed(node: Node) -> void:
	if not _is_relevant_scene_tree_change(node, _scene_inspector):
		return
	var removed_controller: PVController = _scene_inspector.find_controller(node)
	var current_controller: PVController = _controller_instance()
	if is_instance_valid(_controller_inspector_plugin) and removed_controller != null:
		_controller_inspector_plugin.invalidate_controller(removed_controller)
	if current_controller != null and current_controller == removed_controller:
		_set_controller(null)
		_set_interaction_selected_controller(null)
	_update_interaction_selected_controller()
	_request_context_refresh()


func _process(_delta: float) -> void:
	if _interaction_coordinator != null:
		_interaction_coordinator.update_playing_scene(EditorInterface.is_playing_scene(), get_viewport())


func _request_context_refresh() -> void:
	if _context_refresh_queued:
		return
	_context_refresh_queued = true
	_refresh_current_scene.call_deferred()


func _refresh_current_scene() -> void:
	_context_refresh_queued = false
	_update_controller_context()


func _update_controller_context() -> void:
	if _scene_inspector == null:
		return

	var selected_nodes: Array[Node] = []
	if _editor_selection != null:
		selected_nodes = _editor_selection.get_selected_nodes()
	var scene_root: Node = EditorInterface.get_edited_scene_root()
	var controller: PVController = _controller_for_selection(selected_nodes, scene_root)
	_set_interaction_selected_controller(_interaction_controller_for_selection(selected_nodes))
	_set_controller(controller)
	if is_instance_valid(_scene_node_panel) and _scene_node_panel.is_open():
		_scene_node_panel.refresh()


func _on_schema_3_variable_selection_changed(
	controller: PVController,
	collection: FlowGraphEditorCommands.Collection,
	variable_id: String
) -> void:
	if not is_instance_valid(controller):
		return
	if not _activate_controller(controller):
		return
	if _selected_schema_3_variable_id == variable_id:
		return
	_selected_schema_3_variable_id = variable_id
	if is_instance_valid(_fluo_drawer):
		_fluo_drawer.set_variable_selection(controller, collection, variable_id)
		if _selection_context_owns_focus(controller):
			_fluo_drawer.focus_variable_editor(controller, variable_id)

func _on_schema_3_variable_editor_focus_requested(controller: PVController, variable_id: String) -> void:
	if _activate_controller(controller) and controller.flow_graph != null:
		var collection: FlowGraphEditorCommands.Collection = FlowGraphEditorCommands.Collection.VARIABLES

		for process: FlowProcess in controller.flow_graph.processes:
			if process != null and process.get_internal_id() == variable_id:
				collection = FlowGraphEditorCommands.Collection.PROCESSES

		if controller.flow_graph.constructor != null \
				and controller.flow_graph.constructor.get_internal_id() == variable_id:
			collection = FlowGraphEditorCommands.Collection.CONSTRUCTOR

		for method: FlowMethodDefinition in controller.flow_graph.methods:
			if method != null and method.get_internal_id() == variable_id:
				collection = FlowGraphEditorCommands.Collection.METHODS

		if is_instance_valid(_fluo_drawer):
			_fluo_drawer.set_variable_selection(controller, collection, variable_id)
			_fluo_drawer.focus_variable_editor(controller, variable_id)

func _on_fluo_container_navigation_changed(
	controller: PVController,
	collection: FlowGraphEditorCommands.Collection,
	container_id: String
) -> void:
	if not is_instance_valid(controller) or controller != _controller_instance() 			or not is_instance_valid(_controller_inspector_plugin):
		return
	_selected_schema_3_variable_id = container_id
	_controller_inspector_plugin.sync_schema_3_container_selection(
		controller,
		collection,
		container_id
	)


func _on_schema_3_variable_list_focus_requested(controller: PVController, variable_id: String) -> void:
	if is_instance_valid(controller) and controller == _controller_instance() \
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
	if is_instance_valid(controller) and controller == _controller_instance() \
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
		_set_controller(controller)
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
func _activate_controller(controller: PVController) -> bool:
	if not is_instance_valid(_fluo_drawer) or not is_instance_valid(controller):
		return false
	var inspector_plugin: PVControllerInspectorPlugin = _controller_inspector_plugin as PVControllerInspectorPlugin
	if inspector_plugin != null and not inspector_plugin.is_active_controller(controller):
		return false
	_set_controller(controller)
	return true


## Avoids stealing an unrelated editor control's focus during Undo/Redo recovery.
func _selection_context_owns_focus(controller: PVController) -> bool:
	var inspector_plugin: PVControllerInspectorPlugin = _controller_inspector_plugin as PVControllerInspectorPlugin
	if inspector_plugin != null and inspector_plugin.owns_focus(controller):
		return true
	var viewport: Viewport = get_viewport()
	var focus_owner: Control = viewport.gui_get_focus_owner() as Control if viewport != null else null
	if not is_instance_valid(focus_owner):
		return true
	return is_instance_valid(_fluo_drawer) \
		and (focus_owner == _fluo_drawer or _fluo_drawer.is_ancestor_of(focus_owner))


## Applies the single editor-owned controller context shared by Inspector and Fluo.
func _set_controller(controller: PVController) -> bool:
	var next_controller: PVController = controller if is_instance_valid(controller) else null
	var current_controller: PVController = _controller_instance()
	if current_controller == next_controller 			and not (next_controller == null and _controller_reference != null):
		return false

	_controller_reference = weakref(next_controller) if next_controller != null else null
	_selected_schema_3_variable_id = ""
	if is_instance_valid(_fluo_drawer):
		_fluo_drawer.set_controller(next_controller)
		_fluo_drawer.set_variable_selection(
			next_controller,
			FlowGraphEditorCommands.Collection.VARIABLES,
			""
		)
	if is_instance_valid(_scene_node_panel):
		_scene_node_panel.set_controller(next_controller)

	return true


func _controller_instance() -> PVController:
	if _controller_reference == null:
		return null
	var controller: PVController = _controller_reference.get_ref() as PVController
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


func _mount_fluxus_pravah_drawers() -> void:
	var editor_base_control: Control = EditorInterface.get_base_control()
	if not is_instance_valid(editor_base_control):
		return
	if not is_instance_valid(_fluxus_drawer):
		_fluxus_drawer = FLUXUS_DRAWER_CLASS.new() as FluxusDrawer
		if is_instance_valid(_fluxus_drawer):
			editor_base_control.add_child(_fluxus_drawer)
	if not is_instance_valid(_pravah_drawer):
		_pravah_drawer = PRAVAH_DRAWER_CLASS.new() as PravahDrawer
		if is_instance_valid(_pravah_drawer):
			editor_base_control.add_child(_pravah_drawer)
	if not is_instance_valid(_nagare_drawer):
		_nagare_drawer = NAGARE_DRAWER_CLASS.new() as NagareDrawer
		if is_instance_valid(_nagare_drawer):
			editor_base_control.add_child(_nagare_drawer)


func _dispose_fluxus_pravah_drawers() -> void:
	_dispose_editor_drawer(_fluxus_drawer)
	_fluxus_drawer = null
	_dispose_editor_drawer(_pravah_drawer)
	_pravah_drawer = null


func _dispose_nagare_drawer() -> void:
	_dispose_editor_drawer(_nagare_drawer)
	_nagare_drawer = null


func _dispose_editor_drawer(drawer: Control) -> void:
	if not is_instance_valid(drawer):
		return
	if drawer.has_method(&"close"):
		drawer.call(&"close")
	if drawer.has_method(&"clear_instances"):
		drawer.call(&"clear_instances")
	if drawer.get_parent() != null:
		drawer.get_parent().remove_child(drawer)
	drawer.free()


func _mount_fluxus_toolbar_button() -> void:
	if is_instance_valid(_fluxus_toolbar_button):
		return
	_fluxus_toolbar_button = Button.new()
	_fluxus_toolbar_button.name = &"FluxusToggleButton"
	_fluxus_toolbar_button.text = "Fluxus"
	_fluxus_toolbar_button.tooltip_text = "Abrir/cerrar Fluxus (Ctrl+Alt+F)"
	_fluxus_toolbar_button.flat = false
	_fluxus_toolbar_button.focus_mode = Control.FOCUS_NONE
	_fluxus_toolbar_button.pressed.connect(Callable(self, &"toggle_fluxus"))
	# Stable editor toolbar container. Placing exactly next to Play/Stop is not
	# done here because it requires fragile/private editor tree access.
	add_control_to_container(CONTAINER_TOOLBAR, _fluxus_toolbar_button)


func _dispose_fluxus_toolbar_button() -> void:
	if not is_instance_valid(_fluxus_toolbar_button):
		_fluxus_toolbar_button = null
		return
	remove_control_from_container(CONTAINER_TOOLBAR, _fluxus_toolbar_button)
	if _fluxus_toolbar_button.pressed.is_connected(Callable(self, &"toggle_fluxus")):
		_fluxus_toolbar_button.pressed.disconnect(Callable(self, &"toggle_fluxus"))
	_fluxus_toolbar_button.free()
	_fluxus_toolbar_button = null


## Central Fluxus toggle used by toolbar button and editor shortcut.
func toggle_fluxus() -> void:
	var drawer: FluxusDrawer = get_fluxus_drawer()
	if is_instance_valid(drawer):
		drawer.toggle()


func get_fluxus_drawer() -> FluxusDrawer:
	return _fluxus_drawer


func get_pravah_drawer() -> PravahDrawer:
	return _pravah_drawer


func get_nagare_drawer() -> NagareDrawer:
	return _nagare_drawer


func toggle_nagare() -> void:
	var drawer: NagareDrawer = get_nagare_drawer()
	if is_instance_valid(drawer):
		drawer.toggle()


func mount_workspace_in_nagare(workspace: Control) -> bool:
	var drawer: NagareDrawer = get_nagare_drawer()
	return drawer.mount_instance(workspace) if is_instance_valid(drawer) else false


func unmount_workspace_from_nagare(workspace: Control) -> bool:
	var drawer: NagareDrawer = get_nagare_drawer()
	return drawer.unmount_instance(workspace) if is_instance_valid(drawer) else false


## Supported host access for external/editor tooling: mount workspaces through
## the generic FlowDrawerHost API without registering tools in plugin code.
func mount_workspace_in_fluxus(workspace: Control) -> bool:
	var drawer: FluxusDrawer = get_fluxus_drawer()
	return drawer.mount_instance(workspace) if is_instance_valid(drawer) else false


func unmount_workspace_from_fluxus(workspace: Control) -> bool:
	var drawer: FluxusDrawer = get_fluxus_drawer()
	return drawer.unmount_instance(workspace) if is_instance_valid(drawer) else false


func mount_workspace_in_pravah(workspace: Control) -> bool:
	var drawer: PravahDrawer = get_pravah_drawer()
	return drawer.mount_instance(workspace) if is_instance_valid(drawer) else false


func unmount_workspace_from_pravah(workspace: Control) -> bool:
	var drawer: PravahDrawer = get_pravah_drawer()
	return drawer.unmount_instance(workspace) if is_instance_valid(drawer) else false


func _mount_pravah_toolbar_button() -> void:
	if is_instance_valid(_pravah_toolbar_button):
		return
	_pravah_toolbar_button = Button.new()
	_pravah_toolbar_button.name = &"PravahToggleButton"
	_pravah_toolbar_button.text = "Pravah"
	_pravah_toolbar_button.tooltip_text = "Abrir/cerrar Pravah (Ctrl+Alt+P)"
	_pravah_toolbar_button.flat = false
	_pravah_toolbar_button.focus_mode = Control.FOCUS_NONE
	_pravah_toolbar_button.pressed.connect(Callable(self, &"toggle_pravah"))
	# Supported explicit access for testing Pravah; stable toolbar container.
	add_control_to_container(CONTAINER_TOOLBAR, _pravah_toolbar_button)


func _dispose_pravah_toolbar_button() -> void:
	if not is_instance_valid(_pravah_toolbar_button):
		_pravah_toolbar_button = null
		return
	remove_control_from_container(CONTAINER_TOOLBAR, _pravah_toolbar_button)
	if _pravah_toolbar_button.pressed.is_connected(Callable(self, &"toggle_pravah")):
		_pravah_toolbar_button.pressed.disconnect(Callable(self, &"toggle_pravah"))
	_pravah_toolbar_button.free()
	_pravah_toolbar_button = null


func _mount_nagare_toolbar_button() -> void:
	if is_instance_valid(_nagare_toolbar_button):
		return
	_nagare_toolbar_button = Button.new()
	_nagare_toolbar_button.name = &"NagareToggleButton"
	_nagare_toolbar_button.text = "Nagare"
	_nagare_toolbar_button.tooltip_text = "Abrir/cerrar Nagare (Ctrl+Alt+N)"
	_nagare_toolbar_button.flat = false
	_nagare_toolbar_button.focus_mode = Control.FOCUS_NONE
	_nagare_toolbar_button.pressed.connect(Callable(self, &"toggle_nagare"))
	add_control_to_container(CONTAINER_TOOLBAR, _nagare_toolbar_button)


func _dispose_nagare_toolbar_button() -> void:
	if not is_instance_valid(_nagare_toolbar_button):
		_nagare_toolbar_button = null
		return
	remove_control_from_container(CONTAINER_TOOLBAR, _nagare_toolbar_button)
	if _nagare_toolbar_button.pressed.is_connected(Callable(self, &"toggle_nagare")):
		_nagare_toolbar_button.pressed.disconnect(Callable(self, &"toggle_nagare"))
	_nagare_toolbar_button.free()
	_nagare_toolbar_button = null


## Central Pravah toggle used by toolbar button and editor shortcut.
func toggle_pravah() -> void:
	var drawer: PravahDrawer = get_pravah_drawer()
	if is_instance_valid(drawer):
		drawer.toggle()
