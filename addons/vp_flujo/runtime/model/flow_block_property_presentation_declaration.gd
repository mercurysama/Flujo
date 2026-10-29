@tool
class_name FlowBlockPropertyPresentationDeclaration
extends RefCounted

## One validated, data-only declaration from block_property_presentation.json.

const PRESENTATION_AUTO: StringName = &"auto"

var property_name: StringName = &""
var declaration_index: int = -1
var has_label: bool = false
var label: String = ""
var has_order: bool = false
var order: int = 0
var has_group: bool = false
var group: String = ""
var has_tooltip: bool = false
var tooltip: String = ""
var has_presentation: bool = false
var presentation: StringName = PRESENTATION_AUTO


func has_safe_presentation_values() -> bool:
	return has_label or has_order or has_group or has_tooltip or has_presentation
