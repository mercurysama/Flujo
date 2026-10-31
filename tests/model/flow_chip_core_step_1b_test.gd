extends Node


const TEMP_ROOT: String = "res://.godot/flujo_tests/chip_core_step_1b"
const SCHEMA_PATH: String = TEMP_ROOT + "/fixed_schema.tres"
const DOCUMENT_PATH: String = TEMP_ROOT + "/fixed_document.tres"
const SOURCE_SCHEMA_PATH: String = TEMP_ROOT + "/source_schema.tres"
const SOURCE_DOCUMENT_PATH: String = TEMP_ROOT + "/source_document.tres"


var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_schema_and_document_diagnostics()
	_test_fixed_factory_and_validation()
	_test_flexible_factory_and_validation()
	_test_hybrid_factory_and_validation()
	_test_text_policy_and_runtime_boundary()
	_test_persistence_and_deep_duplication()
	_cleanup()
	_finish()


func _test_schema_and_document_diagnostics() -> void:
	var malformed: FlowChipFieldSchema = FlowChipFieldSchema.new()
	malformed.mode = 99
	malformed.text_mode = 99
	malformed.flexible_min_count = -1
	malformed.flexible_max_count = -2
	var duplicate_a: FlowChipSlotDefinition = FlowChipSlotDefinition.new("duplicate", "A")
	var duplicate_b: FlowChipSlotDefinition = FlowChipSlotDefinition.new("duplicate", "B")
	malformed.slots = [null, FlowChipSlotDefinition.new("", "Empty"), duplicate_a, duplicate_b]
	var malformed_result: FlowValidationResult = FlowChipFieldValidator.validate_schema(malformed)
	_check(_has_code(malformed_result, FlowDiagnostic.CODE_INVALID_CHIP_FIELD_SCHEMA_MODE),
		"Schema validation diagnoses an invalid field mode.")
	_check(_has_code(malformed_result, FlowDiagnostic.CODE_INVALID_CHIP_FIELD_TEXT_MODE),
		"Schema validation diagnoses an invalid text mode.")
	_check(_has_code(malformed_result, FlowDiagnostic.CODE_NULL_CHIP_SLOT_DEFINITION),
		"Schema validation diagnoses a null slot definition.")
	_check(_has_code(malformed_result, FlowDiagnostic.CODE_EMPTY_CHIP_SLOT_ID),
		"Schema validation diagnoses an empty slot_id.")
	_check(_has_code(malformed_result, FlowDiagnostic.CODE_DUPLICATE_CHIP_SLOT_ID),
		"Schema validation diagnoses duplicate slot IDs.")
	_check(_has_code(malformed_result, FlowDiagnostic.CODE_INVALID_CHIP_FIELD_COUNT_RANGE),
		"Schema validation diagnoses invalid flexible count limits.")

	var malformed_variadic: FlowChipFieldSchema = FlowChipFieldSchema.new()
	malformed_variadic.mode = FlowChipFieldSchema.Mode.HYBRID
	var non_repeatable_zone: FlowChipSlotDefinition = FlowChipSlotDefinition.new("zone", "Zone")
	malformed_variadic.variadic_slot_definition = non_repeatable_zone
	_check(_has_code(
		FlowChipFieldValidator.validate_schema(malformed_variadic),
		FlowDiagnostic.CODE_INVALID_CHIP_FIELD_VARIADIC_CONFIGURATION
	), "Schema validation diagnoses a malformed variadic zone.")

	var flexible: FlowChipFieldSchema = FlowChipFieldSchema.new()
	flexible.mode = FlowChipFieldSchema.Mode.FLEXIBLE
	_check(_has_code(
		FlowChipFieldValidator.validate(flexible, null),
		FlowDiagnostic.CODE_NULL_CHIP_FIELD_DOCUMENT
	), "Field validation diagnoses a null document.")

	var malformed_document: FlowStructuredDocument = FlowStructuredDocument.new()
	var invalid_id: FlowTextSegment = FlowTextSegment.new()
	invalid_id.segment_id = "not-a-flow-id"
	var duplicate_id: FlowTextSegment = FlowTextSegment.new()
	duplicate_id.segment_id = invalid_id.segment_id
	var source_missing: FlowChipSegment = FlowChipSegment.new()
	malformed_document.segments = [null, invalid_id, duplicate_id, source_missing]
	var document_result: FlowValidationResult = FlowChipFieldValidator.validate(flexible, malformed_document)
	_check(_has_code(document_result, FlowDiagnostic.CODE_NULL_SEGMENT),
		"Field validation diagnoses a null segment.")
	_check(_has_code(document_result, FlowDiagnostic.CODE_INVALID_SEGMENT_ID),
		"Field validation diagnoses an invalid segment ID.")
	_check(_has_code(document_result, FlowDiagnostic.CODE_DUPLICATE_SEGMENT_ID),
		"Field validation diagnoses a duplicate segment ID.")
	_check(_has_code(document_result, FlowDiagnostic.CODE_NULL_VALUE_SOURCE),
		"Field validation diagnoses a chip without a required source.")


func _test_fixed_factory_and_validation() -> void:
	var schema: FlowChipFieldSchema = _fixed_schema()
	var result: FlowChipFieldCreationResult = FlowChipFieldFactory.new().create(schema)
	_check(result.is_successful(), "FIXED factory creates a valid initial field.")
	if result.document == null:
		return

	var document: FlowStructuredDocument = result.document
	var chips: Array[FlowChipSegment] = _chips(document)
	_check(document.segments.size() == 6, "FIXED text template preserves three text parts and three chips.")
	_check(chips.size() == 3, "FIXED factory generates one chip for every required slot.")
	_check(_slot_ids(chips) == ["initialization", "condition", "update"],
		"FIXED chips retain declared semantic slot IDs in visual order.")
	_check(_all_ids_unique(chips), "FIXED generated chips receive unique segment IDs.")
	_check(_all_sources_present(chips), "FIXED generated chips expose a ValueSource boundary.")
	_check(chips[0] is FlowLiteralValueSegment and chips[0].get_value_type() == FlowLiteralValueSource.TYPE_INT \
			and chips[0].get_value() == 0, "FIXED initialization uses the declared int literal default.")
	_check(chips[1] is FlowLiteralValueSegment and chips[1].get_value_type() == FlowLiteralValueSource.TYPE_BOOL \
			and chips[1].get_value() == true, "FIXED condition uses the declared bool literal default.")
	_check(chips[2] is FlowLiteralValueSegment and chips[2].get_value_type() == FlowLiteralValueSource.TYPE_INT \
			and chips[2].get_value() == 1, "FIXED update uses the declared int literal default.")
	_check(document.segments[0] is FlowTextSegment and (document.segments[0] as FlowTextSegment).text == "Inicio: ",
		"FIXED documentation labels are real text segments outside chips.")
	_check(not FlowChipFieldValidator.validate(schema, document).has_errors(),
		"Generated FIXED field passes generic validation.")

	var missing_condition: FlowStructuredDocument = document.duplicate_with_new_ids()
	_remove_chip_by_slot(missing_condition, "condition")
	_check(_has_code(
		FlowChipFieldValidator.validate(schema, missing_condition),
		FlowDiagnostic.CODE_MISSING_REQUIRED_CHIP_SLOT
	), "Deleting required condition produces a diagnostic.")

	var duplicate_initialization: FlowStructuredDocument = document.duplicate_with_new_ids()
	var duplicate_chip: FlowChipSegment = _find_chip(duplicate_initialization, "initialization")
	if duplicate_chip != null:
		duplicate_initialization.segments.append(duplicate_chip.duplicate_with_new_id())
	_check(_has_code(
		FlowChipFieldValidator.validate(schema, duplicate_initialization),
		FlowDiagnostic.CODE_DUPLICATE_CHIP_SLOT
	), "Duplicating a non-repeatable initialization slot produces a diagnostic.")

	var wrong_condition_type: FlowStructuredDocument = document.duplicate_with_new_ids()
	var wrong_condition: FlowLiteralValueSegment = _find_literal(wrong_condition_type, "condition")
	if wrong_condition != null:
		wrong_condition.value_type = FlowLiteralValueSource.TYPE_STRING
		wrong_condition.value = "true"
	_check(_has_code(
		FlowChipFieldValidator.validate(schema, wrong_condition_type),
		FlowDiagnostic.CODE_CHIP_VALUE_TYPE_INCOMPATIBLE
	), "Changing condition from bool to String produces a type diagnostic without repair.")
	_check(wrong_condition != null and wrong_condition.value == "true",
		"FIXED validation preserves an incompatible authored value.")

	var reordered: FlowStructuredDocument = FlowStructuredDocument.new()
	var condition_chip: FlowChipSegment = _find_chip(document, "condition")
	var initialization_chip: FlowChipSegment = _find_chip(document, "initialization")
	var update_chip: FlowChipSegment = _find_chip(document, "update")
	reordered.segments = [condition_chip, initialization_chip, update_chip]
	_check(_has_code(
		FlowChipFieldValidator.validate(schema, reordered),
		FlowDiagnostic.CODE_CHIP_REORDER_NOT_ALLOWED
	), "FIXED validation diagnoses an order change when allow_reorder is false.")


func _test_flexible_factory_and_validation() -> void:
	var schema: FlowChipFieldSchema = FlowChipFieldSchema.new()
	schema.mode = FlowChipFieldSchema.Mode.FLEXIBLE
	schema.text_mode = FlowChipFieldSchema.TextMode.RUNTIME_CONTENT
	schema.flexible_min_count = 0
	schema.flexible_max_count = 4
	schema.accepted_value_types = [
		FlowLiteralValueSource.TYPE_BOOL,
		FlowLiteralValueSource.TYPE_INT,
		FlowLiteralValueSource.TYPE_STRING,
	]
	schema.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_LITERAL]

	var initial: FlowChipFieldCreationResult = FlowChipFieldFactory.new().create(schema)
	_check(initial.is_successful() and initial.document.segments.is_empty(),
		"FLEXIBLE factory starts empty instead of filling max_count.")
	var empty: FlowStructuredDocument = FlowStructuredDocument.new()
	_check(not FlowChipFieldValidator.validate(schema, empty).has_errors(),
		"An empty FLEXIBLE field is valid when min_count is zero.")

	var four: FlowStructuredDocument = FlowStructuredDocument.new()
	four.segments = [
		_literal(FlowLiteralValueSource.TYPE_BOOL, true),
		_literal(FlowLiteralValueSource.TYPE_INT, 2),
		_literal(FlowLiteralValueSource.TYPE_STRING, "three"),
		_literal(FlowLiteralValueSource.TYPE_INT, 4),
	]
	_check(not FlowChipFieldValidator.validate(schema, four).has_errors(),
		"FLEXIBLE accepts one through max_count chips with allowed literal types.")
	four.segments.append(_literal(FlowLiteralValueSource.TYPE_INT, 5))
	_check(_has_code(
		FlowChipFieldValidator.validate(schema, four),
		FlowDiagnostic.CODE_TOO_MANY_CHIPS
	), "FLEXIBLE diagnoses a fifth chip above max_count.")

	var wrong_type: FlowStructuredDocument = FlowStructuredDocument.new()
	wrong_type.segments = [_literal(FlowLiteralValueSource.TYPE_FLOAT, 1.5)]
	_check(_has_code(
		FlowChipFieldValidator.validate(schema, wrong_type),
		FlowDiagnostic.CODE_CHIP_VALUE_TYPE_INCOMPATIBLE
	), "FLEXIBLE diagnoses a type outside accepted_value_types.")

	var wrong_source: FlowStructuredDocument = FlowStructuredDocument.new()
	var source_chip: FlowChipSegment = FlowChipSegment.new()
	source_chip.value_source = FlowValueSource.new()
	wrong_source.segments = [source_chip]
	_check(_has_code(
		FlowChipFieldValidator.validate(schema, wrong_source),
		FlowDiagnostic.CODE_CHIP_SOURCE_KIND_INCOMPATIBLE
	), "FLEXIBLE diagnoses a source kind outside accepted_source_kinds.")


func _test_hybrid_factory_and_validation() -> void:
	var schema: FlowChipFieldSchema = _hybrid_schema()
	var result: FlowChipFieldCreationResult = FlowChipFieldFactory.new().create(schema)
	_check(result.is_successful(), "HYBRID factory creates its required fixed and minimum variadic chips.")
	if result.document == null:
		return

	var document: FlowStructuredDocument = result.document
	var chips: Array[FlowChipSegment] = _chips(document)
	_check(_slot_ids(chips) == ["target", "argument"],
		"HYBRID initial order contains target followed by one argument zone item.")
	_check(chips[1].get_slot_kind() == FlowChipSegment.SLOT_KIND_VARIADIC,
		"HYBRID arguments identify their semantic variadic zone separately from fixed slots.")
	_check(not FlowChipFieldValidator.validate(schema, document).has_errors(),
		"Initial HYBRID field passes generic validation.")

	document.segments.append(_variadic_literal(2))
	document.segments.append(_variadic_literal(3))
	_check(not FlowChipFieldValidator.validate(schema, document).has_errors(),
		"HYBRID accepts variadic arguments up to max_count.")
	document.segments.append(_variadic_literal(4))
	_check(_has_code(
		FlowChipFieldValidator.validate(schema, document),
		FlowDiagnostic.CODE_TOO_MANY_CHIPS
	), "HYBRID diagnoses a fourth argument above max_count three.")

	var no_target: FlowStructuredDocument = result.document.duplicate_with_new_ids()
	_remove_chip_by_slot(no_target, "target")
	_check(_has_code(
		FlowChipFieldValidator.validate(schema, no_target),
		FlowDiagnostic.CODE_MISSING_REQUIRED_CHIP_SLOT
	), "HYBRID diagnoses a missing required target.")

	var no_arguments: FlowStructuredDocument = result.document.duplicate_with_new_ids()
	_remove_variadic_chips(no_arguments, "argument")
	_check(_has_code(
		FlowChipFieldValidator.validate(schema, no_arguments),
		FlowDiagnostic.CODE_TOO_FEW_CHIPS
	), "HYBRID diagnoses a variadic zone below min_count.")


func _test_text_policy_and_runtime_boundary() -> void:
	var disabled: FlowChipFieldSchema = _fixed_schema()
	disabled.text_mode = FlowChipFieldSchema.TextMode.DISABLED
	disabled.template_parts = [
		FlowChipFieldTemplatePart.text_part("No documentation: "),
		FlowChipFieldTemplatePart.slot_part("initialization"),
	]
	var generated: FlowChipFieldCreationResult = FlowChipFieldFactory.new().create(disabled)
	_check(generated.is_successful(), "DISABLED factory can still create chips from slot metadata.")
	if generated.document != null:
		_check(_text_segments(generated.document).is_empty(),
			"DISABLED factory does not create free-text segments from a template.")
		_check(not FlowChipFieldValidator.validate(disabled, generated.document).has_errors(),
			"DISABLED generated document has no forbidden text.")

	var forbidden_text: FlowStructuredDocument = FlowStructuredDocument.new()
	var text: FlowTextSegment = FlowTextSegment.new()
	text.text = "forbidden"
	forbidden_text.segments = [text]
	_check(_has_code(
		FlowChipFieldValidator.validate(disabled, forbidden_text),
		FlowDiagnostic.CODE_CHIP_FIELD_TEXT_NOT_ALLOWED
	), "DISABLED validation diagnoses non-empty FlowTextSegment without deleting it.")
	_check(forbidden_text.segments.size() == 1 and forbidden_text.segments[0] == text,
		"Text validation is read-only and preserves the forbidden text segment.")

	for source_path: String in [
		"res://addons/vp_flujo/runtime/model/flow_chip_field_factory.gd",
		"res://addons/vp_flujo/runtime/model/flow_chip_field_validator.gd",
		"res://addons/vp_flujo/runtime/model/flow_chip_field_schema.gd",
	]:
		var source: String = FileAccess.get_file_as_string(source_path)
		for forbidden_token: String in [
			"EditorPlugin",
			"EditorInterface",
			"EditorUndoRedoManager",
			"Control",
			"FlowForBlock",
			"FPrint",
			"FlowIfBlock",
		]:
			_check(not source.contains(forbidden_token),
				"1B runtime field source has no editor, UI, FPrint, For, or If dependency: %s (%s)." % [forbidden_token, source_path])


func _test_persistence_and_deep_duplication() -> void:
	var schema: FlowChipFieldSchema = _fixed_schema()
	var built: FlowChipFieldCreationResult = FlowChipFieldFactory.new().create(schema)
	_check(built.document != null, "Persistence fixture starts from a generated FIXED document.")
	if built.document == null:
		return
	var document: FlowStructuredDocument = built.document
	_check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT)) == OK,
		"1B persistence directory is available.")
	_check(ResourceSaver.save(schema, SCHEMA_PATH) == OK, "ResourceSaver saves the chip field schema.")
	_check(ResourceSaver.save(document, DOCUMENT_PATH) == OK, "ResourceSaver saves the generated document.")

	var loaded_schema: FlowChipFieldSchema = ResourceLoader.load(
		SCHEMA_PATH,
		"",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as FlowChipFieldSchema
	var loaded_document: FlowStructuredDocument = ResourceLoader.load(
		DOCUMENT_PATH,
		"",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as FlowStructuredDocument
	_check(loaded_schema != null and loaded_document != null,
		"ResourceLoader reloads schema and generated document resources.")
	if loaded_schema == null or loaded_document == null:
		return
	_check(loaded_schema.mode == schema.mode and loaded_schema.text_mode == schema.text_mode,
		"Schema mode and text_mode survive ResourceSaver round-trip.")
	_check(loaded_schema.slots.size() == 3 and loaded_schema.slots[1].slot_id == "condition" \
			and loaded_schema.slots[1].required,
		"Slot order, slot IDs, and required metadata survive persistence.")
	_check(loaded_schema.slots[1].accepted_value_types == [FlowLiteralValueSource.TYPE_BOOL],
		"Slot allowed Variant.Type survives persistence.")
	_check(loaded_schema.slots[1].accepted_source_kinds == [FlowValueSource.SOURCE_KIND_LITERAL],
		"Slot allowed source kind survives persistence.")
	_check(loaded_schema.slots[1].initial_value_source != null \
			and loaded_schema.slots[1].initial_value_source.get_value() == true,
		"Slot default source and literal value survive persistence.")
	_check(loaded_schema.template_parts.size() == schema.template_parts.size(),
		"Schema text/slot template parts survive persistence.")
	_check(loaded_document.segments.size() == document.segments.size(),
		"Generated document order and segment count survive persistence.")
	var loaded_chips: Array[FlowChipSegment] = _chips(loaded_document)
	_check(_slot_ids(loaded_chips) == ["initialization", "condition", "update"],
		"Generated document slot associations survive persistence.")
	_check(_ids(loaded_chips) == _ids(_chips(document)),
		"Generated segment IDs survive ResourceSaver round-trip.")
	_check(loaded_chips[1].get_value_type() == FlowLiteralValueSource.TYPE_BOOL \
			and loaded_chips[1].get_value() == true,
		"Generated literal Variant.Type and value survive persistence.")
	_check(not FlowChipFieldValidator.validate(loaded_schema, loaded_document).has_errors(),
		"Reloaded schema/document pair still validates.")

	var copied: FlowStructuredDocument = document.duplicate_with_new_ids()
	var original_chips: Array[FlowChipSegment] = _chips(document)
	var copied_chips: Array[FlowChipSegment] = _chips(copied)
	_check(_ids(original_chips).size() == 3 and _ids(copied_chips).size() == 3,
		"Deep duplication preserves all generated chips.")
	for chip_index: int in original_chips.size():
		_check(original_chips[chip_index].get_segment_id() != copied_chips[chip_index].get_segment_id(),
			"Deep duplication creates a new segment_id for every chip.")
		_check(original_chips[chip_index].get_slot_id() == copied_chips[chip_index].get_slot_id(),
			"Deep duplication preserves every semantic slot_id.")
		_check(original_chips[chip_index].get_value_source().get_source_id() \
				!= copied_chips[chip_index].get_value_source().get_source_id(),
			"Independent legacy literal adapters receive independent source IDs.")
	var copied_condition: FlowLiteralValueSegment = _find_literal(copied, "condition")
	if copied_condition != null:
		copied_condition.value = false
	_check(_find_literal(document, "condition").value == true,
		"Mutating a duplicated literal does not mutate the original document.")

	var source_schema: FlowChipFieldSchema = FlowChipFieldSchema.new()
	source_schema.mode = FlowChipFieldSchema.Mode.FLEXIBLE
	source_schema.flexible_max_count = 1
	source_schema.accepted_value_types = [FlowLiteralValueSource.TYPE_INT]
	source_schema.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_LITERAL]
	var source_document: FlowStructuredDocument = FlowStructuredDocument.new()
	var source_chip: FlowChipSegment = FlowChipSegment.new()
	var persisted_source: FlowLiteralValueSource = FlowLiteralValueSource.new(
		FlowLiteralValueSource.TYPE_INT,
		9
	)
	source_chip.value_source = persisted_source
	source_document.segments = [source_chip]
	_check(not FlowChipFieldValidator.validate(source_schema, source_document).has_errors(),
		"Generic source fixture validates before persistence.")
	_check(ResourceSaver.save(source_schema, SOURCE_SCHEMA_PATH) == OK,
		"ResourceSaver saves the generic source schema fixture.")
	_check(ResourceSaver.save(source_document, SOURCE_DOCUMENT_PATH) == OK,
		"ResourceSaver saves a generic source-bearing chip document.")
	var loaded_source_document: FlowStructuredDocument = ResourceLoader.load(
		SOURCE_DOCUMENT_PATH,
		"",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as FlowStructuredDocument
	var loaded_source_chip: FlowChipSegment = null
	if loaded_source_document != null and not loaded_source_document.segments.is_empty():
		loaded_source_chip = loaded_source_document.segments[0] as FlowChipSegment
	_check(loaded_source_chip != null \
			and loaded_source_chip.get_value_source().get_source_id() == persisted_source.get_source_id(),
		"Persistent generic source IDs survive ResourceSaver when the source is a stored boundary.")
	var copied_source_document: FlowStructuredDocument = source_document.duplicate_with_new_ids()
	var copied_source_chip: FlowChipSegment = copied_source_document.segments[0] as FlowChipSegment
	_check(copied_source_chip.get_value_source().get_source_id() != persisted_source.get_source_id(),
		"Deep duplication gives a persistent generic source a new independent source ID.")
	var copied_literal_source: FlowLiteralValueSource = copied_source_chip.get_value_source() as FlowLiteralValueSource
	copied_literal_source.set_literal(FlowLiteralValueSource.TYPE_INT, 10)
	_check(persisted_source.get_value() == 9,
		"Mutating a duplicated generic source does not mutate the original source.")


func _fixed_schema() -> FlowChipFieldSchema:
	var schema: FlowChipFieldSchema = FlowChipFieldSchema.new()
	schema.mode = FlowChipFieldSchema.Mode.FIXED
	schema.text_mode = FlowChipFieldSchema.TextMode.DOCUMENTATION
	schema.slots = [
		_fixed_slot("initialization", "Initialization", FlowLiteralValueSource.TYPE_INT, 0),
		_fixed_slot("condition", "Condition", FlowLiteralValueSource.TYPE_BOOL, true),
		_fixed_slot("update", "Update", FlowLiteralValueSource.TYPE_INT, 1),
	]
	schema.template_parts = [
		FlowChipFieldTemplatePart.text_part("Inicio: "),
		FlowChipFieldTemplatePart.slot_part("initialization"),
		FlowChipFieldTemplatePart.text_part(" Condición: "),
		FlowChipFieldTemplatePart.slot_part("condition"),
		FlowChipFieldTemplatePart.text_part(" Incremento: "),
		FlowChipFieldTemplatePart.slot_part("update"),
	]
	return schema


func _hybrid_schema() -> FlowChipFieldSchema:
	var schema: FlowChipFieldSchema = FlowChipFieldSchema.new()
	schema.mode = FlowChipFieldSchema.Mode.HYBRID
	schema.text_mode = FlowChipFieldSchema.TextMode.DOCUMENTATION
	var target: FlowChipSlotDefinition = _fixed_slot(
		"target",
		"Target",
		FlowLiteralValueSource.TYPE_STRING,
		"self"
	)
	var optional: FlowChipSlotDefinition = FlowChipSlotDefinition.new("optional", "Optional", false)
	schema.slots = [target, optional]
	var arguments: FlowChipSlotDefinition = FlowChipSlotDefinition.new("argument", "Argument", false)
	arguments.repeatable = true
	arguments.min_count = 1
	arguments.max_count = 3
	arguments.accepted_value_types = [FlowLiteralValueSource.TYPE_INT]
	arguments.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_LITERAL]
	arguments.initial_value_source = FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_INT, 0)
	schema.variadic_slot_definition = arguments
	schema.template_parts = [
		FlowChipFieldTemplatePart.text_part("Target: "),
		FlowChipFieldTemplatePart.slot_part("target"),
		FlowChipFieldTemplatePart.text_part(" Arguments: "),
		FlowChipFieldTemplatePart.slot_part("argument"),
	]
	return schema


func _fixed_slot(
		slot_id: String,
		display_name: String,
		value_type: Variant.Type,
		value: Variant
) -> FlowChipSlotDefinition:
	var definition: FlowChipSlotDefinition = FlowChipSlotDefinition.new(slot_id, display_name, true)
	definition.accepted_value_types = [value_type]
	definition.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_LITERAL]
	definition.initial_value_source = FlowLiteralValueSource.new(value_type, value)
	definition.allow_delete = false
	definition.allow_reorder = false
	return definition


func _literal(value_type: Variant.Type, value: Variant) -> FlowLiteralValueSegment:
	return FlowLiteralValueSegment.new(value_type, value)


func _variadic_literal(value: int) -> FlowLiteralValueSegment:
	var literal: FlowLiteralValueSegment = _literal(FlowLiteralValueSource.TYPE_INT, value)
	literal.slot_id = "argument"
	literal.slot_kind = FlowChipSegment.SLOT_KIND_VARIADIC
	return literal


func _chips(document: FlowStructuredDocument) -> Array[FlowChipSegment]:
	var result: Array[FlowChipSegment] = []
	for segment: FlowDocumentSegment in document.segments:
		if segment is FlowChipSegment:
			result.append(segment as FlowChipSegment)
	return result


func _text_segments(document: FlowStructuredDocument) -> Array[FlowTextSegment]:
	var result: Array[FlowTextSegment] = []
	for segment: FlowDocumentSegment in document.segments:
		if segment is FlowTextSegment:
			result.append(segment as FlowTextSegment)
	return result


func _find_chip(document: FlowStructuredDocument, slot_id: String) -> FlowChipSegment:
	for chip: FlowChipSegment in _chips(document):
		if chip.slot_id == slot_id:
			return chip
	return null


func _find_literal(document: FlowStructuredDocument, slot_id: String) -> FlowLiteralValueSegment:
	var chip: FlowChipSegment = _find_chip(document, slot_id)
	return chip as FlowLiteralValueSegment if chip is FlowLiteralValueSegment else null


func _remove_chip_by_slot(document: FlowStructuredDocument, slot_id: String) -> void:
	for index: int in document.segments.size():
		var segment: FlowDocumentSegment = document.segments[index]
		if segment is FlowChipSegment and (segment as FlowChipSegment).slot_id == slot_id:
			document.segments.remove_at(index)
			return


func _remove_variadic_chips(document: FlowStructuredDocument, slot_id: String) -> void:
	for index: int in range(document.segments.size() - 1, -1, -1):
		var segment: FlowDocumentSegment = document.segments[index]
		if segment is FlowChipSegment and (segment as FlowChipSegment).slot_id == slot_id:
			document.segments.remove_at(index)


func _slot_ids(chips: Array[FlowChipSegment]) -> Array[String]:
	var result: Array[String] = []
	for chip: FlowChipSegment in chips:
		result.append(chip.slot_id)
	return result


func _ids(chips: Array[FlowChipSegment]) -> Array[String]:
	var result: Array[String] = []
	for chip: FlowChipSegment in chips:
		result.append(chip.get_segment_id())
	return result


func _all_ids_unique(chips: Array[FlowChipSegment]) -> bool:
	var ids: Dictionary = {}
	for chip: FlowChipSegment in chips:
		if ids.has(chip.get_segment_id()) or not FlowId.is_valid(chip.get_segment_id()):
			return false
		ids[chip.get_segment_id()] = true
	return true


func _all_sources_present(chips: Array[FlowChipSegment]) -> bool:
	for chip: FlowChipSegment in chips:
		if chip.get_value_source() == null:
			return false
	return true


func _has_code(result: FlowValidationResult, code: StringName) -> bool:
	for diagnostic: FlowDiagnostic in result.diagnostics:
		if diagnostic.code == code:
			return true
	return false


func _cleanup() -> void:
	for path: String in [SCHEMA_PATH, DOCUMENT_PATH, SOURCE_SCHEMA_PATH, SOURCE_DOCUMENT_PATH]:
		var absolute_path: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)
	var absolute_root: String = ProjectSettings.globalize_path(TEMP_ROOT)
	if DirAccess.dir_exists_absolute(absolute_root):
		DirAccess.remove_absolute(absolute_root)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	_failures.append(message)
	push_error(message)
	return false


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Flow chips core 1B test passed")
	else:
		for failure: String in _failures:
			push_error(failure)
	get_tree().quit(0 if _failures.is_empty() else 1)
