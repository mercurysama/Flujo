@tool
## String-keyed structured dictionary whose values remain FlowValueSources.
class_name FlowDictionaryValueSource
extends FlowValueSource


const SOURCE_KIND: StringName = FlowValueSource.SOURCE_KIND_DICTIONARY
const PRODUCED_TYPE: Variant.Type = Variant.Type.TYPE_DICTIONARY

@export_storage var entries: Array[FlowDictionaryEntry] = []


func _init(new_entries: Array[FlowDictionaryEntry] = []) -> void:
	entries.assign(new_entries)


func get_source_kind() -> StringName:
	return SOURCE_KIND


func get_value_type() -> Variant.Type:
	return PRODUCED_TYPE


func is_valid() -> bool:
	if not FlowId.is_valid(_source_id):
		return false
	var keys: Dictionary = {}
	for entry: FlowDictionaryEntry in entries:
		if entry == null or not FlowId.is_valid(entry.entry_id):
			return false
		var normalized: String = entry.key.strip_edges()
		if normalized.is_empty() or keys.has(normalized):
			return false
		if entry.value_source == null or not entry.value_source.is_valid():
			return false
		keys[normalized] = true
	return true


func get_preview(graph: FlowGraph = null) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for entry: FlowDictionaryEntry in entries:
		if entry == null:
			parts.append("<missing>")
			continue
		parts.append("%s: %s" % [
			entry.key,
			FlowValueSourcePreview.preview(entry.value_source, graph),
		])
	return "{" + ", ".join(parts) + "}"


func validate_structure(result: FlowValidationResult, element_path: String) -> void:
	super.validate_structure(result, element_path)
	if result == null:
		return
	var seen: Dictionary = {}
	for index: int in entries.size():
		var entry: FlowDictionaryEntry = entries[index]
		var entry_path: String = "%s.entries[%d]" % [element_path, index]
		if entry == null:
			_add_error(
				result,
				FlowDiagnostic.CODE_COLLECTION_ELEMENT_MISSING,
				"Dictionary entry is missing.",
				entry_path,
				_source_id
			)
			continue
		var normalized: String = entry.key.strip_edges()
		if normalized.is_empty():
			_add_error(
				result,
				FlowDiagnostic.CODE_DICTIONARY_KEY_EMPTY,
				"Dictionary key cannot be empty.",
				entry_path + ".key",
				entry.entry_id
			)
		elif seen.has(normalized):
			_add_error(
				result,
				FlowDiagnostic.CODE_DICTIONARY_KEY_DUPLICATE,
				"Dictionary keys must be unique.",
				entry_path + ".key",
				entry.entry_id
			)
		else:
			seen[normalized] = true
		if entry.value_source == null:
			_add_error(
				result,
				FlowDiagnostic.CODE_COLLECTION_ELEMENT_MISSING,
				"Dictionary value source is missing.",
				entry_path + ".value_source",
				entry.entry_id
			)
		else:
			entry.value_source.validate_structure(
				result,
				entry_path + ".value_source"
			)


func validate_against_graph(
		result: FlowValidationResult,
		element_path: String,
		graph: FlowGraph
) -> void:
	if result == null or graph == null:
		return
	for index: int in entries.size():
		var entry: FlowDictionaryEntry = entries[index]
		if entry != null and entry.value_source != null:
			entry.value_source.validate_against_graph(
				result,
				"%s.entries[%d].value_source" % [element_path, index],
				graph
			)


func resolve(context: Variant = null) -> FlowValueResult:
	var output: Dictionary = {}
	for entry: FlowDictionaryEntry in entries:
		if entry == null 				or entry.key.strip_edges().is_empty() 				or entry.value_source == null:
			return _failure(
				FlowDiagnostic.CODE_COLLECTION_ELEMENT_MISSING,
				"Dictionary contains an incomplete entry."
			)
		var normalized_key: String = entry.key.strip_edges()
		if output.has(normalized_key):
			return _failure(
				FlowDiagnostic.CODE_DICTIONARY_KEY_DUPLICATE,
				"Dictionary contains a duplicate key."
			)
		var child_result: FlowValueResult = entry.value_source.resolve(context)
		if child_result == null or not child_result.success:
			return FlowValueResult.fail(
				PRODUCED_TYPE,
				child_result.diagnostic if child_result != null else FlowDiagnostic.new(
					FlowDiagnostic.CODE_COLLECTION_ELEMENT_MISSING,
					FlowDiagnostic.Severity.ERROR,
					"Dictionary value failed to resolve.",
					"value_source",
					_source_id
				)
			)
		output[normalized_key] = child_result.value
	return FlowValueResult.ok(output, PRODUCED_TYPE)


func duplicate_with_new_id() -> FlowValueSource:
	var copy: FlowDictionaryValueSource = duplicate(false) as FlowDictionaryValueSource
	copy._source_id = FlowId.create()
	copy.entries = []
	for entry: FlowDictionaryEntry in entries:
		copy.entries.append(entry.duplicate_with_new_id() if entry != null else null)
	return copy


func _failure(code: StringName, message: String) -> FlowValueResult:
	return FlowValueResult.fail(
		PRODUCED_TYPE,
		FlowDiagnostic.new(
			code,
			FlowDiagnostic.Severity.ERROR,
			message,
			"value_source",
			_source_id
		)
	)


static func _add_error(
		result: FlowValidationResult,
		code: StringName,
		message: String,
		path: String,
		related_id: String = ""
) -> void:
	result.add_diagnostic(FlowDiagnostic.new(
		code,
		FlowDiagnostic.Severity.ERROR,
		message,
		path,
		related_id
	))
