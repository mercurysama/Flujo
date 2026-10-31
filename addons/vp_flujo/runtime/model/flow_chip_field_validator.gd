@tool
## Read-only deterministic validation of a chip field against its schema.
class_name FlowChipFieldValidator
extends RefCounted


static func validate(
		schema: FlowChipFieldSchema,
		document: FlowStructuredDocument,
		variable_graph: FlowGraph = null
) -> FlowValidationResult:
	var result: FlowValidationResult = FlowValidationResult.new()
	if schema == null:
		_add_error(
			result,
			FlowDiagnostic.CODE_NULL_CHIP_FIELD_SCHEMA,
			"FlowChipFieldSchema is null.",
			"schema"
		)
	else:
		_validate_schema(schema, result)

	if document == null:
		_add_error(
			result,
			FlowDiagnostic.CODE_NULL_CHIP_FIELD_DOCUMENT,
			"FlowStructuredDocument is null.",
			"document"
		)
	else:
		_validate_document(schema, document, result, variable_graph)
	return result


static func validate_schema(schema: FlowChipFieldSchema) -> FlowValidationResult:
	var result: FlowValidationResult = FlowValidationResult.new()
	if schema == null:
		_add_error(
			result,
			FlowDiagnostic.CODE_NULL_CHIP_FIELD_SCHEMA,
			"FlowChipFieldSchema is null.",
			"schema"
		)
	else:
		_validate_schema(schema, result)
	return result


static func _validate_schema(schema: FlowChipFieldSchema, result: FlowValidationResult) -> void:
	if schema.schema_id.is_empty():
		_add_error(
			result,
			FlowDiagnostic.CODE_EMPTY_CHIP_FIELD_SCHEMA_ID,
			"FlowChipFieldSchema ID is empty.",
			"schema.schema_id"
		)
	elif not FlowId.is_valid(schema.schema_id):
		_add_error(
			result,
			FlowDiagnostic.CODE_INVALID_CHIP_FIELD_SCHEMA_ID,
			"FlowChipFieldSchema ID is not a valid FlowId.",
			"schema.schema_id",
			schema.schema_id
		)

	if not FlowChipFieldSchema.is_valid_mode(schema.mode):
		_add_error(
			result,
			FlowDiagnostic.CODE_INVALID_CHIP_FIELD_SCHEMA_MODE,
			"FlowChipFieldSchema mode is invalid: %d." % schema.mode,
			"schema.mode",
			schema.schema_id
		)
	if not FlowChipFieldSchema.is_valid_text_mode(schema.text_mode):
		_add_error(
			result,
			FlowDiagnostic.CODE_INVALID_CHIP_FIELD_TEXT_MODE,
			"FlowChipFieldSchema text mode is invalid: %d." % schema.text_mode,
			"schema.text_mode",
			schema.schema_id
		)

	_validate_count_range(
		schema.flexible_min_count,
		schema.flexible_max_count,
		"schema.flexible_min_count",
		FlowDiagnostic.CODE_INVALID_CHIP_FIELD_COUNT_RANGE,
		result,
		schema.schema_id
	)
	_validate_variant_type_list(
		schema.accepted_value_types,
		"schema.accepted_value_types",
		FlowDiagnostic.CODE_INVALID_CHIP_FIELD_VALUE_TYPE,
		result,
		schema.schema_id
	)
	_validate_source_kind_list(
		schema.accepted_source_kinds,
		"schema.accepted_source_kinds",
		FlowDiagnostic.CODE_INVALID_CHIP_FIELD_SOURCE_KIND,
		result,
		schema.schema_id
	)

	var slot_paths: Dictionary = {}
	for slot_index: int in schema.slots.size():
		var slot_path: String = "schema.slots[%d]" % slot_index
		var definition: FlowChipSlotDefinition = schema.slots[slot_index]
		if definition == null:
			_add_error(
				result,
				FlowDiagnostic.CODE_NULL_CHIP_SLOT_DEFINITION,
				"FlowChipSlotDefinition is null.",
				slot_path,
				schema.schema_id
			)
			continue
		_validate_slot_definition(definition, slot_path, result)
		if definition.slot_id.is_empty():
			continue
		if slot_paths.has(definition.slot_id):
			_add_error(
				result,
				FlowDiagnostic.CODE_DUPLICATE_CHIP_SLOT_ID,
				"Chip slot ID is already declared at %s." % slot_paths[definition.slot_id],
				slot_path + ".slot_id",
				definition.slot_id
			)
		else:
			slot_paths[definition.slot_id] = slot_path

	if schema.variadic_slot_definition != null:
		var variadic_path: String = "schema.variadic_slot"
		var variadic: FlowChipSlotDefinition = schema.variadic_slot_definition
		_validate_slot_definition(variadic, variadic_path, result)
		if not variadic.repeatable:
			_add_error(
				result,
				FlowDiagnostic.CODE_INVALID_CHIP_FIELD_VARIADIC_CONFIGURATION,
				"A variadic chip zone must be repeatable.",
				variadic_path + ".repeatable",
				variadic.slot_id
			)
		if not variadic.slot_id.is_empty() and slot_paths.has(variadic.slot_id):
			_add_error(
				result,
				FlowDiagnostic.CODE_DUPLICATE_CHIP_SLOT_ID,
				"Variadic chip slot ID is already declared at %s." % slot_paths[variadic.slot_id],
				variadic_path + ".slot_id",
				variadic.slot_id
			)

	if FlowChipFieldSchema.is_valid_mode(schema.mode):
		match schema.mode:
			FlowChipFieldSchema.Mode.FIXED:
				if schema.variadic_slot_definition != null:
					_add_error(
						result,
						FlowDiagnostic.CODE_INVALID_CHIP_FIELD_CONFIGURATION,
						"FIXED fields cannot declare a variadic zone.",
						"schema.variadic_slot",
						schema.schema_id
					)
			FlowChipFieldSchema.Mode.FLEXIBLE:
				if not schema.slots.is_empty():
					_add_error(
						result,
						FlowDiagnostic.CODE_INVALID_CHIP_FIELD_CONFIGURATION,
						"FLEXIBLE fields cannot declare fixed named slots.",
						"schema.slots",
						schema.schema_id
					)
				if schema.flexible_min_count > 0 \
						and schema.variadic_slot_definition == null:
					_add_error(
						result,
						FlowDiagnostic.CODE_MISSING_CHIP_FIELD_INITIAL_SOURCE,
						"A FLEXIBLE field with a positive minimum needs a variadic default source.",
						"schema.variadic_slot.initial_value_source",
						schema.schema_id
					)
			FlowChipFieldSchema.Mode.HYBRID:
				if schema.variadic_slot_definition == null:
					_add_error(
						result,
						FlowDiagnostic.CODE_INVALID_CHIP_FIELD_VARIADIC_CONFIGURATION,
						"HYBRID fields require one variadic zone definition.",
						"schema.variadic_slot",
						schema.schema_id
					)

	_validate_template_parts(schema, slot_paths, result)


static func _validate_slot_definition(
		definition: FlowChipSlotDefinition,
		element_path: String,
		result: FlowValidationResult
) -> void:
	if definition.slot_id.is_empty():
		_add_error(
			result,
			FlowDiagnostic.CODE_EMPTY_CHIP_SLOT_ID,
			"Chip slot ID is empty.",
			element_path + ".slot_id"
		)
	_validate_count_range(
		definition.min_count,
		definition.max_count,
		element_path,
		FlowDiagnostic.CODE_INVALID_CHIP_SLOT_COUNT_RANGE,
		result,
		definition.slot_id
	)
	if not definition.repeatable and (definition.max_count > 1 or definition.max_count == FlowChipSlotDefinition.UNLIMITED_COUNT):
		_add_error(
			result,
			FlowDiagnostic.CODE_INVALID_CHIP_SLOT_COUNT_RANGE,
			"A non-repeating chip slot cannot have more than one occurrence or an unlimited maximum.",
			element_path + ".max_count",
			definition.slot_id
		)
	if definition.get_effective_min_count() > 1 and not definition.repeatable:
		_add_error(
			result,
			FlowDiagnostic.CODE_INVALID_CHIP_SLOT_COUNT_RANGE,
			"A non-repeating chip slot cannot require more than one occurrence.",
			element_path + ".min_count",
			definition.slot_id
		)
	if definition.initial_value_source == null:
		if definition.get_effective_min_count() > 0:
			_add_error(
				result,
				FlowDiagnostic.CODE_NULL_VALUE_SOURCE,
				"A chip slot with a positive minimum needs an initial ValueSource.",
				element_path + ".initial_value_source",
				definition.slot_id
			)
	else:
		_validate_source(
			definition.initial_value_source,
			element_path + ".initial_value_source",
			result
		)
		_validate_source_compatibility(
			definition.initial_value_source,
			definition,
			element_path + ".initial_value_source",
			result
		)
	_validate_variant_type_list(
		definition.accepted_value_types,
		element_path + ".accepted_value_types",
		FlowDiagnostic.CODE_INVALID_CHIP_FIELD_VALUE_TYPE,
		result,
		definition.slot_id
	)
	_validate_source_kind_list(
		definition.accepted_source_kinds,
		element_path + ".accepted_source_kinds",
		FlowDiagnostic.CODE_INVALID_CHIP_FIELD_SOURCE_KIND,
		result,
		definition.slot_id
	)


static func _validate_template_parts(
		schema: FlowChipFieldSchema,
		slot_paths: Dictionary,
		result: FlowValidationResult
) -> void:
	for part_index: int in schema.template_parts.size():
		var part_path: String = "schema.template_parts[%d]" % part_index
		var part: FlowChipFieldTemplatePart = schema.template_parts[part_index]
		if part == null:
			_add_error(
				result,
				FlowDiagnostic.CODE_NULL_CHIP_FIELD_TEMPLATE_PART,
				"FlowChipFieldTemplatePart is null.",
				part_path,
				schema.schema_id
			)
			continue
		if part.kind != FlowChipFieldTemplatePart.Kind.TEXT \
				and part.kind != FlowChipFieldTemplatePart.Kind.SLOT:
			_add_error(
				result,
				FlowDiagnostic.CODE_INVALID_CHIP_FIELD_TEMPLATE_PART,
				"Chip field template part kind is invalid.",
				part_path + ".kind",
				part.part_id
			)
			continue
		if part.is_slot_part():
			if part.slot_id.is_empty():
				_add_error(
					result,
					FlowDiagnostic.CODE_EMPTY_CHIP_SLOT_ID,
					"Chip field template slot ID is empty.",
					part_path + ".slot_id",
					part.part_id
				)
			elif not slot_paths.has(part.slot_id) \
					and (schema.variadic_slot_definition == null \
					or schema.variadic_slot_definition.slot_id != part.slot_id):
				_add_error(
					result,
					FlowDiagnostic.CODE_UNKNOWN_CHIP_FIELD_TEMPLATE_SLOT,
					"Chip field template references an undeclared slot.",
					part_path + ".slot_id",
					part.slot_id
				)


static func _validate_document(
		schema: FlowChipFieldSchema,
		document: FlowStructuredDocument,
		result: FlowValidationResult,
		variable_graph: FlowGraph = null
) -> void:
	if document.version != FlowStructuredDocument.CURRENT_VERSION:
		_add_error(
			result,
			FlowDiagnostic.CODE_UNSUPPORTED_STRUCTURED_DOCUMENT_VERSION,
			"Unsupported FlowStructuredDocument version: %d." % document.version,
			"document.version"
		)

	var slot_map: Dictionary = {}
	if schema != null:
		for slot_index: int in schema.slots.size():
			var definition: FlowChipSlotDefinition = schema.slots[slot_index]
			if definition != null and not definition.slot_id.is_empty() \
					and not slot_map.has(definition.slot_id):
				slot_map[definition.slot_id] = {
					"definition": definition,
					"index": slot_index,
				}

	var variadic_definition: FlowChipSlotDefinition = \
		schema.variadic_slot_definition if schema != null else null
	var seen_segment_ids: Dictionary = {}
	var slot_counts: Dictionary = {}
	var variadic_count: int = 0
	var flexible_count: int = 0
	var previous_order_index: int = -1
	var previous_definition: FlowChipSlotDefinition = null

	for segment_index: int in document.segments.size():
		var segment_path: String = "document.segments[%d]" % segment_index
		var segment: FlowDocumentSegment = document.segments[segment_index]
		if segment == null:
			_add_error(
				result,
				FlowDiagnostic.CODE_NULL_SEGMENT,
				"Structured-document segment is null.",
				segment_path
			)
			continue

		_validate_segment_id(segment, segment_path, seen_segment_ids, result)
		if segment is FlowTextSegment:
			if schema != null \
					and schema.text_mode == FlowChipFieldSchema.TextMode.DISABLED \
					and not (segment as FlowTextSegment).text.is_empty():
				_add_error(
					result,
					FlowDiagnostic.CODE_CHIP_FIELD_TEXT_NOT_ALLOWED,
					"This chip field does not allow free text.",
					segment_path + ".text",
					segment.get_segment_id()
				)
			continue
		if not segment is FlowChipSegment:
			_add_error(
				result,
				FlowDiagnostic.CODE_UNKNOWN_SEGMENT_TYPE,
				"Unsupported chip-field segment type: %s." % segment.get_class(),
				segment_path,
				segment.get_segment_id()
			)
			continue

		var chip: FlowChipSegment = segment as FlowChipSegment
		var source: FlowValueSource = chip.get_value_source()
		if source == null:
			_add_error(
				result,
				FlowDiagnostic.CODE_NULL_VALUE_SOURCE,
				"Chip ValueSource is null.",
				segment_path + ".value_source",
				chip.get_segment_id()
			)
		else:
			chip.validate_structure(result, segment_path)
			_validate_variable_reference(source, variable_graph, segment_path, result)
			_validate_expression_reference(source, variable_graph, segment_path, result)
			_validate_operation_reference(source, variable_graph, segment_path, result)
			_validate_condition_reference(source, variable_graph, segment_path, result)

		if schema == null or not FlowChipFieldSchema.is_valid_mode(schema.mode):
			continue

		var definition: FlowChipSlotDefinition = null
		var order_index: int = -1
		var is_variadic: bool = false
		var slot_id: String = chip.get_slot_id()

		match schema.mode:
			FlowChipFieldSchema.Mode.FLEXIBLE:
				flexible_count += 1
				is_variadic = true
				if variadic_definition != null:
					if slot_id.is_empty():
						_add_error(
							result,
							FlowDiagnostic.CODE_EMPTY_CHIP_SLOT_ID,
							"A flexible chip with a declared variadic zone needs its zone slot_id.",
							segment_path + ".slot_id",
							chip.get_segment_id()
						)
					elif slot_id != variadic_definition.slot_id:
						_add_error(
							result,
							FlowDiagnostic.CODE_UNKNOWN_CHIP_SLOT,
							"Chip references an unknown flexible zone slot_id.",
							segment_path + ".slot_id",
							slot_id
						)
					else:
						definition = variadic_definition
				else:
					if not slot_id.is_empty():
						_add_error(
							result,
							FlowDiagnostic.CODE_UNKNOWN_CHIP_SLOT,
							"An open flexible field does not declare named slot IDs.",
							segment_path + ".slot_id",
							slot_id
						)
			FlowChipFieldSchema.Mode.FIXED, FlowChipFieldSchema.Mode.HYBRID:
				if slot_id.is_empty():
					_add_error(
						result,
						FlowDiagnostic.CODE_EMPTY_CHIP_SLOT_ID,
						"Chip slot ID is required by this field schema.",
						segment_path + ".slot_id",
						chip.get_segment_id()
					)
				elif slot_map.has(slot_id):
					var slot_data: Dictionary = slot_map[slot_id] as Dictionary
					definition = slot_data["definition"] as FlowChipSlotDefinition
					order_index = int(slot_data["index"])
				elif schema.mode == FlowChipFieldSchema.Mode.HYBRID \
						and variadic_definition != null \
						and slot_id == variadic_definition.slot_id:
					definition = variadic_definition
					is_variadic = true
					order_index = schema.slots.size()
				else:
					_add_error(
						result,
						FlowDiagnostic.CODE_UNKNOWN_CHIP_SLOT,
						"Chip references an unknown slot ID.",
						segment_path + ".slot_id",
						slot_id
					)

		if is_variadic and schema.mode == FlowChipFieldSchema.Mode.HYBRID \
				and chip.get_slot_kind() != FlowChipSegment.SLOT_KIND_VARIADIC:
			_add_error(
				result,
				FlowDiagnostic.CODE_VARIADIC_CHIP_SLOT_KIND_REQUIRED,
				"A HYBRID variadic chip must identify its slot as a variadic zone.",
				segment_path + ".slot_kind",
				chip.get_segment_id()
			)
		elif not is_variadic and chip.get_slot_kind() == FlowChipSegment.SLOT_KIND_VARIADIC:
			_add_error(
				result,
				FlowDiagnostic.CODE_INVALID_CHIP_SLOT_KIND,
				"A named fixed chip cannot use the variadic slot kind.",
				segment_path + ".slot_kind",
				chip.get_segment_id()
			)

		if definition != null and source != null:
			_validate_source_compatibility(
				source,
				definition,
				segment_path + ".value_source",
				result
			)
		if (schema.mode == FlowChipFieldSchema.Mode.FLEXIBLE and definition == null) \
				and source != null:
			_validate_field_source_compatibility(
				source,
				schema,
				segment_path + ".value_source",
				result
			)
		elif is_variadic and source != null:
			_validate_field_source_compatibility(
				source,
				schema,
				segment_path + ".value_source",
				result
			)

		if definition == null:
			continue
		var count_key: String = definition.slot_id
		var count: int = int(slot_counts.get(count_key, 0)) + 1
		slot_counts[count_key] = count
		if is_variadic:
			variadic_count += 1
		elif count > 1 and not definition.repeatable:
			_add_error(
				result,
				FlowDiagnostic.CODE_DUPLICATE_CHIP_SLOT,
				"A non-repeating chip slot has more than one chip.",
				segment_path + ".slot_id",
				definition.slot_id
			)

		if order_index >= 0:
			if previous_order_index >= 0 and order_index < previous_order_index \
					and (previous_definition == null \
					or not previous_definition.allow_reorder \
					or not definition.allow_reorder):
				_add_error(
					result,
					FlowDiagnostic.CODE_CHIP_REORDER_NOT_ALLOWED,
					"Chip order does not match the schema's non-reorderable slot order.",
					segment_path,
					chip.get_segment_id()
				)
			previous_order_index = order_index
			previous_definition = definition

	if schema == null or not FlowChipFieldSchema.is_valid_mode(schema.mode):
		return

	if schema.mode == FlowChipFieldSchema.Mode.FLEXIBLE:
		if flexible_count < schema.flexible_min_count:
			_add_error(
				result,
				FlowDiagnostic.CODE_TOO_FEW_CHIPS,
				"Flexible chip field has fewer chips than its minimum count.",
				"document.flexible",
				schema.schema_id
			)
		if schema.flexible_max_count >= 0 and flexible_count > schema.flexible_max_count:
			_add_error(
				result,
				FlowDiagnostic.CODE_TOO_MANY_CHIPS,
				"Flexible chip field has more chips than its maximum count.",
				"document.flexible",
				schema.schema_id
			)

	for slot_index: int in schema.slots.size():
		var definition: FlowChipSlotDefinition = schema.slots[slot_index]
		if definition == null or definition.slot_id.is_empty():
			continue
		var count: int = int(slot_counts.get(definition.slot_id, 0))
		var minimum: int = definition.get_effective_min_count()
		if count < minimum:
			if definition.required:
				_add_error(
					result,
					FlowDiagnostic.CODE_MISSING_REQUIRED_CHIP_SLOT,
					"Required chip slot is absent.",
					"document.slot[%s]" % definition.slot_id,
					definition.slot_id
				)
			else:
				_add_error(
					result,
					FlowDiagnostic.CODE_TOO_FEW_CHIPS,
					"Chip slot has fewer chips than its minimum count.",
					"document.slot[%s]" % definition.slot_id,
					definition.slot_id
				)
		if definition.max_count >= 0 and count > definition.max_count:
			_add_error(
				result,
				FlowDiagnostic.CODE_TOO_MANY_CHIPS,
				"Chip slot has more chips than its maximum count.",
				"document.slot[%s]" % definition.slot_id,
				definition.slot_id
			)

	if schema.mode == FlowChipFieldSchema.Mode.HYBRID \
			and variadic_definition != null:
		var variadic_minimum: int = variadic_definition.get_effective_min_count()
		if variadic_count < variadic_minimum:
			_add_error(
				result,
				FlowDiagnostic.CODE_TOO_FEW_CHIPS,
				"Variadic chip zone has fewer chips than its minimum count.",
				"document.variadic[%s]" % variadic_definition.slot_id,
				variadic_definition.slot_id
			)
		if variadic_definition.max_count >= 0 and variadic_count > variadic_definition.max_count:
			_add_error(
				result,
				FlowDiagnostic.CODE_TOO_MANY_CHIPS,
				"Variadic chip zone has more chips than its maximum count.",
				"document.variadic[%s]" % variadic_definition.slot_id,
				variadic_definition.slot_id
			)


static func _validate_source(
		source: FlowValueSource,
		element_path: String,
		result: FlowValidationResult
) -> void:
	source.validate_structure(result, element_path)
	if not source.is_valid():
		_add_error(
			result,
			FlowDiagnostic.CODE_INVALID_VALUE_SOURCE,
			"ValueSource is structurally invalid.",
			element_path,
			source.get_source_id()
		)


static func _validate_variable_reference(
		source: FlowValueSource,
		variable_graph: FlowGraph,
		segment_path: String,
		result: FlowValidationResult
) -> void:
	var variable_source: FlowVariableRefValueSource = source as FlowVariableRefValueSource
	if variable_source == null or variable_graph == null:
		return
	var variable: FlowVariableDefinition = variable_source.resolve_definition(variable_graph)
	if variable == null:
		_add_error(
			result,
			FlowDiagnostic.CODE_VARIABLE_REFERENCE_MISSING,
			"VariableRef references a variable that is missing from the active FlowGraph.",
			segment_path + ".value_source.variable_id",
			variable_source.variable_id
		)
		return
	if variable.get_declared_variant_type() != variable_source.get_value_type():
		_add_error(
			result,
			FlowDiagnostic.CODE_VARIABLE_REFERENCE_TYPE_MISMATCH,
			"VariableRef declared type does not match the resolved variable type.",
			segment_path + ".value_source.declared_value_type",
			variable_source.variable_id
		)


static func _validate_expression_reference(
		source: FlowValueSource,
		variable_graph: FlowGraph,
		segment_path: String,
		result: FlowValidationResult
) -> void:
	var expression_source: FlowExpressionValueSource = source as FlowExpressionValueSource
	if expression_source == null or variable_graph == null:
		return
	expression_source.validate_against_graph(
		result,
		segment_path + ".value_source",
		variable_graph
	)


static func _validate_operation_reference(
		source: FlowValueSource,
		variable_graph: FlowGraph,
		segment_path: String,
		result: FlowValidationResult
) -> void:
	var operation_source: FlowOperationValueSource = source as FlowOperationValueSource
	if operation_source == null:
		return
	operation_source.validate_against_graph(
		result,
		segment_path + ".value_source",
		variable_graph
	)


static func _validate_condition_reference(
		source: FlowValueSource,
		variable_graph: FlowGraph,
		segment_path: String,
		result: FlowValidationResult
) -> void:
	var condition_source: FlowConditionValueSource = source as FlowConditionValueSource
	if condition_source == null:
		return
	condition_source.validate_graph_references(
		result,
		segment_path + ".value_source",
		variable_graph
	)


static func _validate_source_compatibility(
		source: FlowValueSource,
		definition: FlowChipSlotDefinition,
		element_path: String,
		result: FlowValidationResult
) -> void:
	if source == null or definition == null:
		return
	if not definition.accepts_value_type(source.get_value_type()):
		_add_error(
			result,
			FlowDiagnostic.CODE_EXPRESSION_RESULT_TYPE_INCOMPATIBLE \
				if source is FlowExpressionValueSource \
				else FlowDiagnostic.CODE_CHIP_VALUE_TYPE_INCOMPATIBLE,
			"Expression produced type is not accepted by the slot." \
				if source is FlowExpressionValueSource \
				else "Chip ValueSource type is not accepted by the slot.",
			element_path + ".value_type",
			source.get_source_id()
		)
	if not definition.accepts_source_kind(source.get_source_kind()):
		_add_error(
			result,
			FlowDiagnostic.CODE_CHIP_SOURCE_KIND_INCOMPATIBLE,
			"Chip ValueSource kind is not accepted by the slot.",
			element_path + ".source_kind",
			source.get_source_id()
		)


static func _validate_field_source_compatibility(
		source: FlowValueSource,
		schema: FlowChipFieldSchema,
		element_path: String,
		result: FlowValidationResult
) -> void:
	if source == null or schema == null:
		return
	if not schema.accepts_value_type(source.get_value_type()):
		_add_error(
			result,
			FlowDiagnostic.CODE_EXPRESSION_RESULT_TYPE_INCOMPATIBLE \
				if source is FlowExpressionValueSource \
				else FlowDiagnostic.CODE_CHIP_VALUE_TYPE_INCOMPATIBLE,
			"Expression produced type is not accepted by the field schema." \
				if source is FlowExpressionValueSource \
				else "Chip ValueSource type is not accepted by the field schema.",
			element_path + ".value_type",
			source.get_source_id()
		)
	if not schema.accepts_source_kind(source.get_source_kind()):
		_add_error(
			result,
			FlowDiagnostic.CODE_CHIP_SOURCE_KIND_INCOMPATIBLE,
			"Chip ValueSource kind is not accepted by the field schema.",
			element_path + ".source_kind",
			source.get_source_id()
		)


static func _validate_count_range(
		minimum: int,
		maximum: int,
		element_path: String,
		code: StringName,
		result: FlowValidationResult,
		related_id: String = ""
) -> void:
	if minimum < 0 or maximum < FlowChipSlotDefinition.UNLIMITED_COUNT \
			or (maximum >= 0 and minimum > maximum):
		_add_error(
			result,
			code,
			"Chip count range is invalid.",
			element_path,
			related_id
		)


static func _validate_variant_type_list(
		values: Array[Variant.Type],
		element_path: String,
		code: StringName,
		result: FlowValidationResult,
		related_id: String = ""
) -> void:
	for value_index: int in values.size():
		var candidate: Variant.Type = values[value_index]
		if candidate < Variant.Type.TYPE_NIL or candidate >= Variant.Type.TYPE_MAX:
			_add_error(
				result,
				code,
				"Accepted Variant.Type is invalid: %d." % int(candidate),
				"%s[%d]" % [element_path, value_index],
				related_id
			)


static func _validate_source_kind_list(
		values: Array[StringName],
		element_path: String,
		code: StringName,
		result: FlowValidationResult,
		related_id: String = ""
) -> void:
	for value_index: int in values.size():
		if values[value_index].is_empty():
			_add_error(
				result,
				code,
				"Accepted source kind cannot be empty.",
				"%s[%d]" % [element_path, value_index],
				related_id
			)


static func _validate_segment_id(
		segment: FlowDocumentSegment,
		segment_path: String,
		seen_ids: Dictionary,
		result: FlowValidationResult
) -> void:
	var segment_id: String = segment.get_segment_id()
	if segment_id.is_empty():
		_add_error(
			result,
			FlowDiagnostic.CODE_EMPTY_SEGMENT_ID,
			"Structured-document segment ID is empty.",
			segment_path
		)
	elif not FlowId.is_valid(segment_id):
		_add_error(
			result,
			FlowDiagnostic.CODE_INVALID_SEGMENT_ID,
			"Structured-document segment ID is not a valid FlowId.",
			segment_path,
			segment_id
		)
	if segment_id.is_empty():
		return
	if seen_ids.has(segment_id):
		_add_error(
			result,
			FlowDiagnostic.CODE_DUPLICATE_SEGMENT_ID,
			"Structured-document segment ID is already used at %s." % seen_ids[segment_id],
			segment_path,
			segment_id
		)
	else:
		seen_ids[segment_id] = segment_path


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
