@tool
extends SceneTree


const MANUAL_FIXTURE_ROOT: String = "res://tests/fixtures/manual_block_sdk"
const AUTHORING_CONTEXT_SCRIPT: Script = preload(
	"res://addons/vp_flujo/editor/flow_editor_block_authoring_context.gd"
)


var _failures: Array[String] = []
var _host: Control
var _property: FlowGraphInspectorProperty
var _controller: PVController
var _process: FlowProcess


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _frames()
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if undo_redo == null:
		_failures.append("Editor undo/redo manager is unavailable.")
		_finish()
		return
	await _test_builtin_revert(undo_redo)
	await _test_external_manual_output(undo_redo)
	_finish()


func _test_builtin_revert(undo_redo: EditorUndoRedoManager) -> void:
	await _mount_surface(undo_redo, AUTHORING_CONTEXT_SCRIPT.new() as RefCounted, "Builtin")
	var editor: FlowReadyProcessEditor = _editor()
	var add_print: Button = _button(editor, "Add Print")
	_check(add_print != null, "Built-in Flow exposes the existing Add Print control.")
	if add_print == null:
		await _unmount_surface()
		return
	add_print.pressed.emit()
	await _frames()
	var block: FlowBlock = _process.blocks[0] if _process.blocks.size() == 1 else null
	_check(block is FlowPrintBlock, "Built-in Add creates the existing Print block.")
	if block == null:
		await _unmount_surface()
		return
	var block_id: String = block.get_internal_id()
	var list: ItemList = _node(_editor(), "ReadyBlocksList") as ItemList
	_check(list != null and list.item_count == 1, "Built-in Flow exposes the selected block row.")
	if list == null:
		await _unmount_surface()
		return
	list.item_activated.emit(0)
	await _frames()
	var options: PanelContainer = _node(_property, "BlockOptionsPanel") as PanelContainer
	_check(options != null and options.visible, "Built-in block opens its Flusso options.")
	var name_input: LineEdit = _node(options, "ReadyBlockName") as LineEdit
	var enabled: CheckBox = _node(options, "ReadyBlockEnabled") as CheckBox
	var print_text: TextEdit = _node(options, "ReadyPrintText") as TextEdit
	_check(name_input != null and enabled != null and print_text != null,
		"Built-in Flusso exposes every existing Print editing control.")
	if name_input == null or enabled == null or print_text == null:
		await _unmount_surface()
		return
	var snapshot: Dictionary = _snapshot(block_id)
	_check(snapshot.has(&"display_name") and snapshot.has(&"enabled") and snapshot.has(&"text"),
		"Built-in opening snapshot contains every property owned by the existing controls.")
	_check(snapshot.has(&"user_note") and not snapshot.has(&"message"),
		"Built-in opening snapshot includes the rendered generic note but no external message.")
	_check(_node(options, "GenericPropertyText_text") == null and _node(options, "GenericPropertyMultiline_text") == null,
		"Built-in Print text is not duplicated by the generic renderer.")
	name_input.text = "Changed Print Name"
	name_input.text_changed.emit(name_input.text)
	enabled.toggled.emit(false)
	print_text.text = "Changed Print Text"
	print_text.text_changed.emit()
	_check(
		block.display_name == "Changed Print Name" and not block.enabled \
			and (block as FlowPrintBlock).text == "Changed Print Text",
		"Built-in controls edit their persistent properties immediately."
	)
	var revert_button: Button = _button(options, "Revertir")
	_check(revert_button != null, "Built-in Flusso exposes Revertir.")
	if revert_button != null:
		revert_button.pressed.emit()
	await _frames()
	_check(
		block.display_name == "Print" and block.enabled and (block as FlowPrintBlock).text.is_empty(),
		"Built-in Revertir restores every property edited by the existing controls."
	)
	await _unmount_surface()


func _test_external_manual_output(undo_redo: EditorUndoRedoManager) -> void:
	var context: RefCounted = AUTHORING_CONTEXT_SCRIPT.new(MANUAL_FIXTURE_ROOT) as RefCounted
	await _mount_surface(undo_redo, context, "ManualOutput")
	var manual_button: Button = _authoring_button(_editor(), "manual_output:output")
	_check(manual_button != null, "D3 Flow Add exposes the manual_output:output entry.")
	if manual_button == null:
		await _unmount_surface()
		return
	manual_button.pressed.emit()
	await _frames()
	var external_block: FlowBlock = _process.blocks[0] if _process.blocks.size() == 1 else null
	_check(external_block != null, "D3 Add creates the external manual output instance.")
	if external_block == null:
		await _unmount_surface()
		return
	var flow_id: String = external_block.get_internal_id()
	var script_path: String = external_block.get_script().resource_path
	var message: String = String(external_block.get(&"message"))
	_check(message == "Hello from the manual SDK", "The manual output starts with its exported message.")

	var list: ItemList = _node(_editor(), "ReadyBlocksList") as ItemList
	_check(list != null and list.item_count == 1, "External Add exposes the new Flow row.")
	if list == null:
		await _unmount_surface()
		return
	list.item_activated.emit(0)
	await _frames()
	var options: PanelContainer = _node(_property, "BlockOptionsPanel") as PanelContainer
	_check(options != null and options.visible, "External block opens the normal Flusso options.")
	var message_input: LineEdit = _node(options, "GenericPropertyText_message") as LineEdit
	_check(message_input != null, "Flusso renders the external message through a generic String control.")
	var snapshot: Dictionary = _snapshot(flow_id)
	_check(snapshot.has(&"display_name") and snapshot.has(&"enabled"),
		"External opening snapshot contains the generic properties owned by Flusso controls.")
	_check(snapshot.has(&"message"), "Rendered external message is included in the opening snapshot.")
	_check(String(external_block.get(&"message")) == message,
		"Opening Flusso does not modify the external message.")

	var name_input: LineEdit = _node(options, "ReadyBlockName") as LineEdit
	var enabled: CheckBox = _node(options, "ReadyBlockEnabled") as CheckBox
	_check(name_input != null and enabled != null, "External block retains the generic owned controls.")
	if name_input != null:
		name_input.text = "Changed Manual Output"
		name_input.text_changed.emit(name_input.text)
	if enabled != null:
		enabled.toggled.emit(false)
	if message_input != null:
		message_input.text = "Changed Manual Message"
		message_input.text_changed.emit(message_input.text)
	_check(external_block.display_name == "Changed Manual Output" and not external_block.enabled,
		"External block can edit its generic Flusso-owned properties.")
	_check(String(external_block.get(&"message")) == "Changed Manual Message",
		"External message edit changes the actual block property.")
	var revert_button: Button = _button(options, "Revertir")
	_check(revert_button != null, "External block exposes the same Revertir control.")
	if revert_button != null:
		revert_button.pressed.emit()
	await _frames()
	_check(
		external_block.display_name == "Manual Output" and external_block.enabled \
			and String(external_block.get(&"message")) == message,
		"External Revertir restores built-in and generic owned properties."
	)
	_check(
		external_block.get_internal_id() == flow_id \
			and external_block.get_script().resource_path == script_path \
			and external_block == _process.blocks[0],
		"External Revertir preserves FlowId, script, and block instance."
	)

	options = _node(_property, "BlockOptionsPanel") as PanelContainer
	var close_button: Button = _node(options, "CloseBlockOptions") as Button
	_check(close_button != null, "External Flusso exposes its close control.")
	if close_button != null:
		close_button.pressed.emit()
	await _frames()
	list = _node(_editor(), "ReadyBlocksList") as ItemList
	var closed_options: PanelContainer = _node(_property, "BlockOptionsPanel") as PanelContainer
	_check(list != null and closed_options != null and not closed_options.visible,
		"Closing Flusso leaves the Flow row available for reopening.")
	if list != null:
		list.item_activated.emit(0)
	await _frames()
	options = _node(_property, "BlockOptionsPanel") as PanelContainer
	_check(options != null and options.visible, "The same external block can reopen in Flusso.")
	_check(_node(options, "GenericPropertyText_message") != null,
		"Reopening keeps the generic external message control.")
	_check(
		String(external_block.get(&"message")) == message \
			and external_block.get_internal_id() == flow_id \
			and external_block.get_script().resource_path == script_path \
			and external_block == _process.blocks[0],
		"Closing and reopening preserves external message, FlowId, script, and instance."
	)
	_check(_snapshot(flow_id).has(&"message"), "Reopening starts a new snapshot that owns the rendered message.")
	await _unmount_surface()


func _mount_surface(undo_redo: EditorUndoRedoManager, context: RefCounted, label: String) -> void:
	_host = Control.new()
	_host.name = "FlussoOwnedProperties" + label
	_host.size = Vector2(1200.0, 900.0)
	get_root().add_child(_host)
	_process = FlowProcess.new()
	_process.display_name = "Ready Test"
	_controller = PVController.new()
	_controller.name = "FlussoOwnedController" + label
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	graph.processes = [_process]
	_controller.flow_graph = graph
	_host.add_child(_controller)
	_property = FlowGraphInspectorProperty.new()
	_property.configure(undo_redo, context)
	_property.configure_for_fluo()
	_property.size = Vector2(900.0, 800.0)
	_host.add_child(_property)
	_property.set_dock_controller(_controller)
	_property.set_dock_variable_selection(
		_controller,
		FlowGraphEditorCommands.Collection.PROCESSES,
		_process.get_internal_id()
	)
	await _frames()


func _unmount_surface() -> void:
	if is_instance_valid(_host):
		_host.queue_free()
	await _frames()
	_host = null
	_property = null
	_controller = null
	_process = null


func _editor() -> FlowReadyProcessEditor:
	return _property.find_child("ReadyProcessEditor", true, false) as FlowReadyProcessEditor


func _snapshot(block_id: String) -> Dictionary:
	var snapshots: Dictionary = _property.get("_flusso_snapshots") as Dictionary
	return snapshots.get(block_id, {}) as Dictionary


func _authoring_button(editor: FlowReadyProcessEditor, authoring_id: String) -> Button:
	if editor == null:
		return null
	var add_row: HBoxContainer = _node(editor, "AddBlockActions") as HBoxContainer
	if add_row == null:
		return null
	for child: Node in add_row.get_children():
		if child is Button and child.get_meta(&"authoring_id", "") == authoring_id:
			return child as Button
	return null


func _button(root: Node, text: String) -> Button:
	if root == null:
		return null
	if root is Button and (root as Button).text == text:
		return root as Button
	for child: Node in root.get_children():
		var result: Button = _button(child, text)
		if result != null:
			return result
	return null


func _node(root: Node, node_name: String) -> Node:
	if root == null:
		return null
	if root.name == node_name:
		return root
	return root.find_child(node_name, true, false)


func _contains_message_surface(root: Node) -> bool:
	if root == null:
		return false
	var name: String = String(root.name).to_lower()
	if name.contains("message"):
		return true
	if root is Label and (root as Label).text.to_lower().contains("message"):
		return true
	if root is Button and (root as Button).text.to_lower().contains("message"):
		return true
	if root is CheckBox and (root as CheckBox).text.to_lower().contains("message"):
		return true
	if root is LineEdit and (root as LineEdit).placeholder_text.to_lower().contains("message"):
		return true
	for child: Node in root.get_children():
		if _contains_message_surface(child):
			return true
	return false


func _frames(count: int = 4) -> void:
	for _index: int in count:
		await process_frame


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_failures.append(message)
		push_error(message)
	return condition


func _finish() -> void:
	if is_instance_valid(_host):
		_host.queue_free()
	await _frames(3)
	if _failures.is_empty():
		print("[Flujo] Flusso owned-property Revertir test passed")
	quit(0 if _failures.is_empty() else 1)
