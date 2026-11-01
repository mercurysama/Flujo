@tool
class_name FlowVariableDefinition
extends Resource

enum Scope {
	LOCAL,
	GLOBAL,
}

enum Binding {
	OWN_VALUE,
	GLOBAL_REFERENCE,
}

enum ValueType {
	BOOL,
	INT,
	FLOAT,
	STRING,
	VECTOR2,
	VECTOR3,
	COLOR,
	ARRAY,
	DICTIONARY,
	RESOURCE,
}


static func is_valid_scope(value: int) -> bool:
	return value == Scope.LOCAL or value == Scope.GLOBAL


static func is_valid_binding(value: int) -> bool:
	return value == Binding.OWN_VALUE or value == Binding.GLOBAL_REFERENCE


static func is_valid_value_type(value: int) -> bool:
	return value == ValueType.BOOL \
			or value == ValueType.INT \
			or value == ValueType.FLOAT \
			or value == ValueType.STRING \
			or value == ValueType.VECTOR2 \
			or value == ValueType.VECTOR3 \
			or value == ValueType.COLOR 			or value == ValueType.ARRAY 			or value == ValueType.DICTIONARY 			or value == ValueType.RESOURCE


## The canonical variable taxonomy maps directly to Godot Variant types.
## Value-source consumers use this mapping instead of defining a parallel enum.
static func to_variant_type(value: int) -> Variant.Type:
	match value:
		ValueType.BOOL:
			return Variant.Type.TYPE_BOOL
		ValueType.INT:
			return Variant.Type.TYPE_INT
		ValueType.FLOAT:
			return Variant.Type.TYPE_FLOAT
		ValueType.STRING:
			return Variant.Type.TYPE_STRING
		ValueType.VECTOR2:
			return Variant.Type.TYPE_VECTOR2
		ValueType.VECTOR3:
			return Variant.Type.TYPE_VECTOR3
		ValueType.COLOR:
			return Variant.Type.TYPE_COLOR
		ValueType.ARRAY:
			return Variant.Type.TYPE_ARRAY
		ValueType.DICTIONARY:
			return Variant.Type.TYPE_DICTIONARY
		ValueType.RESOURCE:
			return Variant.Type.TYPE_OBJECT
	return Variant.Type.TYPE_NIL


static func value_type_display_name(value: int) -> String:
	match value:
		ValueType.BOOL:
			return "bool"
		ValueType.INT:
			return "int"
		ValueType.FLOAT:
			return "float"
		ValueType.STRING:
			return "String"
		ValueType.VECTOR2:
			return "Vector2"
		ValueType.VECTOR3:
			return "Vector3"
		ValueType.COLOR:
			return "Color"
		ValueType.ARRAY:
			return "Array"
		ValueType.DICTIONARY:
			return "Dictionary"
		ValueType.RESOURCE:
			return "Resource"
	return "unknown(%d)" % value


func get_declared_variant_type() -> Variant.Type:
	return to_variant_type(value_type)


static func is_complex_value_type(value: int) -> bool:
	return value == ValueType.ARRAY 		or value == ValueType.DICTIONARY 		or value == ValueType.RESOURCE


static func expected_complex_source_kind(value: int) -> StringName:
	match value:
		ValueType.ARRAY:
			return FlowValueSource.SOURCE_KIND_ARRAY
		ValueType.DICTIONARY:
			return FlowValueSource.SOURCE_KIND_DICTIONARY
		ValueType.RESOURCE:
			return FlowValueSource.SOURCE_KIND_RESOURCE_REF
	return &""


static func default_complex_source(value: int) -> FlowValueSource:
	match value:
		ValueType.ARRAY:
			return FlowArrayValueSource.new()
		ValueType.DICTIONARY:
			return FlowDictionaryValueSource.new()
		ValueType.RESOURCE:
			return FlowResourceRefValueSource.placeholder(&"Resource")
	return null


@export_storage var _internal_id: String = FlowId.create()

@export var display_name: String = "Variable"
@export var scope: Scope = Scope.LOCAL
@export var binding: Binding = Binding.OWN_VALUE
@export var value_type: ValueType = ValueType.BOOL
@export var bool_value: bool = false
@export var int_value: int = 0
@export var float_value: float = 0.0
@export var string_value: String = ""
@export var vector2_value: Vector2 = Vector2.ZERO
@export var vector3_value: Vector3 = Vector3.ZERO
@export var color_value: Color = Color.WHITE
## Owned default source for ARRAY / DICTIONARY / RESOURCE variables.
@export_storage var complex_value_source: FlowValueSource
@export var persistent: bool = false
@export_multiline var user_note: String = ""

@export_storage var global_variable_id: String = ""
@export_storage var owner_container_id: String = ""

func get_internal_id() -> String:
	return _internal_id

func get_default_value_result(
		context: FlowValueResolutionContext = null
) -> FlowValueResult:
	match value_type:
		ValueType.BOOL:
			return FlowValueResult.ok(bool_value, Variant.Type.TYPE_BOOL)
		ValueType.INT:
			return FlowValueResult.ok(int_value, Variant.Type.TYPE_INT)
		ValueType.FLOAT:
			return FlowValueResult.ok(float_value, Variant.Type.TYPE_FLOAT)
		ValueType.STRING:
			return FlowValueResult.ok(string_value, Variant.Type.TYPE_STRING)
		ValueType.VECTOR2:
			return FlowValueResult.ok(vector2_value, Variant.Type.TYPE_VECTOR2)
		ValueType.VECTOR3:
			return FlowValueResult.ok(vector3_value, Variant.Type.TYPE_VECTOR3)
		ValueType.COLOR:
			return FlowValueResult.ok(color_value, Variant.Type.TYPE_COLOR)

	if not is_complex_value_type(value_type) or complex_value_source == null:
		return FlowValueResult.fail(
			get_declared_variant_type(),
			FlowDiagnostic.new(
				FlowDiagnostic.CODE_VARIABLE_COMPLEX_SOURCE_MISSING,
				FlowDiagnostic.Severity.ERROR,
				"Complex variable has no default ValueSource.",
				"variable.complex_value_source",
				_internal_id
			)
		)

	var expected_kind: StringName = expected_complex_source_kind(value_type)
	if complex_value_source.get_source_kind() != expected_kind 			or complex_value_source.get_value_type() != get_declared_variant_type():
		return FlowValueResult.fail(
			get_declared_variant_type(),
			FlowDiagnostic.new(
				FlowDiagnostic.CODE_VARIABLE_COMPLEX_SOURCE_TYPE_MISMATCH,
				FlowDiagnostic.Severity.ERROR,
				"Complex variable default source does not match its declared type.",
				"variable.complex_value_source",
				_internal_id
			)
		)
	return complex_value_source.resolve(context)


func duplicate_with_new_id() -> FlowVariableDefinition:
	var copy: FlowVariableDefinition = duplicate(false) as FlowVariableDefinition
	copy._internal_id = FlowId.create()
	copy.complex_value_source = complex_value_source.duplicate_with_new_id() 		if complex_value_source != null else null
	return copy
