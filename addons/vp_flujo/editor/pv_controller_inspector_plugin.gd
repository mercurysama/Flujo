@tool
class_name PVControllerInspectorPlugin
extends EditorInspectorPlugin


const FLOW_GRAPH_PROPERTY: StringName = &"flow_graph"
const FLOW_GRAPH_INSPECTOR_PROPERTY := preload("res://addons/vp_flujo/editor/flow_graph_inspector_property.gd")

var _undo_redo: EditorUndoRedoManager


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
	add_property_editor(property_name, property, false, "Flow Graph")
	return true


## Returns whether a property name is the FlowGraph reference intercepted by this plugin.
static func is_flow_graph_property(property_name: String) -> bool:
	return property_name == FLOW_GRAPH_PROPERTY
