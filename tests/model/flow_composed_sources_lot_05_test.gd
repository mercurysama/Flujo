extends Node


const TEMP_ROOT: String = "res://.godot/flujo_tests/composed_sources_lot_05"
const DOC_PATH: String = TEMP_ROOT + "/composed_document.tres"

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_condition_with_node_property()
	_test_operation_with_node_property()
	_test_strict_mismatch()
	_test_duplication()
	_test_persistence()
	_cleanup()
	_finish()


func _scene_fixture() -> Dictionary:
	var root: Node = Node.new()
	root.name = "Root"
	var target: Node2D = Node2D.new()
	target.name = "Target"
	target.z_index = 3
	target.visible = true
	target.position = Vector2(4.0, 6.0)
	root.add_child(target)
	return {"root": root, "target": target}


func _test_condition_with_node_property() -> void:
	var fixture: Dictionary = _scene_fixture()
	var root: Node = fixture["root"]
	var target: Node2D = fixture["target"]
	var z_index: FlowNodePropertyRefValueSource = FlowNodePropertyRefValueSource.new(
		"",
		NodePath("Target"),
		&"Target",
		&"z_index",
		Variant.Type.TYPE_INT
	)
	var visible: FlowNodePropertyRefValueSource = FlowNodePropertyRefValueSource.new(
		"",
		NodePath("Target"),
		&"Target",
		&"visible",
		Variant.Type.TYPE_BOOL
	)
	var condition: FlowConditionValueSource = FlowConditionValueSource.new(
		[
			FlowConditionComparison.new(
				FlowConditionOperatorCatalog.OPERATOR_GREATER_THAN,
				z_index,
				FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 0)
			),
			FlowConditionComparison.new(
				FlowConditionOperatorCatalog.OPERATOR_EQUAL,
				visible,
				FlowLiteralValueSource.new(Variant.Type.TYPE_BOOL, true)
			),
		],
		[FlowConditionOperatorCatalog.CONNECTOR_AND]
	)
	_check(condition.is_valid(), "Condition accepts NodePropertyRef operands structurally.")
	var context: FlowValueResolutionContext = FlowValueResolutionContext.new(
		null,
		null,
		root
	)
	_check_result(
		condition.resolve(context),
		true,
		Variant.Type.TYPE_BOOL,
		"$Target.z_index > 0 AND $Target.visible == true resolves true."
	)
	target.visible = false
	_check_result(
		condition.resolve(context),
		false,
		Variant.Type.TYPE_BOOL,
		"Condition re-reads live Node properties on every resolve."
	)
	_check(
		condition.get_preview().contains("$Target.z_index")
			and condition.get_preview().contains("$Target.visible"),
		"Condition preview exposes nested NodeProperty Toks."
	)
	root.free()


func _test_operation_with_node_property() -> void:
	var fixture: Dictionary = _scene_fixture()
	var root: Node = fixture["root"]
	var position: FlowNodePropertyRefValueSource = FlowNodePropertyRefValueSource.new(
		"",
		NodePath("Target"),
		&"Target",
		&"position",
		Variant.Type.TYPE_VECTOR2
	)
	var operation: FlowOperationValueSource = FlowOperationValueSource.new(
		FlowOperationOperatorCatalog.OPERATOR_ADD,
		[
			position,
			FlowLiteralValueSource.new(
				Variant.Type.TYPE_VECTOR2,
				Vector2(1.0, 2.0)
			),
		]
	)
	_check(operation.is_valid(), "Operation accepts NodePropertyRef operands structurally.")
	var context: FlowValueResolutionContext = FlowValueResolutionContext.new(
		null,
		null,
		root
	)
	_check_result(
		operation.resolve(context),
		Vector2(5.0, 8.0),
		Variant.Type.TYPE_VECTOR2,
		"$Target.position + Vector2(1, 2) resolves."
	)
	_check(
		operation.get_preview().begins_with("$Target.position +"),
		"Operation preview exposes the nested NodeProperty source."
	)
	root.free()


func _test_strict_mismatch() -> void:
	var position: FlowNodePropertyRefValueSource = FlowNodePropertyRefValueSource.new(
		"",
		NodePath("Target"),
		&"Target",
		&"position",
		Variant.Type.TYPE_VECTOR2
	)
	var invalid: FlowOperationValueSource = FlowOperationValueSource.new(
		FlowOperationOperatorCatalog.OPERATOR_ADD,
		[
			position,
			FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 1),
		]
	)
	_check(
		not invalid.is_valid(),
		"NodeProperty composition does not bypass exact Operation signatures."
	)


func _test_duplication() -> void:
	var requirement_id: String = FlowId.create()
	var node_source: FlowNodePropertyRefValueSource = FlowNodePropertyRefValueSource.new(
		requirement_id,
		NodePath("Target"),
		&"Target",
		&"z_index",
		Variant.Type.TYPE_INT
	)
	var condition: FlowConditionValueSource = FlowConditionValueSource.new(
		[
			FlowConditionComparison.new(
				FlowConditionOperatorCatalog.OPERATOR_GREATER_THAN,
				node_source,
				FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 0)
			)
		],
		[]
	)
	var copy: FlowConditionValueSource = 		condition.duplicate_with_new_id() as FlowConditionValueSource
	var copied_node: FlowNodePropertyRefValueSource = 		copy.comparisons[0].left_source as FlowNodePropertyRefValueSource
	_check(
		copied_node != null
			and copied_node.source_id != node_source.source_id
			and copied_node.requirement_id == requirement_id,
		"Nested duplication renews owned source IDs and preserves Requirement identity."
	)


func _test_persistence() -> void:
	var node_source: FlowNodePropertyRefValueSource = FlowNodePropertyRefValueSource.new(
		"",
		NodePath("Target"),
		&"Target",
		&"position",
		Variant.Type.TYPE_VECTOR2
	)
	var operation: FlowOperationValueSource = FlowOperationValueSource.new(
		FlowOperationOperatorCatalog.OPERATOR_ADD,
		[
			node_source,
			FlowLiteralValueSource.new(
				Variant.Type.TYPE_VECTOR2,
				Vector2(2.0, 3.0)
			),
		]
	)
	var operation_segment: FlowOperationSegment = FlowOperationSegment.new(operation)
	var condition_source: FlowConditionValueSource = FlowConditionValueSource.new(
		[
			FlowConditionComparison.new(
				FlowConditionOperatorCatalog.OPERATOR_GREATER_THAN,
				FlowNodePropertyRefValueSource.new(
					"",
					NodePath("Target"),
					&"Target",
					&"z_index",
					Variant.Type.TYPE_INT
				),
				FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 0)
			)
		],
		[]
	)
	var condition_segment: FlowConditionSegment = FlowConditionSegment.new(condition_source)
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	document.segments = [operation_segment, condition_segment]

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT))
	_check(
		ResourceSaver.save(document, DOC_PATH) == OK,
		"Composed Condition/Operation document saves."
	)
	var loaded: FlowStructuredDocument = ResourceLoader.load(
		DOC_PATH,
		"",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as FlowStructuredDocument
	_check(
		loaded != null
			and loaded.segments.size() == 2
			and loaded.segments[0] is FlowOperationSegment
			and loaded.segments[1] is FlowConditionSegment,
		"Composed sources survive ResourceLoader."
	)
	if loaded != null and loaded.segments.size() == 2:
		var loaded_operation: FlowOperationValueSource = 			(loaded.segments[0] as FlowOperationSegment).get_value_source() 			as FlowOperationValueSource
		var loaded_condition: FlowConditionValueSource = 			(loaded.segments[1] as FlowConditionSegment).get_value_source() 			as FlowConditionValueSource
		_check(
			loaded_operation.operands[0] is FlowNodePropertyRefValueSource
				and loaded_condition.comparisons[0].left_source 					is FlowNodePropertyRefValueSource,
			"Nested NodePropertyRef source kinds persist inside parent Toks."
		)


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
	push_error("[Flujo] Lot 05 composition check failed: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Lot 05 composed value sources test passed")
	else:
		push_error(
			"[Flujo] Lot 05 composition test failed: %d failures" % _failures.size()
		)
	get_tree().quit(0 if _failures.is_empty() else 1)
