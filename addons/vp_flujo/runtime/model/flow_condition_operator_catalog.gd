@tool
## Exact, non-coercing MVP catalog for Condition Tok comparisons/connectors.
class_name FlowConditionOperatorCatalog
extends RefCounted


const OPERATOR_EQUAL: StringName = &"equal"
const OPERATOR_NOT_EQUAL: StringName = &"not_equal"
const OPERATOR_GREATER_THAN: StringName = &"greater_than"
const OPERATOR_LESS_THAN: StringName = &"less_than"
const OPERATOR_GREATER_OR_EQUAL: StringName = &"greater_or_equal"
const OPERATOR_LESS_OR_EQUAL: StringName = &"less_or_equal"

const CONNECTOR_AND: StringName = &"and"
const CONNECTOR_OR: StringName = &"or"


static func comparison_ids() -> Array[StringName]:
	return [
		OPERATOR_EQUAL,
		OPERATOR_NOT_EQUAL,
		OPERATOR_GREATER_THAN,
		OPERATOR_LESS_THAN,
		OPERATOR_GREATER_OR_EQUAL,
		OPERATOR_LESS_OR_EQUAL,
	]


static func connector_ids() -> Array[StringName]:
	return [CONNECTOR_AND, CONNECTOR_OR]


static func has_operator(operator_id: StringName) -> bool:
	return comparison_ids().has(operator_id)


static func has_connector(connector_id: StringName) -> bool:
	return connector_ids().has(connector_id)


static func symbol(operator_id: StringName) -> String:
	match operator_id:
		OPERATOR_EQUAL:
			return "=="
		OPERATOR_NOT_EQUAL:
			return "!="
		OPERATOR_GREATER_THAN:
			return ">"
		OPERATOR_LESS_THAN:
			return "<"
		OPERATOR_GREATER_OR_EQUAL:
			return ">="
		OPERATOR_LESS_OR_EQUAL:
			return "<="
	return ""


static func connector_symbol(connector_id: StringName) -> String:
	match connector_id:
		CONNECTOR_AND:
			return "AND"
		CONNECTOR_OR:
			return "OR"
	return ""


static func get_descriptor(operator_id: StringName) -> Dictionary:
	if not has_operator(operator_id):
		return {}
	var signatures: Array[Dictionary] = []
	for signature: Array[Variant.Type] in _signatures(operator_id):
		signatures.append({
			"left_type": signature[0],
			"right_type": signature[1],
			"produced_type": Variant.Type.TYPE_BOOL,
		})
	return {
		"operator_id": operator_id,
		"symbol": symbol(operator_id),
		"signatures": signatures,
	}


static func find_signature(
		operator_id: StringName,
		left_type: Variant.Type,
		right_type: Variant.Type
) -> Dictionary:
	for signature: Dictionary in get_descriptor(operator_id).get("signatures", []):
		if signature.get("left_type", Variant.Type.TYPE_NIL) == left_type \
				and signature.get("right_type", Variant.Type.TYPE_NIL) == right_type:
			return signature.duplicate(true)
	return {}


static func _signatures(operator_id: StringName) -> Array[Array]:
	var equality: Array[Array] = [
		[Variant.Type.TYPE_INT, Variant.Type.TYPE_INT],
		[Variant.Type.TYPE_FLOAT, Variant.Type.TYPE_FLOAT],
		[Variant.Type.TYPE_STRING, Variant.Type.TYPE_STRING],
		[Variant.Type.TYPE_BOOL, Variant.Type.TYPE_BOOL],
		[Variant.Type.TYPE_BOOL, Variant.Type.TYPE_INT],
		[Variant.Type.TYPE_INT, Variant.Type.TYPE_BOOL],
	]
	if operator_id == OPERATOR_EQUAL or operator_id == OPERATOR_NOT_EQUAL:
		return equality
	return [
		[Variant.Type.TYPE_INT, Variant.Type.TYPE_INT],
		[Variant.Type.TYPE_FLOAT, Variant.Type.TYPE_FLOAT],
	]
