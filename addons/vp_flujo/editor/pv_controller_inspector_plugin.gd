@tool
class_name PVControllerInspectorPlugin
extends EditorInspectorPlugin


const FLOW_GRAPH_PROPERTY: StringName = &"flow_graph"
const FLOW_GRAPH_INSPECTOR_PROPERTY := preload("res://addons/vp_flujo/editor/flow_graph_inspector_property.gd")

## Relays the structural schema 3 selection without making the Inspector depend on the dock.
signal schema_3_variable_selection_changed(
	controller: PVController,
	collection: FlowGraphEditorCommands.Collection,
	variable_id: String
)
signal schema_3_variable_editor_focus_requested(controller: PVController, variable_id: String)

var _undo_redo: EditorUndoRedoManager
var _active_flow_graph_property: FlowGraphInspectorProperty
var _delete_recovery_controller: WeakRef
var _delete_recovery_collection: FlowGraphEditorCommands.Collection = FlowGraphEditorCommands.Collection.PROCESSES
var _delete_recovery_deleted_id: String = ""
var _delete_recovery_replacement_id: String = ""
var _delete_recovery_view_title: String = ""
var _delete_recovery_restore_focus: bool = false
var _delete_recovery_generation: int = 0


## Receives the editor-owned undo/redo manager from the main plugin.
func set_undo_redo(undo_redo: EditorUndoRedoManager) -> void:
	_undo_redo = undo_redo


func _can_handle(object: Object) -> bool:
	return object is PVController


func _parse_property(
		_object: Object,
		_type: Variant.Type,
		property_name: String,
		_hint_type: PropertyHint,
		_hint_string: String,
		_usage_flags: int,
		_wide: bool
) -> bool:
	var is_flow_graph: bool = is_flow_graph_property(property_name)
	if not is_flow_graph:
		return false
	var property: FlowGraphInspectorProperty = FLOW_GRAPH_INSPECTOR_PROPERTY.new()
	property.configure(_undo_redo)
	property.schema_3_variable_selection_changed.connect(_on_schema_3_variable_selection_changed)
	property.schema_3_variable_editor_focus_requested.connect(_on_schema_3_variable_editor_focus_requested)
	_active_flow_graph_property = property
	property.tree_exited.connect(_on_flow_graph_property_tree_exited.bind(property.get_instance_id()))
	add_property_editor(property_name, property, false, "Flow Graph")
	_queue_delete_selection_recovery(_object as PVController)
	return true


func _on_schema_3_variable_selection_changed(
	controller: PVController,
	collection: FlowGraphEditorCommands.Collection,
	variable_id: String
) -> void:
	_clear_delete_selection_recovery_for_other_selection(controller, variable_id)
	emit_signal(&"schema_3_variable_selection_changed", controller, collection, variable_id)


func _on_schema_3_variable_editor_focus_requested(controller: PVController, variable_id: String) -> void:
	emit_signal(&"schema_3_variable_editor_focus_requested", controller, variable_id)


func focus_schema_3_variable_list(controller: PVController, variable_id: String) -> void:
	if not is_instance_valid(_active_flow_graph_property):
		return
	if _active_flow_graph_property.get_edited_object() != controller:
		return
	_active_flow_graph_property.focus_schema_3_variable_list(controller, variable_id)


func apply_schema_3_delete_selection_recovery(
		controller: PVController,
		collection: FlowGraphEditorCommands.Collection,
		deleted_id: String,
		replacement_id: String,
		view_title: String,
		restore_focus: bool
) -> void:
	restore_focus = restore_focus or _active_property_owns_focus(controller)
	_delete_recovery_controller = weakref(controller)
	_delete_recovery_collection = collection
	_delete_recovery_deleted_id = deleted_id
	_delete_recovery_replacement_id = replacement_id
	_delete_recovery_view_title = view_title
	_delete_recovery_restore_focus = restore_focus
	_delete_recovery_generation += 1
	_queue_delete_selection_recovery(controller)


func _active_property_owns_focus(controller: PVController) -> bool:
	if not is_instance_valid(_active_flow_graph_property) \
			or _active_flow_graph_property.get_edited_object() != controller:
		return false
	var viewport: Viewport = _active_flow_graph_property.get_viewport()
	var focus_owner: Control = viewport.gui_get_focus_owner() if viewport != null else null
	return is_instance_valid(focus_owner) \
		and (focus_owner == _active_flow_graph_property or _active_flow_graph_property.is_ancestor_of(focus_owner))


func _queue_delete_selection_recovery(controller: PVController) -> void:
	var pending_controller: PVController = _delete_recovery_controller.get_ref() as PVController \
		if _delete_recovery_controller != null else null
	if controller == null or controller != pending_controller:
		return
	call_deferred(&"_apply_delete_selection_recovery", _delete_recovery_generation)


func _apply_delete_selection_recovery(generation: int) -> void:
	if generation != _delete_recovery_generation or not is_instance_valid(_active_flow_graph_property):
		return
	var controller: PVController = _delete_recovery_controller.get_ref() as PVController \
		if _delete_recovery_controller != null else null
	if controller == null or _active_flow_graph_property.get_edited_object() != controller:
		return
	_active_flow_graph_property.apply_schema_3_delete_selection_recovery(
		controller,
		_delete_recovery_collection,
		_delete_recovery_deleted_id,
		_delete_recovery_replacement_id,
		_delete_recovery_view_title,
		_delete_recovery_restore_focus
	)


## Invalidates relays and deferred recovery owned by a controller removed from the edited scene.
func invalidate_controller(controller: PVController) -> void:
	if not is_instance_valid(controller):
		return
	var pending_controller: PVController = _delete_recovery_controller.get_ref() as PVController \
		if _delete_recovery_controller != null else null
	if pending_controller == controller:
		_clear_delete_selection_recovery()
	if not is_instance_valid(_active_flow_graph_property) \
			or _active_flow_graph_property.get_edited_object() != controller:
		return
	_active_flow_graph_property.invalidate_controller_context(controller)
	if _active_flow_graph_property.schema_3_variable_selection_changed.is_connected(
			_on_schema_3_variable_selection_changed):
		_active_flow_graph_property.schema_3_variable_selection_changed.disconnect(
			_on_schema_3_variable_selection_changed)
	if _active_flow_graph_property.schema_3_variable_editor_focus_requested.is_connected(
			_on_schema_3_variable_editor_focus_requested):
		_active_flow_graph_property.schema_3_variable_editor_focus_requested.disconnect(
			_on_schema_3_variable_editor_focus_requested)
	_active_flow_graph_property = null


func _on_flow_graph_property_tree_exited(property_instance_id: int) -> void:
	if is_instance_valid(_active_flow_graph_property) \
			and _active_flow_graph_property.get_instance_id() != property_instance_id:
		return
	_active_flow_graph_property = null
	# Inspector refreshes replace EditorProperty instances. Keep pending stable-ID
	# recovery until the replacement property consumes it or the controller/selection
	# explicitly invalidates it.


func _clear_delete_selection_recovery_for_other_selection(
		controller: PVController,
		selected_id: String
) -> void:
	var pending_controller: PVController = _delete_recovery_controller.get_ref() as PVController \
		if _delete_recovery_controller != null else null
	if pending_controller == null or controller != pending_controller:
		return
	if selected_id == _delete_recovery_deleted_id or selected_id == _delete_recovery_replacement_id:
		return
	_delete_recovery_controller = null
	_delete_recovery_deleted_id = ""
	_delete_recovery_replacement_id = ""
	_delete_recovery_view_title = ""
	_delete_recovery_restore_focus = false
	_delete_recovery_generation += 1


func _clear_delete_selection_recovery() -> void:
	_delete_recovery_controller = null
	_delete_recovery_deleted_id = ""
	_delete_recovery_replacement_id = ""
	_delete_recovery_view_title = ""
	_delete_recovery_restore_focus = false
	_delete_recovery_generation += 1


## Returns whether the current Inspector property belongs to this controller.
func is_active_controller(controller: PVController) -> bool:
	return is_instance_valid(controller) and is_instance_valid(_active_flow_graph_property) \
		and _active_flow_graph_property.get_edited_object() == controller


## Returns whether a property name is the FlowGraph reference intercepted by this plugin.
static func is_flow_graph_property(property_name: String) -> bool:
	return property_name == FLOW_GRAPH_PROPERTY
