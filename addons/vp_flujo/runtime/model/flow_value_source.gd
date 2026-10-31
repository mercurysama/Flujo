@tool
## Runtime-safe source of one executable chip value.
class_name FlowValueSource
extends Resource


## Stable source-kind vocabulary reserved for the reusable source boundary.
## Only Literal is implemented in this step; the remaining kinds are names,
## not concrete source implementations.
const SOURCE_KIND_LITERAL: StringName = &"literal"
const SOURCE_KIND_VARIABLE_REF: StringName = &"variable_ref"
const SOURCE_KIND_EXPRESSION: StringName = &"expression"
const SOURCE_KIND_CONDITION: StringName = &"condition"
const SOURCE_KIND_NODE_PROPERTY_REF: StringName = &"node_property_ref"

@export_storage var _source_id: String = FlowId.create()

var source_id: String:
	get:
		return _source_id
	set(value):
		_source_id = value


func get_source_id() -> String:
	return _source_id


func get_id() -> String:
	return _source_id


func get_internal_id() -> String:
	return _source_id


## Stable semantic kind, independent from a display label or editor widget.
func get_source_kind() -> StringName:
	return &""


## Alias for consumers that call the semantic kind a source type.
func get_source_type() -> StringName:
	return get_source_kind()


## The exact Variant.Type produced by this source.
func get_value_type() -> Variant.Type:
	return Variant.Type.TYPE_NIL


## Alias that makes the produced-value boundary explicit to callers.
func get_produced_value_type() -> Variant.Type:
	return get_value_type()


## Returns the authored value without applying implicit conversion.
func get_value() -> Variant:
	return null


## Runtime resolution boundary. Concrete sources may override this when
## resolving a future reference requires runtime context.
func resolve_value() -> Variant:
	return get_value()


## Future runtime boundary. Concrete sources may resolve against a runtime
## context; sources without that implementation return a structured failure.
func resolve(_context: Variant = null) -> FlowValueResult:
	return FlowValueResult.fail(
		get_value_type(),
		FlowDiagnostic.new(
			FlowDiagnostic.CODE_VALUE_RESOLUTION_DEFERRED,
			FlowDiagnostic.Severity.ERROR,
			"ValueSource runtime resolution is deferred.",
			"value_source",
			_source_id
		)
	)


func is_valid() -> bool:
	return false


## Validates only source structure and identity. Consumers may add the
## source-specific invalid-value diagnostic without changing this resource.
func validate_structure(result: FlowValidationResult, element_path: String) -> void:
	if result == null:
		return
	if _source_id.is_empty():
		_add_error(
			result,
			FlowDiagnostic.CODE_EMPTY_VALUE_SOURCE_ID,
			"FlowValueSource ID is empty.",
			element_path + ".source_id"
		)
	elif not FlowId.is_valid(_source_id):
		_add_error(
			result,
			FlowDiagnostic.CODE_INVALID_VALUE_SOURCE_ID,
			"FlowValueSource ID is not a valid FlowId.",
			element_path + ".source_id",
			_source_id
		)
	if get_source_kind().is_empty():
		_add_error(
			result,
			FlowDiagnostic.CODE_INVALID_VALUE_SOURCE_KIND,
			"FlowValueSource kind is empty.",
			element_path + ".source_kind",
			_source_id
		)


## Future validators can use the shorter name without changing this boundary.
func validate(result: FlowValidationResult, element_path: String) -> void:
	validate_structure(result, element_path)


## Duplicates this source with a fresh persistent source identity.
func duplicate_with_new_id() -> FlowValueSource:
	var copy: FlowValueSource = duplicate(true) as FlowValueSource
	copy._source_id = FlowId.create()
	return copy


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
