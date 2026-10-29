@tool
extends FlowOutputBlock

@export var boolean_value: bool = true
@export_range(0, 10, 1) var ranged_int: int = 5
@export_enum("Low", "High") var enum_value: int = 1
@export_range(0.0, 1.0, 0.1) var ranged_float: float = 0.5
@export_multiline var message: String = "Hello from the manual SDK"
@export var plain_text: String = "Plain text"
@export var string_name_value: StringName = &"manual_name"
@export var unsupported_vector: Vector2 = Vector2.ONE
@export_storage var storage_only: String = "Storage only"
@export var _private_export: String = "Private"

var _runtime_value: String = "Runtime only"
var _editor_value: String = "Editor only"
var _read_only_value: String = "Read only"


func _get_property_list() -> Array[Dictionary]:
	return [
		{
			"name": "editor_only",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_SCRIPT_VARIABLE,
		},
		{
			"name": "runtime_only",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_SCRIPT_VARIABLE,
		},
		{
			"name": "read_only_value",
			"type": TYPE_STRING,
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE | PROPERTY_USAGE_SCRIPT_VARIABLE | PROPERTY_USAGE_READ_ONLY,
		},
	]


func _get(property: StringName) -> Variant:
	match property:
		&"editor_only":
			return _editor_value
		&"runtime_only":
			return _runtime_value
		&"read_only_value":
			return _read_only_value
	return null


func _set(property: StringName, value: Variant) -> bool:
	match property:
		&"editor_only":
			_editor_value = String(value)
			return true
		&"runtime_only":
			_runtime_value = String(value)
			return true
		&"read_only_value":
			_read_only_value = String(value)
			return true
	return false


func get_output_message() -> String:
	return message
