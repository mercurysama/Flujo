extends Node


const TEMP_ROOT: String = "res://.godot/flujo_tests/structured_document"
const RESOURCE_PATH: String = TEMP_ROOT + "/structured_document.tres"


var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_identity_and_duplication()
	_test_text_literal_preservation()
	_test_literal_types_and_invalid_values()
	_test_validation_order_and_read_only_behavior()
	_test_rendering()
	_test_resource_saver_persistence()
	_cleanup()
	_finish()


func _test_identity_and_duplication() -> void:
	var text: FlowTextSegment = FlowTextSegment.new()
	var literal: FlowLiteralValueSegment = FlowLiteralValueSegment.new(
		FlowLiteralValueSegment.TYPE_INT,
		3
	)
	_check(FlowId.is_valid(text.get_segment_id()), "A new text segment receives a valid FlowId.")
	_check(FlowId.is_valid(literal.get_segment_id()), "A new literal segment receives a valid FlowId.")
	_check(text.get_segment_id() != literal.get_segment_id(), "New segments receive distinct FlowIds.")
	_check(text.get_internal_id() == text.get_segment_id(), "The compatibility identity getter returns the segment ID.")

	var duplicate_id_document: FlowStructuredDocument = FlowStructuredDocument.new()
	var duplicate: FlowTextSegment = FlowTextSegment.new()
	duplicate.segment_id = text.segment_id
	duplicate_id_document.segments = [text, duplicate]
	var duplicate_result: FlowValidationResult = FlowStructuredDocumentValidator.validate(duplicate_id_document)
	_check(
		_has_code_at(duplicate_result, FlowDiagnostic.CODE_DUPLICATE_SEGMENT_ID, "segments[1]"),
		"Duplicate segment IDs are diagnosed at the later ordered position."
	)

	var empty_id: FlowTextSegment = FlowTextSegment.new()
	empty_id.segment_id = ""
	var empty_document: FlowStructuredDocument = FlowStructuredDocument.new()
	empty_document.segments = [empty_id]
	_check(
		_has_code_at(
			FlowStructuredDocumentValidator.validate(empty_document),
			FlowDiagnostic.CODE_EMPTY_SEGMENT_ID,
			"segments[0]"
		),
		"An empty segment ID is diagnosed."
	)

	var malformed_id: FlowTextSegment = FlowTextSegment.new()
	malformed_id.segment_id = "not-a-flow-id"
	var malformed_document: FlowStructuredDocument = FlowStructuredDocument.new()
	malformed_document.segments = [malformed_id]
	_check(
		_has_code_at(
			FlowStructuredDocumentValidator.validate(malformed_document),
			FlowDiagnostic.CODE_INVALID_SEGMENT_ID,
			"segments[0]"
		),
		"A malformed segment ID is diagnosed."
	)

	var source: FlowStructuredDocument = FlowStructuredDocument.new()
	var source_text: FlowTextSegment = FlowTextSegment.new()
	source_text.text = "source"
	var source_literal: FlowLiteralValueSegment = FlowLiteralValueSegment.new(
		FlowLiteralValueSegment.TYPE_STRING_NAME,
		&"source-name"
	)
	source.segments = [source_text, null, source_literal]
	var source_text_id: String = source_text.get_segment_id()
	var source_literal_id: String = source_literal.get_segment_id()
	var copy: FlowStructuredDocument = source.duplicate_with_new_ids()
	_check(copy != source, "Document duplication creates an independent document.")
	_check(copy.segments.size() == 3, "Document duplication preserves collection length.")
	_check(copy.segments[1] == null, "Document duplication preserves deliberate null positions.")
	_check(copy.segments[0] is FlowTextSegment, "Document duplication preserves concrete text type.")
	_check(copy.segments[2] is FlowLiteralValueSegment, "Document duplication preserves concrete literal type.")
	if copy.segments[0] is FlowTextSegment and copy.segments[2] is FlowLiteralValueSegment:
		_check(copy.segments[0].get_segment_id() != source_text_id, "Copied text receives a new ID.")
		_check(copy.segments[2].get_segment_id() != source_literal_id, "Copied literal receives a new ID.")
		_check(copy.segments[0].text == "source", "Copied text preserves its literal value.")
		_check(copy.segments[2].value == &"source-name", "Copied StringName preserves its value.")
	_check(source.segments[0].get_segment_id() == source_text_id, "Duplication does not mutate the source text ID.")
	_check(source.segments[2].get_segment_id() == source_literal_id, "Duplication does not mutate the source literal ID.")
	var snapshot: FlowStructuredDocument = source.duplicate_preserving_ids()
	_check(snapshot != source and snapshot.segments.size() == source.segments.size(),
		"A structured-document snapshot is independent while preserving collection shape.")
	if snapshot != null and snapshot.segments[0] != null and snapshot.segments[2] != null:
		_check(snapshot.segments[0].get_segment_id() == source_text_id \
				and snapshot.segments[2].get_segment_id() == source_literal_id,
			"A Revertir snapshot preserves the exact persistent segment IDs.")
		_check(snapshot.segments[0] != source.segments[0] and snapshot.segments[2] != source.segments[2],
			"A Revertir snapshot does not share mutable segment resources with the source.")


func _test_text_literal_preservation() -> void:
	var text: FlowTextSegment = FlowTextSegment.new()
	text.text = "  Línea 1\n\t@ # $\nUnicode: áéíóú — 世界  "
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	document.segments = [text]
	var validation: FlowValidationResult = FlowStructuredDocumentValidator.validate(document)
	_check(not validation.has_errors(), "Literal text segment with Unicode and symbols is valid.")
	var rendered: FlowStructuredRenderResult = FlowStructuredDocumentRenderer.render(document)
	_check(not rendered.has_errors(), "Literal text document renders without diagnostics.")
	_check(rendered.text == text.text, "Text rendering preserves spaces, tabs, newlines, Unicode, @, #, and $ exactly.")


func _test_literal_types_and_invalid_values() -> void:
	var bool_literal: FlowLiteralValueSegment = _literal(FlowLiteralValueSegment.TYPE_BOOL, true)
	var int_literal: FlowLiteralValueSegment = _literal(FlowLiteralValueSegment.TYPE_INT, 3)
	var float_literal: FlowLiteralValueSegment = _literal(FlowLiteralValueSegment.TYPE_FLOAT, 2.5)
	var string_literal: FlowLiteralValueSegment = _literal(FlowLiteralValueSegment.TYPE_STRING, "literal")
	var string_name_literal: FlowLiteralValueSegment = _literal(
		FlowLiteralValueSegment.TYPE_STRING_NAME,
		&"literal-name"
	)
	for literal: FlowLiteralValueSegment in [
		bool_literal,
		int_literal,
		float_literal,
		string_literal,
		string_name_literal,
	]:
		var document: FlowStructuredDocument = FlowStructuredDocument.new()
		document.segments = [literal]
		_check(
			not FlowStructuredDocumentValidator.validate(document).has_errors(),
			"Allowed literal type %d validates without implicit conversion." % int(literal.value_type)
		)

	_check(typeof(int_literal.value) == TYPE_INT, "An integer literal retains the integer Variant type.")
	_check(typeof(float_literal.value) == TYPE_FLOAT, "A float literal retains the float Variant type.")
	_check(typeof(string_literal.value) == TYPE_STRING, "A String literal retains the String Variant type.")
	_check(typeof(string_name_literal.value) == TYPE_STRING_NAME, "A StringName literal retains the StringName Variant type.")
	_check(FlowLiteralValueSegment.TYPE_STRING != FlowLiteralValueSegment.TYPE_STRING_NAME, "String and StringName are distinct explicit types.")

	var nil_literal: FlowLiteralValueSegment = _literal(TYPE_NIL, null)
	_check(_literal_has_code(nil_literal, FlowDiagnostic.CODE_LITERAL_TYPE_NIL), "TYPE_NIL is invalid.")

	var array_literal: FlowLiteralValueSegment = _literal(typeof([]), [])
	_check(_literal_has_code(array_literal, FlowDiagnostic.CODE_INVALID_LITERAL_VALUE_TYPE), "Array is invalid.")

	var dictionary_literal: FlowLiteralValueSegment = _literal(typeof({}), {})
	_check(_literal_has_code(dictionary_literal, FlowDiagnostic.CODE_INVALID_LITERAL_VALUE_TYPE), "Dictionary is invalid.")

	var object_value: Object = Object.new()
	var object_literal: FlowLiteralValueSegment = _literal(typeof(object_value), object_value)
	_check(_literal_has_code(object_literal, FlowDiagnostic.CODE_INVALID_LITERAL_VALUE_TYPE), "Object is invalid.")

	var resource_value: Resource = Resource.new()
	var resource_literal: FlowLiteralValueSegment = _literal(typeof(resource_value), resource_value)
	_check(_literal_has_code(resource_literal, FlowDiagnostic.CODE_INVALID_LITERAL_VALUE_TYPE), "Resource is invalid.")

	var node_value: Node = Node.new()
	var node_literal: FlowLiteralValueSegment = _literal(typeof(node_value), node_value)
	_check(_literal_has_code(node_literal, FlowDiagnostic.CODE_INVALID_LITERAL_VALUE_TYPE), "Node is invalid.")
	object_value.free()
	node_value.free()

	var mismatch_literal: FlowLiteralValueSegment = _literal(FlowLiteralValueSegment.TYPE_INT, "3")
	_check(_literal_has_code(mismatch_literal, FlowDiagnostic.CODE_LITERAL_VALUE_TYPE_MISMATCH), "Explicit type and real Variant type mismatch is diagnosed.")
	_check(mismatch_literal.value == "3", "Validation preserves the mismatched authored value.")

	for non_finite: float in [NAN, INF, -INF]:
		var non_finite_literal: FlowLiteralValueSegment = _literal(
			FlowLiteralValueSegment.TYPE_FLOAT,
			non_finite
		)
		_check(
			_literal_has_code(non_finite_literal, FlowDiagnostic.CODE_LITERAL_FLOAT_NOT_FINITE),
			"NaN and positive/negative infinity are invalid float literals."
		)


func _test_validation_order_and_read_only_behavior() -> void:
	var null_document_result: FlowValidationResult = FlowStructuredDocumentValidator.validate(null)
	_check(
		_has_code_at(null_document_result, FlowDiagnostic.CODE_NULL_STRUCTURED_DOCUMENT, "document"),
		"A null structured document is diagnosed when validation is requested."
	)

	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	document.version = 99
	var unknown_segment: FlowDocumentSegment = FlowDocumentSegment.new()
	var unknown_chip: FlowChipSegment = FlowChipSegment.new()
	var nil_literal: FlowLiteralValueSegment = _literal(TYPE_NIL, null)
	document.segments = [null, unknown_segment, unknown_chip, nil_literal]
	var original_version: int = document.version
	var original_ids: Array[String] = [
		unknown_segment.get_segment_id(),
		unknown_chip.get_segment_id(),
		nil_literal.get_segment_id(),
	]
	var first: FlowValidationResult = FlowStructuredDocumentValidator.validate(document)
	var second: FlowValidationResult = FlowStructuredDocumentValidator.validate(document)
	_check(first.diagnostics.size() == second.diagnostics.size(), "Validation diagnostic count is deterministic.")
	if first.diagnostics.size() == second.diagnostics.size():
		for diagnostic_index: int in first.diagnostics.size():
			var first_diagnostic: FlowDiagnostic = first.diagnostics[diagnostic_index]
			var second_diagnostic: FlowDiagnostic = second.diagnostics[diagnostic_index]
			_check(first_diagnostic.code == second_diagnostic.code, "Diagnostic code order is deterministic.")
			_check(first_diagnostic.element_path == second_diagnostic.element_path, "Diagnostic path order is deterministic.")
			_check(first_diagnostic.related_id == second_diagnostic.related_id, "Diagnostic related-ID order is deterministic.")
	_check(_has_code_at(first, FlowDiagnostic.CODE_UNSUPPORTED_STRUCTURED_DOCUMENT_VERSION, "version"), "Unsupported document version is diagnosed.")
	_check(_has_code_at(first, FlowDiagnostic.CODE_NULL_SEGMENT, "segments[0]"), "Null segment is diagnosed without removing the position.")
	_check(_has_code_at(first, FlowDiagnostic.CODE_UNKNOWN_SEGMENT_TYPE, "segments[1]"), "Unknown segment type is diagnosed safely.")
	_check(_has_code_at(first, FlowDiagnostic.CODE_UNKNOWN_CHIP_TYPE, "segments[2].chip_type"), "Unknown chip type is diagnosed safely.")
	_check(_has_code_at(first, FlowDiagnostic.CODE_LITERAL_TYPE_NIL, "segments[3].value_type"), "Literal TYPE_NIL is diagnosed in deterministic order.")
	_check(document.version == original_version, "Validation does not normalize the document version.")
	_check(document.segments.size() == 4 and document.segments[0] == null, "Validation does not remove null positions.")
	_check(unknown_segment.get_segment_id() == original_ids[0], "Validation does not mutate unknown segment identity.")
	_check(unknown_chip.get_segment_id() == original_ids[1], "Validation does not mutate unknown chip identity.")
	_check(nil_literal.get_segment_id() == original_ids[2], "Validation does not mutate literal identity.")


func _test_rendering() -> void:
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	var first_text: FlowTextSegment = FlowTextSegment.new()
	first_text.text = "Tengo "
	var count: FlowLiteralValueSegment = _literal(FlowLiteralValueSegment.TYPE_INT, 3)
	var middle_text: FlowTextSegment = FlowTextSegment.new()
	middle_text.text = " vidas\nEstado: "
	var enabled: FlowLiteralValueSegment = _literal(FlowLiteralValueSegment.TYPE_BOOL, true)
	var separator: FlowTextSegment = FlowTextSegment.new()
	separator.text = " / "
	var ratio: FlowLiteralValueSegment = _literal(FlowLiteralValueSegment.TYPE_FLOAT, 2.5)
	var suffix: FlowTextSegment = FlowTextSegment.new()
	suffix.text = " / "
	var name: FlowLiteralValueSegment = _literal(FlowLiteralValueSegment.TYPE_STRING_NAME, &"Kínder")
	document.segments = [first_text, count, middle_text, enabled, separator, ratio, suffix, name]
	var rendered: FlowStructuredRenderResult = FlowStructuredDocumentRenderer.render(document)
	_check(not rendered.has_errors(), "A valid mixed document renders without diagnostics.")
	_check(rendered.text == "Tengo 3 vidas\nEstado: true / 2.5 / Kínder", "Mixed Text/Literal rendering concatenates segments in order exactly.")

	var invalid_document: FlowStructuredDocument = FlowStructuredDocument.new()
	invalid_document.segments = [FlowTextSegment.new(), _literal(FlowLiteralValueSegment.TYPE_INT, "not an int")]
	var invalid_render: FlowStructuredRenderResult = FlowStructuredDocumentRenderer.render(invalid_document)
	_check(invalid_render.has_errors(), "Invalid documents return explicit render diagnostics.")
	_check(invalid_render.text.is_empty(), "Invalid documents do not receive a repaired or substituted rendered value.")


func _test_resource_saver_persistence() -> void:
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	document.version = FlowStructuredDocument.CURRENT_VERSION
	var text: FlowTextSegment = FlowTextSegment.new()
	text.text = "Tengo @ # $\nUnicode: 世界"
	var count: FlowLiteralValueSegment = _literal(FlowLiteralValueSegment.TYPE_INT, 3)
	var name: FlowLiteralValueSegment = _literal(FlowLiteralValueSegment.TYPE_STRING_NAME, &"PersistedName")
	document.segments = [text, null, count, name]
	_check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT)) == OK, "Persistence test directory is available.")
	_check(ResourceSaver.save(document, RESOURCE_PATH) == OK, "ResourceSaver saves a structured document.")
	var loaded: FlowStructuredDocument = ResourceLoader.load(
		RESOURCE_PATH,
		"",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as FlowStructuredDocument
	_check(loaded != null, "ResourceLoader reloads a structured document.")
	if loaded == null:
		return
	_check(loaded.version == document.version, "Document version survives ResourceSaver round-trip.")
	_check(loaded.segments.size() == 4, "Segment collection length survives ResourceSaver round-trip.")
	_check(loaded.segments[1] == null, "Null segment position survives ResourceSaver round-trip.")
	_check(loaded.segments[0] is FlowTextSegment, "FlowTextSegment concrete class survives ResourceSaver round-trip.")
	_check(loaded.segments[2] is FlowLiteralValueSegment, "Integer literal concrete class survives ResourceSaver round-trip.")
	_check(loaded.segments[3] is FlowLiteralValueSegment, "StringName literal concrete class survives ResourceSaver round-trip.")
	if loaded.segments[0] is FlowTextSegment:
		_check(loaded.segments[0].get_segment_id() == text.get_segment_id(), "Text segment ID survives ResourceSaver round-trip.")
		_check(loaded.segments[0].text == text.text, "Text content survives ResourceSaver round-trip exactly.")
	if loaded.segments[2] is FlowLiteralValueSegment:
		var loaded_count: FlowLiteralValueSegment = loaded.segments[2]
		_check(loaded_count.get_segment_id() == count.get_segment_id(), "Integer literal ID survives ResourceSaver round-trip.")
		_check(loaded_count.value_type == FlowLiteralValueSegment.TYPE_INT, "Integer Variant.Type survives ResourceSaver round-trip.")
		_check(loaded_count.value == 3, "Integer value survives ResourceSaver round-trip.")
	if loaded.segments[3] is FlowLiteralValueSegment:
		var loaded_name: FlowLiteralValueSegment = loaded.segments[3]
		_check(loaded_name.get_segment_id() == name.get_segment_id(), "StringName literal ID survives ResourceSaver round-trip.")
		_check(loaded_name.value_type == FlowLiteralValueSegment.TYPE_STRING_NAME, "StringName Variant.Type survives ResourceSaver round-trip.")
		_check(typeof(loaded_name.value) == TYPE_STRING_NAME, "StringName remains StringName after ResourceSaver round-trip.")
		_check(loaded_name.value == &"PersistedName", "StringName value survives ResourceSaver round-trip.")
	var loaded_validation: FlowValidationResult = FlowStructuredDocumentValidator.validate(loaded)
	_check(
		_has_code_at(loaded_validation, FlowDiagnostic.CODE_NULL_SEGMENT, "segments[1]"),
		"Reloaded deliberate null position remains diagnosable without being removed."
	)


func _literal(value_type: Variant.Type, value: Variant) -> FlowLiteralValueSegment:
	return FlowLiteralValueSegment.new(value_type, value)


func _literal_has_code(literal: FlowLiteralValueSegment, code: StringName) -> bool:
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	document.segments = [literal]
	return _has_code(FlowStructuredDocumentValidator.validate(document), code)


func _has_code(result: FlowValidationResult, code: StringName) -> bool:
	for diagnostic: FlowDiagnostic in result.diagnostics:
		if diagnostic.code == code:
			return true
	return false


func _has_code_at(result: FlowValidationResult, code: StringName, path: String) -> bool:
	for diagnostic: FlowDiagnostic in result.diagnostics:
		if diagnostic.code == code and diagnostic.element_path == path:
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
	push_error(message)
	return false


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Structured document test passed")
	else:
		for failure: String in _failures:
			push_error(failure)
	get_tree().quit(0 if _failures.is_empty() else 1)
