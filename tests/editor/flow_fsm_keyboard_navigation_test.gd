@tool
extends SceneTree

## Potok 7E-2A: actual Fluo key routing, state identity, and focus ownership.
## Headless key-path coverage; physical keyboard and Inspector visual sync need manual QA.
var failures: Array[String] = []
var _host: Control
var _drawer: FluoDrawer
var _editor: FlowGraphInspectorProperty


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for _i: int in 5:
		await process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame

	var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	var base: Control = EditorInterface.get_base_control()
	if not _check(manager != null and base != null, "Editor context available"):
		quit(1)
		return

	_host = Control.new()
	_host.name = "Potok7E2AHost"
	_host.size = Vector2(960, 720)
	get_root().add_child(_host)

	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var first := FlowStateDefinition.new()
	first.display_name = "Same name"
	var second := FlowStateDefinition.new()
	second.display_name = "Same name"
	var third := FlowStateDefinition.new()
	third.display_name = "Third"
	var machine := FlowStateMachineDefinition.new()
	machine.display_name = "Main"
	machine.states = [first, second, third]
	machine.initial_state_id = first.get_internal_id()
	var empty := FlowStateMachineDefinition.new()
	empty.display_name = "Draft"
	graph.state_machines = [machine, empty]
	var process := FlowProcess.new()
	process.display_name = "Other process"
	graph.processes = [process]
	var controller := PVController.new()
	controller.name = "Controller"
	controller.flow_graph = graph
	_host.add_child(controller)

	var mid: String = machine.get_internal_id()
	var draft_id: String = empty.get_internal_id()
	var a: String = first.get_internal_id()
	var b: String = second.get_internal_id()
	var c: String = third.get_internal_id()
	_check(not FlowGraphValidator.validate(graph).has_errors(), "Initial authored graph validates")
	_check(a != b and first.display_name == second.display_name,
		"Duplicate labels deliberately require stable-ID navigation")

	var inspector := PVControllerInspectorPlugin.new()
	var activations: Array[String] = []
	inspector.schema_3_container_activated.connect(
		func(_ctrl: PVController, collection: FlowGraphEditorCommands.Collection, id: String) -> void:
			activations.append("%d:%s" % [int(collection), id])
	)
	inspector.call("_on_schema_3_container_activated",
		controller, FlowGraphEditorCommands.Collection.STATE_MACHINES, mid)
	_check(activations == ["%d:%s" % [int(FlowGraphEditorCommands.Collection.STATE_MACHINES), mid]],
		"Inspector activation relay preserves the same machine stable ID")

	_drawer = FluoDrawer.new()
	base.add_child(_drawer)
	_drawer.configure(manager)
	var navigation: Array[String] = []
	_drawer.schema_3_container_navigation_changed.connect(
		func(_ctrl: PVController, collection: FlowGraphEditorCommands.Collection, id: String) -> void:
			navigation.append("%d:%s" % [int(collection), id])
	)
	_drawer.open_container(controller,
		FlowGraphEditorCommands.Collection.STATE_MACHINES, mid)
	await _frames(5)
	_editor = _drawer.find_child("FluoFlowEditor", true, false) as FlowGraphInspectorProperty
	var list: ItemList = _states()
	if not _check(_drawer.is_open() and _editor != null and list != null,
			"Potok opens in existing Fluo Flow with state ItemList"):
		await _finish()
		return
	_check(list.item_count == 3 and list.has_focus() and _state_id() == a,
		"Initial Flow list has focus and selects first authored state ID")
	_check((list.get_item_metadata(1) as Dictionary).get("id") == b,
		"Equal state labels still have distinct row metadata IDs")

	# Native ItemList selection signal is shared by Up/Down and pointer selection.
	_check(_native_select(1), "ItemList selects second equal-label state")
	await _frames(4)
	_check(_state_id() == b and _list_focused(),
		"Native selection signal rebuilds Flow and restores keyboard focus")
	_key_to_drawer(KEY_PAGEDOWN, true)
	await _frames(4)
	_check(_state_id() == c and _list_focused(),
		"Ctrl+PageDown moves to third state and restores Flow focus")
	_key_to_drawer(KEY_PAGEDOWN, true)
	await _frames(4)
	_check(_state_id() == a and _list_focused(),
		"Ctrl+PageDown wraps to first ID, not an equal display name")
	_key_to_drawer(KEY_PAGEUP, true)
	await _frames(4)
	_check(_state_id() == c and _list_focused(),
		"Ctrl+PageUp wraps backwards to third ID")
	_check(_machine_id() == mid and navigation.is_empty(),
		"State navigation never changes Inspector machine selection")

	# Plain Page keys must not interrupt a Potok form text-editing session.
	var name_input: LineEdit = _drawer.find_child(
		"PotokStateName", true, false
	) as LineEdit
	if _check(name_input != null, "Current Potok state exposes a native editable name field"):
		name_input.grab_focus()
		await _frames(2)
		_check(name_input.has_focus(), "Potok text editor owns focus")
		_key_to_drawer(KEY_PAGEDOWN)
		await _frames(2)
		_check(_state_id() == c and _machine_id() == mid and
			name_input.has_focus() and navigation.is_empty(),
			"Plain PageDown leaves machine, state and text editing intact")
		_key_to_drawer(KEY_PAGEDOWN, true)
		await _frames(4)
		_check(_state_id() == a and _list_focused(),
			"Ctrl+PageDown from Potok text field navigates state and refocuses Flow")

	_key_to_drawer(KEY_PAGEDOWN, true, true)
	await _frames(2)
	_check(_state_id() == a and _machine_id() == mid,
		"Unsupported Ctrl+Alt+PageDown cannot steal state/machine selection")

	# External authored array reorder is not an editor key side effect.
	machine.states = [third, first, second]
	_editor.refresh_dock_controller()
	await _frames(4)
	list = _states()
	_check(_state_id() == a and list != null and list.item_count == 3 and
		list.get_selected_items().size() == 1 and list.get_selected_items()[0] == 1,
		"Reordered view tracks selected stable ID instead of the old row index")
	_check(_native_select(2), "Native selection moves to same-label state after reorder")
	await _frames(4)
	_check(_state_id() == b and _list_focused(),
		"After reorder, new ItemList selection retains correct ID and focus")

	# Editor fields outside the Fluo drawer keep their own Page shortcuts.
	var outside := LineEdit.new()
	outside.name = "ForeignEditor"
	outside.focus_mode = Control.FOCUS_ALL
	outside.size = Vector2(200, 36)
	_host.add_child(outside)
	outside.grab_focus()
	await _frames(2)
	_check(outside.has_focus(), "Foreign control can own editor keyboard focus")
	_key_to_drawer(KEY_PAGEDOWN, true)
	_key_to_drawer(KEY_PAGEUP)
	await _frames(2)
	_check(outside.has_focus() and _state_id() == b and _machine_id() == mid
		and navigation.is_empty(),
		"Foreign editor Page/Ctrl+Page shortcuts never change Potok selection")

	# Return to Flow; page keys now navigate authored machines with Inspector relay.
	list = _states()
	if list != null:
		list.grab_focus()
	await _frames(2)
	_check(_list_focused(), "Returning focus to Potok Flow is possible")
	_key_to_drawer(KEY_PAGEDOWN)
	await _frames(4)
	_check(_machine_id() == draft_id and navigation == [
		"%d:%s" % [int(FlowGraphEditorCommands.Collection.STATE_MACHINES), draft_id]
	], "Plain PageDown selects Draft machine by ID and signals Inspector sync")
	list = _states()
	_check(_list_focused() and list != null and list.item_count == 1 and
		list.get_item_text(0) == "Empty" and empty.states.is_empty(),
		"Empty state view stays inert and receives Flow focus")
	_key_to_drawer(KEY_PAGEDOWN, true)
	await _frames(2)
	_check(_machine_id() == draft_id and empty.states.is_empty(),
		"Ctrl+PageDown cannot create or select a phantom Empty state")
	_key_to_drawer(KEY_PAGEUP)
	await _frames(4)
	_check(_machine_id() == mid and _state_id() == c and _list_focused()
		and navigation.size() == 2 and
		navigation[1] == "%d:%s" % [int(FlowGraphEditorCommands.Collection.STATE_MACHINES), mid],
		"Plain PageUp returns to original machine, its first ID and Flow focus")
	_check(graph.processes.size() == 1 and
		graph.processes[0].get_internal_id() == process.get_internal_id()
		and graph.state_machines[0].states[0].get_internal_id() == c
		and graph.state_machines[0].states[1].get_internal_id() == a
		and graph.state_machines[0].states[2].get_internal_id() == b
		and machine.initial_state_id == a and not FlowGraphValidator.validate(graph).has_errors(),
		"Keyboard interactions neither mutate model nor enter adjacent Process route")

	await _finish()


func _machine_id() -> String:
	return String(_editor.get("_selected_id")) if _editor != null else ""


func _state_id() -> String:
	return String(_editor.get("_potok_selected_state_id")) if _editor != null else ""


func _states() -> ItemList:
	return _drawer.find_child("PotokStateList", true, false) as ItemList \
		if _drawer != null else null


func _list_focused() -> bool:
	var list: ItemList = _states()
	return list != null and list.has_focus()


func _native_select(index: int) -> bool:
	var list: ItemList = _states()
	if list == null or index < 0 or index >= list.item_count:
		return false
	list.select(index)
	list.item_selected.emit(index)
	return true


func _key_to_drawer(keycode: Key, ctrl: bool = false, alt: bool = false) -> void:
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = keycode
	key.ctrl_pressed = ctrl
	key.alt_pressed = alt
	_drawer.call("_input", key)


func _frames(count: int) -> void:
	for _i: int in count:
		await process_frame


func _check(ok: bool, message: String) -> bool:
	if not ok:
		failures.append(message)
		push_error("[Flujo] Potok 7E-2A: " + message)
	return ok


func _finish() -> void:
	if _drawer != null:
		_drawer.close()
		_drawer.set_controller(null)
		_drawer.queue_free()
	if _host != null:
		_host.queue_free()
	await _frames(3)
	if failures.is_empty():
		print("[Flujo] Potok 7E-2A keyboard machine/state selection and focus passed")
	quit(0 if failures.is_empty() else 1)
