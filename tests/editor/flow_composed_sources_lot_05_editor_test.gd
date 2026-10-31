extends SceneTree


var _failures: Array[String] = []
var _host: Control
var _panel: FlowSceneNodePanel
var _picked_source: FlowNodePropertyRefValueSource = null


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _frames(2)
	_host = Control.new()
	_host.size = Vector2(1000.0, 700.0)
	get_root().add_child(_host)
	_mount_panel()
	await _test_reusable_picker()
	await _test_condition_editor_composition()
	await _test_operation_editor_composition()
	_dispose_panel()
	_host.queue_free()
	_finish()


func _mount_panel() -> void:
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
	_panel.set_meta(&"lot_05_test_owned", true)
	base.add_child(_panel)


func _dispose_panel() -> void:
	if _panel == null:
		return
	_panel.close()
	if bool(_panel.get_meta(&"lot_05_test_owned", false)):
		if _panel.get_parent() != null:
			_panel.get_parent().remove_child(_panel)
		_panel.free()
	_panel = null


func _scene_fixture() -> Dictionary:
	var root: Node = Node.new()
	root.name = "Root"
	var target: Node2D = Node2D.new()
	target.name = "Target"
	target.z_index = 4
	target.position = Vector2(5.0, 6.0)
	root.add_child(target)
	return {"root": root, "target": target}


func _test_reusable_picker() -> void:
	var fixture: Dictionary = _scene_fixture()
	var root: Node = fixture["root"]
	var picker: FlowNodePropertyOperandPicker = FlowNodePropertyOperandPicker.new()
	_host.add_child(picker)
	picker.configure(null, root)
	picker.source_selected.connect(_on_source_picked)
	_picked_source = null
	_check(
		picker.open_for_types([Variant.Type.TYPE_INT], Rect2(10, 10, 1, 1)),
		"Reusable operand picker starts a Scene Node request."
	)
	_check(
		picker.accept_scene_node_payload({
			"type": "flujo_scene_node",
			"node_path": NodePath("Target"),
			"node_name": "Target",
			"class_name": "Node2D",
			"requirement_id": "",
		}),
		"Reusable picker accepts a Scene Node payload."
	)
	await _frames(1)
	var selector: FlowNodePropertySelector = picker.get_selector()
	var list: ItemList = selector.find_child("PropertyList", true, false) as ItemList
	var z_index_item: int = _property_index(list, &"z_index")
	_check(z_index_item >= 0, "Exact int filtering exposes Target.z_index.")
	_check(
		_property_index(list, &"position") < 0,
		"Exact int filtering hides incompatible Target.position."
	)
	if z_index_item >= 0:
		list.select(z_index_item)
		list.item_selected.emit(z_index_item)
		var confirm: Button = selector.find_child(
			"ConfirmNodeProperty",
			true,
			false
		) as Button
		if confirm != null:
			confirm.pressed.emit()
	await _frames(1)
	_check(
		_picked_source != null
			and _picked_source.property_name == &"z_index"
			and _picked_source.declared_value_type == Variant.Type.TYPE_INT,
		"Reusable picker returns one typed NodePropertyRef source."
	)
	picker.queue_free()
	root.free()


func _test_condition_editor_composition() -> void:
	var fixture: Dictionary = _scene_fixture()
	var root: Node = fixture["root"]
	var editor: FlowConditionEditor = FlowConditionEditor.new()
	_host.add_child(editor)
	editor.open_for_condition(
		null,
		null,
		Rect2(30, 30, 1, 1),
		{"scene_root": root}
	)
	await _frames(1)
	var kind: OptionButton = editor.find_child(
		"OperandASourceKind0",
		true,
		false
	) as OptionButton
	_check(
		_has_source_kind(kind, FlowValueSource.SOURCE_KIND_NODE_PROPERTY_REF),
		"Condition source selector includes Node Property."
	)

	var node_source: FlowNodePropertyRefValueSource = FlowNodePropertyRefValueSource.new(
		"",
		NodePath("Target"),
		&"Target",
		&"z_index",
		Variant.Type.TYPE_INT
	)
	var complete: FlowConditionValueSource = FlowConditionValueSource.new(
		[
			FlowConditionComparison.new(
				FlowConditionOperatorCatalog.OPERATOR_GREATER_THAN,
				node_source,
				FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 0)
			)
		],
		[]
	)
	editor.set_draft(complete)
	await _frames(1)
	var choose: Button = editor.find_child(
		"OperandAChooseNodeProperty0",
		true,
		false
	) as Button
	var badge: Label = editor.find_child(
		"OperandATypeBadge0",
		true,
		false
	) as Label
	_check(
		choose != null and choose.text == "$Target.z_index",
		"Condition renders the selected NodeProperty instead of a manual type selector."
	)
	_check(
		badge != null and badge.text == "int",
		"Condition derives the NodeProperty operand type."
	)
	_check(editor.can_confirm(), "Complete NodeProperty Condition can Confirm.")
	editor.hide()
	editor.queue_free()
	root.free()


func _test_operation_editor_composition() -> void:
	var fixture: Dictionary = _scene_fixture()
	var root: Node = fixture["root"]
	var editor: FlowOperationEditor = FlowOperationEditor.new()
	_host.add_child(editor)
	editor.open_for_operation(
		null,
		null,
		Rect2(40, 40, 1, 1),
		{"scene_root": root}
	)
	await _frames(1)
	var kind: OptionButton = editor.find_child(
		"Operand0SourceKind",
		true,
		false
	) as OptionButton
	_check(
		_has_source_kind(kind, FlowValueSource.SOURCE_KIND_NODE_PROPERTY_REF),
		"Operation source selector includes Node Property."
	)

	var node_source: FlowNodePropertyRefValueSource = FlowNodePropertyRefValueSource.new(
		"",
		NodePath("Target"),
		&"Target",
		&"position",
		Variant.Type.TYPE_VECTOR2
	)
	var complete: FlowOperationValueSource = FlowOperationValueSource.new(
		FlowOperationOperatorCatalog.OPERATOR_ADD,
		[
			node_source,
			FlowLiteralValueSource.new(
				Variant.Type.TYPE_VECTOR2,
				Vector2(1.0, 2.0)
			),
		]
	)
	editor.set_draft(complete)
	await _frames(1)
	var choose: Button = editor.find_child(
		"Operand0ChooseNodeProperty",
		true,
		false
	) as Button
	var badge: Label = editor.find_child(
		"Operand0TypeBadge",
		true,
		false
	) as Label
	_check(
		choose != null and choose.text == "$Target.position",
		"Operation renders the selected NodeProperty source."
	)
	_check(
		badge != null and badge.text == "Vector2",
		"Operation derives Vector2 from the selected property."
	)
	_check(editor.can_confirm(), "Complete NodeProperty Operation can Confirm.")
	editor.hide()
	editor.queue_free()
	root.free()


func _on_source_picked(source: FlowNodePropertyRefValueSource) -> void:
	_picked_source = source


func _has_source_kind(menu: OptionButton, source_kind: StringName) -> bool:
	if menu == null:
		return false
	for index: int in menu.item_count:
		if StringName(menu.get_item_metadata(index)) == source_kind:
			return true
	return false


func _property_index(list: ItemList, property_name: StringName) -> int:
	if list == null:
		return -1
	for index: int in list.item_count:
		var descriptor: Dictionary = list.get_item_metadata(index) as Dictionary
		if StringName(descriptor.get("name", &"")) == property_name:
			return index
	return -1


func _frames(count: int = 1) -> void:
	for _index: int in count:
		await process_frame


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("[Flujo] Lot 05 editor check failed: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Lot 05 composed editor test passed")
	else:
		push_error(
			"[Flujo] Lot 05 editor test failed: %d failures" % _failures.size()
		)
	quit(0 if _failures.is_empty() else 1)
