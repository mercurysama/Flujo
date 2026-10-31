@tool
## Runtime-safe typed literal implementation of FlowValueSource.
class_name FlowLiteralValueSource
extends FlowValueSource


const SOURCE_KIND: StringName = FlowValueSource.SOURCE_KIND_LITERAL
const TYPE_BOOL: Variant.Type = Variant.Type.TYPE_BOOL
const TYPE_INT: Variant.Type = Variant.Type.TYPE_INT
const TYPE_FLOAT: Variant.Type = Variant.Type.TYPE_FLOAT
const TYPE_STRING: Variant.Type = Variant.Type.TYPE_STRING
const TYPE_STRING_NAME: Variant.Type = Variant.Type.TYPE_STRING_NAME

@export_storage var value_type: Variant.Type = Variant.Type.TYPE_NIL
@export_storage var value: Variant


func _init(new_value_type: Variant.Type = Variant.Type.TYPE_NIL, new_value: Variant = null) -> void:
	value_type = new_value_type
	value = new_value


func get_source_kind() -> StringName:
	return SOURCE_KIND


func get_value_type() -> Variant.Type:
	return value_type


func get_value() -> Variant:
	return value


func resolve_value() -> Variant:
	return value


func resolve(_context: Variant = null) -> FlowValueResult:
	if not is_valid():
		return FlowValueResult.fail(
			value_type,
			FlowDiagnostic.new(
				FlowDiagnostic.CODE_INVALID_LITERAL_VALUE_TYPE,
				FlowDiagnostic.Severity.ERROR,
				"Literal value source is invalid.",
				"value_source",
				_source_id
			)
		)
	return FlowValueResult.ok(value, value_type)


func is_valid() -> bool:
	return FlowId.is_valid(_source_id) and is_valid_literal(value_type, value)


func can_set_literal(candidate_type: Variant.Type, candidate_value: Variant) -> bool:
	return is_valid_literal(candidate_type, candidate_value)


func set_literal(candidate_type: Variant.Type, candidate_value: Variant) -> bool:
	if not can_set_literal(candidate_type, candidate_value):
		return false
	value_type = candidate_type
	value = candidate_value
	return true


func get_runtime_text() -> String:
	return format_runtime_text(value_type, value) if is_valid() else ""


func validate_structure(result: FlowValidationResult, element_path: String) -> void:
	super.validate_structure(result, element_path)
	if result == null:
		return
	if value_type == Variant.Type.TYPE_NIL:
		_add_error(
			result,
			FlowDiagnostic.CODE_LITERAL_TYPE_NIL,
			"Literal value source cannot use TYPE_NIL.",
			element_path + ".value_type",
			_source_id
		)
	elif not is_allowed_type(value_type):
		_add_error(
			result,
			FlowDiagnostic.CODE_INVALID_LITERAL_VALUE_TYPE,
			"Literal value source uses an unsupported Variant.Type: %d." % int(value_type),
			element_path + ".value_type",
			_source_id
		)
	elif typeof(value) != value_type:
		_add_error(
			result,
			FlowDiagnostic.CODE_LITERAL_VALUE_TYPE_MISMATCH,
			"Literal value source explicit type does not match the stored Variant type.",
			element_path + ".value",
			_source_id
		)
	elif value_type == TYPE_FLOAT and not is_finite(float(value)):
		_add_error(
			result,
			FlowDiagnostic.CODE_LITERAL_FLOAT_NOT_FINITE,
			"Literal value source float must be finite.",
			element_path + ".value",
			_source_id
		)


static func is_allowed_type(candidate: Variant.Type) -> bool:
	return candidate == TYPE_BOOL or candidate == TYPE_INT or candidate == TYPE_FLOAT \
		or candidate == TYPE_STRING or candidate == TYPE_STRING_NAME


static func value_matches_declared_type(
		candidate_type: Variant.Type,
		candidate_value: Variant
) -> bool:
	return is_allowed_type(candidate_type) and typeof(candidate_value) == candidate_type


static func has_finite_float(
		candidate_type: Variant.Type,
		candidate_value: Variant
) -> bool:
	return candidate_type != TYPE_FLOAT \
		or typeof(candidate_value) != TYPE_FLOAT \
		or is_finite(float(candidate_value))


## One exact literal rule set is shared by LiteralValueSource and the legacy
## LiteralValueSegment adapter.
static func is_valid_literal(
		candidate_type: Variant.Type,
		candidate_value: Variant
) -> bool:
	return value_matches_declared_type(candidate_type, candidate_value) \
		and has_finite_float(candidate_type, candidate_value)


static func format_runtime_text(candidate_type: Variant.Type, candidate_value: Variant) -> String:
	if candidate_type == TYPE_BOOL:
		return "true" if bool(candidate_value) else "false"
	if candidate_type == TYPE_INT:
		return str(int(candidate_value))
	if candidate_type == TYPE_FLOAT:
		return str(float(candidate_value))
	if candidate_type == TYPE_STRING or candidate_type == TYPE_STRING_NAME:
		return String(candidate_value)
	return ""


static func _add_error(
		result: FlowValidationResult,
		code: StringName,
		message: String,
		element_path: String,
		related_id: String = ""
) -> void:
	result.add_diagnostic(FlowDiagnostic.new(
		code,
		FlowDiagnostic.Severity.ERROR,
		message,
		element_path,
		related_id
	))
