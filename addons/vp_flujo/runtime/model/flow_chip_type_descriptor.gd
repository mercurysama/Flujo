@tool
## Runtime-safe semantic description of one reusable typed chip kind.
class_name FlowChipTypeDescriptor
extends RefCounted


const CATEGORY_LITERAL: StringName = &"literal"
const LABEL_STRATEGY_VALUE: StringName = &"value"
const STYLE_ROLE_LITERAL: StringName = &"literal"

const VARIANT_TYPE_BOOL: Variant.Type = Variant.Type.TYPE_BOOL
const VARIANT_TYPE_INT: Variant.Type = Variant.Type.TYPE_INT
const VARIANT_TYPE_FLOAT: Variant.Type = Variant.Type.TYPE_FLOAT
const VARIANT_TYPE_STRING: Variant.Type = Variant.Type.TYPE_STRING
const VARIANT_TYPE_STRING_NAME: Variant.Type = Variant.Type.TYPE_STRING_NAME
const VARIANT_TYPE_VECTOR2: Variant.Type = Variant.Type.TYPE_VECTOR2
const VARIANT_TYPE_VECTOR2I: Variant.Type = Variant.Type.TYPE_VECTOR2I
const VARIANT_TYPE_VECTOR3: Variant.Type = Variant.Type.TYPE_VECTOR3
const VARIANT_TYPE_VECTOR3I: Variant.Type = Variant.Type.TYPE_VECTOR3I
const VARIANT_TYPE_COLOR: Variant.Type = Variant.Type.TYPE_COLOR
const VARIANT_TYPE_NODE_PATH: Variant.Type = Variant.Type.TYPE_NODE_PATH


## Stable semantic identity. This is not a display name or an array index.
var type_id: StringName = &""
## Localized/display-ready name selected by the host/editor.
var display_name: String = ""
## Reusable semantic category, independent from the visual widget.
var category: StringName = &""
## Tells a future consumer where the chip label comes from.
var label_strategy: StringName = &""
## Theme-mappable semantic role; visual mapping remains with the host.
var semantic_style_role: StringName = &""
## Whether a future editor may offer editing for this chip kind.
var editable: bool = false
## Variant.Type values that a generic editor may offer for this chip.
var supported_variant_types: Array[Variant.Type] = []


func supports_variant_type(candidate: Variant.Type) -> bool:
	return supported_variant_types.has(candidate)


func get_supported_variant_types() -> Array[Variant.Type]:
	return supported_variant_types.duplicate()


## Defaults are part of the semantic contract, not an editor-side conversion.
func get_default_value(candidate: Variant.Type) -> Variant:
	return default_value_for_type(candidate)


static func default_value_for_type(candidate: Variant.Type) -> Variant:
	match candidate:
		VARIANT_TYPE_BOOL:
			return false
		VARIANT_TYPE_INT:
			return 0
		VARIANT_TYPE_FLOAT:
			return 0.0
		VARIANT_TYPE_STRING:
			return ""
		VARIANT_TYPE_STRING_NAME:
			return StringName()
		VARIANT_TYPE_VECTOR2:
			return Vector2.ZERO
		VARIANT_TYPE_VECTOR2I:
			return Vector2i.ZERO
		VARIANT_TYPE_VECTOR3:
			return Vector3.ZERO
		VARIANT_TYPE_VECTOR3I:
			return Vector3i.ZERO
		VARIANT_TYPE_COLOR:
			return Color.WHITE
		VARIANT_TYPE_NODE_PATH:
			return NodePath()
	return null


static func variant_type_display_name(candidate: Variant.Type) -> String:
	match candidate:
		VARIANT_TYPE_BOOL:
			return "bool"
		VARIANT_TYPE_INT:
			return "int"
		VARIANT_TYPE_FLOAT:
			return "float"
		VARIANT_TYPE_STRING:
			return "String"
		VARIANT_TYPE_STRING_NAME:
			return "StringName"
		VARIANT_TYPE_VECTOR2:
			return "Vector2"
		VARIANT_TYPE_VECTOR2I:
			return "Vector2i"
		VARIANT_TYPE_VECTOR3:
			return "Vector3"
		VARIANT_TYPE_VECTOR3I:
			return "Vector3i"
		VARIANT_TYPE_COLOR:
			return "Color"
		VARIANT_TYPE_NODE_PATH:
			return "NodePath"
	return "unknown(%d)" % int(candidate)
