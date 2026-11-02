@tool
extends SceneTree

## Potok 7D-2: Event field operand is authored only in Potok Tok context.
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	for i: int in 4:
		await process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	var host := Control.new()
	host.size = Vector2(850, 700)
	get_root().add_child(host)
	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var popup := FlowConditionEditor.new()
	host.add_child(popup)
	popup.open_for_condition(null, graph, Rect2(10,10,100,10), {"potok_event_payload": true})
	await _frames(3)
	var kind: OptionButton = popup.find_child("OperandASourceKind0", true, false) as OptionButton
	var index: int = _index(kind, FlowEventPayloadValueSource.SOURCE_KIND)
	_check(index >= 0, "Potok Condition Tok offers Event field source")
	if index >= 0:
		kind.select(index)
		kind.item_selected.emit(index)
	await _frames(3)
	var name: LineEdit = popup.find_child("OperandAEventName0", true, false) as LineEdit
	var field: LineEdit = popup.find_child("OperandAEventField0", true, false) as LineEdit
	var type: OptionButton = popup.find_child("OperandAEventType0", true, false) as OptionButton
	_check(name != null and field != null and type != null, "Event name, field and type are separate")
	_check(not popup.can_confirm(), "Blank field cannot create valid Tok")
	if name != null and field != null and type != null:
		name.text = "hit"
		name.text_changed.emit(name.text)
		field.text = "hp"
		field.text_changed.emit(field.text)
		var target: int = _index(type, int(Variant.Type.TYPE_INT))
		_check(target > 0, "Int type is selectable")
		if target > 0:
			type.select(target)
			type.item_selected.emit(target)
	await _frames(3)
	var operand: FlowEventPayloadValueSource = popup.get_draft().comparisons[0].left_source as FlowEventPayloadValueSource
	_check(operand != null and operand.is_valid(), "Explicit event operand configured")
	if operand != null:
		_check(operand.event_name == &"hit" and operand.field_name == "hp"
			and operand.value_type == Variant.Type.TYPE_INT, "Typed metadata preserved")
	var complete := FlowConditionValueSource.new([
		FlowConditionComparison.new(
			FlowConditionOperatorCatalog.OPERATOR_GREATER_THAN,
			operand, FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 5))
	], [])
	popup.set_draft(complete)
	await _frames(2)
	_check(popup.can_confirm(), "Typed event condition may be confirmed")
	_check(popup.get_draft().get_preview(graph).contains("event(\"hit\").hp"),
		"Preview identifies event and field, not live value")
	var confirmed: Array[FlowConditionValueSource] = []
	popup.condition_confirmed.connect(func(source: FlowConditionValueSource) -> void:
		confirmed.append(source))
	popup.call("_confirm")
	await _frames(2)
	_check(confirmed.size() == 1 and confirmed[0].is_valid(graph),
		"Event field condition saved as typed source")
	var context := FlowValueResolutionContext.new(graph)
	_check(not confirmed[0].resolve(context).success, "No packet means unresolved value")
	context.begin_event_packet_scope("machine")
	context.record_event_packet("machine", &"hit", {"hp": 8})
	_check(confirmed[0].resolve(context).success and confirmed[0].resolve(context).value,
		"Condition reads explicitly scoped int field")
	context.end_event_packet_scope()
	_check(not confirmed[0].resolve(context).success, "End scope clears data")
	var generic := FlowConditionEditor.new()
	host.add_child(generic)
	generic.open_for_condition(null, graph)
	await _frames(2)
	var normal: OptionButton = generic.find_child("OperandASourceKind0", true, false) as OptionButton
	_check(_index(normal, FlowEventPayloadValueSource.SOURCE_KIND) < 0,
		"Unrelated generic Tok editor has no Potok-only Event field option")
	generic.call("_cancel")
	host.queue_free()
	await _frames(4)
	if failures.is_empty():
		print("[Flujo] Potok 7D-2 event payload Tok authoring passed")
	quit(0 if failures.is_empty() else 1)

func _index(menu: OptionButton, value: Variant) -> int:
	if menu == null:
		return -1
	for i: int in menu.item_count:
		if menu.get_item_metadata(i) == value:
			return i
	return -1

func _frames(n: int) -> void:
	for i: int in n:
		await process_frame

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error("[Flujo] Potok 7D-2 Tok: " + message)
