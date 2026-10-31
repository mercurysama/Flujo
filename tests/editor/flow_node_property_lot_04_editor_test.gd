extends SceneTree


var _failures: Array[String] = []
var _host: Control
var _undo_redo: EditorUndoRedoManager
var _panel: FlowSceneNodePanel


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _frames(2)
	_undo_redo = EditorInterface.get_editor_undo_redo()
	_check(_undo_redo != null, "NodeProperty editor has an Akis history.")
	_host = Control.new()
	_host.size = Vector2(1000.0, 700.0)
	get_root().add_child(_host)
	_mount_test_panel()
	await _test_property_filter()
	await _test_dollar_escape()
	await _test_dollar_requirement_insert_and_history()
	_dispose_test_panel()
	_host.queue_free()
	_finish()


func _mount_test_panel() -> void:
	var base: Control = EditorInterface.get_base_control()
	var existing: FlowSceneNodePanel = base.find_child(
		"FlowSceneNodePanel",
		true,
		false
	) as FlowSceneNodePanel
	if existing != null:
		_panel = existing
		return
	_panel = FlowSceneNodePanel.new()
	_panel.set_meta(&"lot_04_test_owned", true)
	base.add_child(_panel)


func _dispose_test_panel() -> void:
	if _panel == null:
		return
	_panel.close()
	if bool(_panel.get_meta(&"lot_04_test_owned", false)):
		if _panel.get_parent() != null:
			_panel.get_parent().remove_child(_panel)
		_panel.free()
	_panel = null


func _test_property_filter() -> void:
	var target: Node2D = Node2D.new()
	target.name = "Target"
	var selector: FlowNodePropertySelector = FlowNodePropertySelector.new()
	_host.add_child(selector)
	selector.open_for_node(
		target,
		"",
		NodePath("Target"),
		[Variant.Type.TYPE_VECTOR2],
		Rect2(20.0, 20.0, 1.0, 1.0)
	)
	await _frames(1)
	var list: ItemList = selector.find_child("PropertyList", true, false) as ItemList
	_check(
		list != null and list.item_count > 0,
		"Property selector exposes compatible Node2D Vector2 properties."
	)
	if list != null:
		var saw_position: bool = false
		var only_vector2: bool = true
		for index: int in list.item_count:
			var descriptor: Dictionary = list.get_item_metadata(index) as Dictionary
			var value_type: Variant.Type = int(
				descriptor.get("type", Variant.Type.TYPE_NIL)
			) as Variant.Type
			only_vector2 = only_vector2 and value_type == Variant.Type.TYPE_VECTOR2
			saw_position = saw_position 				or StringName(descriptor.get("name", &"")) == &"position"
		_check(only_vector2, "Property selector uses exact field-compatible Variant.Types.")
		_check(saw_position, "Node2D.position is available to a Vector2 field.")
	selector.hide()
	selector.queue_free()
	target.free()


func _test_dollar_escape() -> void:
	var document: FlowStructuredDocument = _text_document("")
	var editor: FlowChipFieldEditor = _new_editor(
		_node_property_schema(),
		document
	)
	await _frames(2)
	var text: FlowTextSegment = document.segments[0] as FlowTextSegment
	var input: TextEdit = editor.get_text_control(text.segment_id)
	input.insert_text_at_caret("\\$")
	await _frames(2)
	_check(
		text.text == "$",
		"\\$ becomes a literal dollar sign."
	)
	_check(
		not _panel.is_open(),
		"Escaped dollar does not open the Scene Node Panel."
	)
	editor.queue_free()


func _test_dollar_requirement_insert_and_history() -> void:
	var controller: PVController = PVController.new()
	controller.name = "Controller"
	var target: Node2D = Node2D.new()
	target.name = "Target"
	target.position = Vector2(7.0, 11.0)
	controller.add_child(target)

	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_4
	graph.constructor = FlowConstructorDefinition.new()
	controller.flow_graph = graph
	_panel.set_controller(controller)

	var document: FlowStructuredDocument = _text_document("Before  after")
	var editor: FlowChipFieldEditor = _new_editor(
		_node_property_schema(),
		document
	)
	editor.set_variable_graph(graph)
	editor.set_scene_context(controller, controller)
	await _frames(2)

	var text: FlowTextSegment = document.segments[0] as FlowTextSegment
	editor.set_caret_position(text.segment_id, "Before ".length())
	var input: TextEdit = editor.get_text_control(text.segment_id)
	input.insert_text_at_caret("$")
	await _frames(2)
	_check(
		_panel.is_open(),
		"Typing an unescaped $ opens the Scene Node Panel."
	)
	_check(
		editor.get_feedback_text().contains("scene node"),
		"$ leaves Akis waiting for a node before property selection."
	)

	var accepted: bool = editor.accept_scene_node_payload({
		"type": "flujo_scene_node",
		"node_path": NodePath("Target"),
		"node_name": "Target",
		"class_name": "Node2D",
		"requirement_id": "",
	})
	_check(accepted, "Akis accepts the selected Scene Node payload.")
	await _frames(2)

	var selector: FlowNodePropertySelector = editor.get_node_property_selector()
	_check(
		selector != null and selector.visible,
		"Choosing a node opens the compatible property selector."
	)
	var list: ItemList = selector.find_child("PropertyList", true, false) as ItemList
	var position_index: int = _property_index(list, &"position")
	_check(position_index >= 0, "Compatible selector exposes Target.position.")
	if position_index >= 0:
		list.select(position_index)
		list.item_selected.emit(position_index)
		var confirm: Button = selector.find_child(
			"ConfirmNodeProperty",
			true,
			false
		) as Button
		_check(
			confirm != null and not confirm.disabled,
			"Selecting Target.position enables Confirm."
		)
		if confirm != null:
			confirm.pressed.emit()
	await _frames(3)

	var segment: FlowNodePropertyRefSegment = _first_node_property(document)
	_check(segment != null, "Confirm creates one Node Property Tok.")
	var source: FlowNodePropertyRefValueSource = 		segment.get_value_source() as FlowNodePropertyRefValueSource 		if segment != null else null
	_check(
		source != null
			and source.property_name == &"position"
			and source.declared_value_type == Variant.Type.TYPE_VECTOR2
			and not source.requirement_id.is_empty(),
		"Direct controller child is promoted to a Requirement-backed NodePropertyRef."
	)
	_check(
		graph.constructor.requirements.size() == 1
			and controller.requirement_bindings.size() == 1,
		"Confirm creates one Requirement and one scene-local binding."
	)
	_check(
		segment != null
			and segment.get_chip_label() == "$Target.position"
			and segment.slot_id == "scene_value",
		"Node Property Tok has the expected preview and slot metadata."
	)
	_check(
		document.segments.size() == 3
			and (document.segments[0] as FlowTextSegment).text == "Before ",
		"Node Property insertion removes only the $ trigger."
	)

	var context: FlowValueResolutionContext = FlowValueResolutionContext.new(
		graph,
		controller,
		controller
	)
	_check_result(
		source.resolve(context),
		Vector2(7.0, 11.0),
		Variant.Type.TYPE_VECTOR2,
		"Inserted Requirement-backed Tok resolves the live property."
	)

	var history: UndoRedo = _history(document)
	history.undo()
	_check(
		_first_node_property(document) == null,
		"First Undo removes only the Node Property Tok."
	)
	_check(
		graph.constructor.requirements.size() == 1,
		"Requirement binding remains after Tok Undo because it is a separate scene-model action."
	)
	history.undo()
	_check(
		graph.constructor.requirements.is_empty()
			and controller.requirement_bindings.is_empty(),
		"Second Undo removes the auto-created Requirement and binding."
	)
	history.redo()
	history.redo()
	_check(
		_first_node_property(document) != null
			and graph.constructor.requirements.size() == 1
			and controller.requirement_bindings.size() == 1,
		"Two Redos restore Requirement binding and Node Property Tok."
	)

	editor.queue_free()
	controller.free()


func _property_index(list: ItemList, property_name: StringName) -> int:
	if list == null:
		return -1
	for index: int in list.item_count:
		var descriptor: Dictionary = list.get_item_metadata(index) as Dictionary
		if StringName(descriptor.get("name", &"")) == property_name:
			return index
	return -1


func _new_editor(
		schema: FlowChipFieldSchema,
		document: FlowStructuredDocument
) -> FlowChipFieldEditor:
	var editor: FlowChipFieldEditor = FlowChipFieldEditor.new()
	editor.size = Vector2(900.0, 560.0)
	_host.add_child(editor)
	editor.configure_field(schema, document, _undo_redo, document)
	return editor


func _node_property_schema() -> FlowChipFieldSchema:
	var field: FlowChipFieldSchema = FlowChipFieldSchema.new()
	field.mode = FlowChipFieldSchema.Mode.FLEXIBLE
	field.text_mode = FlowChipFieldSchema.TextMode.RUNTIME_CONTENT
	field.accepted_value_types = [
		Variant.Type.TYPE_BOOL,
		Variant.Type.TYPE_INT,
		Variant.Type.TYPE_FLOAT,
		Variant.Type.TYPE_STRING,
		Variant.Type.TYPE_VECTOR2,
		Variant.Type.TYPE_VECTOR3,
		Variant.Type.TYPE_COLOR,
		Variant.Type.TYPE_NODE_PATH,
	]
	field.accepted_source_kinds = [
		FlowValueSource.SOURCE_KIND_NODE_PROPERTY_REF,
	]
	field.flexible_max_count = 4
	var slot: FlowChipSlotDefinition = FlowChipSlotDefinition.new(
		"scene_value",
		"Scene Value"
	)
	slot.repeatable = true
	slot.max_count = 4
	slot.accepted_value_types = field.accepted_value_types.duplicate()
	slot.accepted_source_kinds = [
		FlowValueSource.SOURCE_KIND_NODE_PROPERTY_REF,
	]
	field.variadic_slot_definition = slot
	field.add_text_part("")
	field.add_slot_part("scene_value")
	return field


func _text_document(value: String) -> FlowStructuredDocument:
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	var text: FlowTextSegment = FlowTextSegment.new()
	text.text = value
	document.segments = [text]
	return document


func _first_node_property(
		document: FlowStructuredDocument
) -> FlowNodePropertyRefSegment:
	for candidate: FlowDocumentSegment in document.segments:
		if candidate is FlowNodePropertyRefSegment:
			return candidate as FlowNodePropertyRefSegment
	return null


func _history(document: FlowStructuredDocument) -> UndoRedo:
	return _undo_redo.get_history_undo_redo(
		_undo_redo.get_object_history_id(document)
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


func _frames(count: int = 1) -> void:
	for _index: int in count:
		await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("[Flujo] NodeProperty editor check failed: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] NodeProperty Lot 04 editor test passed")
	else:
		push_error(
			"[Flujo] NodeProperty Lot 04 editor test failed: %d failures" 				% _failures.size()
		)
	quit(0 if _failures.is_empty() else 1)
