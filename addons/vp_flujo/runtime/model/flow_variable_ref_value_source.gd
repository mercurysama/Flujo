@tool
## Runtime-safe reference to one graph-owned FlowVariableDefinition.
class_name FlowVariableRefValueSource
extends FlowValueSource


const SOURCE_KIND: StringName = FlowValueSource.SOURCE_KIND_VARIABLE_REF

## This is the only variable identity persisted by the source. The visible
## variable name and collection position are deliberately not copied here.
@export_storage var variable_id: String = ""
## Retain the authored type even when the referenced definition is missing.
@export_storage var declared_value_type: FlowVariableDefinition.ValueType = FlowVariableDefinition.ValueType.BOOL


func _init(
		new_variable_id: String = "",
		new_declared_value_type: FlowVariableDefinition.ValueType = FlowVariableDefinition.ValueType.BOOL
) -> void:
	variable_id = new_variable_id
	declared_value_type = new_declared_value_type


func get_source_kind() -> StringName:
	return SOURCE_KIND


func get_variable_id() -> String:
	return variable_id


func get_declared_value_type() -> FlowVariableDefinition.ValueType:
	return declared_value_type


func get_value_type() -> Variant.Type:
	return FlowVariableDefinition.to_variant_type(declared_value_type)


## A reference has no authored literal value. Runtime resolution is a separate
## context boundary and remains intentionally deferred in this delivery.
func get_value() -> Variant:
	return null


func resolve_value() -> Variant:
	return null


func resolve(context: Variant = null) -> FlowValueResult:
	var resolution_context: FlowValueResolutionContext = context as FlowValueResolutionContext
	var graph: FlowGraph = resolution_context.graph if resolution_context != null else context as FlowGraph
	var variable: FlowVariableDefinition = resolve_definition(graph)
	if variable == null:
		return FlowValueResult.fail(
			get_value_type(),
			FlowDiagnostic.new(
				FlowDiagnostic.CODE_VARIABLE_REFERENCE_MISSING,
				FlowDiagnostic.Severity.ERROR,
				"VariableRef cannot resolve without an existing FlowGraph variable.",
				"value_source.variable_id",
				variable_id
			)
		)
	if variable.get_declared_variant_type() != get_value_type():
		return FlowValueResult.fail(
			get_value_type(),
			FlowDiagnostic.new(
				FlowDiagnostic.CODE_VARIABLE_REFERENCE_TYPE_MISMATCH,
				FlowDiagnostic.Severity.ERROR,
				"VariableRef declared type does not match the FlowGraph variable.",
				"value_source.declared_value_type",
				variable_id
			)
		)
	if resolution_context != null and resolution_context.has_variable_value(variable_id):
		var runtime_value: Variant = resolution_context.get_variable_value(variable_id)
		if typeof(runtime_value) != get_value_type():
			return FlowValueResult.fail(
				get_value_type(),
				FlowDiagnostic.new(
					FlowDiagnostic.CODE_VALUE_RESOLUTION_TYPE_MISMATCH,
					FlowDiagnostic.Severity.ERROR,
					"Runtime variable value does not match its declared type.",
					"value_source.variable_id",
					variable_id
				)
			)
		return FlowValueResult.ok(runtime_value, get_value_type())
	return FlowValueResult.ok(_default_value(variable), get_value_type())


func is_valid() -> bool:
	return FlowId.is_valid(_source_id) \
		and FlowId.is_valid(variable_id) \
		and FlowVariableDefinition.is_valid_value_type(declared_value_type) \
		and get_value_type() != Variant.Type.TYPE_NIL


func resolve_definition(graph: FlowGraph) -> FlowVariableDefinition:
	if graph == null or variable_id.is_empty():
		return null
	for variable: FlowVariableDefinition in graph.variables:
		if variable != null and variable.get_internal_id() == variable_id:
			return variable
	return null


func validate_structure(result: FlowValidationResult, element_path: String) -> void:
	super.validate_structure(result, element_path)
	if result == null:
		return
	if variable_id.is_empty():
		_add_error(
			result,
			FlowDiagnostic.CODE_EMPTY_VARIABLE_REFERENCE_ID,
			"VariableRef value source ID is empty.",
			element_path + ".variable_id",
			_source_id
		)
	elif not FlowId.is_valid(variable_id):
		_add_error(
			result,
			FlowDiagnostic.CODE_INVALID_VARIABLE_REFERENCE_ID,
			"VariableRef value source references an invalid variable ID.",
			element_path + ".variable_id",
			variable_id
		)
	if not FlowVariableDefinition.is_valid_value_type(declared_value_type) \
			or get_value_type() == Variant.Type.TYPE_NIL:
		_add_error(
			result,
			FlowDiagnostic.CODE_INVALID_VARIABLE_REFERENCE_TYPE,
			"VariableRef value source uses an invalid declared value type.",
			element_path + ".declared_value_type",
			variable_id
		)


func duplicate_with_new_id() -> FlowValueSource:
	var copy: FlowVariableRefValueSource = duplicate(false) as FlowVariableRefValueSource
	copy._source_id = FlowId.create()
	return copy


static func _default_value(variable: FlowVariableDefinition) -> Variant:
	match variable.value_type:
		FlowVariableDefinition.ValueType.BOOL:
			return variable.bool_value
		FlowVariableDefinition.ValueType.INT:
			return variable.int_value
		FlowVariableDefinition.ValueType.FLOAT:
			return variable.float_value
		FlowVariableDefinition.ValueType.STRING:
			return variable.string_value
		FlowVariableDefinition.ValueType.VECTOR2:
			return variable.vector2_value
		FlowVariableDefinition.ValueType.VECTOR3:
			return variable.vector3_value
		FlowVariableDefinition.ValueType.COLOR:
			return variable.color_value
	return null


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
