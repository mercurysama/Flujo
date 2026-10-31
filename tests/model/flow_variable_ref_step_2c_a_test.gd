extends Node


const TEMP_ROOT: String = "res://.godot/flujo_tests/variable_ref_step_2c_a"
const RESOURCE_PATH: String = TEMP_ROOT + "/document.tres"


var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_source_identity_and_validation()
	_test_document_duplication()
	_test_resource_saver_round_trip()
	_test_factory_and_field_validation()
	_cleanup()
	_finish()


func _test_source_identity_and_validation() -> void:
	var graph: FlowGraph = FlowGraph.new()
	var count: FlowVariableDefinition = _variable(
		"Count",
		FlowVariableDefinition.ValueType.INT
	)
	graph.variables = [count]
	var source: FlowVariableRefValueSource = FlowVariableRefValueSource.new(
		count.get_internal_id(),
		count.value_type
	)
	var segment: FlowVariableRefSegment = FlowVariableRefSegment.new(source)
	var text: FlowTextSegment = FlowTextSegment.new()
	text.text = "Value: "
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	document.segments = [text, segment]

	_check(FlowId.is_valid(source.get_source_id()), "VariableRef source has a stable source_id.")
	_check(source.get_variable_id() == count.get_internal_id(),
		"VariableRef stores the variable's stable ID rather than its display name.")
	_check(source.get_declared_value_type() == count.value_type,
		"VariableRef stores the declared FlowVariableDefinition value type.")
	_check(not source.get_value(), "VariableRef has no implicit authored literal value.")
	var valid: FlowValidationResult = FlowStructuredDocumentValidator.validate(document, graph)
	_check(not valid.has_errors(), "A graph-resolved VariableRef validates without diagnostics.")

	var missing_source: FlowVariableRefValueSource = FlowVariableRefValueSource.new(
		FlowId.create(),
		FlowVariableDefinition.ValueType.INT
	)
	var missing_segment: FlowVariableRefSegment = FlowVariableRefSegment.new(missing_source)
	var missing_document: FlowStructuredDocument = FlowStructuredDocument.new()
	missing_document.segments = [missing_segment]
	var missing_result: FlowValidationResult = FlowStructuredDocumentValidator.validate(
		missing_document,
		graph
	)
	_check(_has_code(missing_result, FlowDiagnostic.CODE_VARIABLE_REFERENCE_MISSING),
		"A missing graph variable produces a structured VariableRef diagnostic.")

	var mismatch_source: FlowVariableRefValueSource = FlowVariableRefValueSource.new(
		count.get_internal_id(),
		FlowVariableDefinition.ValueType.STRING
	)
	var mismatch_document: FlowStructuredDocument = FlowStructuredDocument.new()
	mismatch_document.segments = [FlowVariableRefSegment.new(mismatch_source)]
	var mismatch_result: FlowValidationResult = FlowStructuredDocumentValidator.validate(
		mismatch_document,
		graph
	)
	_check(_has_code(mismatch_result, FlowDiagnostic.CODE_VARIABLE_REFERENCE_TYPE_MISMATCH),
		"A resolved VariableRef type mismatch is diagnosed without repair.")


func _test_document_duplication() -> void:
	var variable_id: String = FlowId.create()
	var source: FlowVariableRefValueSource = FlowVariableRefValueSource.new(
		variable_id,
		FlowVariableDefinition.ValueType.STRING
	)
	var original_segment: FlowVariableRefSegment = FlowVariableRefSegment.new(source)
	var original: FlowStructuredDocument = FlowStructuredDocument.new()
	original.segments = [FlowTextSegment.new(), null, original_segment]
	var copy: FlowStructuredDocument = original.duplicate_with_new_ids()
	var copied_segment: FlowVariableRefSegment = copy.segments[2] as FlowVariableRefSegment
	_check(copy != original and copy.segments[1] == null,
		"VariableRef document duplication preserves independence and null positions.")
	_check(copied_segment != null and copied_segment.get_segment_id() != original_segment.get_segment_id(),
		"Duplicated VariableRef receives a new segment_id.")
	var copied_source: FlowVariableRefValueSource = copied_segment.get_value_source() as FlowVariableRefValueSource \
		if copied_segment != null else null
	_check(copied_source != null and copied_source.get_source_id() != source.get_source_id(),
		"Duplicated VariableRef receives an independent source_id.")
	_check(copied_source != null and copied_source.variable_id == variable_id,
		"Duplication preserves the external graph variable ID.")
	_check(original_segment.get_segment_id() != copied_segment.get_segment_id(),
		"Duplication does not mutate the original VariableRef segment.")


func _test_resource_saver_round_trip() -> void:
	var variable_id: String = FlowId.create()
	var source: FlowVariableRefValueSource = FlowVariableRefValueSource.new(
		variable_id,
		FlowVariableDefinition.ValueType.VECTOR2
	)
	var segment: FlowVariableRefSegment = FlowVariableRefSegment.new(source)
	segment.set_slot_id("value")
	segment.set_slot_kind(FlowChipSegment.SLOT_KIND_VARIADIC)
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	document.segments = [segment]
	_check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT)) == OK,
		"VariableRef persistence directory is available.")
	_check(ResourceSaver.save(document, RESOURCE_PATH) == OK,
		"ResourceSaver saves a VariableRef document.")
	var loaded: FlowStructuredDocument = ResourceLoader.load(
		RESOURCE_PATH,
		"",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as FlowStructuredDocument
	_check(loaded != null, "ResourceLoader reloads a VariableRef document.")
	if loaded == null:
		return
	var loaded_segment: FlowVariableRefSegment = loaded.segments[0] as FlowVariableRefSegment
	var loaded_source: FlowVariableRefValueSource = loaded_segment.get_value_source() as FlowVariableRefValueSource \
		if loaded_segment != null else null
	_check(loaded_segment != null and loaded_segment.get_segment_id() == segment.get_segment_id(),
		"VariableRef segment_id survives ResourceSaver reload.")
	_check(loaded_source != null and loaded_source.get_source_id() == source.get_source_id(),
		"VariableRef source_id survives ResourceSaver reload.")
	_check(loaded_source != null and loaded_source.variable_id == variable_id \
			and loaded_source.declared_value_type == FlowVariableDefinition.ValueType.VECTOR2,
		"VariableRef variable ID and declared type survive ResourceSaver reload.")
	_check(loaded_segment != null and loaded_segment.get_slot_id() == "value" \
			and loaded_segment.get_slot_kind() == FlowChipSegment.SLOT_KIND_VARIADIC,
		"VariableRef slot identity survives ResourceSaver reload.")


func _test_factory_and_field_validation() -> void:
	var variable: FlowVariableDefinition = _variable(
		"Factory Variable",
		FlowVariableDefinition.ValueType.STRING
	)
	var graph: FlowGraph = FlowGraph.new()
	graph.variables = [variable]
	var field: FlowChipFieldSchema = FlowChipFieldSchema.new()
	field.mode = FlowChipFieldSchema.Mode.FIXED
	field.accepted_value_types = [Variant.Type.TYPE_STRING]
	field.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_VARIABLE_REF]
	var slot: FlowChipSlotDefinition = FlowChipSlotDefinition.new("value", "Value", true)
	slot.accepted_value_types = [Variant.Type.TYPE_STRING]
	slot.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_VARIABLE_REF]
	slot.initial_value_source = FlowVariableRefValueSource.new(
		variable.get_internal_id(),
		variable.value_type
	)
	slot.allow_delete = false
	slot.min_count = 1
	slot.max_count = 1
	field.slots = [slot]
	field.add_text_part("Value: ")
	field.add_slot_part("value")
	var creation: FlowChipFieldCreationResult = FlowChipFieldFactory.new().create(field)
	_check(creation.is_successful() and creation.document != null,
		"The generic field factory materializes a VariableRef initial source.")
	if creation.document == null:
		return
	_check(creation.document.segments[1] is FlowVariableRefSegment,
		"Factory output retains the concrete VariableRef segment type.")
	var validation: FlowValidationResult = FlowChipFieldValidator.validate(
		field,
		creation.document,
		graph
	)
	_check(not validation.has_errors(),
		"A fixed field with a graph-owned VariableRef source validates successfully.")


func _variable(name: String, value_type: FlowVariableDefinition.ValueType) -> FlowVariableDefinition:
	var variable: FlowVariableDefinition = FlowVariableDefinition.new()
	variable.display_name = name
	variable.value_type = value_type
	return variable


func _has_code(result: FlowValidationResult, code: StringName) -> bool:
	for diagnostic: FlowDiagnostic in result.diagnostics:
		if diagnostic.code == code:
			return true
	return false


func _cleanup() -> void:
	var absolute_path: String = ProjectSettings.globalize_path(RESOURCE_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
	var absolute_root: String = ProjectSettings.globalize_path(TEMP_ROOT)
	if DirAccess.dir_exists_absolute(absolute_root):
		DirAccess.remove_absolute(absolute_root)


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	_failures.append(message)
	push_error("[Flujo] VariableRef model check failed: " + message)
	return false


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Flow VariableRef Step 2C-A model test passed")
	else:
		push_error("[Flujo] Flow VariableRef Step 2C-A model test failed: %d failures" % _failures.size())
	get_tree().quit(0 if _failures.is_empty() else 1)
