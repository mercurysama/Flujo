extends Node


const TEMP_ROOT: String = "res://.godot/flujo_tests/node_property_lot_04"
const DOC_PATH: String = TEMP_ROOT + "/node_property_document.tres"

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_fallback_path_resolution()
	_test_requirement_resolution()
	_test_resolution_failures()
	_test_graph_validation()
	_test_duplication()
	_test_persistence()
	_cleanup()
	_finish()


func _test_fallback_path_resolution() -> void:
	var root: Node = Node.new()
	root.name = "Root"
	var target: Node2D = Node2D.new()
	target.name = "Target"
	target.position = Vector2(12.5, -3.0)
	root.add_child(target)

	var source: FlowNodePropertyRefValueSource = FlowNodePropertyRefValueSource.new(
		"",
		NodePath("Target"),
		&"Target",
		&"position",
		Variant.Type.TYPE_VECTOR2
	)
	var context: FlowValueResolutionContext = FlowValueResolutionContext.new(
		null,
		null,
		root
	)
	var result: FlowValueResult = source.resolve(context)
	_check_result(
		result,
		Vector2(12.5, -3.0),
		Variant.Type.TYPE_VECTOR2,
		"Fallback scene-root NodePath resolves the exact property value."
	)

	target.position = Vector2(-4.0, 8.25)
	result = source.resolve(context)
	_check_result(
		result,
		Vector2(-4.0, 8.25),
		Variant.Type.TYPE_VECTOR2,
		"NodePropertyRef reads the live property value on every resolution."
	)
	root.free()


func _test_requirement_resolution() -> void:
	var controller: PVController = PVController.new()
	controller.name = "Controller"
	var target: Node2D = Node2D.new()
	target.name = "Target"
	target.position = Vector2(5.0, 9.0)
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

	var source: FlowNodePropertyRefValueSource = FlowNodePropertyRefValueSource.new(
		requirement.get_internal_id(),
		NodePath("MissingFallback"),
		&"Target",
		&"position",
		Variant.Type.TYPE_VECTOR2
	)
	var context: FlowValueResolutionContext = FlowValueResolutionContext.new(
		graph,
		controller,
		controller
	)
	_check_result(
		source.resolve(context),
		Vector2(5.0, 9.0),
		Variant.Type.TYPE_VECTOR2,
		"Requirement binding has priority over the fallback NodePath."
	)

	var validation: FlowValidationResult = FlowValidationResult.new()
	source.validate_against_graph(validation, "source", graph)
	_check(
		not validation.has_errors(),
		"Requirement-backed source validates against the owning FlowGraph."
	)
	controller.free()


func _test_resolution_failures() -> void:
	var root: Node = Node.new()
	root.name = "Root"
	var target: Node2D = Node2D.new()
	target.name = "Target"
	root.add_child(target)

	var missing_property: FlowNodePropertyRefValueSource = FlowNodePropertyRefValueSource.new(
		"",
		NodePath("Target"),
		&"Target",
		&"not_a_property",
		Variant.Type.TYPE_INT
	)
	var context: FlowValueResolutionContext = FlowValueResolutionContext.new(
		null,
		null,
		root
	)
	var missing_result: FlowValueResult = missing_property.resolve(context)
	_check(
		not missing_result.success
			and missing_result.diagnostic != null
			and missing_result.diagnostic.code == FlowDiagnostic.CODE_NODE_PROPERTY_MISSING,
		"Missing property returns a structured diagnostic."
	)

	var wrong_type: FlowNodePropertyRefValueSource = FlowNodePropertyRefValueSource.new(
		"",
		NodePath("Target"),
		&"Target",
		&"position",
		Variant.Type.TYPE_FLOAT
	)
	var type_result: FlowValueResult = wrong_type.resolve(context)
	_check(
		not type_result.success
			and type_result.diagnostic != null
			and type_result.diagnostic.code == FlowDiagnostic.CODE_NODE_PROPERTY_TYPE_MISMATCH,
		"Authored property type mismatch returns a structured diagnostic."
	)

	var no_context: FlowValueResult = wrong_type.resolve()
	_check(
		not no_context.success
			and no_context.diagnostic != null
			and no_context.diagnostic.code == FlowDiagnostic.CODE_NODE_PROPERTY_CONTEXT_MISSING,
		"NodePropertyRef rejects resolution without scene context."
	)
	root.free()


func _test_graph_validation() -> void:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_4
	graph.constructor = FlowConstructorDefinition.new()

	var source: FlowNodePropertyRefValueSource = FlowNodePropertyRefValueSource.new(
		FlowId.create(),
		NodePath("Target"),
		&"Target",
		&"position",
		Variant.Type.TYPE_VECTOR2
	)
	var result: FlowValidationResult = FlowValidationResult.new()
	source.validate_against_graph(result, "source", graph)
	_check(
		_has_code(result, FlowDiagnostic.CODE_NODE_PROPERTY_REQUIREMENT_MISSING),
		"Missing requirement_id is reported against the active graph."
	)


func _test_duplication() -> void:
	var requirement_id: String = FlowId.create()
	var source: FlowNodePropertyRefValueSource = FlowNodePropertyRefValueSource.new(
		requirement_id,
		NodePath("Target"),
		&"Target",
		&"position",
		Variant.Type.TYPE_VECTOR2
	)
	var copy: FlowNodePropertyRefValueSource = 		source.duplicate_with_new_id() as FlowNodePropertyRefValueSource
	_check(
		copy != null
			and copy.source_id != source.source_id
			and copy.requirement_id == requirement_id
			and copy.node_path == NodePath("Target")
			and copy.property_name == &"position"
			and copy.declared_value_type == Variant.Type.TYPE_VECTOR2,
		"Duplicate changes owned source identity but preserves external scene semantics."
	)


func _test_persistence() -> void:
	var source: FlowNodePropertyRefValueSource = FlowNodePropertyRefValueSource.new(
		"",
		NodePath("Target"),
		&"Target",
		&"position",
		Variant.Type.TYPE_VECTOR2
	)
	var segment: FlowNodePropertyRefSegment = FlowNodePropertyRefSegment.new(source)
	segment.slot_id = "scene_value"
	segment.slot_kind = FlowChipSegment.SLOT_KIND_VARIADIC
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	document.segments = [segment]

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT))
	_check(
		ResourceSaver.save(document, DOC_PATH) == OK,
		"NodeProperty document saves through ResourceSaver."
	)
	var loaded: FlowStructuredDocument = ResourceLoader.load(
		DOC_PATH,
		"",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as FlowStructuredDocument
	_check(
		loaded != null
			and loaded.segments.size() == 1
			and loaded.segments[0] is FlowNodePropertyRefSegment,
		"NodeProperty segment survives ResourceLoader."
	)
	if loaded == null or loaded.segments.is_empty():
		return
	var loaded_segment: FlowNodePropertyRefSegment = 		loaded.segments[0] as FlowNodePropertyRefSegment
	var loaded_source: FlowNodePropertyRefValueSource = 		loaded_segment.get_value_source() as FlowNodePropertyRefValueSource
	_check(
		loaded_segment.segment_id == segment.segment_id
			and loaded_segment.slot_id == "scene_value"
			and loaded_source != null
			and loaded_source.source_id == source.source_id
			and loaded_source.node_path == NodePath("Target")
			and loaded_source.node_name_hint == &"Target"
			and loaded_source.property_name == &"position"
			and loaded_source.declared_value_type == Variant.Type.TYPE_VECTOR2,
		"Persistence preserves IDs, locator, property and exact Variant.Type."
	)


func _has_code(result: FlowValidationResult, code: StringName) -> bool:
	for diagnostic: FlowDiagnostic in result.diagnostics:
		if diagnostic != null and diagnostic.code == code:
			return true
	return false


func _check_result(
		result: FlowValueResult,
		expected_value: Variant,
		expected_type: Variant.Type,
		message: String
) -> void:
	_check(
		result != null
			and result.success
			and result.value_type == expected_type
			and typeof(result.value) == expected_type
			and result.value == expected_value,
		message
	)


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
	push_error("[Flujo] NodeProperty Lot 04 check failed: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] NodeProperty Lot 04 model test passed")
	else:
		push_error(
			"[Flujo] NodeProperty Lot 04 model test failed: %d failures" 				% _failures.size()
		)
	get_tree().quit(0 if _failures.is_empty() else 1)
