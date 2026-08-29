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
}

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
@export var persistent: bool = false
@export_multiline var user_note: String = ""

@export_storage var global_variable_id: String = ""
@export_storage var owner_container_id: String = ""

func get_internal_id() -> String:
	return _internal_id

func duplicate_with_new_id() -> FlowVariableDefinition:
	var copy: FlowVariableDefinition = duplicate(false) as FlowVariableDefinition
	copy._internal_id = FlowId.create()
	return copy
