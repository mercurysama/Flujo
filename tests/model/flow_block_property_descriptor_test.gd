extends Node

const FIXTURE_SCRIPT: Script = preload(
	"res://tests/fixtures/property_descriptors/manual_output/block.gd"
)
const PACKAGE_ROOT: String = "res://tests/fixtures/property_descriptors/manual_output"
const BLOCK_TYPE_ID: String = "output"
const TEMP_ROOT: String = "res://.godot/flujo_tests/d4b_property_metadata"
const RUNTIME_DESCRIPTOR_FILES: Array[String] = [
	"res://addons/vp_flujo/runtime/model/flow_block_property_descriptor.gd",
	"res://addons/vp_flujo/runtime/model/flow_block_property_presentation_declaration.gd",
	"res://addons/vp_flujo/runtime/model/flow_block_property_presentation_document.gd",
	"res://addons/vp_flujo/runtime/model/flow_block_property_presentation_load_result.gd",
	"res://addons/vp_flujo/runtime/model/flow_block_property_presentation_loader.gd",
	"res://addons/vp_flujo/runtime/model/flow_block_property_catalog_result.gd",
	"res://addons/vp_flujo/runtime/model/flow_block_property_catalog.gd",
]

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var block: FlowBlock = FIXTURE_SCRIPT.new() as FlowBlock
	_check(block != null, "The D4-B fixture creates a normal FlowBlock instance.")
	if block == null:
		_finish()
		return
	_test_supported_types_and_hints(block)
	_test_default_presentation_and_ordering(block)
	_test_metadata_projection(block)
	_test_invalid_metadata(block)
	_test_eligibility_and_no_invention(block)
	_test_container_independence(block)
	_test_builtin_without_metadata()
	_test_runtime_boundary()
	_cleanup_temp_metadata()
	_finish()


func _test_supported_types_and_hints(block: FlowBlock) -> void:
	var result: FlowBlockPropertyCatalogResult = FlowBlockPropertyCatalog.describe(
		block, PACKAGE_ROOT, BLOCK_TYPE_ID
	)
	var descriptors: Dictionary = _by_name(result)
	var message: FlowBlockPropertyDescriptor = descriptors.get("message") as FlowBlockPropertyDescriptor
	var boolean_value: FlowBlockPropertyDescriptor = descriptors.get("boolean_value") as FlowBlockPropertyDescriptor
	var ranged_int: FlowBlockPropertyDescriptor = descriptors.get("ranged_int") as FlowBlockPropertyDescriptor
	var ranged_float: FlowBlockPropertyDescriptor = descriptors.get("ranged_float") as FlowBlockPropertyDescriptor
	var enum_value: FlowBlockPropertyDescriptor = descriptors.get("enum_value") as FlowBlockPropertyDescriptor
	var string_name_value: FlowBlockPropertyDescriptor = descriptors.get("string_name_value") as FlowBlockPropertyDescriptor

	_check(message != null, "The manual-SDK message field produces a generic descriptor.")
	if message != null:
		_check(message.model_type == TYPE_STRING, "message retains the reflected String model type.")
		_check(message.current_value == "Hello from the manual SDK", "message exposes its current model value.")
		_check(message.presentation_kind == FlowBlockPropertyDescriptor.PRESENTATION_MULTILINE,
			"message uses the approved multiline presentation.")
	_check(boolean_value != null and boolean_value.model_type == TYPE_BOOL,
		"A bool property produces a Boolean descriptor.")
	_check(ranged_int != null and ranged_int.model_type == TYPE_INT,
		"An int property produces an Integer descriptor.")
	_check(ranged_float != null and ranged_float.model_type == TYPE_FLOAT,
		"A float property produces a Floating-point descriptor.")
	_check(enum_value != null and enum_value.model_type == TYPE_INT,
		"An enum property retains its reflected int model type.")
	_check(string_name_value != null and string_name_value.model_type == TYPE_STRING_NAME,
		"A StringName property produces a StringName-preserving descriptor.")
	_check(ranged_int != null and ranged_int.hint == PROPERTY_HINT_RANGE \
			and ranged_int.presentation_kind == FlowBlockPropertyDescriptor.PRESENTATION_RANGE,
		"The reflected int range hint is described as range.")
	_check(ranged_float != null and ranged_float.hint == PROPERTY_HINT_RANGE \
			and ranged_float.presentation_kind == FlowBlockPropertyDescriptor.PRESENTATION_RANGE,
		"The reflected float range hint is described as range.")
	_check(enum_value != null and enum_value.hint == PROPERTY_HINT_ENUM \
			and enum_value.presentation_kind == FlowBlockPropertyDescriptor.PRESENTATION_ENUM,
		"The reflected enum hint is described as enum.")
	_check(_has_code(result, FlowBlockPropertyCatalog.CODE_UNSUPPORTED_TYPE),
		"Unsupported reflected types emit a deterministic diagnostic.")


func _test_default_presentation_and_ordering(block: FlowBlock) -> void:
	var first: FlowBlockPropertyCatalogResult = FlowBlockPropertyCatalog.describe(
		block, PACKAGE_ROOT, BLOCK_TYPE_ID
	)
	var second: FlowBlockPropertyCatalogResult = FlowBlockPropertyCatalog.describe(
		block, PACKAGE_ROOT, BLOCK_TYPE_ID
	)
	_check(_descriptor_signature(first) == _descriptor_signature(second),
		"Repeated descriptor construction has deterministic values and ordering.")
	var descriptors: Dictionary = _by_name(first)
	var plain_text: FlowBlockPropertyDescriptor = descriptors.get("plain_text") as FlowBlockPropertyDescriptor
	_check(plain_text != null and plain_text.label == "Plain Text",
		"The default label humanizes snake_case deterministically.")
	var expected_order: Array[String] = [
		"display_name",
		"enabled",
		"boolean_value",
		"message",
		"enum_value",
		"ranged_int",
		"plain_text",
		"ranged_float",
		"read_only_value",
		"string_name_value",
		"user_note",
	]
	_check(_descriptor_names(first) == expected_order,
		"Explicit host properties stay first and generic fields follow the exact order rule.")
	_check(descriptors.get("user_note") != null, "The public persistent FlowBlock note is describable generically.")
	var read_only: FlowBlockPropertyDescriptor = descriptors.get("read_only_value") as FlowBlockPropertyDescriptor
	_check(read_only != null and not read_only.editable,
		"A supported reflected read-only property remains descriptive but is not editable.")
	var display_name: FlowBlockPropertyDescriptor = descriptors.get("display_name") as FlowBlockPropertyDescriptor
	_check(display_name != null and display_name.is_explicit_built_in() and not display_name.is_generic_candidate(),
		"Built-in display_name is classified so a future renderer cannot duplicate it.")
	var enabled: FlowBlockPropertyDescriptor = descriptors.get("enabled") as FlowBlockPropertyDescriptor
	_check(enabled != null and enabled.is_explicit_built_in(),
		"Built-in enabled is classified as an explicit host control.")


func _test_metadata_projection(block: FlowBlock) -> void:
	var result: FlowBlockPropertyCatalogResult = FlowBlockPropertyCatalog.describe(
		block, PACKAGE_ROOT, BLOCK_TYPE_ID
	)
	var descriptors: Dictionary = _by_name(result)
	var message: FlowBlockPropertyDescriptor = descriptors.get("message") as FlowBlockPropertyDescriptor
	var boolean_value: FlowBlockPropertyDescriptor = descriptors.get("boolean_value") as FlowBlockPropertyDescriptor
	var ranged_float: FlowBlockPropertyDescriptor = descriptors.get("ranged_float") as FlowBlockPropertyDescriptor
	_check(message != null and message.label == "Output Message", "Metadata can override a safe display label.")
	_check(message != null and message.has_order and message.order == 20,
		"Metadata can provide a deterministic explicit order.")
	_check(message != null and message.group == "Output" and message.tooltip == "Text emitted by this block.",
		"Metadata can provide group and tooltip presentation data.")
	_check(message != null and message.presentation_source == FlowBlockPropertyDescriptor.SOURCE_REFLECTION_AND_METADATA,
		"Descriptor provenance records reflection plus metadata presentation intent.")
	_check(boolean_value != null and boolean_value.has_order and boolean_value.order == 10 \
			and boolean_value.group == "Options",
		"Partial metadata applies to the declared bool property.")
	_check(ranged_float != null and not ranged_float.has_order and ranged_float.group.is_empty() \
			and ranged_float.tooltip.is_empty(),
		"Partial metadata leaves undeclared properties on reflection defaults.")


func _test_invalid_metadata(block: FlowBlock) -> void:
	var invalid_json: FlowBlockPropertyCatalogResult = _describe_with_metadata(
		block, "invalid_json", "{ invalid"
	)
	_check(_has_code(invalid_json, FlowBlockPropertyPresentationLoader.CODE_JSON_INVALID),
		"Invalid JSON is diagnosed without aborting descriptor construction.")
	_check((_by_name(invalid_json).get("message") as FlowBlockPropertyDescriptor).label == "Message",
		"Invalid JSON falls back to deterministic reflection presentation.")

	var wrong_root: FlowBlockPropertyCatalogResult = _describe_with_metadata(
		block, "wrong_root", "[]"
	)
	_check(_has_code(wrong_root, FlowBlockPropertyPresentationLoader.CODE_ROOT_INVALID),
		"A wrong metadata top-level shape is diagnosed safely.")

	var unknown_property: FlowBlockPropertyCatalogResult = _describe_with_metadata(block, "unknown_property", _metadata([
		{"property": "does_not_exist", "label": "Invented"},
	]))
	_check(_has_code(unknown_property, FlowBlockPropertyCatalog.CODE_PROPERTY_UNKNOWN),
		"Unknown metadata properties emit a diagnostic.")
	_check(not _by_name(unknown_property).has("does_not_exist"),
		"Unknown metadata properties never invent descriptors.")

	var duplicate: FlowBlockPropertyCatalogResult = _describe_with_metadata(block, "duplicate", _metadata([
		{"property": "message", "label": "First"},
		{"property": "message", "label": "Second"},
	]))
	_check(_has_code(duplicate, FlowBlockPropertyPresentationLoader.CODE_PROPERTY_DUPLICATE),
		"Duplicate metadata declarations emit one deterministic diagnostic.")
	var duplicate_message: FlowBlockPropertyDescriptor = _by_name(duplicate).get("message") as FlowBlockPropertyDescriptor
	_check(duplicate_message != null and duplicate_message.label == "Message",
		"Duplicate declarations are ignored rather than choosing an incidental entry.")

	var incompatible: FlowBlockPropertyCatalogResult = _describe_with_metadata(block, "incompatible", _metadata([
		{"property": "boolean_value", "presentation": "range"},
	]))
	_check(_has_code(incompatible, FlowBlockPropertyCatalog.CODE_PRESENTATION_INCOMPATIBLE),
		"Incompatible presentation requests emit a diagnostic.")
	var boolean_descriptor: FlowBlockPropertyDescriptor = _by_name(incompatible).get("boolean_value") as FlowBlockPropertyDescriptor
	_check(boolean_descriptor != null and boolean_descriptor.presentation_kind == FlowBlockPropertyDescriptor.PRESENTATION_BOOLEAN,
		"Incompatible presentation requests fall back to the reflected scalar kind.")

	var malformed_fields: FlowBlockPropertyCatalogResult = _describe_with_metadata(block, "malformed_fields", _metadata([
		{"property": "plain_text", "label": "", "order": "first", "group": "", "tooltip": ""},
	]))
	_check(_has_code(malformed_fields, FlowBlockPropertyPresentationLoader.CODE_LABEL_INVALID),
		"Malformed labels are diagnosed.")
	_check(_has_code(malformed_fields, FlowBlockPropertyPresentationLoader.CODE_ORDER_INVALID),
		"Malformed orders are diagnosed.")
	_check(_has_code(malformed_fields, FlowBlockPropertyPresentationLoader.CODE_GROUP_INVALID),
		"Malformed groups are diagnosed.")
	_check(_has_code(malformed_fields, FlowBlockPropertyPresentationLoader.CODE_TOOLTIP_INVALID),
		"Malformed tooltips/help are diagnosed.")
	var malformed_descriptor: FlowBlockPropertyDescriptor = _by_name(malformed_fields).get("plain_text") as FlowBlockPropertyDescriptor
	_check(malformed_descriptor != null and malformed_descriptor.label == "Plain Text" \
			and not malformed_descriptor.has_order and malformed_descriptor.group.is_empty() \
			and malformed_descriptor.tooltip.is_empty(),
		"Malformed presentation fields use deterministic field-level fallbacks.")

	var type_override: FlowBlockPropertyCatalogResult = _describe_with_metadata(block, "type_override", _metadata([
		{"property": "message", "type": "int", "label": "Still Message"},
	]))
	_check(_has_code(type_override, FlowBlockPropertyPresentationLoader.CODE_DECLARATION_FIELD_UNKNOWN),
		"A metadata type field is rejected as unsupported presentation data.")
	var message_descriptor: FlowBlockPropertyDescriptor = _by_name(type_override).get("message") as FlowBlockPropertyDescriptor
	_check(message_descriptor != null and message_descriptor.model_type == TYPE_STRING \
			and message_descriptor.label == "Still Message",
		"The reflected model type remains authoritative over metadata.")

	var wrong_identity: FlowBlockPropertyCatalogResult = _describe_with_metadata(block, "wrong_identity", JSON.stringify({
		"format_version": 1,
		"block_type_id": "other",
		"properties": [],
	}))
	_check(_has_code(wrong_identity, FlowBlockPropertyPresentationLoader.CODE_BLOCK_TYPE_ID_MISMATCH),
		"A package metadata identity mismatch falls back safely.")

	var absolute_package_path: String = ProjectSettings.globalize_path(PACKAGE_ROOT)
	var absolute_path_result: FlowBlockPropertyCatalogResult = FlowBlockPropertyCatalog.describe(
		block, absolute_package_path, BLOCK_TYPE_ID
	)
	_check(_has_code(absolute_path_result, FlowBlockPropertyPresentationLoader.CODE_PACKAGE_PATH_INVALID),
		"Absolute filesystem paths are rejected for metadata resolution.")
	var absolute_message: FlowBlockPropertyDescriptor = _by_name(absolute_path_result).get("message") as FlowBlockPropertyDescriptor
	_check(absolute_message != null and absolute_message.label == "Message",
		"Rejected absolute metadata paths use reflection defaults without filesystem fallback.")


func _test_eligibility_and_no_invention(block: FlowBlock) -> void:
	var before_message: Variant = block.get("message")
	var result: FlowBlockPropertyCatalogResult = FlowBlockPropertyCatalog.describe(
		block, PACKAGE_ROOT, BLOCK_TYPE_ID
	)
	var descriptors: Dictionary = _by_name(result)
	_check(not descriptors.has("storage_only"), "Storage-only properties are excluded without editor usage.")
	_check(not descriptors.has("editor_only"), "Editor-only non-storage properties are excluded.")
	_check(not descriptors.has("runtime_only"), "Runtime-only properties are excluded.")
	_check(not descriptors.has("_private_export") and not descriptors.has("_internal_id"),
		"Private and internal bookkeeping properties are excluded.")
	_check(not descriptors.has("unsupported_vector"), "Unsupported types are omitted from the generic v1 list.")
	_check(block.get("message") == before_message, "Discovery and metadata validation never mutate the FlowBlock.")
	_check(_has_code(result, FlowBlockPropertyCatalog.CODE_UNSUPPORTED_TYPE),
		"Unsupported properties remain observable through structured diagnostics.")


func _test_container_independence(block: FlowBlock) -> void:
	var process: FlowProcess = FlowProcess.new()
	process.blocks = [block]
	var timer: FlowTimerDefinition = FlowTimerDefinition.new()
	timer.blocks = [block]
	var process_result: FlowBlockPropertyCatalogResult = FlowBlockPropertyCatalog.describe(
		process.blocks[0], PACKAGE_ROOT, BLOCK_TYPE_ID
	)
	var timer_result: FlowBlockPropertyCatalogResult = FlowBlockPropertyCatalog.describe(
		timer.blocks[0], PACKAGE_ROOT, BLOCK_TYPE_ID
	)
	_check(_descriptor_signature(process_result) == _descriptor_signature(timer_result),
		"The same block produces equivalent descriptors in Process and Timer contexts.")


func _test_builtin_without_metadata() -> void:
	for block: FlowBlock in [FlowPrintBlock.new(), FlowEverythingFlowsBlock.new(), FlowMethodCallBlock.new()]:
		var result: FlowBlockPropertyCatalogResult = FlowBlockPropertyCatalog.describe(block)
		_check(result != null and not _has_code(result, FlowBlockPropertyPresentationLoader.CODE_READ_FAILED),
			"Built-in %s describes without requiring package metadata." % block.get_class())
		_check(_by_name(result).has("display_name"),
			"Built-in %s retains the explicit display_name descriptor." % block.get_class())


func _test_runtime_boundary() -> void:
	var prohibited: Array[String] = [
		"EditorInterface",
		"EditorPlugin",
		"EditorUndoRedoManager",
		"FlowEditorBlockAuthoringContext",
		"Control",
		"ResourceLoader",
		"Callable",
		"FlowIfBlock",
	]
	for path: String in RUNTIME_DESCRIPTOR_FILES:
		var source: String = FileAccess.get_file_as_string(path)
		_check(not source.is_empty(), "Runtime descriptor source exists: %s" % path)
		for token: String in prohibited:
			_check(not source.contains(token), "%s has no prohibited editor/executable dependency: %s" % [path, token])
		_check(not source.contains("if package_id ==") and not source.contains("if block is"),
			"%s has no package- or concrete-block-specific branch." % path)


func _describe_with_metadata(
		block: FlowBlock,
		case_name: String,
		metadata: String
) -> FlowBlockPropertyCatalogResult:
	var directory: String = TEMP_ROOT.path_join(case_name)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var path: String = directory.path_join(FlowBlockPropertyPresentationLoader.FILE_NAME)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_failures.append("Could not create temporary metadata case: " + case_name)
		return FlowBlockPropertyCatalog.describe(block, directory, BLOCK_TYPE_ID)
	file.store_string(metadata)
	file.close()
	return FlowBlockPropertyCatalog.describe(block, directory, BLOCK_TYPE_ID)


func _metadata(properties: Array) -> String:
	return JSON.stringify({
		"format_version": 1,
		"block_type_id": BLOCK_TYPE_ID,
		"properties": properties,
	})


func _by_name(result: FlowBlockPropertyCatalogResult) -> Dictionary:
	var by_name: Dictionary = {}
	if result == null:
		return by_name
	for descriptor: FlowBlockPropertyDescriptor in result.descriptors:
		by_name[String(descriptor.property_name)] = descriptor
	return by_name


func _descriptor_names(result: FlowBlockPropertyCatalogResult) -> Array[String]:
	var names: Array[String] = []
	if result == null:
		return names
	for descriptor: FlowBlockPropertyDescriptor in result.descriptors:
		names.append(String(descriptor.property_name))
	return names


func _descriptor_signature(result: FlowBlockPropertyCatalogResult) -> Array[String]:
	var signature: Array[String] = []
	if result == null:
		return signature
	for descriptor: FlowBlockPropertyDescriptor in result.descriptors:
		signature.append("%s|%d|%s|%s|%s|%d|%s|%s" % [
			String(descriptor.property_name),
			descriptor.model_type,
			String(descriptor.presentation_kind),
			descriptor.label,
			descriptor.group,
			descriptor.order if descriptor.has_order else -1,
			descriptor.tooltip,
			str(descriptor.classification),
		])
	return signature


func _has_code(result: FlowValidationResult, code: StringName) -> bool:
	if result == null:
		return false
	for diagnostic: FlowDiagnostic in result.diagnostics:
		if diagnostic.code == code:
			return true
	return false


func _cleanup_temp_metadata() -> void:
	var absolute_root: String = ProjectSettings.globalize_path(TEMP_ROOT)
	if not DirAccess.dir_exists_absolute(absolute_root):
		return
	var access: DirAccess = DirAccess.open(absolute_root)
	if access == null:
		return
	for directory: String in access.get_directories():
		var child: String = absolute_root.path_join(directory)
		var child_access: DirAccess = DirAccess.open(child)
		if child_access != null:
			for file_name: String in child_access.get_files():
				DirAccess.remove_absolute(child.path_join(file_name))
		DirAccess.remove_absolute(child)
	DirAccess.remove_absolute(absolute_root)


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] D4-B FlowBlock property descriptor test passed")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
