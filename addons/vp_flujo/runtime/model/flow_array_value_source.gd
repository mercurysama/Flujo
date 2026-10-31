@tool
## Ordered collection whose elements remain independent FlowValueSources.
class_name FlowArrayValueSource
extends FlowValueSource


const SOURCE_KIND: StringName = FlowValueSource.SOURCE_KIND_ARRAY
const PRODUCED_TYPE: Variant.Type = Variant.Type.TYPE_ARRAY

@export_storage var elements: Array[FlowValueSource] = []


func _init(new_elements: Array[FlowValueSource] = []) -> void:
	elements.assign(new_elements)


func get_source_kind() -> StringName:
	return SOURCE_KIND


func get_value_type() -> Variant.Type:
	return PRODUCED_TYPE


func is_valid() -> bool:
	if not FlowId.is_valid(_source_id):
		return false
	for element: FlowValueSource in elements:
		if element == null or not element.is_valid():
			return false
	return true


func get_preview(graph: FlowGraph = null) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for element: FlowValueSource in elements:
		parts.append(FlowValueSourcePreview.preview(element, graph))
	return "[" + ", ".join(parts) + "]"


func validate_structure(result: FlowValidationResult, element_path: String) -> void:
	super.validate_structure(result, element_path)
	if result == null:
		return
	for index: int in elements.size():
		var child: FlowValueSource = elements[index]
		var child_path: String = "%s.elements[%d]" % [element_path, index]
		if child == null:
			_add_error(
				result,
				FlowDiagnostic.CODE_COLLECTION_ELEMENT_MISSING,
				"Array element is missing.",
				child_path,
				_source_id
			)
			continue
		child.validate_structure(result, child_path)


func validate_against_graph(
		result: FlowValidationResult,
		element_path: String,
		graph: FlowGraph
) -> void:
	if result == null or graph == null:
		return
	for index: int in elements.size():
		var child: FlowValueSource = elements[index]
		if child != null:
			child.validate_against_graph(
				result,
				"%s.elements[%d]" % [element_path, index],
				graph
			)


func resolve(context: Variant = null) -> FlowValueResult:
	var output: Array = []
	for child: FlowValueSource in elements:
		if child == null:
			return _failure(
				FlowDiagnostic.CODE_COLLECTION_ELEMENT_MISSING,
				"Array contains a missing element."
			)
		var child_result: FlowValueResult = child.resolve(context)
		if child_result == null or not child_result.success:
			return FlowValueResult.fail(
				PRODUCED_TYPE,
				child_result.diagnostic if child_result != null else FlowDiagnostic.new(
					FlowDiagnostic.CODE_COLLECTION_ELEMENT_MISSING,
					FlowDiagnostic.Severity.ERROR,
					"Array element failed to resolve.",
					"value_source",
					_source_id
				)
			)
		output.append(child_result.value)
	return FlowValueResult.ok(output, PRODUCED_TYPE)


func duplicate_with_new_id() -> FlowValueSource:
	var copy: FlowArrayValueSource = duplicate(false) as FlowArrayValueSource
	copy._source_id = FlowId.create()
	copy.elements = []
	for child: FlowValueSource in elements:
		copy.elements.append(child.duplicate_with_new_id() if child != null else null)
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
