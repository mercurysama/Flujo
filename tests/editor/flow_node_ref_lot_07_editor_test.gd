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
	_check(_undo_redo != null, "NodeRef editor has an Akis history.")
	_host = Control.new()
	_host.size = Vector2(1000.0, 700.0)
	get_root().add_child(_host)
	_mount_test_panel()
	await _test_node_only_direct_insert()
	await _test_both_semantics_chooser()
	await _test_property_only_regression()
	await _test_required_fixed_placeholder_repair()
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
	_panel.set_meta(&"lot_07_test_owned", true)
	base.add_child(_panel)


func _dispose_test_panel() -> void:
	if _panel == null:
		return
	_panel.close()
	if bool(_panel.get_meta(&"lot_07_test_owned", false)):
		if _panel.get_parent() != null:
			_panel.get_parent().remove_child(_panel)
		_panel.free()
	_panel = null


func _test_node_only_direct_insert() -> void:
	var controller: PVController = PVController.new()
	controller.name = "Controller"
	var target: Node2D = Node2D.new()
	target.name = "Target"
	controller.add_child(target)
	var graph: FlowGraph = _schema_4_graph()
	controller.flow_graph = graph
	_panel.set_controller(controller)

	var document: FlowStructuredDocument = _text_document("Before  after")
	var editor: FlowChipFieldEditor = _new_editor(_node_only_schema(), document)
	editor.set_variable_graph(graph)
	editor.set_scene_context(controller, controller)
	await _frames(2)

	var text: FlowTextSegment = document.segments[0] as FlowTextSegment
	editor.set_caret_position(text.segment_id, "Before ".length())
	var input: TextEdit = editor.get_text_control(text.segment_id)
	input.insert_text_at_caret("$")
	await _frames(2)
	_check(_panel.is_open(), "$ opens Scene Nodes for a Node-only field.")

	var accepted: bool = editor.accept_scene_node_payload(_payload("Target", "Node2D"))
	_check(accepted, "Node-only Akis accepts the selected Scene Node.")
	await _frames(3)

	var segment: FlowNodeRefSegment = _first_node_ref(document)
	var source: FlowNodeRefValueSource = 		segment.get_value_source() as FlowNodeRefValueSource 		if segment != null else null
	_check(segment != null, "Node-only selection inserts a NodeRef Tok directly.")
	_check(
		editor.get_scene_reference_choice() != null 			and not editor.get_scene_reference_choice().visible,
		"Node-only schema does not show the Node/Property chooser."
	)
	_check(
		editor.get_node_property_selector() != null 			and not editor.get_node_property_selector().visible,
		"Node-only schema does not open the property selector."
	)
	_check(
		source != null
			and source.get_value_type() == Variant.Type.TYPE_OBJECT
			and source.node_name_hint == &"Target"
			and source.node_class_hint == &"Node2D"
			and not source.requirement_id.is_empty(),
		"Inserted NodeRef derives Object type/class and promotes direct child to Requirement."
	)
	_check(
		segment != null and segment.get_chip_label() == "$Target",
		"Node Tok preview is $Target."
	)
	var context: FlowValueResolutionContext = FlowValueResolutionContext.new(
		graph,
		controller,
		controller
	)
	var resolved: FlowValueResult = source.resolve(context)
	_check(
		resolved.success and resolved.value == target,
		"Inserted Node Tok resolves to the live target Node."
	)

	var history: UndoRedo = _history(document)
	history.undo()
	_check(_first_node_ref(document) == null, "First Undo removes the Node Tok.")
	_check(
		graph.constructor.requirements.size() == 1,
		"Requirement remains after Tok Undo as its own reusable action."
	)
	history.undo()
	_check(
		graph.constructor.requirements.is_empty()
			and controller.requirement_bindings.is_empty(),
		"Second Undo removes auto-created Node Requirement and binding."
	)

	editor.queue_free()
	controller.free()


func _test_both_semantics_chooser() -> void:
	var root: Node = Node.new()
	root.name = "Root"
	var target: Node2D = Node2D.new()
	target.name = "Target"
	root.add_child(target)
	_panel.set_controller(null)

	var document: FlowStructuredDocument = _text_document("")
	var editor: FlowChipFieldEditor = _new_editor(_node_or_property_schema(), document)
	editor.set_scene_context(null, root)
	await _frames(2)

	var text: FlowTextSegment = document.segments[0] as FlowTextSegment
	var input: TextEdit = editor.get_text_control(text.segment_id)
	input.insert_text_at_caret("$")
	await _frames(2)
	_check(editor.accept_scene_node_payload(_payload("Target", "Node2D")),
		"Mixed scene-reference field accepts node payload.")
	await _frames(1)

	var choice: FlowSceneReferenceChoice = editor.get_scene_reference_choice()
	_check(choice != null and choice.visible,
		"Field accepting Node and Property shows an explicit semantic chooser.")
	var node_button: Button = choice.find_child("UseSceneNode", true, false) as Button
	var property_button: Button = choice.find_child(
		"ChooseSceneProperty",
		true,
		false
	) as Button
	_check(node_button != null and property_button != null,
		"Chooser exposes Use Node and Choose Property.")
	if node_button != null:
		node_button.pressed.emit()
	await _frames(2)
	_check(_first_node_ref(document) != null,
		"Use Node path creates a NodeRef Tok.")

	editor.queue_free()
	root.free()


func _test_property_only_regression() -> void:
	var root: Node = Node.new()
	root.name = "Root"
	var target: Node2D = Node2D.new()
	target.name = "Target"
	root.add_child(target)

	var document: FlowStructuredDocument = _text_document("")
	var editor: FlowChipFieldEditor = _new_editor(_property_only_schema(), document)
	editor.set_scene_context(null, root)
	await _frames(2)

	var text: FlowTextSegment = document.segments[0] as FlowTextSegment
	var input: TextEdit = editor.get_text_control(text.segment_id)
	input.insert_text_at_caret("$")
	await _frames(2)
	_check(editor.accept_scene_node_payload(_payload("Target", "Node2D")),
		"Property-only field accepts node payload.")
	await _frames(1)
	_check(
		not editor.get_scene_reference_choice().visible,
		"Property-only schema bypasses the semantic chooser."
	)
	_check(
		editor.get_node_property_selector().visible,
		"Property-only schema keeps the Lot-04 property selector flow."
	)
	editor.get_node_property_selector().hide()
	editor.queue_free()
	root.free()


func _test_required_fixed_placeholder_repair() -> void:
	var root: Node = Node.new()
	root.name = "Root"
	var first: Node2D = Node2D.new()
	first.name = "First"
	var second: Node2D = Node2D.new()
	second.name = "Second"
	root.add_child(first)
	root.add_child(second)

	var schema: FlowChipFieldSchema = _required_node_schema()
	var creation: FlowChipFieldCreationResult = FlowChipFieldFactory.new().create(schema)
	_check(creation.document != null,
		"Required Node schema creates a document with an unbound placeholder.")
	if creation.document == null:
		root.free()
		return
	var document: FlowStructuredDocument = creation.document
	var segment: FlowNodeRefSegment = _first_node_ref(document)
	var initial_source: FlowNodeRefValueSource = 		segment.get_value_source() as FlowNodeRefValueSource
	var original_segment_id: String = segment.segment_id
	var original_source_id: String = initial_source.source_id

	var editor: FlowChipFieldEditor = _new_editor(schema, document)
	editor.set_scene_context(null, root)
	await _frames(2)
	_check(
		segment.get_chip_label() == "$Node",
		"Required unbound Node slot renders a semantic $Node placeholder."
	)
	_check(editor.get_chip_control(segment.segment_id).is_invalid(),
		"Placeholder is visibly unresolved once scene context exists.")

	var chip: FlowChipControl = editor.get_chip_control(segment.segment_id)
	var enter: InputEventKey = InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	chip._gui_input(enter)
	await _frames(1)
	_check(_panel.is_open(), "Editing required Node Tok opens Scene Nodes.")
	_check(editor.accept_scene_node_payload(_payload("First", "Node2D")),
		"Required Node placeholder accepts a concrete Node.")
	await _frames(2)

	segment = _first_node_ref(document)
	var source: FlowNodeRefValueSource = segment.get_value_source() as FlowNodeRefValueSource
	_check(
		segment.segment_id == original_segment_id
			and source.source_id == original_source_id
			and segment.get_chip_label() == "$First",
		"Repair preserves segment_id/source_id while binding First."
	)

	chip = editor.get_chip_control(segment.segment_id)
	chip._gui_input(enter)
	await _frames(1)
	_check(editor.accept_scene_node_payload(_payload("Second", "Node2D")),
		"Existing NodeRef can be changed to another Node.")
	await _frames(2)
	segment = _first_node_ref(document)
	source = segment.get_value_source() as FlowNodeRefValueSource
	_check(
		segment.segment_id == original_segment_id
			and source.source_id == original_source_id
			and segment.get_chip_label() == "$Second",
		"Changing Node preserves semantic identities."
	)

	var history: UndoRedo = _history(document)
	history.undo()
	segment = _first_node_ref(document)
	_check(
		segment != null and segment.get_chip_label() == "$First",
		"Undo restores the previous Node reference."
	)
	history.redo()
	segment = _first_node_ref(document)
	_check(
		segment != null and segment.get_chip_label() == "$Second",
		"Redo restores the changed Node reference."
	)

	editor.queue_free()
	root.free()


func _schema_4_graph() -> FlowGraph:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_4
	graph.constructor = FlowConstructorDefinition.new()
	return graph


func _node_only_schema() -> FlowChipFieldSchema:
	var field: FlowChipFieldSchema = FlowChipFieldSchema.new()
	field.mode = FlowChipFieldSchema.Mode.FLEXIBLE
	field.text_mode = FlowChipFieldSchema.TextMode.RUNTIME_CONTENT
	field.accepted_value_types = [Variant.Type.TYPE_OBJECT]
	field.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_NODE_REF]
	field.flexible_max_count = 4
	var slot: FlowChipSlotDefinition = FlowChipSlotDefinition.new("node", "Node")
	slot.repeatable = true
	slot.max_count = 4
	slot.accepted_value_types = [Variant.Type.TYPE_OBJECT]
	slot.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_NODE_REF]
	field.variadic_slot_definition = slot
	field.add_text_part("")
	field.add_slot_part("node")
	return field


func _node_or_property_schema() -> FlowChipFieldSchema:
	var field: FlowChipFieldSchema = FlowChipFieldSchema.new()
	field.mode = FlowChipFieldSchema.Mode.FLEXIBLE
	field.text_mode = FlowChipFieldSchema.TextMode.RUNTIME_CONTENT
	field.accepted_value_types = [
		Variant.Type.TYPE_OBJECT,
		Variant.Type.TYPE_VECTOR2,
	]
	field.accepted_source_kinds = [
		FlowValueSource.SOURCE_KIND_NODE_REF,
		FlowValueSource.SOURCE_KIND_NODE_PROPERTY_REF,
	]
	field.flexible_max_count = 4
	var slot: FlowChipSlotDefinition = FlowChipSlotDefinition.new(
		"scene_ref",
		"Scene Reference"
	)
	slot.repeatable = true
	slot.max_count = 4
	slot.accepted_value_types = field.accepted_value_types.duplicate()
	slot.accepted_source_kinds = field.accepted_source_kinds.duplicate()
	field.variadic_slot_definition = slot
	field.add_text_part("")
	field.add_slot_part("scene_ref")
	return field


func _property_only_schema() -> FlowChipFieldSchema:
	var field: FlowChipFieldSchema = FlowChipFieldSchema.new()
	field.mode = FlowChipFieldSchema.Mode.FLEXIBLE
	field.text_mode = FlowChipFieldSchema.TextMode.RUNTIME_CONTENT
	field.accepted_value_types = [Variant.Type.TYPE_VECTOR2]
	field.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_NODE_PROPERTY_REF]
	field.flexible_max_count = 4
	var slot: FlowChipSlotDefinition = FlowChipSlotDefinition.new(
		"scene_value",
		"Scene Value"
	)
	slot.repeatable = true
	slot.max_count = 4
	slot.accepted_value_types = [Variant.Type.TYPE_VECTOR2]
	slot.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_NODE_PROPERTY_REF]
	field.variadic_slot_definition = slot
	field.add_text_part("")
	field.add_slot_part("scene_value")
	return field


func _required_node_schema() -> FlowChipFieldSchema:
	var field: FlowChipFieldSchema = FlowChipFieldSchema.new()
	field.mode = FlowChipFieldSchema.Mode.FIXED
	field.text_mode = FlowChipFieldSchema.TextMode.RUNTIME_CONTENT
	field.accepted_value_types = [Variant.Type.TYPE_OBJECT]
	field.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_NODE_REF]
	var slot: FlowChipSlotDefinition = FlowChipSlotDefinition.new(
		"target",
		"Target Node",
		true
	)
	slot.accepted_value_types = [Variant.Type.TYPE_OBJECT]
	slot.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_NODE_REF]
	slot.initial_value_source = FlowNodeRefValueSource.placeholder(&"Node")
	slot.allow_delete = false
	slot.allow_reference_change = true
	slot.min_count = 1
	slot.max_count = 1
	field.slots = [slot]
	field.add_text_part("Target: ")
	field.add_slot_part("target")
	return field


func _payload(node_name: String, class_name: String) -> Dictionary:
	return {
		"type": "flujo_scene_node",
		"node_path": NodePath(node_name),
		"node_name": node_name,
		"class_name": class_name,
		"requirement_id": "",
	}


func _new_editor(
		schema: FlowChipFieldSchema,
		document: FlowStructuredDocument
) -> FlowChipFieldEditor:
	var editor: FlowChipFieldEditor = FlowChipFieldEditor.new()
	editor.size = Vector2(900.0, 560.0)
	_host.add_child(editor)
	editor.configure_field(schema, document, _undo_redo, document)
	return editor


func _text_document(value: String) -> FlowStructuredDocument:
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	var text: FlowTextSegment = FlowTextSegment.new()
	text.text = value
	document.segments = [text]
	return document


func _first_node_ref(document: FlowStructuredDocument) -> FlowNodeRefSegment:
	for candidate: FlowDocumentSegment in document.segments:
		if candidate is FlowNodeRefSegment:
			return candidate as FlowNodeRefSegment
	return null


func _history(document: FlowStructuredDocument) -> UndoRedo:
	return _undo_redo.get_history_undo_redo(
		_undo_redo.get_object_history_id(document)
	)


func _frames(count: int = 1) -> void:
	for _index: int in count:
		await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("[Flujo] NodeRef editor check failed: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] NodeRef Lot 07 editor test passed")
	else:
		push_error(
			"[Flujo] NodeRef Lot 07 editor test failed: %d failures" % _failures.size()
		)
	quit(0 if _failures.is_empty() else 1)
