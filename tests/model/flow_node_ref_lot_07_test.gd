extends Node


const TEMP_ROOT: String = "res://.godot/flujo_tests/node_ref_lot_07"
const DOC_PATH: String = TEMP_ROOT + "/node_ref_document.tres"

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_object_boundary()
	_test_unbound_required_placeholder()
	_test_fallback_path_resolution()
	_test_requirement_resolution()
	_test_resolution_failures()
	_test_graph_validation()
	_test_duplication()
	_test_persistence()
	_cleanup()
	_finish()


func _test_object_boundary() -> void:
	_check(
		not FlowLiteralValueSource.is_allowed_type(Variant.Type.TYPE_OBJECT),
		"TYPE_OBJECT remains excluded from LiteralValueSource."
	)
	_check(
		FlowChipTypeDescriptor.variant_type_display_name(
			Variant.Type.TYPE_OBJECT
		) == "Object",
		"Shared type descriptor exposes TYPE_OBJECT without making it a Literal."
	)


func _test_unbound_required_placeholder() -> void:
	var schema: FlowChipFieldSchema = FlowChipFieldSchema.new()
	schema.mode = FlowChipFieldSchema.Mode.FIXED
	schema.text_mode = FlowChipFieldSchema.TextMode.RUNTIME_CONTENT
	schema.accepted_value_types = [Variant.Type.TYPE_OBJECT]
	schema.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_NODE_REF]

	var slot: FlowChipSlotDefinition = FlowChipSlotDefinition.new(
		"target",
		"Target Node",
		true
	)
	slot.accepted_value_types = [Variant.Type.TYPE_OBJECT]
	slot.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_NODE_REF]
	slot.initial_value_source = FlowNodeRefValueSource.placeholder(&"Node")
	slot.allow_delete = false
	slot.min_count = 1
	slot.max_count = 1
	schema.slots = [slot]
	schema.add_text_part("Target: ")
	schema.add_slot_part("target")

	var schema_validation: FlowValidationResult = schema.validate_structure()
	_check(
		not schema_validation.has_errors(),
		"Required Node slot accepts an unbound NodeRef prototype."
	)

	var creation: FlowChipFieldCreationResult = FlowChipFieldFactory.new().create(schema)
	_check(
		creation.document != null
			and creation.document.segments.size() == 2
			and creation.document.segments[1] is FlowNodeRefSegment,
		"Factory materializes the required unbound Node Tok."
	)
	if creation.document == null or creation.document.segments.size() < 2:
		return
	var segment: FlowNodeRefSegment = creation.document.segments[1] as FlowNodeRefSegment
	var source: FlowNodeRefValueSource = 		segment.get_value_source() as FlowNodeRefValueSource
	_check(
		source != null
			and source.is_valid()
			and not source.has_locator()
			and source.get_value_type() == Variant.Type.TYPE_OBJECT,
		"Unbound NodeRef is structurally valid and explicitly unresolved."
	)
	var unresolved: FlowValueResult = source.resolve()
	_check(
		not unresolved.success
			and unresolved.diagnostic != null
			and unresolved.diagnostic.code == FlowDiagnostic.CODE_NODE_REF_LOCATOR_MISSING,
		"Unbound placeholder fails only at runtime resolution."
	)


func _test_fallback_path_resolution() -> void:
	var root: Node = Node.new()
	root.name = "Root"
	var target: Node2D = Node2D.new()
	target.name = "Target"
	root.add_child(target)

	var source: FlowNodeRefValueSource = FlowNodeRefValueSource.new(
		"",
		NodePath("Target"),
		&"Target",
		&"Node2D"
	)
	var context: FlowValueResolutionContext = FlowValueResolutionContext.new(
		null,
		null,
		root
	)
	var result: FlowValueResult = source.resolve(context)
	_check(
		result != null
			and result.success
			and result.value_type == Variant.Type.TYPE_OBJECT
			and result.value == target,
		"NodeRef resolves the live Node through scene-root-relative NodePath."
	)
	root.free()


func _test_requirement_resolution() -> void:
	var controller: PVController = PVController.new()
	controller.name = "Controller"
	var target: Node2D = Node2D.new()
	target.name = "Target"
	controller.add_child(target)

	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_4
	graph.constructor = FlowConstructorDefinition.new()
	var requirement: FlowRequiredNodeDefinition = FlowRequiredNodeDefinition.new()
	requirement.display_name = "Target"
	requirement.expected_node_name = &"Target"
	requirement.required_class_name = &"Node2D"
	graph.constructor.requirements = [requirement]
	controller.flow_graph = graph
	controller.requirement_bindings = {
		requirement.get_internal_id(): NodePath("Target"),
	}

	var source: FlowNodeRefValueSource = FlowNodeRefValueSource.new(
		requirement.get_internal_id(),
		NodePath("MissingFallback"),
		&"Target",
		&"Node2D"
	)
	var context: FlowValueResolutionContext = FlowValueResolutionContext.new(
		graph,
		controller,
		controller
	)
	var result: FlowValueResult = source.resolve(context)
	_check(
		result.success and result.value == target,
		"Requirement binding has priority over NodePath fallback."
	)
	var validation: FlowValidationResult = FlowValidationResult.new()
	source.validate_against_graph(validation, "source", graph)
	_check(
		not validation.has_errors(),
		"Requirement-backed NodeRef validates against its FlowGraph."
	)
	controller.free()


func _test_resolution_failures() -> void:
	var root: Node = Node.new()
	root.name = "Root"
	var target: Node2D = Node2D.new()
	target.name = "Target"
	root.add_child(target)
	var context: FlowValueResolutionContext = FlowValueResolutionContext.new(
		null,
		null,
		root
	)

	var missing: FlowNodeRefValueSource = FlowNodeRefValueSource.new(
		"",
		NodePath("Missing"),
		&"Missing",
		&"Node"
	)
	var missing_result: FlowValueResult = missing.resolve(context)
	_check(
		not missing_result.success
			and missing_result.diagnostic != null
			and missing_result.diagnostic.code == FlowDiagnostic.CODE_NODE_REF_NODE_MISSING,
		"Missing scene Node returns a structured NodeRef diagnostic."
	)

	var wrong_class: FlowNodeRefValueSource = FlowNodeRefValueSource.new(
		"",
		NodePath("Target"),
		&"Target",
		&"Sprite2D"
	)
	var class_result: FlowValueResult = wrong_class.resolve(context)
	_check(
		not class_result.success
			and class_result.diagnostic != null
			and class_result.diagnostic.code == FlowDiagnostic.CODE_NODE_REF_CLASS_MISMATCH,
		"Resolved Node class mismatch is explicit."
	)

	var no_context: FlowValueResult = FlowNodeRefValueSource.new(
		"",
		NodePath("Target"),
		&"Target",
		&"Node2D"
	).resolve()
	_check(
		not no_context.success
			and no_context.diagnostic != null
			and no_context.diagnostic.code == FlowDiagnostic.CODE_NODE_REF_CONTEXT_MISSING,
		"Bound NodeRef requires scene resolution context."
	)
	root.free()


func _test_graph_validation() -> void:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_4
	graph.constructor = FlowConstructorDefinition.new()
	var source: FlowNodeRefValueSource = FlowNodeRefValueSource.new(
		FlowId.create(),
		NodePath("Target"),
		&"Target",
		&"Node2D"
	)
	var result: FlowValidationResult = FlowValidationResult.new()
	source.validate_against_graph(result, "source", graph)
	_check(
		_has_code(result, FlowDiagnostic.CODE_NODE_REF_REQUIREMENT_MISSING),
		"Missing NodeRef requirement_id is diagnosed against the graph."
	)


func _test_duplication() -> void:
	var requirement_id: String = FlowId.create()
	var source: FlowNodeRefValueSource = FlowNodeRefValueSource.new(
		requirement_id,
		NodePath("Target"),
		&"Target",
		&"Node2D"
	)
	var copy: FlowNodeRefValueSource = 		source.duplicate_with_new_id() as FlowNodeRefValueSource
	_check(
		copy != null
			and copy.source_id != source.source_id
			and copy.requirement_id == requirement_id
			and copy.node_path == NodePath("Target")
			and copy.node_class_hint == &"Node2D",
		"NodeRef duplication renews owned identity and preserves scene semantics."
	)


func _test_persistence() -> void:
	var source: FlowNodeRefValueSource = FlowNodeRefValueSource.new(
		"",
		NodePath("Target"),
		&"Target",
		&"Node2D"
	)
	var segment: FlowNodeRefSegment = FlowNodeRefSegment.new(source)
	segment.slot_id = "target"
	segment.slot_kind = FlowChipSegment.SLOT_KIND_NAMED
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	document.segments = [segment]
	_check(
		not FlowStructuredDocumentValidator.validate(document).has_errors(),
		"StructuredDocumentValidator recognizes a bound NodeRefSegment."
	)

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT))
	_check(
		ResourceSaver.save(document, DOC_PATH) == OK,
		"NodeRef document saves."
	)
	var loaded: FlowStructuredDocument = ResourceLoader.load(
		DOC_PATH,
		"",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as FlowStructuredDocument
	_check(
		loaded != null
			and loaded.segments.size() == 1
			and loaded.segments[0] is FlowNodeRefSegment,
		"NodeRef segment survives ResourceLoader."
	)
	if loaded == null or loaded.segments.is_empty():
		return
	var loaded_segment: FlowNodeRefSegment = loaded.segments[0] as FlowNodeRefSegment
	var loaded_source: FlowNodeRefValueSource = 		loaded_segment.get_value_source() as FlowNodeRefValueSource
	_check(
		loaded_segment.segment_id == segment.segment_id
			and loaded_segment.slot_id == "target"
			and loaded_source != null
			and loaded_source.source_id == source.source_id
			and loaded_source.node_path == NodePath("Target")
			and loaded_source.node_name_hint == &"Target"
			and loaded_source.node_class_hint == &"Node2D",
		"Persistence preserves NodeRef identity, locator, name and class hint."
	)


func _has_code(result: FlowValidationResult, code: StringName) -> bool:
	for diagnostic: FlowDiagnostic in result.diagnostics:
		if diagnostic != null and diagnostic.code == code:
			return true
	return false


func _cleanup() -> void:
	var absolute_path: String = ProjectSettings.globalize_path(DOC_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
	var absolute_root: String = ProjectSettings.globalize_path(TEMP_ROOT)
	if DirAccess.dir_exists_absolute(absolute_root):
		DirAccess.remove_absolute(absolute_root)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("[Flujo] NodeRef Lot 07 check failed: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] NodeRef Lot 07 model test passed")
	else:
		push_error(
			"[Flujo] NodeRef Lot 07 model test failed: %d failures" % _failures.size()
		)
	get_tree().quit(0 if _failures.is_empty() else 1)
