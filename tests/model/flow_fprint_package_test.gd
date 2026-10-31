extends Node


const PACKAGE_ROOT: String = "res://flow_packages/mercury.fprint"
const MANIFEST_PATH: String = PACKAGE_ROOT + "/manifest.json"
const PRESENTATION_PATH: String = PACKAGE_ROOT + "/block_property_presentation.json"
const FPRINT_SCRIPT_PATH: String = PACKAGE_ROOT + "/block.gd"
const FPRINT_SCRIPT: Script = preload("res://flow_packages/mercury.fprint/block.gd")
const TEMP_ROOT: String = "res://.godot/flujo_tests/fprint_package"
const GRAPH_PATH: String = TEMP_ROOT + "/fprint_graph.tres"
const SCENE_PATH: String = TEMP_ROOT + "/fprint_controller.tscn"


var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_manifest_and_presentation_data()
	var discovery: FlowPackageManifestDiscoveryResult = FlowPackageManifestLoader.new().discover()
	var manifest: FlowPackageManifest = _manifest_for(discovery, "mercury.fprint")
	_test_discovery_and_script_validation(discovery, manifest)
	var first: FlowBlock = _create_fprint(manifest)
	var second: FlowBlock = _create_fprint(manifest)
	_test_defaults_and_independent_instances(first, second)
	_test_duplication(first)
	_test_persistence(first)
	_test_static_boundaries()
	_cleanup()
	_finish()


func _test_manifest_and_presentation_data() -> void:
	var manifest_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))
	_check(manifest_data is Dictionary, "FPrint manifest is valid JSON data.")
	if not manifest_data is Dictionary:
		return
	var manifest: Dictionary = manifest_data as Dictionary
	_check(_keys_are_exact(manifest, ["manifest_version", "package_id", "blocks"]),
		"FPrint manifest uses only the manifest v1 fields.")
	_check(manifest.get("manifest_version") == 1, "FPrint manifest declares manifest_version 1.")
	_check(manifest.get("package_id") == "mercury.fprint", "FPrint manifest declares its package ID.")
	var blocks: Array = manifest.get("blocks", []) as Array
	_check(blocks.size() == 1, "FPrint manifest contains exactly one block descriptor.")
	if blocks.size() != 1 or not blocks[0] is Dictionary:
		return
	var descriptor: Dictionary = blocks[0] as Dictionary
	_check(_keys_are_exact(descriptor, ["type_id", "script", "display_name"]),
		"FPrint descriptor uses only the manifest v1 descriptor fields.")
	_check(descriptor.get("type_id") == "fprint", "FPrint manifest declares type_id fprint.")
	_check(descriptor.get("script") == "block.gd", "FPrint manifest keeps the script package-relative.")
	_check(descriptor.get("display_name") == "FPrint", "FPrint manifest declares the display name.")

	var presentation_data: Variant = JSON.parse_string(FileAccess.get_file_as_string(PRESENTATION_PATH))
	_check(presentation_data is Dictionary, "FPrint presentation metadata is valid JSON data.")
	if not presentation_data is Dictionary:
		return
	var presentation: Dictionary = presentation_data as Dictionary
	_check(_keys_are_exact(presentation, ["format_version", "block_type_id", "properties"]),
		"FPrint presentation metadata is data-only and uses the D4 v1 fields.")
	_check(presentation.get("format_version") == 1 and presentation.get("block_type_id") == "fprint",
		"FPrint presentation metadata identifies the fprint block type.")
	var properties: Array = presentation.get("properties", []) as Array
	_check(properties.size() == 4, "FPrint presentation metadata declares the three legacy fields and optional document field.")
	var expected_names: Array[String] = ["prefix", "message", "document", "suffix"]
	var expected_labels: Array[String] = ["Prefix", "Message", "Structured Document", "Suffix"]
	for index: int in mini(properties.size(), expected_names.size()):
		if not properties[index] is Dictionary:
			_check(false, "FPrint presentation field %d is an object." % index)
			continue
		var property: Dictionary = properties[index] as Dictionary
		_check(property.get("property") == expected_names[index],
			"FPrint presentation keeps the approved property order at index %d." % index)
		_check(property.get("label") == expected_labels[index],
			"FPrint presentation uses the approved friendly label at index %d." % index)
	if properties.size() > 1 and properties[1] is Dictionary:
		_check((properties[1] as Dictionary).get("presentation") == "multiline",
			"FPrint Message metadata requests the generic multiline presentation.")
	if properties.size() > 2 and properties[2] is Dictionary:
		_check((properties[2] as Dictionary).get("tooltip", "").to_lower().contains("replaces"),
			"FPrint document metadata explains that a present document replaces Message.")


func _test_discovery_and_script_validation(
		discovery: FlowPackageManifestDiscoveryResult,
		manifest: FlowPackageManifest
) -> void:
	_check(manifest != null, "FPrint is discovered from the production package root.")
	if manifest == null:
		return
	_check(manifest.manifest_version == 1, "Discovered FPrint manifest retains manifest_version 1.")
	_check(manifest.blocks.size() == 1, "Discovery retains one FPrint descriptor.")
	if manifest.blocks.size() != 1:
		return
	var descriptor: FlowExternalBlockDescriptor = manifest.blocks[0]
	_check(descriptor.global_type_id() == "mercury.fprint:fprint",
		"Discovery exposes the expected FPrint authoring ID.")
	var validation: FlowPackageManifestScriptValidationResult = FlowExternalBlockScriptValidator.new().validate(
		manifest, PACKAGE_ROOT
	)
	_check(not validation.has_errors() and validation.valid_descriptors.size() == 1,
		"FPrint script validation accepts the declared block.")
	var catalog: FlowEditorBlockCatalog = FlowEditorBlockCatalog.combine(
		discovery, {manifest.package_id: validation}
	)
	var entry: FlowEditorBlockCatalogEntry = catalog.find("mercury.fprint:fprint")
	_check(entry != null and entry.is_external(), "The public catalog exposes FPrint as an external entry.")
	_check(entry != null and entry.display_name == "FPrint", "The catalog preserves FPrint's display name.")


func _create_fprint(manifest: FlowPackageManifest) -> FlowBlock:
	if manifest == null or manifest.blocks.is_empty():
		return null
	var descriptor: FlowExternalBlockDescriptor = manifest.blocks[0]
	var entry: FlowEditorBlockCatalogEntry = FlowEditorBlockCatalogEntry.external(descriptor)
	var creation: FlowExternalBlockCreationResult = FlowExternalBlockFactory.new().create(entry, PACKAGE_ROOT)
	_check(creation.block != null and not creation.has_errors(), "The public external factory creates FPrint.")
	return creation.block


func _test_defaults_and_independent_instances(first: FlowBlock, second: FlowBlock) -> void:
	_check(first != null and first is FlowOutputBlock, "FPrint instances satisfy the FlowOutputBlock contract.")
	_check(second != null and second is FlowOutputBlock, "A second FPrint instance satisfies the output contract.")
	if first == null or second == null:
		return
	_check(FlowId.is_valid(first.get_internal_id()) and FlowId.is_valid(second.get_internal_id()),
		"FPrint instances receive valid FlowIds.")
	_check(first.get_internal_id() != second.get_internal_id(),
		"Two FPrint factory creations receive independent FlowIds.")
	_check(first.display_name == "FPrint" and second.display_name == "FPrint",
		"Factory-created FPrint instances receive the manifest display name.")
	_check(_value(first, &"prefix").is_empty() and _value(first, &"message").is_empty() \
			and _value(first, &"suffix").is_empty() and first.get(&"document") == null,
		"FPrint defaults retain empty legacy strings and a null structured document.")
	_check(_value(second, &"prefix").is_empty() and _value(second, &"message").is_empty() \
			and _value(second, &"suffix").is_empty() and second.get(&"document") == null,
		"A second FPrint keeps independent exact defaults including null document state.")
	var descriptor_result: FlowBlockPropertyCatalogResult = FlowBlockPropertyCatalog.describe(
		first,
		PACKAGE_ROOT,
		"fprint"
	)
	var document_descriptor: FlowBlockPropertyDescriptor = _descriptor(descriptor_result, &"document")
	_check(document_descriptor != null \
			and document_descriptor.model_type == TYPE_OBJECT \
			and document_descriptor.presentation_kind == FlowBlockPropertyDescriptor.PRESENTATION_STRUCTURED_DOCUMENT \
			and document_descriptor.current_value == null,
		"The generic catalog describes the optional null structured-document property without a package-specific editor.")
	first.set(&"message", "first")
	second.set(&"message", "second")
	_check(String(first.get(&"message")) == "first" and String(second.get(&"message")) == "second",
		"Two FPrint instances keep independent exported values.")


func _test_duplication(source: FlowBlock) -> void:
	if source == null:
		return
	source.set(&"prefix", "[")
	source.set(&"message", "duplicated")
	source.set(&"suffix", "]")
	source.set(&"document", _make_document("duplicated document", 7))
	var copy: FlowBlock = source.duplicate_with_new_id()
	_check(copy != null and copy != source, "FPrint duplication creates an independent block.")
	if copy == null:
		return
	_check(FlowId.is_valid(copy.get_internal_id()) and copy.get_internal_id() != source.get_internal_id(),
		"FPrint duplication creates a new FlowId.")
	_check(_value(copy, &"prefix") == "[" and _value(copy, &"message") == "duplicated" \
			and _value(copy, &"suffix") == "]", "FPrint duplication preserves all legacy exported values.")
	var source_document: FlowStructuredDocument = source.get(&"document") as FlowStructuredDocument
	var copied_document: FlowStructuredDocument = copy.get(&"document") as FlowStructuredDocument
	var present_descriptor: FlowBlockPropertyDescriptor = _descriptor(
		FlowBlockPropertyCatalog.describe(source, PACKAGE_ROOT, "fprint"),
		&"document"
	)
	_check(present_descriptor != null and present_descriptor.current_value is FlowStructuredDocument \
			and present_descriptor.presentation_kind == FlowBlockPropertyDescriptor.PRESENTATION_STRUCTURED_DOCUMENT,
		"The generic catalog describes a present structured document with its reusable presentation kind.")
	_check(copied_document != null and copied_document != source_document,
		"FPrint duplication deep-copies the optional structured document.")
	if source_document != null and copied_document != null:
		_check(copied_document.segments.size() == 3 and copied_document.segments[0] is FlowTextSegment \
				and copied_document.segments[1] == null and copied_document.segments[2] is FlowLiteralValueSegment,
			"FPrint duplication preserves structured segment types and order.")
		_check(copied_document.segments[0].get_segment_id() != source_document.segments[0].get_segment_id() \
				and copied_document.segments[2].get_segment_id() != source_document.segments[2].get_segment_id(),
			"FPrint duplication gives nested structured segments fresh IDs.")
		_check((copied_document.segments[0] as FlowTextSegment).text == "duplicated document" \
				and (copied_document.segments[2] as FlowLiteralValueSegment).value == 7,
			"FPrint duplication preserves structured values without sharing mutable segments.")
	var invalid_document: FlowStructuredDocument = FlowStructuredDocument.new()
	var invalid_literal: FlowLiteralValueSegment = FlowLiteralValueSegment.new(
		FlowLiteralValueSegment.TYPE_INT,
		"not an int"
	)
	invalid_document.segments = [invalid_literal]
	source.set(&"document", invalid_document)
	_check((source as FlowOutputBlock).get_output_message() == "[]",
		"An invalid present document produces empty rendered central content rather than falling back to Message.")
	source.set(&"document", source_document)
	copy.set(&"message", "copy only")
	_check(String(source.get(&"message")) == "duplicated" \
			and (source.get(&"document") as FlowStructuredDocument).segments[0].text == "duplicated document",
		"FPrint duplicate edits do not mutate the source.")

	var graph: FlowGraph = _graph_with_block(source)
	_check(not FlowGraphValidator.validate(graph).has_errors(), "FPrint graph fixture satisfies the public validator.")
	var graph_copy: FlowGraph = graph.duplicate_with_new_ids()
	_check(graph_copy != null and graph_copy.get_internal_id() != graph.get_internal_id(),
		"FPrint graph duplication creates a new graph identity.")
	if graph_copy == null or graph_copy.processes.is_empty() or graph_copy.processes[0] == null:
		return
	var copied_block: FlowBlock = graph_copy.processes[0].blocks[0]
	_check(copied_block != null and copied_block.get_internal_id() != source.get_internal_id(),
		"Graph duplication gives the contained FPrint a new FlowId.")
	_check(copied_block != null and _value(copied_block, &"message") == "duplicated",
			"Graph duplication preserves FPrint legacy values.")
	if copied_block != null:
		var copied_graph_document: FlowStructuredDocument = copied_block.get(&"document") as FlowStructuredDocument
		_check(copied_graph_document != null and copied_graph_document.segments.size() == 3 \
				and copied_graph_document.segments[1] == null \
				and copied_graph_document.segments[0].get_segment_id() != source_document.segments[0].get_segment_id(),
			"Graph duplication preserves the structured document with independent nested IDs.")


func _test_persistence(source: FlowBlock) -> void:
	if source == null:
		return
	_check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT)) == OK,
		"Create the scoped FPrint persistence directory.")
	var graph: FlowGraph = _graph_with_block(source)
	_check(ResourceSaver.save(graph, GRAPH_PATH) == OK, "ResourceSaver persists the FPrint FlowGraph.")
	var loaded_graph: FlowGraph = ResourceLoader.load(
		GRAPH_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as FlowGraph
	_check(loaded_graph != null, "ResourceLoader reloads the FPrint FlowGraph.")
	if loaded_graph != null:
		var loaded_block: FlowBlock = loaded_graph.processes[0].blocks[0]
		_check(loaded_block.get_script().resource_path == FPRINT_SCRIPT_PATH,
			"ResourceSaver reload preserves the FPrint script resource.")
		_check(_value(loaded_block, &"prefix") == "[" and _value(loaded_block, &"message") == "duplicated" \
				and _value(loaded_block, &"suffix") == "]", "ResourceSaver reload preserves FPrint legacy values.")
		_check(_document_signature(loaded_block.get(&"document") as FlowStructuredDocument) == _document_signature(source.get(&"document") as FlowStructuredDocument),
			"ResourceSaver reload preserves the structured document's classes, order, IDs, values, and Variant types.")

	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	var packed: PackedScene = PackedScene.new()
	_check(packed.pack(controller) == OK, "PackedScene packs a controller containing FPrint.")
	controller.free()
	_check(ResourceSaver.save(packed, SCENE_PATH) == OK, "ResourceSaver persists the FPrint PackedScene.")
	var loaded_scene: PackedScene = ResourceLoader.load(
		SCENE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as PackedScene
	_check(loaded_scene != null, "ResourceLoader reloads the FPrint PackedScene.")
	if loaded_scene == null:
		return
	var loaded_controller: PVController = loaded_scene.instantiate() as PVController
	_check(loaded_controller != null and loaded_controller.flow_graph != null,
		"PackedScene reload preserves the FPrint controller graph.")
	if loaded_controller != null and loaded_controller.flow_graph != null:
		var loaded_block: FlowBlock = loaded_controller.flow_graph.processes[0].blocks[0]
		_check(loaded_block.get_internal_id() == source.get_internal_id(),
			"PackedScene reload preserves the FPrint FlowId.")
		_check(loaded_block.get_script().resource_path == FPRINT_SCRIPT_PATH,
			"PackedScene reload preserves the concrete FPrint script.")
		_check(_value(loaded_block, &"prefix") == "[" and _value(loaded_block, &"message") == "duplicated" \
				and _value(loaded_block, &"suffix") == "]", "PackedScene reload preserves FPrint legacy values.")
		_check(_document_signature(loaded_block.get(&"document") as FlowStructuredDocument) == _document_signature(source.get(&"document") as FlowStructuredDocument),
			"PackedScene reload preserves the structured document's classes, order, IDs, values, and Variant types.")
		loaded_controller.free()


func _test_static_boundaries() -> void:
	var package_source: String = FileAccess.get_file_as_string(FPRINT_SCRIPT_PATH)
	_check(package_source.contains("extends FlowOutputBlock"), "FPrint source uses the public FlowOutputBlock base.")
	_check(package_source.contains("func get_output_message() -> String"),
		"FPrint source implements the public output-message method.")
	_check(package_source.contains("return prefix + central_content + suffix"),
		"FPrint source composes prefix, selected central content, and suffix exactly.")
	var forbidden_package_tokens: Array[String] = [
		"flujo-block-builder", "skill", "editorinterface", "editorplugin", "editorundoredo", "resourcepath",
		"flowprocess", "flowtimerdefinition", "statemachine", "if container", "if block is", "timer", "while",
		"for", "res://", "/home/",
	]
	var lower_source: String = package_source.to_lower()
	for token: String in forbidden_package_tokens:
		_check(not lower_source.contains(token), "FPrint source has no forbidden runtime/container token: %s" % token)

	var production_sources: Array[String] = []
	_collect_gd_scripts("res://addons/vp_flujo", production_sources)
	for path: String in production_sources:
		var source: String = FileAccess.get_file_as_string(path).to_lower()
		_check(not source.contains("fprint") and not source.contains("mercury.fprint"),
			"Production core has no FPrint-specific branch or registration: %s" % path)


func _graph_with_block(block: FlowBlock) -> FlowGraph:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var process: FlowProcess = FlowProcess.new()
	process.display_name = "FPrint Process"
	process.blocks = [block]
	graph.processes = [process]
	return graph


func _manifest_for(
		discovery: FlowPackageManifestDiscoveryResult,
		package_id: String
) -> FlowPackageManifest:
	for manifest: FlowPackageManifest in discovery.manifests:
		if manifest.package_id == package_id:
			return manifest
	return null


func _value(block: FlowBlock, property: StringName) -> String:
	return String(block.get(property)) if block != null else ""


func _make_document(text_value: String, integer_value: int) -> FlowStructuredDocument:
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	var text: FlowTextSegment = FlowTextSegment.new()
	text.text = text_value
	var literal: FlowLiteralValueSegment = FlowLiteralValueSegment.new(
		FlowLiteralValueSegment.TYPE_INT,
		integer_value
	)
	document.segments = [text, null, literal]
	return document


func _document_signature(document: FlowStructuredDocument) -> Array[String]:
	var signature: Array[String] = []
	if document == null:
		return signature
	for segment: FlowDocumentSegment in document.segments:
		if segment == null:
			signature.append("null")
		elif segment is FlowTextSegment:
			signature.append("text|%s|%s" % [segment.get_segment_id(), (segment as FlowTextSegment).text])
		elif segment is FlowLiteralValueSegment:
			var literal: FlowLiteralValueSegment = segment as FlowLiteralValueSegment
			signature.append("literal|%s|%d|%s|%s" % [
				literal.get_segment_id(),
				literal.value_type,
				str(literal.value),
				str(typeof(literal.value)),
			])
	return signature


func _descriptor(
		result: FlowBlockPropertyCatalogResult,
		property_name: StringName
) -> FlowBlockPropertyDescriptor:
	if result == null:
		return null
	for descriptor: FlowBlockPropertyDescriptor in result.descriptors:
		if descriptor.property_name == property_name:
			return descriptor
	return null


func _keys_are_exact(data: Dictionary, expected: Array[String]) -> bool:
	if data.size() != expected.size():
		return false
	for key: String in expected:
		if not data.has(key):
			return false
	return true


func _collect_gd_scripts(path: String, result: Array[String]) -> void:
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return
	for file_name: String in directory.get_files():
		if file_name.ends_with(".gd"):
			result.append(path.path_join(file_name))
	for directory_name: String in directory.get_directories():
		_collect_gd_scripts(path.path_join(directory_name), result)


func _cleanup() -> void:
	var absolute_root: String = ProjectSettings.globalize_path(TEMP_ROOT)
	if not DirAccess.dir_exists_absolute(absolute_root):
		return
	var directory: DirAccess = DirAccess.open(absolute_root)
	if directory == null:
		return
	for file_name: String in directory.get_files():
		DirAccess.remove_absolute(absolute_root.path_join(file_name))
	DirAccess.remove_absolute(absolute_root)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_failures.append(message)
		push_error(message)
	return condition


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] FPrint package test passed")
	else:
		for failure: String in _failures:
			push_error(failure)
	get_tree().quit(0 if _failures.is_empty() else 1)
