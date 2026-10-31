@tool
## Runtime-safe, read-only catalog for the Step 2C-B expression operators.
class_name FlowExpressionOperatorCatalog
extends RefCounted


const OPERATOR_ADD: StringName = &"add"
const OPERATOR_SUBTRACT: StringName = &"subtract"
const OPERATOR_MULTIPLY: StringName = &"multiply"
const OPERATOR_DIVIDE: StringName = &"divide"
const OPERATOR_MODULO: StringName = &"modulo"
const OPERATOR_CONCAT: StringName = &"concat"
const OPERATOR_GREATER_THAN: StringName = &"greater_than"
const OPERATOR_EQUAL: StringName = &"equal"
const OPERATOR_AND: StringName = &"and"


static func operator_ids() -> Array[StringName]:
	return [
		OPERATOR_ADD, OPERATOR_SUBTRACT, OPERATOR_MULTIPLY,
		OPERATOR_DIVIDE, OPERATOR_MODULO, OPERATOR_CONCAT,
		OPERATOR_GREATER_THAN, OPERATOR_EQUAL, OPERATOR_AND,
	]


static func has_operator(operator_id: StringName) -> bool:
	return operator_ids().has(operator_id)


## Returns a detached descriptor. The catalog has no mutable global registry.
static func get_descriptor(operator_id: StringName) -> Dictionary:
	match operator_id:
		OPERATOR_ADD:
			return _descriptor(OPERATOR_ADD, "Add", "+", [
				_signature([Variant.Type.TYPE_INT, Variant.Type.TYPE_INT], Variant.Type.TYPE_INT),
				_signature([Variant.Type.TYPE_FLOAT, Variant.Type.TYPE_FLOAT], Variant.Type.TYPE_FLOAT),
				_signature([Variant.Type.TYPE_STRING, Variant.Type.TYPE_STRING], Variant.Type.TYPE_STRING),
			])
		OPERATOR_SUBTRACT:
			return _descriptor(OPERATOR_SUBTRACT, "Subtract", "-", [
				_signature([Variant.Type.TYPE_INT, Variant.Type.TYPE_INT], Variant.Type.TYPE_INT),
				_signature([Variant.Type.TYPE_FLOAT, Variant.Type.TYPE_FLOAT], Variant.Type.TYPE_FLOAT),
			])
		OPERATOR_MULTIPLY:
			return _descriptor(OPERATOR_MULTIPLY, "Multiply", "*", [
				_signature([Variant.Type.TYPE_INT, Variant.Type.TYPE_INT], Variant.Type.TYPE_INT),
				_signature([Variant.Type.TYPE_FLOAT, Variant.Type.TYPE_FLOAT], Variant.Type.TYPE_FLOAT),
			])
		OPERATOR_DIVIDE:
			return _descriptor(OPERATOR_DIVIDE, "Divide", "/", [
				_signature([Variant.Type.TYPE_INT, Variant.Type.TYPE_INT], Variant.Type.TYPE_INT),
				_signature([Variant.Type.TYPE_FLOAT, Variant.Type.TYPE_FLOAT], Variant.Type.TYPE_FLOAT),
			])
		OPERATOR_MODULO:
			return _descriptor(OPERATOR_MODULO, "Modulo", "%", [
				_signature([Variant.Type.TYPE_INT, Variant.Type.TYPE_INT], Variant.Type.TYPE_INT),
			])
		OPERATOR_CONCAT:
			return _descriptor(OPERATOR_CONCAT, "Concatenate", "+", [
				_signature([Variant.Type.TYPE_STRING, Variant.Type.TYPE_STRING], Variant.Type.TYPE_STRING),
			])
		OPERATOR_GREATER_THAN:
			return _descriptor(OPERATOR_GREATER_THAN, "Greater Than", ">", [
				_signature([Variant.Type.TYPE_INT, Variant.Type.TYPE_INT], Variant.Type.TYPE_BOOL),
				_signature([Variant.Type.TYPE_FLOAT, Variant.Type.TYPE_FLOAT], Variant.Type.TYPE_BOOL),
			])
		OPERATOR_EQUAL:
			return _descriptor(OPERATOR_EQUAL, "Equal", "==", [
				_signature([Variant.Type.TYPE_INT, Variant.Type.TYPE_INT], Variant.Type.TYPE_BOOL),
				_signature([Variant.Type.TYPE_FLOAT, Variant.Type.TYPE_FLOAT], Variant.Type.TYPE_BOOL),
				_signature([Variant.Type.TYPE_BOOL, Variant.Type.TYPE_BOOL], Variant.Type.TYPE_BOOL),
				_signature([Variant.Type.TYPE_STRING, Variant.Type.TYPE_STRING], Variant.Type.TYPE_BOOL),
			])
		OPERATOR_AND:
			return _descriptor(OPERATOR_AND, "And", "AND", [
				_signature([Variant.Type.TYPE_BOOL, Variant.Type.TYPE_BOOL], Variant.Type.TYPE_BOOL),
			])
	return {}


static func get_descriptors() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for operator_id: StringName in operator_ids():
		result.append(get_descriptor(operator_id))
	return result


static func get_signatures(operator_id: StringName) -> Array[Dictionary]:
	var descriptor: Dictionary = get_descriptor(operator_id)
	return (descriptor.get("signatures", []) as Array).duplicate(true)


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
		display_label_value: String,
		symbol_value: String,
		signatures: Array[Dictionary]
) -> Dictionary:
	return {
		"operator_id": operator_id,
		"display_label": display_label_value,
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
