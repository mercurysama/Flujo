extends Node


const TEMP_ROOT: String = "res://.godot/flujo_tests/complex_values_lot_08"
const DOCUMENT_PATH: String = TEMP_ROOT + "/complex_document.tres"
const RESOURCE_PATH: String = TEMP_ROOT + "/gradient.tres"

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT))
	_test_array_and_dictionary_resolution()
	_test_resource_ref()
	_test_enum_and_bitfield()
	_test_factory_projection()
	_test_deep_duplication()
	_test_persistence()
	_cleanup()
	_finish()


func _test_array_and_dictionary_resolution() -> void:
	var graph: FlowGraph = FlowGraph.new()
	var count: FlowVariableDefinition = FlowVariableDefinition.new()
	count.display_name = "Count"
	count.value_type = FlowVariableDefinition.ValueType.INT
	count.int_value = 7
	graph.variables = [count]

	var variable: FlowVariableRefValueSource = FlowVariableRefValueSource.new(
		count.get_internal_id(),
		count.value_type
	)
	var operation: FlowOperationValueSource = FlowOperationValueSource.new(
		FlowOperationOperatorCatalog.OPERATOR_ADD,
		[
			FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 2),
			FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 3),
		]
	)
	var nested_dictionary: FlowDictionaryValueSource = FlowDictionaryValueSource.new([
		FlowDictionaryEntry.new(
			"name",
			FlowLiteralValueSource.new(Variant.Type.TYPE_STRING, "Flujo")
		),
		FlowDictionaryEntry.new("count", variable),
	])
	var array: FlowArrayValueSource = FlowArrayValueSource.new([
		FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 1),
		operation,
		nested_dictionary,
	])

	_check(array.is_valid(), "Array accepts nested FlowValueSources.")
	var result: FlowValueResult = array.resolve(graph)
	_check(
		result.success
			and result.value_type == Variant.Type.TYPE_ARRAY
			and result.value.size() == 3
			and result.value[0] == 1
			and result.value[1] == 5
			and result.value[2] is Dictionary
			and result.value[2]["name"] == "Flujo"
			and result.value[2]["count"] == 7,
		"Array recursively resolves Literal, Operation, Dictionary and VariableRef children."
	)
	_check(
		array.get_preview(graph).contains("Count"),
		"Collection preview resolves graph variable names without flattening sources."
	)

	var duplicate_keys: FlowDictionaryValueSource = FlowDictionaryValueSource.new([
		FlowDictionaryEntry.new(
			" x ",
			FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 1)
		),
		FlowDictionaryEntry.new(
			"x",
			FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 2)
		),
	])
	var validation: FlowValidationResult = FlowValidationResult.new()
	duplicate_keys.validate_structure(validation, "dictionary")
	_check(
		_has_code(validation, FlowDiagnostic.CODE_DICTIONARY_KEY_DUPLICATE),
		"Dictionary treats trimmed String keys as one semantic key."
	)


func _test_resource_ref() -> void:
	var gradient: Gradient = Gradient.new()
	gradient.add_point(0.5, Color(0.2, 0.4, 0.8))
	_check(
		ResourceSaver.save(gradient, RESOURCE_PATH) == OK,
		"Resource fixture saves."
	)

	var source: FlowResourceRefValueSource = FlowResourceRefValueSource.new(
		RESOURCE_PATH,
		&"Gradient"
	)
	_check(source.is_valid() and source.has_path(), "ResourceRef is structurally valid.")
	var result: FlowValueResult = source.resolve()
	_check(
		result.success
			and result.value_type == Variant.Type.TYPE_OBJECT
			and result.value is Gradient,
		"ResourceRef resolves the live project Resource through ResourceLoader."
	)

	var mismatch: FlowResourceRefValueSource = FlowResourceRefValueSource.new(
		RESOURCE_PATH,
		&"Curve"
	)
	var mismatch_result: FlowValueResult = mismatch.resolve()
	_check(
		not mismatch_result.success
			and mismatch_result.diagnostic != null
			and mismatch_result.diagnostic.code == FlowDiagnostic.CODE_RESOURCE_REF_TYPE_MISMATCH,
		"ResourceRef enforces the authored Resource class."
	)

	var placeholder: FlowResourceRefValueSource = FlowResourceRefValueSource.placeholder(&"Resource")
	var placeholder_validation: FlowValidationResult = FlowValidationResult.new()
	placeholder.validate_structure(placeholder_validation, "resource")
	_check(
		not placeholder_validation.has_errors()
			and _has_code(placeholder_validation, FlowDiagnostic.CODE_RESOURCE_REF_PATH_MISSING),
		"Unbound ResourceRef is structurally valid but emits a warning."
	)
	_check(
		not placeholder.resolve().success,
		"Unbound ResourceRef fails only at runtime resolution."
	)


func _test_enum_and_bitfield() -> void:
	var enum_source: FlowEnumValueSource = FlowEnumValueSource.new(
		&"Direction",
		[&"Left", &"Right", &"Up"],
		[0, 10, 20],
		10,
		true
	)
	_check(enum_source.is_valid(), "Enum preserves named non-contiguous int options.")
	var enum_result: FlowValueResult = enum_source.resolve()
	_check(
		enum_result.success
			and enum_result.value == 10
			and enum_source.get_preview() == "Direction.Right",
		"Enum resolves to int while preview preserves semantic option name."
	)

	var unset_enum: FlowEnumValueSource = FlowEnumValueSource.new(
		&"Direction",
		[&"Left", &"Right"],
		[0, 1],
		0,
		false
	)
	_check(
		not unset_enum.is_valid(),
		"Enum requires an explicit selected option even when value 0 exists."
	)

	var flags: FlowBitfieldValueSource = FlowBitfieldValueSource.new(
		&"Permissions",
		[&"Read", &"Write", &"Execute"],
		[1, 2, 4],
		5
	)
	_check(flags.is_valid(), "Bitfield accepts unique power-of-two flags.")
	var flag_result: FlowValueResult = flags.resolve()
	_check(
		flag_result.success
			and flag_result.value == 5
			and flags.get_preview().contains("Read")
			and flags.get_preview().contains("Execute"),
		"Bitfield resolves to int mask while preview preserves selected names."
	)

	var invalid_flags: FlowBitfieldValueSource = FlowBitfieldValueSource.new(
		&"Broken",
		[&"A", &"Overlap"],
		[1, 3],
		1
	)
	_check(
		not invalid_flags.is_valid(),
		"Bitfield rejects overlapping/non-power-of-two flag definitions."
	)


func _test_factory_projection() -> void:
	var sources: Array[FlowValueSource] = [
		FlowArrayValueSource.new(),
		FlowDictionaryValueSource.new(),
		FlowResourceRefValueSource.placeholder(&"Resource"),
		FlowEnumValueSource.new(&"Mode", [&"A", &"B"], [0, 1], 1, true),
		FlowBitfieldValueSource.new(&"Flags", [&"A", &"B"], [1, 2], 3),
	]
	var expected_classes: Array[StringName] = [
		&"FlowArraySegment",
		&"FlowDictionarySegment",
		&"FlowResourceRefSegment",
		&"FlowEnumSegment",
		&"FlowBitfieldSegment",
	]
	for index: int in sources.size():
		var source: FlowValueSource = sources[index]
		var schema: FlowChipFieldSchema = _fixed_schema(
			source.get_value_type(),
			source.get_source_kind(),
			source
		)
		var creation: FlowChipFieldCreationResult = FlowChipFieldFactory.new().create(schema)
		_check(
			creation.document != null
				and creation.document.segments.size() == 1
				and StringName(creation.document.segments[0].get_class()) == expected_classes[index],
			"Factory projects %s to its semantic Tok." % String(source.get_source_kind())
		)


func _test_deep_duplication() -> void:
	var graph: FlowGraph = FlowGraph.new()
	var count: FlowVariableDefinition = FlowVariableDefinition.new()
	count.display_name = "Count"
	count.value_type = FlowVariableDefinition.ValueType.INT
	graph.variables = [count]

	var variable: FlowVariableRefValueSource = FlowVariableRefValueSource.new(
		count.get_internal_id(),
		count.value_type
	)
	var dictionary: FlowDictionaryValueSource = FlowDictionaryValueSource.new([
		FlowDictionaryEntry.new("count", variable),
	])
	var array: FlowArrayValueSource = FlowArrayValueSource.new([dictionary])
	var copy: FlowArrayValueSource = array.duplicate_with_new_id() as FlowArrayValueSource
	var copied_dictionary: FlowDictionaryValueSource = copy.elements[0] as FlowDictionaryValueSource
	var copied_variable: FlowVariableRefValueSource = 		copied_dictionary.entries[0].value_source as FlowVariableRefValueSource
	_check(
		copy.source_id != array.source_id
			and copied_dictionary.source_id != dictionary.source_id
			and copied_dictionary.entries[0].entry_id != dictionary.entries[0].entry_id
			and copied_variable.source_id != variable.source_id
			and copied_variable.variable_id == variable.variable_id,
		"Deep duplication renews owned collection IDs and preserves external variable identity."
	)


func _test_persistence() -> void:
	var array: FlowArrayValueSource = FlowArrayValueSource.new([
		FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 3),
		FlowArrayValueSource.new([
			FlowLiteralValueSource.new(Variant.Type.TYPE_STRING, "nested"),
		]),
	])
	var dictionary: FlowDictionaryValueSource = FlowDictionaryValueSource.new([
		FlowDictionaryEntry.new(
			"enabled",
			FlowLiteralValueSource.new(Variant.Type.TYPE_BOOL, true)
		),
	])
	var resource: FlowResourceRefValueSource = FlowResourceRefValueSource.new(
		RESOURCE_PATH,
		&"Gradient"
	)
	var enum_source: FlowEnumValueSource = FlowEnumValueSource.new(
		&"Mode",
		[&"A", &"B"],
		[0, 1],
		1,
		true
	)
	var bitfield: FlowBitfieldValueSource = FlowBitfieldValueSource.new(
		&"Flags",
		[&"A", &"B"],
		[1, 2],
		3
	)
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	document.segments = [
		FlowArraySegment.new(array),
		FlowDictionarySegment.new(dictionary),
		FlowResourceRefSegment.new(resource),
		FlowEnumSegment.new(enum_source),
		FlowBitfieldSegment.new(bitfield),
	]
	_check(
		not FlowStructuredDocumentValidator.validate(document).has_errors(),
		"StructuredDocumentValidator recognizes all Lot-08 semantic Toks."
	)
	_check(
		ResourceSaver.save(document, DOCUMENT_PATH) == OK,
		"Complex document saves through ResourceSaver."
	)
	var loaded: FlowStructuredDocument = ResourceLoader.load(
		DOCUMENT_PATH,
		"",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as FlowStructuredDocument
	_check(
		loaded != null
			and loaded.segments.size() == 5
			and loaded.segments[0] is FlowArraySegment
			and loaded.segments[1] is FlowDictionarySegment
			and loaded.segments[2] is FlowResourceRefSegment
			and loaded.segments[3] is FlowEnumSegment
			and loaded.segments[4] is FlowBitfieldSegment,
		"All complex Tok classes survive ResourceLoader."
	)
	if loaded == null or loaded.segments.size() != 5:
		return
	var loaded_array: FlowArrayValueSource = 		(loaded.segments[0] as FlowArraySegment).get_value_source() as FlowArrayValueSource
	var loaded_enum: FlowEnumValueSource = 		(loaded.segments[3] as FlowEnumSegment).get_value_source() as FlowEnumValueSource
	_check(
		loaded_array != null
			and loaded_array.source_id == array.source_id
			and loaded_array.elements[1] is FlowArrayValueSource
			and loaded_enum != null
			and loaded_enum.has_selection
			and loaded_enum.get_preview() == "Mode.B",
		"Persistence preserves nested structure, source IDs and enum selection metadata."
	)


func _fixed_schema(
		value_type: Variant.Type,
		source_kind: StringName,
		source: FlowValueSource
) -> FlowChipFieldSchema:
	var field: FlowChipFieldSchema = FlowChipFieldSchema.new()
	field.mode = FlowChipFieldSchema.Mode.FIXED
	field.text_mode = FlowChipFieldSchema.TextMode.DISABLED
	field.accepted_value_types = [value_type]
	field.accepted_source_kinds = [source_kind]
	var slot: FlowChipSlotDefinition = FlowChipSlotDefinition.new("value", "Value", true)
	slot.accepted_value_types = [value_type]
	slot.accepted_source_kinds = [source_kind]
	slot.initial_value_source = source
	slot.min_count = 1
	slot.max_count = 1
	slot.allow_delete = false
	field.slots = [slot]
	field.add_slot_part("value")
	return field


func _has_code(result: FlowValidationResult, code: StringName) -> bool:
	for diagnostic: FlowDiagnostic in result.diagnostics:
		if diagnostic != null and diagnostic.code == code:
			return true
	return false


func _cleanup() -> void:
	for path: String in [DOCUMENT_PATH, RESOURCE_PATH]:
		var absolute_path: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)
	var absolute_root: String = ProjectSettings.globalize_path(TEMP_ROOT)
	if DirAccess.dir_exists_absolute(absolute_root):
		DirAccess.remove_absolute(absolute_root)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("[Flujo] Lot 08 complex value check failed: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Lot 08 complex value model test passed")
	else:
		push_error(
			"[Flujo] Lot 08 model test failed: %d failures" % _failures.size()
		)
	get_tree().quit(0 if _failures.is_empty() else 1)
