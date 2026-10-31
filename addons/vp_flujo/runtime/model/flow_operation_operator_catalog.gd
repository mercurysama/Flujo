@tool
## Exact, non-coercing catalog for Operation Tok operators.
class_name FlowOperationOperatorCatalog
extends RefCounted


const OPERATOR_ADD: StringName = &"add"
const OPERATOR_SUBTRACT: StringName = &"subtract"
const OPERATOR_MULTIPLY: StringName = &"multiply"
const OPERATOR_DIVIDE: StringName = &"divide"
const OPERATOR_MODULO: StringName = &"modulo"
const OPERATOR_CONCAT: StringName = &"concat"


static func operator_ids() -> Array[StringName]:
	return [
		OPERATOR_ADD,
		OPERATOR_SUBTRACT,
		OPERATOR_MULTIPLY,
		OPERATOR_DIVIDE,
		OPERATOR_MODULO,
		OPERATOR_CONCAT,
	]


static func has_operator(operator_id: StringName) -> bool:
	return operator_ids().has(operator_id)


static func get_descriptor(operator_id: StringName) -> Dictionary:
	match operator_id:
		OPERATOR_ADD:
			return _descriptor(operator_id, "Add", "+", [
				_signature([Variant.Type.TYPE_INT, Variant.Type.TYPE_INT], Variant.Type.TYPE_INT),
				_signature([Variant.Type.TYPE_FLOAT, Variant.Type.TYPE_FLOAT], Variant.Type.TYPE_FLOAT),
				_signature([Variant.Type.TYPE_VECTOR2, Variant.Type.TYPE_VECTOR2], Variant.Type.TYPE_VECTOR2),
				_signature([Variant.Type.TYPE_VECTOR3, Variant.Type.TYPE_VECTOR3], Variant.Type.TYPE_VECTOR3),
			])
		OPERATOR_SUBTRACT:
			return _descriptor(operator_id, "Subtract", "-", [
				_signature([Variant.Type.TYPE_INT, Variant.Type.TYPE_INT], Variant.Type.TYPE_INT),
				_signature([Variant.Type.TYPE_FLOAT, Variant.Type.TYPE_FLOAT], Variant.Type.TYPE_FLOAT),
				_signature([Variant.Type.TYPE_VECTOR2, Variant.Type.TYPE_VECTOR2], Variant.Type.TYPE_VECTOR2),
				_signature([Variant.Type.TYPE_VECTOR3, Variant.Type.TYPE_VECTOR3], Variant.Type.TYPE_VECTOR3),
			])
		OPERATOR_MULTIPLY:
			return _descriptor(operator_id, "Multiply", "*", [
				_signature([Variant.Type.TYPE_INT, Variant.Type.TYPE_INT], Variant.Type.TYPE_INT),
				_signature([Variant.Type.TYPE_FLOAT, Variant.Type.TYPE_FLOAT], Variant.Type.TYPE_FLOAT),
			])
		OPERATOR_DIVIDE:
			return _descriptor(operator_id, "Divide", "/", [
				_signature([Variant.Type.TYPE_INT, Variant.Type.TYPE_INT], Variant.Type.TYPE_INT),
				_signature([Variant.Type.TYPE_FLOAT, Variant.Type.TYPE_FLOAT], Variant.Type.TYPE_FLOAT),
			])
		OPERATOR_MODULO:
			return _descriptor(operator_id, "Modulo", "%", [
				_signature([Variant.Type.TYPE_INT, Variant.Type.TYPE_INT], Variant.Type.TYPE_INT),
			])
		OPERATOR_CONCAT:
			return _descriptor(operator_id, "Concatenate", "+", [
				_signature([Variant.Type.TYPE_STRING, Variant.Type.TYPE_STRING], Variant.Type.TYPE_STRING),
			])
	return {}


static func get_signatures(operator_id: StringName) -> Array[Dictionary]:
	return (get_descriptor(operator_id).get("signatures", []) as Array).duplicate(true)


static func find_signature(
		operator_id: StringName,
		operand_types: Array[Variant.Type]
) -> Dictionary:
	for signature: Dictionary in get_signatures(operator_id):
		var expected: Array = signature.get("operand_types", []) as Array
		if expected.size() != operand_types.size():
			continue
		var matches: bool = true
		for index: int in operand_types.size():
			if int(expected[index]) != int(operand_types[index]):
				matches = false
				break
		if matches:
			return signature.duplicate(true)
	return {}


static func symbol(operator_id: StringName) -> String:
	return String(get_descriptor(operator_id).get("symbol", ""))


static func display_label(operator_id: StringName) -> String:
	return String(get_descriptor(operator_id).get("display_label", ""))


static func _descriptor(
		operator_id: StringName,
		label: String,
		symbol_value: String,
		signatures: Array[Dictionary]
) -> Dictionary:
	return {
		"operator_id": operator_id,
		"display_label": label,
		"symbol": symbol_value,
		"arity": 2,
		"signatures": signatures,
	}


static func _signature(
		operand_types: Array[Variant.Type],
		produced_type: Variant.Type
) -> Dictionary:
	return {
		"operand_types": operand_types,
		"produced_type": produced_type,
	}
