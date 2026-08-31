@tool
class_name PVControllerInspectorPlugin
extends EditorInspectorPlugin


const FLOW_GRAPH_PROPERTY: StringName = &"flow_graph"
const FLOW_GRAPH_INSPECTOR_PROPERTY := preload("res://addons/vp_flujo/editor/flow_graph_inspector_property.gd")


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
	if property_name != FLOW_GRAPH_PROPERTY:
		return false

	var property: FlowGraphInspectorProperty = FLOW_GRAPH_INSPECTOR_PROPERTY.new()
	add_property_editor(property_name, property, true, "Flow Graph")
	return true
