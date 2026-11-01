extends SceneTree


var _failures: Array[String] = []
var _host: Control


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_host = Control.new()
	_host.size = Vector2(1000.0, 700.0)
	get_root().add_child(_host)
	await _frames(2)
	await _test_collection_source_composition()
	await _test_collection_depth_guard()
	_host.queue_free()
	await _frames(1)
	_finish()


func _test_collection_source_composition() -> void:
	var graph: FlowGraph = FlowGraph.new()
	var count: FlowVariableDefinition = FlowVariableDefinition.new()
	count.display_name = "Count"
	count.value_type = FlowVariableDefinition.ValueType.INT
	count.int_value = 7
	graph.variables = [count]

	var editor: FlowComplexValueEditor = FlowComplexValueEditor.new()
	_host.add_child(editor)
	editor.open_for_source(
		FlowArrayValueSource.new(),
		graph,
		Rect2(20, 20, 1, 1)
	)
	await _frames(1)

	var add_source: MenuButton = _menu_with_text(editor, "Add Source…")
	_check(add_source != null, "Array editor exposes Add Source menu.")
	if add_source == null:
		editor.queue_free()
		return
	var popup: PopupMenu = add_source.get_popup()
	_check(
		_has_id(popup, FlowComplexValueEditor.CHILD_SOURCE_VARIABLE)
			and _has_id(popup, FlowComplexValueEditor.CHILD_SOURCE_OPERATION)
			and _has_id(popup, FlowComplexValueEditor.CHILD_SOURCE_CONDITION)
			and _has_id(popup, FlowComplexValueEditor.CHILD_SOURCE_NODE)
			and _has_id(popup, FlowComplexValueEditor.CHILD_SOURCE_NODE_PROPERTY)
			and _has_id(popup, FlowComplexValueEditor.CHILD_SOURCE_RESOURCE)
			and _has_id(popup, FlowComplexValueEditor.CHILD_SOURCE_ENUM)
			and _has_id(popup, FlowComplexValueEditor.CHILD_SOURCE_BITFIELD),
		"Collection source menu exposes Variable, Operation, Condition, Node, Node Property and structured source families."
	)

	popup.id_pressed.emit(FlowComplexValueEditor.CHILD_SOURCE_VARIABLE)
	await _frames(1)
	var variable_selector: FlowVariableSelector = editor.find_child(
		"NestedVariableSelector",
		true,
		false
	) as FlowVariableSelector
	_check(
		variable_selector != null and variable_selector.visible,
		"Variable source opens the shared Variable selector."
	)
	if variable_selector != null:
		variable_selector.variable_selected.emit(count.get_internal_id())
	await _frames(2)

	var array: FlowArrayValueSource = editor.get_draft() as FlowArrayValueSource
	_check(
		array != null
			and array.elements.size() == 1
			and array.elements[0] is FlowVariableRefValueSource,
		"Variable selector appends one VariableRef source to the Array draft."
	)

	add_source = _menu_with_text(editor, "Add Source…")
	add_source.get_popup().id_pressed.emit(
		FlowComplexValueEditor.CHILD_SOURCE_OPERATION
	)
	await _frames(1)
	var operation_editor: FlowOperationEditor = editor.find_child(
		"NestedOperationEditor",
		true,
		false
	) as FlowOperationEditor
	_check(
		operation_editor != null and operation_editor.visible,
		"Operation source opens the shared Operation editor."
	)
	if operation_editor != null:
		operation_editor.set_draft(FlowOperationValueSource.new(
			FlowOperationOperatorCatalog.OPERATOR_ADD,
			[
				FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 2),
				FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 3),
			]
		))
		var confirm_operation: Button = operation_editor.find_child(
			"ConfirmOperation",
			true,
			false
		) as Button
		if confirm_operation != null:
			confirm_operation.pressed.emit()
	await _frames(2)

	array = editor.get_draft() as FlowArrayValueSource
	_check(
		array.elements.size() == 2
			and array.elements[1] is FlowOperationValueSource,
		"Confirmed Operation appends as a real nested ValueSource."
	)

	add_source = _menu_with_text(editor, "Add Source…")
	add_source.get_popup().id_pressed.emit(
		FlowComplexValueEditor.CHILD_SOURCE_CONDITION
	)
	await _frames(1)
	var condition_editor: FlowConditionEditor = editor.find_child(
		"NestedConditionEditor",
		true,
		false
	) as FlowConditionEditor
	_check(
		condition_editor != null and condition_editor.visible,
		"Condition source opens the shared Condition editor."
	)
	if condition_editor != null:
		condition_editor.set_draft(FlowConditionValueSource.new(
			[
				FlowConditionComparison.new(
					FlowConditionOperatorCatalog.OPERATOR_GREATER_THAN,
					FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 4),
					FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 1)
				),
			],
			[]
		))
		var confirm_condition: Button = condition_editor.find_child(
			"ConfirmCondition",
			true,
			false
		) as Button
		if confirm_condition != null:
			confirm_condition.pressed.emit()
	await _frames(2)

	array = editor.get_draft() as FlowArrayValueSource
	_check(
		array.elements.size() == 3
			and array.elements[2] is FlowConditionValueSource,
		"Confirmed Condition appends as a real nested ValueSource."
	)
	var resolved: FlowValueResult = array.resolve(
		FlowValueResolutionContext.new(graph)
	)
	_check(
		resolved.success
			and resolved.value == [7, 5, true],
		"UI-authored Variable + Operation + Condition Array resolves end to end."
	)

	editor.queue_free()


func _test_collection_depth_guard() -> void:
	var editor: FlowComplexValueEditor = FlowComplexValueEditor.new()
	_host.add_child(editor)
	editor.open_for_source(
		FlowArrayValueSource.new(),
		null,
		Rect2(40, 40, 1, 1),
		{
			"complex_nesting_depth": FlowComplexValueEditor.MAX_EDITOR_NESTING_DEPTH,
		}
	)
	await _frames(1)
	var add_source: MenuButton = _menu_with_text(editor, "Add Source…")
	_check(add_source != null, "Depth-guard fixture exposes Add Source menu.")
	if add_source != null:
		var popup: PopupMenu = add_source.get_popup()
		var array_index: int = popup.get_item_index(
			FlowComplexValueEditor.CHILD_SOURCE_ARRAY
		)
		var dictionary_index: int = popup.get_item_index(
			FlowComplexValueEditor.CHILD_SOURCE_DICTIONARY
		)
		var operation_index: int = popup.get_item_index(
			FlowComplexValueEditor.CHILD_SOURCE_OPERATION
		)
		_check(
			array_index >= 0
				and dictionary_index >= 0
				and popup.is_item_disabled(array_index)
				and popup.is_item_disabled(dictionary_index),
			"Complex editor disables deeper Array/Dictionary creation at the nesting limit."
		)
		_check(
			operation_index >= 0 and not popup.is_item_disabled(operation_index),
			"Depth guard does not disable non-collection composed sources."
		)
	editor.hide()
	editor.queue_free()
	await _frames(1)


func _menu_with_text(root: Node, text_value: String) -> MenuButton:
	for child: Node in root.find_children("*", "MenuButton", true, false):
		var menu: MenuButton = child as MenuButton
		if menu != null and menu.text == text_value:
			return menu
	return null


func _has_id(popup: PopupMenu, item_id: int) -> bool:
	return popup != null and popup.get_item_index(item_id) >= 0


func _frames(count: int = 1) -> void:
	for _index: int in count:
		await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("[Flujo] Lot 10 editor integration check failed: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Lot 10 complex source integration test passed")
	else:
		push_error(
			"[Flujo] Lot 10 editor test failed: %d failures" % _failures.size()
		)
	quit(0 if _failures.is_empty() else 1)
