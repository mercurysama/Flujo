@tool
extends FlowBlock

## Target variable definition ID (stable). Empty means unconfigured.
@export_storage var target_variable_id: String = ""
## Typed value/expression authored as Akis. Runtime execution of assignment
## requires executor support for executable blocks (pending integration).
@export var value_document: FlowStructuredDocument = null


func _init() -> void:
	display_name = "FSet"
	if value_document == null:
		value_document = FlowStructuredDocument.new()


func get_target_variable_id() -> String:
	return target_variable_id


func set_target_variable_id(value: String) -> void:
	target_variable_id = value


func get_value_document() -> FlowStructuredDocument:
	return value_document


## Attempts to resolve the authored value without mutating runtime state.
## Returns a FlowValueResult for preview/validation tooling.
func resolve_value_preview(context: FlowValueResolutionContext) -> FlowValueResult:
	if value_document == null:
		return FlowValueResult.fail(
			Variant.Type.TYPE_NIL,
			FlowDiagnostic.new(
				FlowDiagnostic.CODE_STRUCTURED_VALUE_SHAPE_INVALID,
				FlowDiagnostic.Severity.ERROR,
				"FSet value document is missing.",
				"value_document",
				get_internal_id()
			)
		)
	return FlowStructuredDocumentResolver.resolve_value(value_document, context)


## Validates target configuration. Structured document properties are also
## validated generically by FlowGraphValidator.
func validate_structure(_context: Dictionary) -> void:
	if _context == null:
		return
	var result: FlowValidationResult = _context.get("result", null) as FlowValidationResult
	var element_path: String = String(_context.get("path", ""))
	if result == null:
		return
	if target_variable_id.is_empty():
		result.add_diagnostic(FlowDiagnostic.new(
			FlowDiagnostic.CODE_EMPTY_VARIABLE_REFERENCE_ID,
			FlowDiagnostic.Severity.ERROR,
			"FSet target variable is not configured.",
			element_path + ".target_variable_id",
			get_internal_id()
		))
	elif not FlowId.is_valid(target_variable_id):
		result.add_diagnostic(FlowDiagnostic.new(
			FlowDiagnostic.CODE_INVALID_VARIABLE_REFERENCE_ID,
			FlowDiagnostic.Severity.ERROR,
			"FSet target variable ID is invalid.",
			element_path + ".target_variable_id",
			target_variable_id
		))


func remap_internal_references(id_map: Dictionary[String, String]) -> void:
	super.remap_internal_references(id_map)
	if id_map.has(target_variable_id):
		target_variable_id = id_map[target_variable_id]
	# FlowBlock.remap_internal_references() already remaps ValueSources inside
	# FlowStructuredDocument properties (including value_document).

