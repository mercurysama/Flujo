@tool
## Runtime-safe constructor for initial chip-field documents.
class_name FlowChipFieldFactory
extends RefCounted


## Builds a new document and reports invalid schema/build data without repairing it.
func create(schema: FlowChipFieldSchema) -> FlowChipFieldCreationResult:
	var result: FlowChipFieldCreationResult = FlowChipFieldCreationResult.new()
	if schema == null:
		_add_error(
			result,
			FlowDiagnostic.CODE_NULL_CHIP_FIELD_SCHEMA,
			"FlowChipFieldSchema is null.",
			"schema"
		)
		return result

	var schema_validation: FlowValidationResult = FlowChipFieldValidator.validate_schema(schema)
	_copy_diagnostics(schema_validation, result)
	if schema_validation.has_errors():
		return result

	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	var generated_by_slot: Dictionary = {}
	var ordered_slot_ids: Array[String] = []

	if schema.mode == FlowChipFieldSchema.Mode.FIXED \
			or schema.mode == FlowChipFieldSchema.Mode.HYBRID:
		for definition: FlowChipSlotDefinition in schema.slots:
			if definition == null or definition.slot_id.is_empty():
				continue
			ordered_slot_ids.append(definition.slot_id)
			generated_by_slot[definition.slot_id] = _build_slot_chips(
				definition,
				_definition_initial_count(definition),
				false
			)

	if schema.mode == FlowChipFieldSchema.Mode.HYBRID \
			and schema.variadic_slot_definition != null:
		var variadic: FlowChipSlotDefinition = schema.variadic_slot_definition
		ordered_slot_ids.append(variadic.slot_id)
		generated_by_slot[variadic.slot_id] = _build_slot_chips(
			variadic,
			variadic.get_effective_min_count(),
			true
		)
	elif schema.mode == FlowChipFieldSchema.Mode.FLEXIBLE:
		var flexible_definition: FlowChipSlotDefinition = schema.variadic_slot_definition
		var flexible_slot_id: String = flexible_definition.slot_id \
			if flexible_definition != null else ""
		if flexible_definition != null:
			ordered_slot_ids.append(flexible_slot_id)
			generated_by_slot[flexible_slot_id] = _build_slot_chips(
				flexible_definition,
				schema.flexible_min_count,
				true
			)
		else:
			generated_by_slot[""] = []

	_materialize_template(schema, generated_by_slot, document)
	_append_remaining_chips(ordered_slot_ids, generated_by_slot, document)

	var document_validation: FlowValidationResult = FlowChipFieldValidator.validate(schema, document)
	_copy_diagnostics(document_validation, result)
	if document_validation.has_errors():
		return result
	result.document = document
	return result


## Convenience API for callers that only need the valid document.
static func create_document(schema: FlowChipFieldSchema) -> FlowStructuredDocument:
	var result: FlowChipFieldCreationResult = FlowChipFieldFactory.new().create(schema)
	return result.document if result.is_successful() else null


## Alias for callers that name construction as a build operation.
static func build(schema: FlowChipFieldSchema) -> FlowStructuredDocument:
	return create_document(schema)


func _definition_initial_count(definition: FlowChipSlotDefinition) -> int:
	if definition == null:
		return 0
	var minimum: int = definition.get_effective_min_count()
	if minimum > 0:
		return minimum
	if definition.initial_value_source != null:
		return 1
	return 0


func _build_slot_chips(
		definition: FlowChipSlotDefinition,
		count: int,
		is_variadic: bool
) -> Array[FlowChipSegment]:
	var chips: Array[FlowChipSegment] = []
	if definition == null or count <= 0 or definition.initial_value_source == null:
		return chips
	for _index: int in count:
		var chip: FlowChipSegment = _create_chip(definition, is_variadic)
		if chip != null:
			chips.append(chip)
	return chips


func _create_chip(
		definition: FlowChipSlotDefinition,
		is_variadic: bool
) -> FlowChipSegment:
	var source: FlowValueSource = definition.create_initial_value_source()
	if source == null:
		return null

	var chip: FlowChipSegment
	if source is FlowLiteralValueSource:
		var literal_source: FlowLiteralValueSource = source as FlowLiteralValueSource
		chip = FlowLiteralValueSegment.new(
			literal_source.get_value_type(),
			literal_source.get_value()
		)
	elif source is FlowVariableRefValueSource:
		chip = FlowVariableRefSegment.new(source as FlowVariableRefValueSource)
	elif source is FlowExpressionValueSource:
		chip = FlowExpressionSegment.new(source as FlowExpressionValueSource)
	elif source is FlowConditionValueSource:
		chip = FlowConditionSegment.new(source as FlowConditionValueSource)
	elif source is FlowOperationValueSource:
		chip = FlowOperationSegment.new(source as FlowOperationValueSource)
	else:
		chip = FlowChipSegment.new()
		chip.set_value_source(source)
	if chip == null:
		return null

	chip.set_slot_id(definition.slot_id)
	chip.set_slot_kind(
		FlowChipSegment.SLOT_KIND_VARIADIC
		if is_variadic else FlowChipSegment.SLOT_KIND_NAMED
	)
	return chip


func _materialize_template(
		schema: FlowChipFieldSchema,
		generated_by_slot: Dictionary,
		document: FlowStructuredDocument
) -> void:
	for part: FlowChipFieldTemplatePart in schema.template_parts:
		if part == null:
			continue
		if part.is_text_part():
			if schema.text_mode == FlowChipFieldSchema.TextMode.DISABLED \
					or part.text.is_empty():
				continue
			var text_segment: FlowTextSegment = FlowTextSegment.new()
			text_segment.text = part.text
			document.segments.append(text_segment)
			continue
		if not part.is_slot_part():
			continue
		var pending: Array[FlowChipSegment] = _pending_chips(generated_by_slot.get(part.slot_id, []))
		for chip: FlowChipSegment in pending:
			document.segments.append(chip)
		generated_by_slot[part.slot_id] = []


func _append_remaining_chips(
		ordered_slot_ids: Array[String],
		generated_by_slot: Dictionary,
		document: FlowStructuredDocument
) -> void:
	for slot_id: String in ordered_slot_ids:
		var pending: Array[FlowChipSegment] = _pending_chips(generated_by_slot.get(slot_id, []))
		for chip: FlowChipSegment in pending:
			document.segments.append(chip)
		generated_by_slot[slot_id] = []


func _pending_chips(value: Variant) -> Array[FlowChipSegment]:
	var result: Array[FlowChipSegment] = []
	if not value is Array:
		return result
	for candidate: Variant in value:
		if candidate is FlowChipSegment:
			result.append(candidate as FlowChipSegment)
	return result


static func _copy_diagnostics(
		source: FlowValidationResult,
		target: FlowValidationResult
) -> void:
	for diagnostic: FlowDiagnostic in source.diagnostics:
		target.add_diagnostic(diagnostic)


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
