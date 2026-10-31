@tool
class_name FlowBlockPropertyCatalog
extends RefCounted

## Runtime-safe reflection plus optional data-only presentation metadata.
##
## This class deliberately has no editor dependency and does not construct UI,
## mutate the block, apply undo/redo, or claim Flusso ownership.

const EXPLICIT_HOST_PROPERTY_NAMES: Array[StringName] = [
	&"display_name",
	&"enabled",
	&"text",
	&"method_id",
]

const CODE_BLOCK_MISSING: StringName = &"property_descriptor_block_missing"
const CODE_REFLECTION_PROPERTY_INVALID: StringName = &"property_descriptor_reflection_property_invalid"
const CODE_PROPERTY_INELIGIBLE: StringName = &"property_descriptor_property_ineligible"
const CODE_PROPERTY_UNKNOWN: StringName = &"property_descriptor_metadata_unknown_property"
const CODE_UNSUPPORTED_TYPE: StringName = &"unsupported_property_type"
const CODE_VALUE_TYPE_INVALID: StringName = &"property_descriptor_value_type_invalid"
const CODE_HINT_INVALID: StringName = &"property_descriptor_hint_invalid"
const CODE_HINT_UNSUPPORTED: StringName = &"property_descriptor_hint_unsupported"
const CODE_PRESENTATION_INCOMPATIBLE: StringName = &"property_descriptor_presentation_incompatible"


static func describe(
		block: FlowBlock,
		package_directory: String = "",
		block_type_id: String = ""
) -> FlowBlockPropertyCatalogResult:
	var result: FlowBlockPropertyCatalogResult = FlowBlockPropertyCatalogResult.new()
	if block == null:
		_issue(result, CODE_BLOCK_MISSING, "block", "", "FlowBlock is missing.", FlowDiagnostic.Severity.ERROR)
		return result

	var metadata_result: FlowBlockPropertyPresentationLoadResult = FlowBlockPropertyPresentationLoader.new().read(
		package_directory, block_type_id
	)
	result.diagnostics.append_array(metadata_result.diagnostics)
	var document: FlowBlockPropertyPresentationDocument = metadata_result.document
	var property_infos: Dictionary = {}
	var property_names: Array[String] = []
	for raw_property: Variant in block.get_property_list():
		if not raw_property is Dictionary:
			_issue(result, CODE_REFLECTION_PROPERTY_INVALID, "property_list", str(block.get_instance_id()),
				"Reflected property information is not an object.", FlowDiagnostic.Severity.WARNING)
			continue
		var property: Dictionary = raw_property as Dictionary
		if not property.has("name"):
			_issue(result, CODE_REFLECTION_PROPERTY_INVALID, "property_list", str(block.get_instance_id()),
				"Reflected property information has no name.", FlowDiagnostic.Severity.WARNING)
			continue
		var property_name: StringName = StringName(String(property["name"]))
		if property_name.is_empty() or property_infos.has(property_name):
			continue
		property_infos[property_name] = property
		property_names.append(String(property_name))
	property_names.sort()

	if document != null:
		for declaration: FlowBlockPropertyPresentationDeclaration in document.declarations:
			if not property_infos.has(declaration.property_name):
				_issue(result, CODE_PROPERTY_UNKNOWN, _declaration_path(document, declaration),
					String(declaration.property_name), "Presentation metadata names a property that does not exist.",
					FlowDiagnostic.Severity.WARNING)
				continue
			var reflected: Dictionary = property_infos[declaration.property_name] as Dictionary
			if not _is_eligible(reflected, declaration.property_name):
				_issue(result, CODE_PROPERTY_INELIGIBLE, _declaration_path(document, declaration),
					String(declaration.property_name), "Presentation metadata names an ineligible property.",
					FlowDiagnostic.Severity.WARNING)

	var explicit_descriptors: Array[FlowBlockPropertyDescriptor] = []
	var generic_descriptors: Array[FlowBlockPropertyDescriptor] = []
	for property_name_text: String in property_names:
		var property_name: StringName = StringName(property_name_text)
		var property: Dictionary = property_infos[property_name] as Dictionary
		if not _is_eligible(property, property_name):
			continue
		var model_type: Variant.Type = int(property.get("type", TYPE_NIL)) as Variant.Type
		var reflected_hint: int = int(property.get("hint", PROPERTY_HINT_NONE))
		var reflected_hint_string: String = String(property.get("hint_string", ""))
		if not _is_supported_type(model_type, reflected_hint, reflected_hint_string):
			_issue(result, CODE_UNSUPPORTED_TYPE, String(property_name), str(block.get_instance_id()),
				"Property type is outside the generic v1 property set.", FlowDiagnostic.Severity.WARNING)
			continue

		var current_value: Variant = block.get(property_name)
		if not _value_matches_type(current_value, model_type, reflected_hint, reflected_hint_string):
			_issue(result, CODE_VALUE_TYPE_INVALID, String(property_name), str(block.get_instance_id()),
				"Current property value does not match the reflected model type.", FlowDiagnostic.Severity.WARNING)
			continue

		var hint_kind: StringName = _base_presentation_kind(model_type)
		if _is_structured_document_property(model_type, reflected_hint, reflected_hint_string):
			hint_kind = FlowBlockPropertyDescriptor.PRESENTATION_STRUCTURED_DOCUMENT
		elif reflected_hint != PROPERTY_HINT_NONE:
			var hint_result: Dictionary = _validate_reflected_hint(
				model_type, reflected_hint, reflected_hint_string, property_name, result
			)
			if bool(hint_result.get("valid", false)):
				hint_kind = hint_result["kind"] as StringName

		var declaration: FlowBlockPropertyPresentationDeclaration = document.declaration_for(property_name) if document != null else null
		var effective_kind: StringName = hint_kind
		if declaration != null and declaration.has_presentation and declaration.presentation != FlowBlockPropertyPresentationDeclaration.PRESENTATION_AUTO:
			var requested_kind: StringName = declaration.presentation
			if _presentation_is_compatible(requested_kind, model_type, hint_kind):
				effective_kind = requested_kind
			else:
				_issue(result, CODE_PRESENTATION_INCOMPATIBLE, _declaration_path(document, declaration) + ".presentation",
					String(property_name), "Requested presentation is incompatible with the reflected property.",
					FlowDiagnostic.Severity.WARNING)

		var descriptor: FlowBlockPropertyDescriptor = FlowBlockPropertyDescriptor.new()
		descriptor.property_name = property_name
		descriptor.model_type = model_type
		descriptor.usage = int(property.get("usage", 0))
		descriptor.hint = reflected_hint
		descriptor.hint_string = reflected_hint_string
		descriptor.resource_type_name = reflected_hint_string if model_type == TYPE_OBJECT else ""
		descriptor.editable = not bool(descriptor.usage & PROPERTY_USAGE_READ_ONLY)
		descriptor.current_value = current_value
		descriptor.label = _default_label(property_name)
		descriptor.presentation_kind = effective_kind
		descriptor.classification = FlowBlockPropertyDescriptor.Classification.EXPLICIT_BUILT_IN \
			if EXPLICIT_HOST_PROPERTY_NAMES.has(property_name) \
			else FlowBlockPropertyDescriptor.Classification.GENERIC
		if declaration != null:
			if declaration.has_label:
				descriptor.label = declaration.label
			if declaration.has_order:
				descriptor.has_order = true
				descriptor.order = declaration.order
			if declaration.has_group:
				descriptor.group = declaration.group
			if declaration.has_tooltip:
				descriptor.tooltip = declaration.tooltip
			if declaration.has_safe_presentation_values():
				descriptor.presentation_source = FlowBlockPropertyDescriptor.SOURCE_METADATA
				if reflected_hint != PROPERTY_HINT_NONE:
					descriptor.presentation_source = FlowBlockPropertyDescriptor.SOURCE_REFLECTION_AND_METADATA

		if descriptor.is_explicit_built_in():
			explicit_descriptors.append(descriptor)
		else:
			generic_descriptors.append(descriptor)

	_sort_explicit_descriptors(explicit_descriptors)
	_sort_generic_descriptors(generic_descriptors)
	result.descriptors.append_array(explicit_descriptors)
	result.descriptors.append_array(generic_descriptors)
	return result


static func _is_eligible(property: Dictionary, property_name: StringName) -> bool:
	if property_name.is_empty() or property_name == &"script" or String(property_name).begins_with("_"):
		return false
	var usage: int = int(property.get("usage", 0))
	if bool(usage & PROPERTY_USAGE_INTERNAL):
		return false
	if bool(usage & (PROPERTY_USAGE_CATEGORY | PROPERTY_USAGE_GROUP | PROPERTY_USAGE_SUBGROUP)):
		return false
	return bool(usage & PROPERTY_USAGE_SCRIPT_VARIABLE) \
		and bool(usage & PROPERTY_USAGE_EDITOR) \
		and bool(usage & PROPERTY_USAGE_STORAGE)


static func _is_supported_type(
		model_type: Variant.Type,
		hint: int = PROPERTY_HINT_NONE,
		hint_string: String = ""
) -> bool:
	return model_type == TYPE_BOOL or model_type == TYPE_INT or model_type == TYPE_FLOAT \
		or model_type == TYPE_STRING or model_type == TYPE_STRING_NAME \
		or _is_structured_document_property(model_type, hint, hint_string)


static func _value_matches_type(
		value: Variant,
		model_type: Variant.Type,
		hint: int = PROPERTY_HINT_NONE,
		hint_string: String = ""
) -> bool:
	if _is_structured_document_property(model_type, hint, hint_string):
		return value == null or value is FlowStructuredDocument
	return typeof(value) == model_type


static func _is_structured_document_property(
		model_type: Variant.Type,
		hint: int,
		hint_string: String
) -> bool:
	return model_type == TYPE_OBJECT \
		and hint == PROPERTY_HINT_RESOURCE_TYPE \
		and hint_string.strip_edges() == "FlowStructuredDocument"


static func _base_presentation_kind(model_type: Variant.Type) -> StringName:
	match model_type:
		TYPE_BOOL:
			return FlowBlockPropertyDescriptor.PRESENTATION_BOOLEAN
		TYPE_INT:
			return FlowBlockPropertyDescriptor.PRESENTATION_INTEGER
		TYPE_FLOAT:
			return FlowBlockPropertyDescriptor.PRESENTATION_FLOAT
		TYPE_STRING:
			return FlowBlockPropertyDescriptor.PRESENTATION_TEXT
		TYPE_STRING_NAME:
			return FlowBlockPropertyDescriptor.PRESENTATION_STRING_NAME
		TYPE_OBJECT:
			return FlowBlockPropertyDescriptor.PRESENTATION_STRUCTURED_DOCUMENT
	return &""


static func _validate_reflected_hint(
		model_type: Variant.Type,
		hint: int,
		hint_string: String,
		property_name: StringName,
		result: FlowBlockPropertyCatalogResult
) -> Dictionary:
	if hint == PROPERTY_HINT_RANGE and (model_type == TYPE_INT or model_type == TYPE_FLOAT):
		if _valid_range_hint(hint_string):
			return {"valid": true, "kind": FlowBlockPropertyDescriptor.PRESENTATION_RANGE}
		_issue(result, CODE_HINT_INVALID, String(property_name), "",
			"Reflected range hint is malformed.", FlowDiagnostic.Severity.WARNING)
		return {"valid": false}
	if hint == PROPERTY_HINT_ENUM and (model_type == TYPE_INT or model_type == TYPE_STRING):
		if _valid_enum_hint(hint_string):
			return {"valid": true, "kind": FlowBlockPropertyDescriptor.PRESENTATION_ENUM}
		_issue(result, CODE_HINT_INVALID, String(property_name), "",
			"Reflected enum hint is malformed.", FlowDiagnostic.Severity.WARNING)
		return {"valid": false}
	if hint == PROPERTY_HINT_MULTILINE_TEXT and model_type == TYPE_STRING:
		return {"valid": true, "kind": FlowBlockPropertyDescriptor.PRESENTATION_MULTILINE}
	_issue(result, CODE_HINT_UNSUPPORTED, String(property_name), "",
		"Reflected hint is unsupported or incompatible with the model type.", FlowDiagnostic.Severity.WARNING)
	return {"valid": false}


static func _valid_range_hint(hint_string: String) -> bool:
	var parts: PackedStringArray = hint_string.split(",", false)
	if parts.size() < 2:
		return false
	for index: int in 2:
		var token: String = parts[index].strip_edges()
		if not token.is_valid_float() or not is_finite(token.to_float()):
			return false
	return true


static func _valid_enum_hint(hint_string: String) -> bool:
	var parts: PackedStringArray = hint_string.split(",", false)
	if parts.is_empty():
		return false
	for raw_part: String in parts:
		var part: String = raw_part.strip_edges()
		if part.is_empty():
			return false
		var colon_index: int = part.rfind(":")
		if colon_index >= 0:
			var enum_value: String = part.substr(colon_index + 1).strip_edges()
			if not enum_value.is_valid_int():
				return false
	return true


static func _presentation_is_compatible(
		requested_kind: StringName,
		model_type: Variant.Type,
		reflected_kind: StringName
) -> bool:
	match requested_kind:
		&"multiline":
			return model_type == TYPE_STRING
		&"range":
			return (model_type == TYPE_INT or model_type == TYPE_FLOAT) \
				and reflected_kind == FlowBlockPropertyDescriptor.PRESENTATION_RANGE
		&"enum":
			return (model_type == TYPE_INT or model_type == TYPE_STRING) \
				and reflected_kind == FlowBlockPropertyDescriptor.PRESENTATION_ENUM
	return false


static func _default_label(property_name: StringName) -> String:
	var raw: String = String(property_name).replace("_", " ").replace("-", " ")
	var words: Array[String] = []
	var current: String = ""
	for index: int in raw.length():
		var character: String = raw[index]
		var previous: String = raw[index - 1] if index > 0 else ""
		var next: String = raw[index + 1] if index + 1 < raw.length() else ""
		var starts_word: bool = character == " " or character == "\t"
		var camel_boundary: bool = index > 0 and character != " " and character != "\t" \
			and character.to_upper() == character and previous.to_lower() == previous \
			and previous != " " and previous != "\t"
		var acronym_boundary: bool = index > 1 and character != " " and character != "\t" \
			and character.to_upper() == character and previous.to_upper() == previous \
			and next.to_lower() == next and next != " " and next != "\t"
		if starts_word:
			if not current.is_empty():
				words.append(current)
			current = ""
			continue
		if camel_boundary or acronym_boundary:
			if not current.is_empty():
				words.append(current)
			current = ""
		current += character
	if not current.is_empty():
		words.append(current)
	var formatted: Array[String] = []
	for word: String in words:
		if word.to_lower() == "id":
			formatted.append("ID")
		else:
			formatted.append(word.left(1).to_upper() + word.substr(1).to_lower())
	return " ".join(formatted)


static func _sort_explicit_descriptors(descriptors: Array[FlowBlockPropertyDescriptor]) -> void:
	for index: int in range(1, descriptors.size()):
		var candidate: FlowBlockPropertyDescriptor = descriptors[index]
		var position: int = index
		while position > 0 and _explicit_before(candidate, descriptors[position - 1]):
			descriptors[position] = descriptors[position - 1]
			position -= 1
		descriptors[position] = candidate


static func _explicit_before(
		left: FlowBlockPropertyDescriptor,
		right: FlowBlockPropertyDescriptor
) -> bool:
	var left_index: int = EXPLICIT_HOST_PROPERTY_NAMES.find(left.property_name)
	var right_index: int = EXPLICIT_HOST_PROPERTY_NAMES.find(right.property_name)
	if left_index != right_index:
		return left_index < right_index
	return _ordinal_less(String(left.property_name), String(right.property_name))


static func _sort_generic_descriptors(descriptors: Array[FlowBlockPropertyDescriptor]) -> void:
	for index: int in range(1, descriptors.size()):
		var candidate: FlowBlockPropertyDescriptor = descriptors[index]
		var position: int = index
		while position > 0 and _generic_before(candidate, descriptors[position - 1]):
			descriptors[position] = descriptors[position - 1]
			position -= 1
		descriptors[position] = candidate


static func _generic_before(
		left: FlowBlockPropertyDescriptor,
		right: FlowBlockPropertyDescriptor
) -> bool:
	if left.has_order != right.has_order:
		return left.has_order
	if left.has_order and left.order != right.order:
		return left.order < right.order
	return _ordinal_less(String(left.property_name), String(right.property_name))


static func _ordinal_less(left: String, right: String) -> bool:
	var common_length: int = mini(left.length(), right.length())
	for index: int in common_length:
		var left_code: int = left.unicode_at(index)
		var right_code: int = right.unicode_at(index)
		if left_code != right_code:
			return left_code < right_code
	return left.length() < right.length()


static func _declaration_path(
		document: FlowBlockPropertyPresentationDocument,
		declaration: FlowBlockPropertyPresentationDeclaration
) -> String:
	return document.source_path + ".properties[%d]" % declaration.declaration_index


static func _issue(
		result: FlowValidationResult,
		code: StringName,
		path: String,
		related_id: String,
		message: String,
		severity: FlowDiagnostic.Severity
) -> void:
	result.add_diagnostic(FlowDiagnostic.new(code, severity, message, path, related_id))
