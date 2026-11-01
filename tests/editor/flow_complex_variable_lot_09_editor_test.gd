extends SceneTree


var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var undo_manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	_check(undo_manager != null, "Editor UndoRedo is available.")
	if undo_manager == null:
		_finish()
		return

	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var variable: FlowVariableDefinition = FlowVariableDefinition.new()
	variable.display_name = "Payload"
	variable.value_type = FlowVariableDefinition.ValueType.INT
	variable.int_value = 3
	graph.variables = [variable]

	var controller: PVController = PVController.new()
	controller.flow_graph = graph
	var host: Control = Control.new()
	get_root().add_child(host)

	var inspector: FlowGraphInspectorProperty = FlowGraphInspectorProperty.new()
	host.add_child(inspector)
	inspector.configure(undo_manager)
	inspector.configure_for_dock()
	inspector.set_dock_controller(controller)
	inspector.set_dock_variable_selection(
		controller,
		FlowGraphEditorCommands.Collection.VARIABLES,
		variable.get_internal_id()
	)
	await _frames(4)

	var type_option: OptionButton = inspector.find_child(
		"VariableTypeOption",
		true,
		false
	) as OptionButton
	_check(type_option != null, "Variable editor exposes Type selector.")
	var array_index: int = _item_index(type_option, "ARRAY")
	_check(array_index >= 0, "Variable Type selector exposes ARRAY.")
	if type_option != null and array_index >= 0:
		type_option.select(array_index)
		type_option.item_selected.emit(array_index)
	await _frames(4)

	_check(
		variable.value_type == FlowVariableDefinition.ValueType.ARRAY
			and variable.complex_value_source is FlowArrayValueSource,
		"Selecting ARRAY atomically creates its structured default source."
	)
	var source_id: String = variable.complex_value_source.source_id
	var edit_button: Button = inspector.find_child(
		"VariableComplexValueEdit",
		true,
		false
	) as Button
	_check(edit_button != null, "Complex Variable exposes Edit Array.")
	if edit_button != null:
		edit_button.pressed.emit()
	await _frames(2)

	var complex: FlowComplexValueEditor = inspector.find_child(
		"VariableComplexValueEditor",
		true,
		false
	) as FlowComplexValueEditor
	_check(complex != null and complex.visible, "Variable opens shared structured-value editor.")
	if complex != null:
		complex.set_draft(FlowArrayValueSource.new([
			FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 9),
		]))
		var confirm: Button = complex.find_child(
			"ConfirmComplexValue",
			true,
			false
		) as Button
		if confirm != null:
			confirm.pressed.emit()
	await _frames(4)

	var edited: FlowArrayValueSource = variable.complex_value_source as FlowArrayValueSource
	_check(
		edited != null
			and edited.source_id == source_id
			and edited.elements.size() == 1
			and (edited.elements[0] as FlowLiteralValueSource).value == 9,
		"Complex Variable edit preserves source_id and updates its source tree."
	)

	var history: UndoRedo = undo_manager.get_history_undo_redo(
		undo_manager.get_object_history_id(controller)
	)
	history.undo()
	await _frames(2)
	edited = variable.complex_value_source as FlowArrayValueSource
	_check(
		edited != null and edited.elements.is_empty(),
		"Undo restores the previous complex Variable source."
	)
	history.undo()
	await _frames(2)
	_check(
		variable.value_type == FlowVariableDefinition.ValueType.INT
			and variable.complex_value_source == null,
		"Undo of type change restores scalar type and previous source state."
	)
	history.redo()
	history.redo()
	await _frames(3)
	edited = variable.complex_value_source as FlowArrayValueSource
	_check(
		variable.value_type == FlowVariableDefinition.ValueType.ARRAY
			and edited != null
			and edited.elements.size() == 1,
		"Redo reapplies type creation and structured edit in chronological order."
	)

	type_option = inspector.find_child(
		"VariableTypeOption",
		true,
		false
	) as OptionButton
	var int_index: int = _item_index(type_option, "INT")
	if type_option != null and int_index >= 0:
		type_option.select(int_index)
		type_option.item_selected.emit(int_index)
	await _frames(3)
	_check(
		variable.value_type == FlowVariableDefinition.ValueType.INT
			and variable.complex_value_source == null,
		"Changing a complex Variable back to scalar clears its active structured source."
	)
	history.undo()
	await _frames(2)
	edited = variable.complex_value_source as FlowArrayValueSource
	_check(
		variable.value_type == FlowVariableDefinition.ValueType.ARRAY
			and edited != null
			and edited.elements.size() == 1,
		"Undo of complex-to-scalar restores the previous structured source."
	)

	host.queue_free()
	await _frames(1)
	_finish()


func _item_index(option: OptionButton, label: String) -> int:
	if option == null:
		return -1
	for index: int in option.item_count:
		if option.get_item_text(index) == label:
			return index
	return -1


func _frames(count: int) -> void:
	for _index: int in count:
		await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("[Flujo] Lot 09 editor check failed: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Lot 09 complex Variable editor test passed")
	else:
		push_error("[Flujo] Lot 09 editor test failed: %d failures" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
