@tool
extends SceneTree

## Potok 7D-1: reuse Condition Tok popup on selected transition, safe cancel.
var failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	for i: int in 5:
		await process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	var host := Control.new()
	host.size = Vector2(1100, 800)
	get_root().add_child(host)
	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var idle := FlowStateDefinition.new()
	var run := FlowStateDefinition.new()
	var edge := FlowStateTransitionDefinition.new()
	edge.trigger = FlowStateTransitionDefinition.Trigger.EVENT
	edge.event_name = &"go"
	edge.target_state_id = run.get_internal_id()
	idle.transitions = [edge]
	var machine := FlowStateMachineDefinition.new()
	machine.states = [idle, run]
	machine.initial_state_id = idle.get_internal_id()
	graph.state_machines = [machine]
	var controller := PVController.new()
	controller.flow_graph = graph
	host.add_child(controller)
	var property := FlowGraphInspectorProperty.new()
	property.configure(manager)
	property.configure_for_fluo()
	host.add_child(property)
	property.set_dock_controller(controller)
	property.set_dock_variable_selection(controller, FlowGraphEditorCommands.Collection.STATE_MACHINES,
		machine.get_internal_id())
	await _frames(6)
	var button: Button = property.find_child("PotokTransitionConditionEdit", true, false) as Button
	_check(button != null, "Flusso exposes Edit Condition # on selected event edge")
	if button == null:
		await _done(host)
		return
	var history: UndoRedo = manager.get_history_undo_redo(manager.get_object_history_id(controller))
	_check(not history.has_undo(), "No edits in history before popup opens")
	button.pressed.emit()
	await _frames(4)
	var popup: FlowConditionEditor = property.find_child("FlowConditionEditor", true, false) as FlowConditionEditor
	_check(popup != null and popup.visible, "Existing Condition Tok editor opens")
	_check(edge.condition == null and not history.has_undo(), "Opening is read-only")
	if popup != null:
		_check(not popup.can_confirm(), "Empty condition is not valid")
		popup.call("_cancel")
	await _frames(5)
	_check(edge.condition == null and not history.has_undo(),
		"Cancel never changes model or creates history")
	button = property.find_child("PotokTransitionConditionEdit", true, false) as Button
	button.pressed.emit()
	await _frames(3)
	popup = property.find_child("FlowConditionEditor", true, false) as FlowConditionEditor
	var source := _condition(true)
	if popup != null:
		popup.set_draft(source)
		_check(popup.can_confirm(), "Well-typed Bool comparison accepted")
		popup.call("_confirm")
	await _frames(6)
	var stored: FlowConditionValueSource = edge.condition as FlowConditionValueSource
	_check(stored != null and stored.is_valid(graph), "Confirmed Condition # saved in authored edge")
	_check(stored != null and stored.source_id != source.source_id,
		"Stored condition detached from editor draft")
	_check(edge.trigger == FlowStateTransitionDefinition.Trigger.EVENT,
		"Saving source does not silently switch EVENT trigger")
	_check(history.has_undo(), "Condition confirmation creates one undo action")
	history.undo()
	await _frames(5)
	_check(edge.condition == null, "Undo restores no original condition")
	history.redo()
	await _frames(5)
	_check(edge.condition == stored, "Redo restores same confirmed condition identity")
	var commands := FlowGraphEditorCommands.new(manager)
	_check(commands.set_fsm_transition_property(controller,machine.get_internal_id(),
		idle.get_internal_id(),edge.get_internal_id(), &"trigger",
		FlowStateTransitionDefinition.Trigger.CONDITION), "Ready Bool condition permits trigger switch")
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Valid condition graph accepted")
	# Edit an existing source, then close without confirming: old source must remain.
	button = property.find_child("PotokTransitionConditionEdit", true, false) as Button
	button.pressed.emit()
	await _frames(3)
	popup = property.find_child("FlowConditionEditor", true, false) as FlowConditionEditor
	if popup != null:
		popup.set_draft(_condition(false))
		popup.close_requested.emit()
	await _frames(4)
	_check(edge.condition == stored, "Window close discards editing existing source")
	# The selection can move while a draft popup is open. Its old confirmation cannot write.
	button = property.find_child("PotokTransitionConditionEdit", true, false) as Button
	button.pressed.emit()
	await _frames(3)
	popup = property.find_child("FlowConditionEditor", true, false) as FlowConditionEditor
	if popup != null:
		popup.set_draft(_condition(false))
		var states: ItemList = property.find_child("PotokStateList", true, false) as ItemList
		states.select(1)
		states.item_selected.emit(1)
		# Simulate a late Confirm callback during the same frame, before
		# queue_free() reclaims the invalidated popup.
		if is_instance_valid(popup):
			popup.call("_confirm")
	await _frames(4)
	_check(edge.condition == stored, "Stale popup after state selection cannot commit")
	_check(property.find_child("FlowConditionEditor", true, false) == null,
		"Condition popup closed and invalidated on selection change")
	_check(not FlowGraphValidator.validate(graph).has_errors(),
		"Undo redo cancel and stale guard leave graph valid")
	host.queue_free()
	await _frames(4)
	if failures.is_empty():
		print("[Flujo] Potok 7D-1 Condition Tok Flusso bridge passed")
	quit(0 if failures.is_empty() else 1)

func _condition(left: bool) -> FlowConditionValueSource:
	return FlowConditionValueSource.new([
		FlowConditionComparison.new(
			FlowConditionOperatorCatalog.OPERATOR_EQUAL,
			FlowLiteralValueSource.new(Variant.Type.TYPE_BOOL, left),
			FlowLiteralValueSource.new(Variant.Type.TYPE_BOOL, true)
		)
	], [])

func _frames(n: int) -> void:
	for i: int in n:
		await process_frame

func _done(host: Control) -> void:
	host.queue_free()
	await _frames(3)
	quit(1)

func _check(ok: bool, why: String) -> void:
	if not ok:
		failures.append(why)
		push_error("[Flujo] Potok 7D-1: " + why)
