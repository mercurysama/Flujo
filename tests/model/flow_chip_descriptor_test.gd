extends Node


const DESCRIPTOR_SOURCE_PATH: String = "res://addons/vp_flujo/runtime/model/flow_chip_type_descriptor.gd"
const TOOLTIP_SOURCE_PATH: String = "res://addons/vp_flujo/runtime/model/flow_chip_tooltip_data.gd"
const SEGMENT_SOURCE_PATH: String = "res://addons/vp_flujo/runtime/model/flow_chip_segment.gd"
const LITERAL_SOURCE_PATH: String = "res://addons/vp_flujo/runtime/model/flow_literal_value_segment.gd"


var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_literal_descriptor()
	_test_literal_labels()
	_test_literal_tooltips()
	_test_generic_contract()
	_test_invalid_literal_safety()
	_test_runtime_editor_boundary()
	_finish()


func _test_literal_descriptor() -> void:
	var segment: FlowChipSegment = _literal(FlowLiteralValueSegment.TYPE_INT, 100)
	var descriptor: FlowChipTypeDescriptor = _consume_descriptor(segment)
	_check(descriptor != null, "LiteralValue exposes a non-null generic chip descriptor.")
	if descriptor == null:
		return
	_check(descriptor.type_id == &"literal_value", "LiteralValue uses the stable literal_value type ID.")
	_check(descriptor.display_name == "Literal", "LiteralValue descriptor uses the Literal display name.")
	_check(descriptor.category == &"literal", "LiteralValue descriptor uses the literal semantic category.")
	_check(descriptor.label_strategy == &"value", "LiteralValue descriptor declares value label strategy.")
	_check(descriptor.semantic_style_role == &"literal", "LiteralValue descriptor declares a literal semantic style role.")
	_check(descriptor.editable, "LiteralValue descriptor marks the chip as editable.")


func _test_literal_labels() -> void:
	var cases: Array[Dictionary] = [
		{"segment": _literal(FlowLiteralValueSegment.TYPE_BOOL, true), "expected": "true"},
		{"segment": _literal(FlowLiteralValueSegment.TYPE_BOOL, false), "expected": "false"},
		{"segment": _literal(FlowLiteralValueSegment.TYPE_INT, 100), "expected": "100"},
		{"segment": _literal(FlowLiteralValueSegment.TYPE_FLOAT, 2.5), "expected": "2.5"},
		{"segment": _literal(FlowLiteralValueSegment.TYPE_STRING, "hello"), "expected": "hello"},
		{"segment": _literal(FlowLiteralValueSegment.TYPE_STRING_NAME, &"hello-name"), "expected": "hello-name"},
	]
	for case_data: Dictionary in cases:
		var segment: FlowChipSegment = case_data["segment"] as FlowChipSegment
		_check(
			_consume_label(segment) == case_data["expected"],
			"Generic chip label is deterministic for the literal value %s." % case_data["expected"]
		)


func _test_literal_tooltips() -> void:
	var cases: Array[Dictionary] = [
		{"segment": _literal(FlowLiteralValueSegment.TYPE_BOOL, true), "value": "true", "variant": "bool"},
		{"segment": _literal(FlowLiteralValueSegment.TYPE_INT, 100), "value": "100", "variant": "int"},
		{"segment": _literal(FlowLiteralValueSegment.TYPE_FLOAT, 2.5), "value": "2.5", "variant": "float"},
		{"segment": _literal(FlowLiteralValueSegment.TYPE_STRING, "hello"), "value": "hello", "variant": "String"},
		{"segment": _literal(FlowLiteralValueSegment.TYPE_STRING_NAME, &"hello-name"), "value": "hello-name", "variant": "StringName"},
	]
	for case_data: Dictionary in cases:
		_assert_tooltip(
			case_data["segment"] as FlowChipSegment,
			String(case_data["value"]),
			String(case_data["variant"])
		)


func _test_generic_contract() -> void:
	var literal_as_boundary: FlowChipSegment = _literal(FlowLiteralValueSegment.TYPE_INT, 100)
	var projection: Dictionary = _consume_chip(literal_as_boundary)
	_check(projection["descriptor"] != null, "A consumer typed only as FlowChipSegment can request a descriptor.")
	_check(projection["label"] == "100", "A consumer typed only as FlowChipSegment can request a label.")
	var tooltip: FlowChipTooltipData = projection["tooltip"] as FlowChipTooltipData
	_check(tooltip != null and tooltip.fields.size() == 3, "A consumer typed only as FlowChipSegment can request tooltip data.")

	var unimplemented: FlowChipSegment = FlowChipSegment.new()
	var safe_projection: Dictionary = _consume_chip(unimplemented)
	_check(safe_projection["descriptor"] == null, "An unimplemented chip contract returns a safe null descriptor.")
	_check(safe_projection["label"] == "", "An unimplemented chip contract returns a safe empty label.")
	_check(safe_projection["tooltip"] == null, "An unimplemented chip contract returns safe null tooltip data.")


func _test_invalid_literal_safety() -> void:
	var invalid_cases: Array[FlowLiteralValueSegment] = [
		_literal(Variant.Type.TYPE_NIL, null),
		_literal(FlowLiteralValueSegment.TYPE_INT, "not an int"),
		_literal(FlowLiteralValueSegment.TYPE_FLOAT, NAN),
	]
	for literal: FlowLiteralValueSegment in invalid_cases:
		var original_type: Variant.Type = literal.value_type
		var original_value: Variant = literal.value
		var descriptor: FlowChipTypeDescriptor = literal.get_chip_type_descriptor()
		var label: String = literal.get_chip_label()
		var tooltip: FlowChipTooltipData = literal.get_chip_tooltip_data()
		_check(descriptor != null, "An invalid LiteralValue still exposes its stable descriptor safely.")
		_check(label == "", "An invalid LiteralValue produces a safe empty label without coercion.")
		_check(tooltip != null and tooltip.fields.size() == 3, "An invalid LiteralValue produces structured tooltip data safely.")
		_check(literal.value_type == original_type, "Descriptor queries do not repair invalid LiteralValue type metadata.")
		_check(_same_variant(original_value, literal.value), "Descriptor queries do not repair invalid LiteralValue data.")


func _test_runtime_editor_boundary() -> void:
	var forbidden_tokens: Array[String] = [
		"EditorPlugin",
		"EditorInterface",
		"EditorUndoRedoManager",
		"Control",
		"Button",
		"RichTextLabel",
		"Fluo",
		"Flusso",
		"FPrint",
	]
	for source_path: String in [
		DESCRIPTOR_SOURCE_PATH,
		TOOLTIP_SOURCE_PATH,
		SEGMENT_SOURCE_PATH,
		LITERAL_SOURCE_PATH,
	]:
		var source: String = FileAccess.get_file_as_string(source_path)
		var lower_source: String = source.to_lower()
		for forbidden_token: String in forbidden_tokens:
			_check(
				not lower_source.contains(forbidden_token.to_lower()),
				"Runtime chip source has no editor/UI/FPrint dependency: %s (%s)." % [forbidden_token, source_path]
			)


func _consume_descriptor(segment: FlowChipSegment) -> FlowChipTypeDescriptor:
	return segment.get_chip_type_descriptor() if segment != null else null


func _consume_label(segment: FlowChipSegment) -> String:
	return segment.get_chip_label() if segment != null else ""


func _consume_chip(segment: FlowChipSegment) -> Dictionary:
	return {
		"descriptor": _consume_descriptor(segment),
		"label": _consume_label(segment),
		"tooltip": segment.get_chip_tooltip_data() if segment != null else null,
	}


func _assert_tooltip(segment: FlowChipSegment, expected_value: String, expected_variant: String) -> void:
	var tooltip: FlowChipTooltipData = _consume_chip(segment)["tooltip"] as FlowChipTooltipData
	_check(tooltip != null, "LiteralValue tooltip data is non-null through the generic contract.")
	if tooltip == null:
		return
	_check(tooltip.title == "Literal", "LiteralValue tooltip title is Literal.")
	_check(tooltip.fields.size() == 3, "LiteralValue tooltip has exactly three ordered fields.")
	if tooltip.fields.size() != 3:
		return
	_check(tooltip.get_field(0).get("label") == "Type" and tooltip.get_field(0).get("value") == "Literal",
		"LiteralValue tooltip field 1 is Type → Literal.")
	_check(tooltip.get_field(1).get("label") == "Value" and tooltip.get_field(1).get("value") == expected_value,
		"LiteralValue tooltip field 2 is Value → expected label.")
	_check(tooltip.get_field(2).get("label") == "Variant" and tooltip.get_field(2).get("value") == expected_variant,
		"LiteralValue tooltip field 3 is Variant → expected Variant type.")


func _literal(value_type: Variant.Type, value: Variant) -> FlowLiteralValueSegment:
	return FlowLiteralValueSegment.new(value_type, value)


func _same_variant(left: Variant, right: Variant) -> bool:
	if typeof(left) != typeof(right):
		return false
	if typeof(left) == TYPE_FLOAT and is_nan(float(left)) and is_nan(float(right)):
		return true
	return left == right


func _check(condition: bool, message: String) -> bool:
	if condition:
		return true
	_failures.append(message)
	push_error(message)
	return false


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Generic chip descriptor test passed")
	else:
		for failure: String in _failures:
			push_error(failure)
	get_tree().quit(0 if _failures.is_empty() else 1)
