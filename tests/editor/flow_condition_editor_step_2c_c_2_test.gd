extends SceneTree


var _failures: Array[String] = []
var _host: Control
var _undo_redo: EditorUndoRedoManager


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _frames(2)
	_undo_redo = EditorInterface.get_editor_undo_redo()
	_host = Control.new()
	_host.size = Vector2(1100.0, 800.0)
	get_root().add_child(_host)
	await _test_condition_popup()
	await _test_hash_condition_insert_cancel_undo()
	await _test_persistence_and_schema_policy()
	_host.queue_free()
	_finish()


func _test_condition_popup() -> void:
	var graph: FlowGraph = _graph()
	var popup: FlowConditionEditor = FlowConditionEditor.new()
	_host.add_child(popup)
	popup.open_for_condition(null, graph, Rect2(30.0, 30.0, 10.0, 10.0))
	await _frames(2)
	_check(popup.visible, "Condition editor opens as a visual popup.")
	var initial: FlowConditionComparison = popup.get_draft().comparisons[0]
	_check(initial.left_source == null and initial.right_source == null and initial.operator_id.is_empty(),
		"A new comparison starts without semantic operand or comparison defaults.")
	var left_kind: OptionButton = popup.find_child("OperandASourceKind0", true, false) as OptionButton
	var right_kind: OptionButton = popup.find_child("OperandBSourceKind0", true, false) as OptionButton
	_check(left_kind != null and right_kind != null and left_kind.selected == 0 and right_kind.selected == 0,
		"Both new operands start at Select source... with no selected source.")
	_check((popup.find_child("ComparisonOperator0", true, false) as OptionButton).selected == 0,
		"A new comparison starts at Select comparison... .")
	_check(not popup.get_draft().get_preview(graph).contains("0"),
		"The partial preview does not invent a literal zero.")
	_check(not popup.can_confirm(), "Confirm is disabled while the new comparison is incomplete.")

	left_kind.select(1)
	left_kind.item_selected.emit(1)
	await _frames(1)
	_check(popup.find_child("OperandAChooseVariable0", true, false) != null \
			and popup.find_child("OperandATypeBadge0", true, false) == null,
		"Selecting Variable shows Choose variable... but no type badge before a real variable.")
	var empty_variable: FlowVariableRefValueSource = popup.get_draft().comparisons[0].left_source as FlowVariableRefValueSource
	_check(empty_variable != null and empty_variable.variable_id.is_empty(),
		"Variable source remains unselected until the user chooses a graph variable.")
	var choose_new: Button = popup.find_child("OperandAChooseVariable0", true, false) as Button
	if choose_new != null:
		choose_new.pressed.emit()
		await _frames(1)
	var selector_new: FlowVariableSelector = popup.find_child("FlowVariableSelector", true, false) as FlowVariableSelector
	if selector_new != null:
		_select_variable(selector_new, "Count", graph)
	await _frames(1)
	_check(popup.find_child("OperandATypeBadge0", true, false) != null \
			and (popup.find_child("OperandATypeBadge0", true, false) as Label).text == "int",
		"Selecting Count derives the read-only int badge from FlowGraph.variables.")
	var choose_enabled: Button = popup.find_child("OperandAChooseVariable0", true, false) as Button
	if choose_enabled != null:
		choose_enabled.pressed.emit()
		await _frames(1)
		var enabled_selector: FlowVariableSelector = popup.find_child("FlowVariableSelector", true, false) as FlowVariableSelector
		if enabled_selector != null:
			_select_variable(enabled_selector, "Enabled", graph)
	await _frames(1)
	_check((popup.find_child("OperandATypeBadge0", true, false) as Label).text == "bool",
		"Changing Count to Enabled derives bool automatically.")

	right_kind = popup.find_child("OperandBSourceKind0", true, false) as OptionButton
	right_kind.select(2)
	right_kind.item_selected.emit(2)
	await _frames(1)
	var literal_type: OptionButton = popup.find_child("OperandBType0", true, false) as OptionButton
	_check(literal_type != null and literal_type.selected == 0 \
			and popup.find_child("OperandBValue0", true, false) == null,
		"Selecting Literal shows Select type... and no value editor or implicit zero.")
	var literal_type_names: Array[String] = []
	for item_index: int in literal_type.item_count:
		literal_type_names.append(literal_type.get_item_text(item_index))
	_check(literal_type_names.has("int") and literal_type_names.has("float") \
			and literal_type_names.has("String") and literal_type_names.has("bool"),
		"Literal types are int, float, String, and bool.")
	var int_type_index: int = _item_index_with_text(literal_type, "int")
	literal_type.select(int_type_index)
	literal_type.item_selected.emit(int_type_index)
	await _frames(1)
	var literal_value: LineEdit = popup.find_child("OperandBValue0", true, false) as LineEdit
	_check(literal_value != null and literal_value.text.is_empty(),
		"Choosing int reveals an empty value editor rather than auto-selecting 0.")
	_check((popup.find_child("ComparisonOperator0", true, false) as OptionButton).selected == 0,
		"Comparison remains explicitly unselected until the user chooses an operator.")

	var health: FlowVariableDefinition = graph.variables[1] as FlowVariableDefinition
	var left_source: FlowVariableRefValueSource = FlowVariableRefValueSource.new(
		health.get_internal_id(), health.value_type
	)
	var health_condition: FlowConditionValueSource = FlowConditionValueSource.new([
		FlowConditionComparison.new(
			FlowConditionOperatorCatalog.OPERATOR_GREATER_THAN,
			left_source,
			FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_INT, 0)
		)
	], [])
	popup.set_draft(health_condition)
	_check(popup.find_child("OperandAType0", true, false) == null,
		"Variable operand does not render an editable type selector.")
	_check(popup.find_child("OperandATypeBadge0", true, false) != null,
		"Variable operand renders a derived type badge.")
	_check(popup.find_child("OperandBType0", true, false) != null \
			and popup.find_child("OperandBValue0", true, false) != null,
		"Literal operand renders type and value controls.")
	_check(popup.get_draft().get_preview(graph) == "Health > 0",
		"Health > 0 preview updates immediately from graph-owned variable data.")

	var choose: Button = popup.find_child("OperandAChooseVariable0", true, false) as Button
	if choose != null:
		choose.pressed.emit()
		await _frames(1)
	var selector: FlowVariableSelector = popup.find_child("FlowVariableSelector", true, false) as FlowVariableSelector
	_check(selector != null and selector.get_visible_variable_ids().has(_id(graph, "Health")),
		"Variable selector shows compatible graph variables.")
	var original_source_id: String = (popup.get_draft().comparisons[0].left_source as FlowVariableRefValueSource).source_id
	if selector != null:
		_select_variable(selector, "Count", graph)
	await _frames(1)
	var changed: FlowVariableRefValueSource = popup.get_draft().comparisons[0].left_source as FlowVariableRefValueSource
	_check(changed.variable_id == _id(graph, "Count") and changed.source_id == original_source_id,
		"Changing a variable updates the draft immediately and preserves source_id.")

	popup.set_draft(FlowConditionValueSource.new([
		FlowConditionComparison.new(
			FlowConditionOperatorCatalog.OPERATOR_GREATER_THAN,
			FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_BOOL, true),
			FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_INT, 1)
		)
	], []))
	_check(not popup.can_confirm() and popup.find_child("ConditionFeedback", true, false).text.contains("Cannot compare"),
		"Incompatible bool > int is rejected immediately with brief feedback.")

	popup.set_draft(FlowConditionValueSource.new([
		FlowConditionComparison.new(
			FlowConditionOperatorCatalog.OPERATOR_EQUAL,
			FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_BOOL, true),
			FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_INT, 2)
		)
	], []))
	_check(popup.can_confirm() and not bool(popup.get_draft().resolve().value),
		"bool == int accepts non-0/1 integers and resolves false without an error.")

	popup.set_draft(FlowConditionValueSource.new([
		FlowConditionComparison.new(
			FlowConditionOperatorCatalog.OPERATOR_GREATER_THAN,
			FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_STRING, "hola"),
			FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_STRING, "adios")
		)
	], []))
	_check(not popup.can_confirm(), "String ordering is rejected by the Condition editor.")

	popup.set_draft(health_condition)
	var add: Button = popup.find_child("AddCondition", true, false) as Button
	if add != null: add.pressed.emit()
	_check(popup.get_draft().comparisons.size() == 2 and popup.get_draft().connectors.size() == 1,
		"Add condition creates a comparison and its connector.")
	var new_connector: OptionButton = popup.find_child("Connector1", true, false) as OptionButton
	var new_comparison: FlowConditionComparison = popup.get_draft().comparisons[1] as FlowConditionComparison
	_check(new_connector != null and new_connector.selected == 0 and popup.get_draft().connectors[0].is_empty(),
		"Add condition creates an empty connector, not an implicit AND.")
	_check(new_comparison.left_source == null and new_comparison.right_source == null \
			and new_comparison.operator_id.is_empty() and not popup.can_confirm(),
		"Add condition creates a fully empty comparison and keeps Confirm disabled.")
	# Regression: an OptionButton emits selected first; the bound connector slot
	# index comes second. The second comparison must not be required to refresh
	# the connector and Confirm state with a third additional row.
	popup.get_draft().comparisons[1] = FlowConditionComparison.new(
		FlowConditionOperatorCatalog.OPERATOR_GREATER_THAN,
		FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_INT, 2),
		FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_INT, 1)
	)
	popup._rebuild_rows()
	new_connector = popup.find_child("Connector1", true, false) as OptionButton
	_check(new_connector != null, "The connector remains available after setting a complete second row.")
	if new_connector != null:
		new_connector.select(1)
		new_connector.item_selected.emit(1)
		_check(popup.get_draft().connectors[0] == FlowConditionOperatorCatalog.CONNECTOR_AND \
				and popup.get_draft().get_preview(graph).contains(" AND ") \
				and popup.can_confirm(),
			"Selecting AND immediately updates the connector, preview and Confirm.")
		new_connector.select(2)
		new_connector.item_selected.emit(2)
		_check(popup.get_draft().connectors[0] == FlowConditionOperatorCatalog.CONNECTOR_OR \
				and popup.get_draft().get_preview(graph).contains(" OR ") \
				and popup.can_confirm(),
			"Selecting OR immediately updates the connector, preview and Confirm.")
	var remove: Button = popup.find_child("DeleteComparison1", true, false) as Button
	if remove != null: remove.pressed.emit()
	_check(popup.get_draft().comparisons.size() == 1 and popup.get_draft().connectors.is_empty(),
		"Removing an additional comparison preserves the first-row invariant.")
	popup.queue_free()


func _item_index_with_text(menu: OptionButton, text: String) -> int:
	for index: int in menu.item_count:
		if menu.get_item_text(index) == text:
			return index
	return -1


func _test_hash_condition_insert_cancel_undo() -> void:
	var graph: FlowGraph = _graph()
	var document: FlowStructuredDocument = _text_document("Before  after")
	var editor: FlowChipFieldEditor = FlowChipFieldEditor.new()
	editor.size = Vector2(1000.0, 600.0)
	_host.add_child(editor)
	editor.configure_field(_condition_schema(), document, _undo_redo, document)
	editor.set_variable_graph(graph)
	await _frames(2)
	var text: FlowTextSegment = document.segments[0] as FlowTextSegment
	editor.set_caret_position(text.segment_id, "Before ".length())
	var input: TextEdit = editor.get_text_control(text.segment_id)
	var version_before_trigger: int = _history(document).get_version()
	input.insert_text_at_caret("#")
	await _frames(2)
	var popup: FlowConditionEditor = editor.get_condition_editor()
	_check(popup.visible and not editor.get_expression_editor().visible,
		"# opens Condition Editor exclusively, not the legacy Expression editor.")
	popup.set_draft(_health_condition(graph))
	var confirm: Button = popup.find_child("ConfirmCondition", true, false) as Button
	if confirm != null: confirm.pressed.emit()
	await _frames(2)
	var condition: FlowConditionSegment = _first_condition(document)
	_check(condition != null and condition.get_chip_label() == "Health > 0",
		"Confirm inserts a Condition Tok with graph preview.")
	_check(_history(document).get_version() == version_before_trigger + 1,
		"Confirm creates one document history action.")
	var inserted_chip: FlowChipControl = editor.get_chip_control(condition.segment_id)
	var enter: InputEventKey = InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	if inserted_chip != null: inserted_chip._gui_input(enter)
	await _frames(2)
	_check(editor.get_condition_editor().visible, "Enter on an existing Condition Tok reopens the same editor.")
	if editor.get_condition_editor().visible:
		var edit_confirm: Button = editor.get_condition_editor().find_child("ConfirmCondition", true, false) as Button
		if edit_confirm != null: edit_confirm.pressed.emit()
	await _frames(1)
	_history(document).undo()
	_check(_first_condition(document) != null, "Undo restores the original existing Condition Tok after edit.")
	_history(document).redo()
	_history(document).undo()
	_history(document).undo()
	_check(_first_condition(document) == null and text.text == "Before  after",
		"Undo removes the Condition Tok and restores the semantic caret text.")
	_history(document).redo()
	_check(_first_condition(document) != null, "Redo restores the complete Condition Tok.")

	var cancel_document: FlowStructuredDocument = _text_document("Cancel me")
	var cancel_editor: FlowChipFieldEditor = FlowChipFieldEditor.new()
	_host.add_child(cancel_editor)
	cancel_editor.configure_field(_condition_schema(), cancel_document, _undo_redo, cancel_document)
	cancel_editor.set_variable_graph(graph)
	await _frames(2)
	var cancel_text: FlowTextSegment = cancel_document.segments[0] as FlowTextSegment
	cancel_editor.set_caret_position(cancel_text.segment_id, "Cancel ".length())
	var cancel_input: TextEdit = cancel_editor.get_text_control(cancel_text.segment_id)
	cancel_input.insert_text_at_caret("#")
	await _frames(2)
	var version: int = _history(cancel_document).get_version()
	var cancel: Button = cancel_editor.get_condition_editor().find_child("CancelCondition", true, false) as Button
	if cancel != null: cancel.pressed.emit()
	await _frames(2)
	_check(cancel_text.text == "Cancel me" and _history(cancel_document).get_version() == version,
		"Cancel discards the draft and creates no Undo action.")
	cancel_editor.queue_free()

	var escaped_document: FlowStructuredDocument = _text_document("")
	var escaped_editor: FlowChipFieldEditor = FlowChipFieldEditor.new()
	_host.add_child(escaped_editor)
	escaped_editor.configure_field(_condition_schema(), escaped_document, _undo_redo, escaped_document)
	escaped_editor.set_variable_graph(graph)
	await _frames(2)
	var escaped_input: TextEdit = escaped_editor.get_text_control((escaped_document.segments[0] as FlowTextSegment).segment_id)
	escaped_input.insert_text_at_caret("\\#")
	await _frames(2)
	_check((escaped_document.segments[0] as FlowTextSegment).text == "#" and not escaped_editor.get_condition_editor().visible,
		"\\# remains literal text and does not open Condition Editor.")
	escaped_editor.queue_free()
	editor.queue_free()


func _test_persistence_and_schema_policy() -> void:
	var graph: FlowGraph = _graph()
	var condition: FlowConditionValueSource = _health_condition(graph)
	var segment: FlowConditionSegment = FlowConditionSegment.new(condition)
	segment.slot_id = "condition"
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	document.segments = [segment]
	var root: String = "res://.godot/flujo_tests/condition_editor_c2"
	var path: String = root + "/condition.tres"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	_check(ResourceSaver.save(document, path) == OK, "Condition editor persistence fixture saves.")
	var loaded: FlowStructuredDocument = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as FlowStructuredDocument
	_check(loaded != null and loaded.segments[0] is FlowConditionSegment,
		"Condition editor persistence reloads the concrete segment.")
	if loaded != null:
		var loaded_source: FlowConditionValueSource = (loaded.segments[0] as FlowConditionSegment).get_value_source() as FlowConditionValueSource
		_check(loaded_source.get_preview(graph) == "Health > 0" and loaded_source.get_value_type() == Variant.Type.TYPE_BOOL,
			"Persistence preserves ordered Condition data and produced bool type.")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

	for mode: int in [FlowChipFieldSchema.Mode.FIXED, FlowChipFieldSchema.Mode.FLEXIBLE, FlowChipFieldSchema.Mode.HYBRID]:
		var schema: FlowChipFieldSchema = _condition_schema()
		schema.mode = mode
		if mode == FlowChipFieldSchema.Mode.FIXED:
			schema.slots = [_condition_slot()]
			schema.slots[0].required = true
			schema.slots[0].initial_value_source = _health_condition(graph)
			schema.variadic_slot_definition = null
		elif mode != FlowChipFieldSchema.Mode.FIXED:
			schema.slots = []
			schema.variadic_slot_definition = _condition_slot()
			schema.flexible_min_count = 0
			schema.flexible_max_count = 2
		_check(FlowChipFieldValidator.validate_schema(schema).has_errors() == false,
			"Condition schema remains valid for FIXED/FLEXIBLE/HYBRID mode %d." % mode)


func _condition_schema() -> FlowChipFieldSchema:
	var schema: FlowChipFieldSchema = FlowChipFieldSchema.new()
	schema.mode = FlowChipFieldSchema.Mode.FLEXIBLE
	schema.text_mode = FlowChipFieldSchema.TextMode.RUNTIME_CONTENT
	schema.accepted_value_types = [Variant.Type.TYPE_BOOL]
	schema.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_CONDITION]
	schema.variadic_slot_definition = _condition_slot()
	schema.flexible_max_count = 2
	schema.add_text_part("")
	schema.add_slot_part("condition")
	return schema


func _condition_slot() -> FlowChipSlotDefinition:
	var slot: FlowChipSlotDefinition = FlowChipSlotDefinition.new("condition", "Condition")
	slot.repeatable = true
	slot.max_count = 2
	slot.accepted_value_types = [Variant.Type.TYPE_BOOL]
	slot.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_CONDITION]
	return slot


func _health_condition(graph: FlowGraph) -> FlowConditionValueSource:
	return FlowConditionValueSource.new([
		FlowConditionComparison.new(
			FlowConditionOperatorCatalog.OPERATOR_GREATER_THAN,
			FlowVariableRefValueSource.new(_id(graph, "Health"), FlowVariableDefinition.ValueType.INT),
			FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_INT, 0)
		)
	], [])


func _first_condition(document: FlowStructuredDocument) -> FlowConditionSegment:
	for segment: FlowDocumentSegment in document.segments:
		if segment is FlowConditionSegment: return segment as FlowConditionSegment
	return null


func _select_variable(selector: FlowVariableSelector, name: String, graph: FlowGraph) -> void:
	for index: int in selector.get_variable_list().item_count:
		if _variable_name(graph, String(selector.get_variable_list().get_item_metadata(index))) == name:
			selector.get_variable_list().item_activated.emit(index)
			return


func _graph() -> FlowGraph:
	var graph: FlowGraph = FlowGraph.new()
	graph.variables = [
		_variable(graph, "Count"), _variable(graph, "Health"),
		_variable(graph, "Enabled", FlowVariableDefinition.ValueType.BOOL),
		_variable(graph, "Message", FlowVariableDefinition.ValueType.STRING),
	]
	return graph


func _variable(graph: FlowGraph, name: String, value_type: FlowVariableDefinition.ValueType = FlowVariableDefinition.ValueType.INT) -> FlowVariableDefinition:
	var variable: FlowVariableDefinition = FlowVariableDefinition.new()
	variable.display_name = name
	variable.value_type = value_type
	return variable


func _id(graph: FlowGraph, name: String) -> String:
	for variable: FlowVariableDefinition in graph.variables:
		if variable != null and variable.display_name == name: return variable.get_internal_id()
	return ""


func _variable_name(graph: FlowGraph, id: String) -> String:
	for variable: FlowVariableDefinition in graph.variables:
		if variable != null and variable.get_internal_id() == id: return variable.display_name
	return ""


func _text_document(value: String) -> FlowStructuredDocument:
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	var text: FlowTextSegment = FlowTextSegment.new()
	text.text = value
	document.segments = [text]
	return document


func _history(document: FlowStructuredDocument) -> UndoRedo:
	return _undo_redo.get_history_undo_redo(_undo_redo.get_object_history_id(document))


func _frames(count: int = 1) -> void:
	for _index: int in count: await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error("[Flujo] Condition C.2 check failed: " + message)


func _finish() -> void:
	if _failures.is_empty(): print("[Flujo] Flow Condition Step 2C-C.2 editor test passed")
	else: push_error("[Flujo] Flow Condition Step 2C-C.2 editor test failed: %d failures" % _failures.size())
	quit(0 if _failures.is_empty() else 1)
