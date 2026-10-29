@tool
class_name FlowBlockPropertyPresentationLoader
extends RefCounted

## Reads only the data-only block_property_presentation.json sidecar.
##
## This loader never loads scripts, scenes, resources, widgets, or callbacks.

const FILE_NAME: String = "block_property_presentation.json"
const FORMAT_VERSION: int = 1

const CODE_PACKAGE_PATH_INVALID: StringName = &"presentation_metadata_package_path_invalid"
const CODE_READ_FAILED: StringName = &"presentation_metadata_read_failed"
const CODE_JSON_INVALID: StringName = &"presentation_metadata_json_invalid"
const CODE_ROOT_INVALID: StringName = &"presentation_metadata_root_invalid"
const CODE_TOP_LEVEL_KEY_UNKNOWN: StringName = &"presentation_metadata_top_level_key_unknown"
const CODE_FORMAT_VERSION_INVALID: StringName = &"presentation_metadata_format_version_invalid"
const CODE_BLOCK_TYPE_ID_INVALID: StringName = &"presentation_metadata_block_type_id_invalid"
const CODE_BLOCK_TYPE_ID_MISMATCH: StringName = &"presentation_metadata_block_type_id_mismatch"
const CODE_PROPERTIES_INVALID: StringName = &"presentation_metadata_properties_invalid"
const CODE_DECLARATION_INVALID: StringName = &"presentation_metadata_declaration_invalid"
const CODE_DECLARATION_FIELD_UNKNOWN: StringName = &"presentation_metadata_declaration_field_unknown"
const CODE_PROPERTY_INVALID: StringName = &"presentation_metadata_property_invalid"
const CODE_PROPERTY_DUPLICATE: StringName = &"presentation_metadata_property_duplicate"
const CODE_LABEL_INVALID: StringName = &"presentation_metadata_label_invalid"
const CODE_ORDER_INVALID: StringName = &"presentation_metadata_order_invalid"
const CODE_GROUP_INVALID: StringName = &"presentation_metadata_group_invalid"
const CODE_TOOLTIP_INVALID: StringName = &"presentation_metadata_tooltip_invalid"
const CODE_PRESENTATION_INVALID: StringName = &"presentation_metadata_presentation_invalid"

const _TOP_LEVEL_FIELDS: Array[String] = ["format_version", "block_type_id", "properties"]
const _DECLARATION_FIELDS: Array[String] = [
	"property",
	"label",
	"order",
	"group",
	"tooltip",
	"presentation",
]
const _PRESENTATIONS: Array[String] = ["auto", "multiline", "range", "enum"]


func read(package_directory: String, block_type_id: String) -> FlowBlockPropertyPresentationLoadResult:
	var result: FlowBlockPropertyPresentationLoadResult = FlowBlockPropertyPresentationLoadResult.new()
	if package_directory.is_empty():
		return result
	if not _is_project_relative_package_path(package_directory):
		result.found = true
		_issue(result, CODE_PACKAGE_PATH_INVALID, package_directory, block_type_id,
			"Presentation metadata package path must be project-relative.", FlowDiagnostic.Severity.ERROR)
		return result

	var metadata_path: String = package_directory.path_join(FILE_NAME)
	if not FileAccess.file_exists(metadata_path):
		return result
	result.found = true
	var file: FileAccess = FileAccess.open(metadata_path, FileAccess.READ)
	if file == null:
		_issue(result, CODE_READ_FAILED, metadata_path, block_type_id,
			"Presentation metadata cannot be read.", FlowDiagnostic.Severity.ERROR)
		return result
	return parse_text(file.get_as_text(), metadata_path, block_type_id)


func parse_text(
	text: String,
	source_path: String,
	expected_block_type_id: String
) -> FlowBlockPropertyPresentationLoadResult:
	var result: FlowBlockPropertyPresentationLoadResult = FlowBlockPropertyPresentationLoadResult.new()
	result.found = true
	var parser: JSON = JSON.new()
	if parser.parse(text) != OK:
		_issue(result, CODE_JSON_INVALID, source_path, expected_block_type_id,
			"Presentation metadata is not valid JSON.", FlowDiagnostic.Severity.ERROR)
		return result

	var raw: Variant = parser.data
	if not raw is Dictionary:
		_issue(result, CODE_ROOT_INVALID, source_path, expected_block_type_id,
			"Presentation metadata root must be an object.", FlowDiagnostic.Severity.ERROR)
		return result
	return _parse_document(raw as Dictionary, source_path, expected_block_type_id)


func _parse_document(
	data: Dictionary,
	source_path: String,
	expected_block_type_id: String
) -> FlowBlockPropertyPresentationLoadResult:
	var result: FlowBlockPropertyPresentationLoadResult = FlowBlockPropertyPresentationLoadResult.new()
	result.found = true
	var document_valid: bool = true
	var unknown_top_level: Array[String] = []
	for raw_key: Variant in data.keys():
		var key: String = String(raw_key)
		if not _TOP_LEVEL_FIELDS.has(key):
			unknown_top_level.append(key)
	unknown_top_level.sort()
	for key: String in unknown_top_level:
		_issue(result, CODE_TOP_LEVEL_KEY_UNKNOWN, source_path + "." + key, expected_block_type_id,
			"Presentation metadata contains an unknown top-level field.", FlowDiagnostic.Severity.ERROR)
		document_valid = false

	if not data.has("format_version") or not _is_integer_number(data["format_version"]) \
			or int(data["format_version"]) != FORMAT_VERSION:
		_issue(result, CODE_FORMAT_VERSION_INVALID, source_path + ".format_version", expected_block_type_id,
			"format_version must be integer 1.", FlowDiagnostic.Severity.ERROR)
		document_valid = false

	var actual_block_type_id: String = ""
	if not data.has("block_type_id") or typeof(data["block_type_id"]) != TYPE_STRING \
			or String(data["block_type_id"]).strip_edges().is_empty():
		_issue(result, CODE_BLOCK_TYPE_ID_INVALID, source_path + ".block_type_id", expected_block_type_id,
			"block_type_id must be a non-empty string.", FlowDiagnostic.Severity.ERROR)
		document_valid = false
	else:
		actual_block_type_id = String(data["block_type_id"]).strip_edges()
		if expected_block_type_id.is_empty() or actual_block_type_id != expected_block_type_id:
			_issue(result, CODE_BLOCK_TYPE_ID_MISMATCH, source_path + ".block_type_id", expected_block_type_id,
				"block_type_id does not match the selected block identity.", FlowDiagnostic.Severity.ERROR)
			document_valid = false

	var raw_properties: Array = []
	if not data.has("properties") or not data["properties"] is Array:
		_issue(result, CODE_PROPERTIES_INVALID, source_path + ".properties", expected_block_type_id,
			"properties must be an array.", FlowDiagnostic.Severity.ERROR)
		document_valid = false
	else:
		raw_properties = data["properties"] as Array

	if not document_valid:
		return result

	var document: FlowBlockPropertyPresentationDocument = FlowBlockPropertyPresentationDocument.new(
		source_path, actual_block_type_id
	)
	var candidate_declarations: Array[FlowBlockPropertyPresentationDeclaration] = []
	var first_indices: Dictionary = {}
	var duplicate_names: Dictionary = {}
	for index: int in raw_properties.size():
		var declaration_path: String = source_path + ".properties[%d]" % index
		var raw_declaration: Variant = raw_properties[index]
		if not raw_declaration is Dictionary:
			_issue(result, CODE_DECLARATION_INVALID, declaration_path, expected_block_type_id,
				"Each property presentation declaration must be an object.", FlowDiagnostic.Severity.WARNING)
			continue
		var declaration: FlowBlockPropertyPresentationDeclaration = _parse_declaration(
			raw_declaration as Dictionary, index, declaration_path, expected_block_type_id, result
		)
		if declaration == null:
			continue
		candidate_declarations.append(declaration)
		if first_indices.has(declaration.property_name):
			if not duplicate_names.has(declaration.property_name):
				_issue(result, CODE_PROPERTY_DUPLICATE, declaration_path, String(declaration.property_name),
					"Property presentation metadata declares the same property more than once.",
					FlowDiagnostic.Severity.WARNING)
			duplicate_names[declaration.property_name] = true
		else:
			first_indices[declaration.property_name] = index

	for declaration: FlowBlockPropertyPresentationDeclaration in candidate_declarations:
		if duplicate_names.has(declaration.property_name):
			continue
		document.add_declaration(declaration)

	result.document = document
	result.valid_document = true
	return result


func _parse_declaration(
	data: Dictionary,
	index: int,
	declaration_path: String,
	related_id: String,
	result: FlowBlockPropertyPresentationLoadResult
) -> FlowBlockPropertyPresentationDeclaration:
	var unknown_fields: Array[String] = []
	for raw_key: Variant in data.keys():
		var key: String = String(raw_key)
		if not _DECLARATION_FIELDS.has(key):
			unknown_fields.append(key)
	unknown_fields.sort()
	for key: String in unknown_fields:
		_issue(result, CODE_DECLARATION_FIELD_UNKNOWN, declaration_path + "." + key, related_id,
			"Property presentation declaration contains an unsupported field.", FlowDiagnostic.Severity.WARNING)

	if not data.has("property") or typeof(data["property"]) != TYPE_STRING \
			or String(data["property"]).strip_edges().is_empty():
		_issue(result, CODE_PROPERTY_INVALID, declaration_path + ".property", related_id,
			"property must be a non-empty string.", FlowDiagnostic.Severity.WARNING)
		return null

	var declaration: FlowBlockPropertyPresentationDeclaration = FlowBlockPropertyPresentationDeclaration.new()
	declaration.property_name = StringName(String(data["property"]).strip_edges())
	declaration.declaration_index = index
	if data.has("label"):
		if typeof(data["label"]) == TYPE_STRING and not String(data["label"]).strip_edges().is_empty():
			declaration.has_label = true
			declaration.label = String(data["label"]).strip_edges()
		else:
			_issue(result, CODE_LABEL_INVALID, declaration_path + ".label", String(declaration.property_name),
				"label must be a non-empty string.", FlowDiagnostic.Severity.WARNING)
	if data.has("order"):
		if _is_integer_number(data["order"]):
			declaration.has_order = true
			declaration.order = int(data["order"])
		else:
			_issue(result, CODE_ORDER_INVALID, declaration_path + ".order", String(declaration.property_name),
				"order must be an integer.", FlowDiagnostic.Severity.WARNING)
	if data.has("group"):
		if typeof(data["group"]) == TYPE_STRING and not String(data["group"]).strip_edges().is_empty():
			declaration.has_group = true
			declaration.group = String(data["group"]).strip_edges()
		else:
			_issue(result, CODE_GROUP_INVALID, declaration_path + ".group", String(declaration.property_name),
				"group must be a non-empty string.", FlowDiagnostic.Severity.WARNING)
	if data.has("tooltip"):
		if typeof(data["tooltip"]) == TYPE_STRING and not String(data["tooltip"]).strip_edges().is_empty():
			declaration.has_tooltip = true
			declaration.tooltip = String(data["tooltip"]).strip_edges()
		else:
			_issue(result, CODE_TOOLTIP_INVALID, declaration_path + ".tooltip", String(declaration.property_name),
				"tooltip must be a non-empty string.", FlowDiagnostic.Severity.WARNING)
	if data.has("presentation"):
		if typeof(data["presentation"]) == TYPE_STRING \
				and _PRESENTATIONS.has(String(data["presentation"]).strip_edges()):
			declaration.has_presentation = true
			declaration.presentation = StringName(String(data["presentation"]).strip_edges())
		else:
			_issue(result, CODE_PRESENTATION_INVALID, declaration_path + ".presentation", String(declaration.property_name),
				"presentation must be one of auto, multiline, range, or enum.", FlowDiagnostic.Severity.WARNING)
	return declaration


func _is_project_relative_package_path(path: String) -> bool:
	if not (path.begins_with("res://") or path.begins_with("user://")):
		return false
	var relative: String = path.substr(path.find("://") + 3)
	for segment: String in relative.replace("\\", "/").split("/"):
		if segment == "..":
			return false
	return true


static func _is_integer_number(value: Variant) -> bool:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return false
	var numeric: float = float(value)
	return is_finite(numeric) and numeric == floor(numeric)


static func _issue(
	result: FlowValidationResult,
	code: StringName,
	path: String,
	related_id: String,
	message: String,
	severity: FlowDiagnostic.Severity
) -> void:
	result.add_diagnostic(FlowDiagnostic.new(code, severity, message, path, related_id))
