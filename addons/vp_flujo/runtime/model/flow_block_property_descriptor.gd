@tool
class_name FlowBlockPropertyDescriptor
extends RefCounted

## UI-independent description of one eligible FlowBlock property.
##
## The descriptor does not retain the block, create a widget, or provide a
## setter. A consumer is responsible for applying its own access policy.

enum Classification {
	GENERIC,
	EXPLICIT_BUILT_IN,
}

const PRESENTATION_BOOLEAN: StringName = &"boolean"
const PRESENTATION_INTEGER: StringName = &"integer"
const PRESENTATION_FLOAT: StringName = &"float"
const PRESENTATION_TEXT: StringName = &"text"
const PRESENTATION_STRING_NAME: StringName = &"string_name"
const PRESENTATION_RANGE: StringName = &"range"
const PRESENTATION_ENUM: StringName = &"enum"
const PRESENTATION_MULTILINE: StringName = &"multiline"

const SOURCE_REFLECTION: StringName = &"reflection"
const SOURCE_METADATA: StringName = &"metadata"
const SOURCE_REFLECTION_AND_METADATA: StringName = &"reflection_and_metadata"

var property_name: StringName = &""
var model_type: Variant.Type = TYPE_NIL
var usage: int = 0
var hint: int = PROPERTY_HINT_NONE
var hint_string: String = ""
var editable: bool = false
var current_value: Variant
var label: String = ""
var has_order: bool = false
var order: int = 0
var group: String = ""
var tooltip: String = ""
var presentation_kind: StringName = &""
var presentation_source: StringName = SOURCE_REFLECTION
var classification: Classification = Classification.GENERIC


func is_explicit_built_in() -> bool:
	return classification == Classification.EXPLICIT_BUILT_IN


func is_generic_candidate() -> bool:
	return classification == Classification.GENERIC
