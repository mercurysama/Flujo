extends SceneTree


var _failures: Array[String] = []
var _host: Control


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _frames(2)
	_host = Control.new()
	_host.size = Vector2(1000.0, 700.0)
	get_root().add_child(_host)
	await _test_operation_nested_source_ui()
	await _test_operation_depth_guard()
	await _test_condition_nested_operation_and_not()
	_host.queue_free()
	_finish()


func _test_operation_nested_source_ui() -> void:
	var editor: FlowOperationEditor = FlowOperationEditor.new()
	_host.add_child(editor)
	editor.open_for_operation(
		null,
		null,
		Rect2(20, 20, 1, 1),
		{"operation_nesting_depth": 0}
	)
	await _frames(1)
	var kind: OptionButton = editor.find_child(
		"Operand0SourceKind",
		true,
		false
	) as OptionButton
	var operation_item: int = _source_kind_index(
		kind,
		FlowValueSource.SOURCE_KIND_OPERATION
	)
	_check(operation_item >= 0, "Operation editor exposes nested Operation source kind.")
	_check(
		operation_item >= 0 and not kind.is_item_disabled(operation_item),
		"Nested Operation source is enabled below the depth limit."
	)

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
	editor.set_draft(outer)
	await _frames(1)
	var edit_nested: Button = editor.find_child(
		"Operand0EditOperation",
		true,
		false
	) as Button
	var badge: Label = editor.find_child(
		"Operand0TypeBadge",
		true,
		false
	) as Label
	_check(
		edit_nested != null and edit_nested.text == "(2 + 3)",
		"Nested Operation editor button preserves explicit grouping."
	)
	_check(
		badge != null and badge.text == "int",
		"Nested Operation operand exposes its produced type."
	)
	_check(editor.can_confirm(), "Valid nested Operation can Confirm.")
	editor.hide()
	editor.queue_free()


func _test_operation_depth_guard() -> void:
	var editor: FlowOperationEditor = FlowOperationEditor.new()
	_host.add_child(editor)
	editor.open_for_operation(
		null,
		null,
		Rect2(30, 30, 1, 1),
		{"operation_nesting_depth": FlowOperationEditor.MAX_EDITOR_NESTING_DEPTH}
	)
	await _frames(1)
	var kind: OptionButton = editor.find_child(
		"Operand0SourceKind",
		true,
		false
	) as OptionButton
	var operation_item: int = _source_kind_index(
		kind,
		FlowValueSource.SOURCE_KIND_OPERATION
	)
	_check(
		operation_item >= 0 and kind.is_item_disabled(operation_item),
		"Editor disables deeper nesting at MAX_EDITOR_NESTING_DEPTH."
	)
	editor.hide()
	editor.queue_free()


func _test_condition_nested_operation_and_not() -> void:
	var editor: FlowConditionEditor = FlowConditionEditor.new()
	_host.add_child(editor)
	editor.open_for_condition(
		null,
		null,
		Rect2(40, 40, 1, 1),
		{}
	)
	await _frames(1)
	var kind: OptionButton = editor.find_child(
		"OperandASourceKind0",
		true,
		false
	) as OptionButton
	_check(
		_source_kind_index(kind, FlowValueSource.SOURCE_KIND_OPERATION) >= 0,
		"Condition source selector exposes Operation."
	)

	var inner: FlowOperationValueSource = FlowOperationValueSource.new(
		FlowOperationOperatorCatalog.OPERATOR_ADD,
		[
			FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 4),
			FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 5),
		]
	)
	var source: FlowConditionValueSource = FlowConditionValueSource.new(
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
	editor.set_draft(source)
	await _frames(1)
	var toggle: CheckBox = editor.find_child(
		"NegateCondition",
		true,
		false
	) as CheckBox
	var edit_nested: Button = editor.find_child(
		"OperandAEditOperation0",
		true,
		false
	) as Button
	var preview: Label = editor.find_child(
		"ConditionPreview",
		true,
		false
	) as Label
	_check(
		toggle != null and toggle.button_pressed,
		"Condition editor restores persisted NOT state."
	)
	_check(
		edit_nested != null and edit_nested.text == "(4 + 5)",
		"Condition renders nested Operation with grouping."
	)
	_check(
		preview != null and preview.text == "NOT ((4 + 5) > 3)",
		"Condition preview exposes NOT and nested parentheses."
	)
	_check(editor.can_confirm(), "Valid NOT Condition with nested Operation can Confirm.")

	if toggle != null:
		toggle.button_pressed = false
	await _frames(1)
	var draft: FlowConditionValueSource = editor.get_draft()
	_check(
		draft != null and not draft.negated,
		"NOT toggle updates the detached Condition draft."
	)
	editor.hide()
	editor.queue_free()


func _source_kind_index(menu: OptionButton, source_kind: StringName) -> int:
	if menu == null:
		return -1
	for index: int in menu.item_count:
		if StringName(menu.get_item_metadata(index)) == source_kind:
			return index
	return -1


func _frames(count: int = 1) -> void:
	for _index: int in count:
		await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("[Flujo] Lot 06 editor check failed: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Lot 06 nested composition editor test passed")
	else:
		push_error(
			"[Flujo] Lot 06 editor test failed: %d failures" % _failures.size()
		)
	quit(0 if _failures.is_empty() else 1)
