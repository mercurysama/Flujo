@tool
class_name FlowAttributeDefinition
extends Resource

enum Storage { INSTANCE, CLASS }
enum Visibility { PUBLIC, PROTECTED, PRIVATE }
enum Mutability { MUTABLE, READONLY, CONST }

@export_storage var _internal_id: String = FlowId.create()
@export var display_name: String = "Attribute"
@export var enabled: bool = true
@export_multiline var user_note: String = ""
@export var storage: Storage = Storage.INSTANCE
@export var visibility: Visibility = Visibility.PUBLIC
@export var mutability: Mutability = Mutability.MUTABLE
@export var value_type: FlowVariableDefinition.ValueType = FlowVariableDefinition.ValueType.BOOL
@export var nullable: bool = false
@export var default_is_null: bool = false
@export var bool_value: bool = false
@export var int_value: int = 0
@export var float_value: float = 0.0
@export var string_value: String = ""
@export var vector2_value: Vector2 = Vector2.ZERO
@export var vector3_value: Vector3 = Vector3.ZERO
@export var color_value: Color = Color.WHITE

func get_internal_id() -> String:
	return _internal_id
