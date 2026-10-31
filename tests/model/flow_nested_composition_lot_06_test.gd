extends Node


const TEMP_ROOT: String = "res://.godot/flujo_tests/nested_composition_lot_06"
const DOC_PATH: String = TEMP_ROOT + "/nested_document.tres"

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_nested_operation_precedence()
	_test_operation_inside_condition_with_not()
	_test_nested_signature_strictness()
	_test_deep_duplication()
	_test_persistence()
	_cleanup()
	_finish()


func _test_nested_operation_precedence() -> void:
	var inner: FlowOperationValueSource = FlowOperationValueSource.new(
		FlowOperationOperatorCatalog.OPERATOR_ADD,
		[
			FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 2),
			FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 3),
		]
	)
	var outer: FlowOperationValueSource = FlowOperationValueSource.new(
		FlowOperationOperatorCatalog.OPERATOR_MULTIPLY,
		[
			inner,
			FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 4),
		]
	)
	_check(outer.is_valid(), "Nested Operation is structurally valid.")
	_check_result(
		outer.resolve(),
		20,
		Variant.Type.TYPE_INT,
		"(2 + 3) * 4 resolves with explicit tree precedence."
	)
	_check(
		outer.get_preview() == "(2 + 3) * 4",
		"Nested Operation preview always groups the child with parentheses."
	)


func _test_operation_inside_condition_with_not() -> void:
	var root: Node = Node.new()
	root.name = "Root"
	var target: Node2D = Node2D.new()
	target.name = "Target"
	target.z_index = 3
	root.add_child(target)

	var property: FlowNodePropertyRefValueSource = FlowNodePropertyRefValueSource.new(
		"",
		NodePath("Target"),
		&"Target",
		&"z_index",
		Variant.Type.TYPE_INT
	)
	var operation: FlowOperationValueSource = FlowOperationValueSource.new(
		FlowOperationOperatorCatalog.OPERATOR_ADD,
		[
			property,
			FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 2),
		]
	)
	var condition: FlowConditionValueSource = FlowConditionValueSource.new(
		[
			FlowConditionComparison.new(
				FlowConditionOperatorCatalog.OPERATOR_GREATER_THAN,
				operation,
				FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 10)
			)
		],
		[],
		true
	)
	var context: FlowValueResolutionContext = FlowValueResolutionContext.new(
		null,
		null,
		root
	)
	_check(condition.is_valid(), "Condition accepts a nested Operation operand.")
	_check_result(
		condition.resolve(context),
		true,
		Variant.Type.TYPE_BOOL,
		"NOT (($Target.z_index + 2) > 10) resolves true for z_index=3."
	)
	_check(
		condition.get_preview() == "NOT (($Target.z_index + 2) > 10)",
		"Condition preview makes nested grouping and NOT explicit."
	)

	target.z_index = 12
	_check_result(
		condition.resolve(context),
		false,
		Variant.Type.TYPE_BOOL,
		"NOT is applied after live nested Operation resolution."
	)
	root.free()


func _test_nested_signature_strictness() -> void:
	var inner: FlowOperationValueSource = FlowOperationValueSource.new(
		FlowOperationOperatorCatalog.OPERATOR_ADD,
		[
			FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 1),
			FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 2),
		]
	)
	var invalid: FlowOperationValueSource = FlowOperationValueSource.new(
		FlowOperationOperatorCatalog.OPERATOR_ADD,
		[
			inner,
			FlowLiteralValueSource.new(Variant.Type.TYPE_FLOAT, 1.0),
		]
	)
	_check(
		not invalid.is_valid(),
		"Nested composition preserves strict int/float signatures."
	)


func _test_deep_duplication() -> void:
	var node_source: FlowNodePropertyRefValueSource = FlowNodePropertyRefValueSource.new(
		FlowId.create(),
		NodePath("Target"),
		&"Target",
		&"z_index",
		Variant.Type.TYPE_INT
	)
	var inner: FlowOperationValueSource = FlowOperationValueSource.new(
		FlowOperationOperatorCatalog.OPERATOR_ADD,
		[
			node_source,
			FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 1),
		]
	)
	var outer: FlowOperationValueSource = FlowOperationValueSource.new(
		FlowOperationOperatorCatalog.OPERATOR_MULTIPLY,
		[
			inner,
			FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 2),
		]
	)
	var copy: FlowOperationValueSource = 		outer.duplicate_with_new_id() as FlowOperationValueSource
	var copied_inner: FlowOperationValueSource = 		copy.operands[0] as FlowOperationValueSource
	var copied_node: FlowNodePropertyRefValueSource = 		copied_inner.operands[0] as FlowNodePropertyRefValueSource
	_check(
		copy.source_id != outer.source_id
			and copied_inner.source_id != inner.source_id
			and copied_node.source_id != node_source.source_id
			and copied_node.requirement_id == node_source.requirement_id,
		"Deep duplication renews owned IDs through the nested tree."
	)


func _test_persistence() -> void:
	var inner: FlowOperationValueSource = FlowOperationValueSource.new(
		FlowOperationOperatorCatalog.OPERATOR_ADD,
		[
			FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 4),
			FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 5),
		]
	)
	var condition: FlowConditionValueSource = FlowConditionValueSource.new(
		[
			FlowConditionComparison.new(
				FlowConditionOperatorCatalog.OPERATOR_GREATER_THAN,
				inner,
				FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 3)
			)
		],
		[],
		true
	)
	var segment: FlowConditionSegment = FlowConditionSegment.new(condition)
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	document.segments = [segment]

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT))
	_check(
		ResourceSaver.save(document, DOC_PATH) == OK,
		"Nested Condition document saves."
	)
	var loaded: FlowStructuredDocument = ResourceLoader.load(
		DOC_PATH,
		"",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as FlowStructuredDocument
	_check(
		loaded != null
			and loaded.segments.size() == 1
			and loaded.segments[0] is FlowConditionSegment,
		"Nested Condition document reloads."
	)
	if loaded != null and loaded.segments.size() == 1:
		var loaded_condition: FlowConditionValueSource = 			(loaded.segments[0] as FlowConditionSegment).get_value_source() 			as FlowConditionValueSource
		_check(
			loaded_condition != null
				and loaded_condition.negated
				and loaded_condition.comparisons[0].left_source 					is FlowOperationValueSource,
			"Persistence preserves NOT and nested Operation source kind."
		)
		_check_result(
			loaded_condition.resolve(),
			false,
			Variant.Type.TYPE_BOOL,
			"Reloaded NOT ((4 + 5) > 3) resolves false."
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
	push_error("[Flujo] Lot 06 nested composition check failed: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Lot 06 nested composition model test passed")
	else:
		push_error(
			"[Flujo] Lot 06 model test failed: %d failures" % _failures.size()
		)
	get_tree().quit(0 if _failures.is_empty() else 1)
