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
	add_property_editor(property_name, property, false, "Flow Graph")
	return true


func _on_schema_3_variable_selection_changed(
	controller: PVController,
	collection: FlowGraphEditorCommands.Collection,
	variable_id: String
) -> void:
	emit_signal(&"schema_3_variable_selection_changed", controller, collection, variable_id)


func _on_schema_3_variable_editor_focus_requested(controller: PVController, variable_id: String) -> void:
	emit_signal(&"schema_3_variable_editor_focus_requested", controller, variable_id)


func focus_schema_3_variable_list(controller: PVController, variable_id: String) -> void:
	if not is_instance_valid(_active_flow_graph_property):
		return
	if _active_flow_graph_property.get_edited_object() != controller:
		return
	_active_flow_graph_property.focus_schema_3_variable_list(controller, variable_id)


## Returns whether the current Inspector property belongs to this controller.
func is_active_controller(controller: PVController) -> bool:
	return is_instance_valid(_active_flow_graph_property) \
		and _active_flow_graph_property.get_edited_object() == controller


## Returns whether a property name is the FlowGraph reference intercepted by this plugin.
static func is_flow_graph_property(property_name: String) -> bool:
	return property_name == FLOW_GRAPH_PROPERTY
