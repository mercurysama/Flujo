extends Node


var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_schema_modes_and_slots()
	_test_literal_value_sources()
	_test_chip_source_boundary_and_duplication()
	_finish()


func _test_schema_modes_and_slots() -> void:
	var condition: FlowChipSlotDefinition = FlowChipSlotDefinition.new(
		"condition",
		"Condition",
		true
	)
	condition.accepted_value_types.append(FlowLiteralValueSource.TYPE_BOOL)
	condition.accepted_source_kinds.append(FlowValueSource.SOURCE_KIND_LITERAL)
	condition.allow_delete = false
	condition.allow_reorder = false
	_check(condition.slot_id == "condition", "A slot keeps its semantic slot_id.")
	_check(condition.display_name == "Condition", "A slot exposes its display name separately from slot_id.")
	_check(condition.required, "A slot records required state.")
	_check(not condition.allow_delete and not condition.allow_reorder, "A slot records delete and reorder policy.")
	_check(condition.accepts_value_type(FlowLiteralValueSource.TYPE_BOOL), "A slot accepts its declared value type.")
	_check(condition.accepts_source_kind(FlowValueSource.SOURCE_KIND_LITERAL), "A slot accepts its declared source kind.")

	var fixed: FlowChipFieldSchema = FlowChipFieldSchema.new()
	fixed.mode = FlowChipFieldSchema.Mode.FIXED
	fixed.text_policy = FlowChipFieldSchema.TextMode.DOCUMENTATION
	fixed.slots = [condition]
	_check(FlowChipFieldSchema.is_valid_mode(fixed.mode), "FIXED is a supported schema mode.")
	_check(fixed.accepts_text(), "DOCUMENTATION permits text in the field contract.")
	_check(fixed.get_slot_definition("condition") == condition, "FIXED resolves a slot by semantic slot_id.")
	_check(fixed.get_slot_definition("0") == null, "A slot is not resolved by an array index string.")

	var flexible: FlowChipFieldSchema = FlowChipFieldSchema.new()
	flexible.mode = FlowChipFieldSchema.Mode.FLEXIBLE
	flexible.text_policy = FlowChipFieldSchema.TextMode.RUNTIME_CONTENT
	flexible.flexible_min_count = 1
	flexible.flexible_max_count = 3
	flexible.accepted_value_types.append(FlowLiteralValueSource.TYPE_STRING)
	flexible.accepted_source_kinds.append(FlowValueSource.SOURCE_KIND_LITERAL)
	_check(FlowChipFieldSchema.is_valid_mode(flexible.mode), "FLEXIBLE is a supported schema mode.")
	_check(flexible.get_flexible_min_count() == 1 and flexible.get_flexible_max_count() == 3,
		"FLEXIBLE exposes explicit minimum and maximum counts.")
	_check(flexible.accepts_value_type(FlowLiteralValueSource.TYPE_STRING),
		"FLEXIBLE exposes field-level accepted value types.")
	_check(flexible.accepts_source_kind(FlowValueSource.SOURCE_KIND_LITERAL),
		"FLEXIBLE exposes field-level accepted source kinds.")

	var variadic: FlowChipSlotDefinition = FlowChipSlotDefinition.new("arguments", "Arguments")
	variadic.repeatable = true
	variadic.min_count = 0
	variadic.max_count = FlowChipSlotDefinition.UNLIMITED_COUNT
	var hybrid: FlowChipFieldSchema = FlowChipFieldSchema.new()
	hybrid.mode = FlowChipFieldSchema.Mode.HYBRID
	hybrid.text_policy = FlowChipFieldSchema.TextMode.DISABLED
	hybrid.slots = [condition]
	hybrid.variadic_slot_definition = variadic
	_check(FlowChipFieldSchema.is_valid_mode(hybrid.mode), "HYBRID is a supported schema mode.")
	_check(not hybrid.accepts_text(), "DISABLED rejects free text at the schema boundary.")
	_check(hybrid.get_variadic_slot_definition() == variadic, "HYBRID exposes its variadic slot definition.")
	_check(variadic.is_repeatable() and variadic.max_count == FlowChipSlotDefinition.UNLIMITED_COUNT,
		"A variadic slot records repeatability and an unlimited maximum.")

	var copied_schema: FlowChipFieldSchema = hybrid.duplicate_with_new_ids()
	_check(copied_schema.get_schema_id() != hybrid.get_schema_id(), "Duplicating a schema creates a new schema ID.")
	_check(copied_schema.get_slot_definition("condition") != null,
		"Schema duplication preserves the semantic slot_id.")
	_check(copied_schema.get_variadic_slot_definition().slot_id == "arguments",
		"Schema duplication preserves the variadic semantic slot_id.")

	for text_mode: int in [
		FlowChipFieldSchema.TextMode.DOCUMENTATION,
		FlowChipFieldSchema.TextMode.RUNTIME_CONTENT,
		FlowChipFieldSchema.TextMode.DISABLED,
	]:
		var text_schema: FlowChipFieldSchema = FlowChipFieldSchema.new()
		text_schema.text_policy = text_mode
		_check(FlowChipFieldSchema.is_valid_text_mode(text_mode), "Text policy %d is supported." % text_mode)


func _test_literal_value_sources() -> void:
	var valid_cases: Array[Dictionary] = [
		{"type": FlowLiteralValueSource.TYPE_BOOL, "value": true},
		{"type": FlowLiteralValueSource.TYPE_INT, "value": 7},
		{"type": FlowLiteralValueSource.TYPE_FLOAT, "value": 2.5},
		{"type": FlowLiteralValueSource.TYPE_STRING, "value": "text"},
		{"type": FlowLiteralValueSource.TYPE_STRING_NAME, "value": &"name"},
	]
	for case_data: Dictionary in valid_cases:
		var value_type: Variant.Type = case_data["type"]
		var value: Variant = case_data["value"]
		var source: FlowLiteralValueSource = FlowLiteralValueSource.new(value_type, value)
		_check(source.is_valid(), "LiteralValueSource accepts its exact declared type.")
		_check(source.get_source_kind() == FlowValueSource.SOURCE_KIND_LITERAL,
			"LiteralValueSource exposes the stable literal source kind.")
		_check(source.get_value_type() == value_type and typeof(source.get_value()) == value_type,
			"LiteralValueSource preserves the exact Variant.Type.")
		_check(source.resolve_value() == value, "LiteralValueSource resolves without implicit conversion.")
		_check(FlowId.is_valid(source.get_source_id()), "LiteralValueSource receives a stable FlowId.")

	var int_source: FlowLiteralValueSource = FlowLiteralValueSource.new(
		FlowLiteralValueSource.TYPE_INT,
		3
	)
	_check(not int_source.can_set_literal(FlowLiteralValueSource.TYPE_FLOAT, 3),
		"LiteralValueSource rejects int-to-float conversion.")
	_check(not int_source.can_set_literal(FlowLiteralValueSource.TYPE_STRING, 3),
		"LiteralValueSource rejects int-to-String conversion.")
	_check(not int_source.can_set_literal(FlowLiteralValueSource.TYPE_STRING_NAME, "name"),
		"LiteralValueSource rejects String-to-StringName conversion.")
	_check(int_source.set_literal(FlowLiteralValueSource.TYPE_INT, 4),
		"LiteralValueSource accepts an exact replacement value.")
	_check(int_source.get_value() == 4 and int_source.get_value_type() == FlowLiteralValueSource.TYPE_INT,
		"An exact literal replacement preserves its explicit type.")

	var invalid_sources: Array[FlowLiteralValueSource] = [
		FlowLiteralValueSource.new(Variant.Type.TYPE_NIL, null),
		FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_INT, "3"),
		FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_FLOAT, NAN),
		FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_FLOAT, INF),
		FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_FLOAT, -INF),
		FlowLiteralValueSource.new(typeof([]), []),
		FlowLiteralValueSource.new(typeof({}), {}),
	]
	for source: FlowLiteralValueSource in invalid_sources:
		_check(not source.is_valid(), "Unsupported, mismatched, NIL, or non-finite literals are invalid.")

	var object_value: Object = Object.new()
	var object_source: FlowLiteralValueSource = FlowLiteralValueSource.new(typeof(object_value), object_value)
	_check(not object_source.is_valid(), "Object literals are invalid.")
	object_value.free()
	var resource_source: FlowLiteralValueSource = FlowLiteralValueSource.new(typeof(Resource.new()), Resource.new())
	_check(not resource_source.is_valid(), "Resource literals are invalid.")
	var node_value: Node = Node.new()
	var node_source: FlowLiteralValueSource = FlowLiteralValueSource.new(typeof(node_value), node_value)
	_check(not node_source.is_valid(), "Node literals are invalid.")
	node_value.free()

	var copied_source: FlowValueSource = int_source.duplicate_with_new_id()
	_check(copied_source.get_source_id() != int_source.get_source_id(),
		"Duplicating a ValueSource creates an independent source ID.")
	_check(copied_source.get_value_type() == int_source.get_value_type() and copied_source.get_value() == int_source.get_value(),
		"Duplicating a ValueSource preserves its literal payload.")


func _test_chip_source_boundary_and_duplication() -> void:
	var source: FlowLiteralValueSource = FlowLiteralValueSource.new(
		FlowLiteralValueSource.TYPE_BOOL,
		true
	)
	var chip: FlowChipSegment = FlowChipSegment.new()
	chip.slot_id = "condition"
	chip.value_source = source
	_check(FlowId.is_valid(chip.get_segment_id()), "A chip receives an independent segment_id.")
	_check(chip.get_slot_id() == "condition", "A chip stores its semantic slot_id without using an index.")
	_check(chip.get_value_source() == source, "A generic chip exposes its assigned ValueSource.")
	_check(chip.get_value_type() == FlowLiteralValueSource.TYPE_BOOL and chip.get_value() == true,
		"The chip → value source boundary exposes exact value data.")
	_check(chip.get_segment_id() != chip.get_slot_id() and chip.get_segment_id() != source.get_source_id(),
		"segment_id, slot_id, and source_id are distinct identity concepts.")

	var copied_chip: FlowChipSegment = chip.duplicate_with_new_id() as FlowChipSegment
	_check(copied_chip.get_segment_id() != chip.get_segment_id(), "Duplicating a chip creates a new segment_id.")
	_check(copied_chip.get_slot_id() == chip.get_slot_id(), "Duplicating a chip preserves semantic slot_id.")
	_check(copied_chip.get_value_source().get_source_id() != source.get_source_id(),
		"Duplicating a chip creates an independent ValueSource ID.")
	_check(copied_chip.get_value_source().get_value() == true, "Chip duplication preserves source payload.")

	var legacy: FlowLiteralValueSegment = FlowLiteralValueSegment.new(
		FlowLiteralValueSegment.TYPE_STRING,
		"legacy"
	)
	legacy.slot_id = "message"
	var legacy_source: FlowLiteralValueSource = legacy.get_value_source() as FlowLiteralValueSource
	_check(legacy_source != null, "Legacy LiteralValueSegment exposes a LiteralValueSource adapter.")
	_check(legacy_source.get_value() == "legacy" and legacy_source.get_value_type() == FlowLiteralValueSegment.TYPE_STRING,
		"The legacy adapter mirrors the persisted literal fields exactly.")
	var legacy_source_id: String = legacy_source.get_source_id()
	legacy.value = "updated"
	_check(legacy.get_value_source().get_value() == "updated",
		"The legacy adapter re-syncs when K1/K2 literal storage changes.")
	legacy.set_value_source(FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_INT, 9))
	_check(legacy.value_type == FlowLiteralValueSegment.TYPE_INT and legacy.value == 9,
		"Assigning through the boundary updates legacy storage without sharing resources.")
	var legacy_copy: FlowLiteralValueSegment = legacy.duplicate_with_new_id() as FlowLiteralValueSegment
	var copied_legacy_source: FlowLiteralValueSource = legacy_copy.get_value_source() as FlowLiteralValueSource
	_check(legacy_copy.get_segment_id() != legacy.get_segment_id(), "Legacy duplication creates a new segment_id.")
	_check(legacy_copy.slot_id == legacy.slot_id, "Legacy duplication preserves semantic slot_id.")
	_check(copied_legacy_source.get_source_id() != legacy.get_value_source().get_source_id(),
		"The legacy adapter receives a new source ID for an independent duplicate.")
	_check(legacy_source_id != copied_legacy_source.get_source_id(),
		"The legacy source adapter identity is not reused by duplication.")
	_check(legacy.get_value() == 9, "Duplicating a legacy literal does not mutate the original.")


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	_failures.append(message)
	push_error(message)
	return false


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Flow chips core 1A test passed")
	else:
		for failure: String in _failures:
			push_error(failure)
	get_tree().quit(0 if _failures.is_empty() else 1)
