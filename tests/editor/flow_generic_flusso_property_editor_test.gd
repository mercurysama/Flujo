@tool
extends SceneTree


const PROPERTY_FIXTURE_ROOT: String = "res://tests/fixtures/property_descriptors"
const PROPERTY_FIXTURE_SCRIPT: Script = preload(
	"res://tests/fixtures/property_descriptors/manual_output/block.gd"
)
const AUTHORING_CONTEXT_SCRIPT: Script = preload(
	"res://addons/vp_flujo/editor/flow_editor_block_authoring_context.gd"
)
const TEMP_METADATA_ROOT: String = "res://.godot/flujo_tests/d4c_invalid_metadata"


class DescriptorOnlyContext extends RefCounted:
	var metadata_root: String = ""

	func _init(root: String) -> void:
		metadata_root = root

	func get_entries() -> Array[FlowEditorBlockCatalogEntry]:
		return []

	func describe_block_properties(block: FlowBlock) -> FlowBlockPropertyCatalogResult:
		return FlowBlockPropertyCatalog.describe(block, metadata_root, "output")


var _failures: Array[String] = []
var _undo_redo: EditorUndoRedoManager
var _history: UndoRedo
var _host: Control
var _property: FlowGraphInspectorProperty
var _controller: PVController
var _container: FlowProcess


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _frames()
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame
	_undo_redo = EditorInterface.get_editor_undo_redo()
	if _undo_redo == null:
		_failures.append("Editor undo/redo manager is unavailable.")
		_finish()
		return
	await _test_external_scalar_controls_and_revert()
	await _test_process_timer_equivalence()
	await _test_builtin_boundaries_and_call_method()
	await _test_invalid_metadata_fallback()
	_cleanup_temp_metadata()
	_finish()


func _test_external_scalar_controls_and_revert() -> void:
	var block: FlowBlock = PROPERTY_FIXTURE_SCRIPT.new() as FlowBlock
	var context: RefCounted = AUTHORING_CONTEXT_SCRIPT.new(PROPERTY_FIXTURE_ROOT) as RefCounted
	await _mount_surface([block], context)
	await _open_block(0)
	var options: PanelContainer = _node(_property, "BlockOptionsPanel") as PanelContainer
	_check(options != null and options.visible, "External descriptor block opens the generic Flusso surface.")
	if options == null:
		await _unmount_surface()
		return

	var generic: VBoxContainer = _node(options, "GenericBlockProperties") as VBoxContainer
	_check(generic != null, "Flusso mounts one descriptor-driven generic property section.")
	if generic == null:
		await _unmount_surface()
		return

	var boolean_input: CheckBox = _node(generic, "GenericPropertyBoolean_boolean_value") as CheckBox
	var int_input: SpinBox = _node(generic, "GenericPropertyNumeric_ranged_int") as SpinBox
	var float_input: SpinBox = _node(generic, "GenericPropertyNumeric_ranged_float") as SpinBox
	var enum_input: OptionButton = _node(generic, "GenericPropertyEnum_enum_value") as OptionButton
	var message_input: TextEdit = _node(generic, "GenericPropertyMultiline_message") as TextEdit
	var plain_input: LineEdit = _node(generic, "GenericPropertyText_plain_text") as LineEdit
	var string_name_input: LineEdit = _node(generic, "GenericPropertyText_string_name_value") as LineEdit
	_check(boolean_input != null, "bool descriptor renders a CheckBox.")
	_check(int_input != null and int_input.min_value == 0.0 and int_input.max_value == 10.0 and int_input.step == 1.0,
		"int range descriptor configures a constrained integer SpinBox.")
	_check(float_input != null and float_input.min_value == 0.0 and float_input.max_value == 1.0 and is_equal_approx(float_input.step, 0.1),
		"float range descriptor configures a constrained floating-point SpinBox.")
	_check(enum_input != null and enum_input.item_count == 2 and enum_input.get_item_text(0) == "Low" and enum_input.get_item_text(1) == "High",
		"enum descriptor renders an OptionButton with reflected values.")
	_check(message_input != null and plain_input != null and string_name_input != null,
		"String, multiline String, and StringName descriptors render text-oriented controls.")
	_check(message_input != null and message_input.tooltip_text == "Text emitted by this block.",
		"Descriptor tooltip/help is applied to the multiline control.")
	_check(_node(generic, "GenericPropertyLabel_message") is Label \
			and (_node(generic, "GenericPropertyLabel_message") as Label).text == "Output Message",
		"Descriptor label is used instead of a package-specific renderer label.")
	_check(_node(generic, "GenericPropertyGroup_Options") is Label \
			and (_node(generic, "GenericPropertyGroup_Options") as Label).text == "Options" \
			and _node(generic, "GenericPropertyGroup_Output") is Label \
			and (_node(generic, "GenericPropertyGroup_Output") as Label).text == "Output",
		"Descriptor groups render as deterministic generic section headers.")
	_check(_generic_property_order(generic) == [
		"boolean_value",
		"message",
		"enum_value",
		"ranged_int",
		"plain_text",
		"ranged_float",
		"string_name_value",
		"user_note",
	], "Generic controls follow deterministic descriptor order.")

	var block_id: String = block.get_internal_id()
	var owned: Dictionary = _owned(block_id)
	_check(owned.has(&"message") and owned.has(&"boolean_value") and owned.has(&"string_name_value"),
		"Rendered editable descriptors become Flusso-owned for the active block.")
	_check(not owned.has(&"unsupported_vector") and not owned.has(&"read_only_value"),
		"Unsupported and read-only descriptors are not registered as owned.")
	_check(_node(generic, "GenericPropertyText_unsupported_vector") == null,
		"Unsupported descriptor types do not create a phantom control.")
	_check(_node(generic, "GenericPropertyDiagnostics") != null,
		"Descriptor diagnostics are presented safely in the existing Flusso surface.")

	var opening_message: String = String(block.get(&"message"))
	var opening_bool: bool = bool(block.get(&"boolean_value"))
	var opening_int: int = int(block.get(&"ranged_int"))
	var opening_float: float = float(block.get(&"ranged_float"))
	var opening_plain: String = String(block.get(&"plain_text"))
	var opening_name: StringName = block.get(&"string_name_value") as StringName
	var snapshot: Dictionary = _snapshot(block_id)
	_check(snapshot.has(&"message") and snapshot.has(&"boolean_value") and snapshot.has(&"ranged_int"),
		"The session snapshot includes rendered generic properties.")

	if boolean_input != null:
		boolean_input.toggled.emit(false)
	if int_input != null:
		int_input.value_changed.emit(8.0)
	if float_input != null:
		float_input.value_changed.emit(0.8)
	if enum_input != null:
		enum_input.item_selected.emit(0)
	if message_input != null:
		message_input.text = "Edited through Flusso"
		message_input.text_changed.emit()
	if plain_input != null:
		plain_input.text = "Edited plain text"
		plain_input.text_changed.emit(plain_input.text)
	if string_name_input != null:
		string_name_input.text = "edited_name"
		string_name_input.text_changed.emit(string_name_input.text)
	_check(not bool(block.get(&"boolean_value")) and int(block.get(&"ranged_int")) == 8 \
			and is_equal_approx(float(block.get(&"ranged_float")), 0.8),
		"bool, int, and float generic edits update the actual block live.")
	_check(String(block.get(&"message")) == "Edited through Flusso" \
			and String(block.get(&"plain_text")) == "Edited plain text" \
			and (block.get(&"string_name_value") as StringName) == &"edited_name",
		"String, multiline String, and StringName edits update the actual block live.")
	_check(int(block.get(&"enum_value")) == 0, "Enum selection updates the reflected integer value.")

	var revert_button: Button = _button(options, "Revertir")
	_check(revert_button != null, "Generic Flusso keeps the existing Revertir action.")
	if revert_button != null:
		revert_button.pressed.emit()
	await _frames()
	_check(String(block.get(&"message")) == opening_message and bool(block.get(&"boolean_value")) == opening_bool \
			and int(block.get(&"ranged_int")) == opening_int and is_equal_approx(float(block.get(&"ranged_float")), opening_float) \
			and String(block.get(&"plain_text")) == opening_plain and (block.get(&"string_name_value") as StringName) == opening_name,
		"Revertir restores all rendered generic values from the session boundary.")
	_check(options.visible, "Revertir keeps the generic Flusso panel open.")

	options = _node(_property, "BlockOptionsPanel") as PanelContainer
	message_input = _node(options, "GenericPropertyMultiline_message") as TextEdit
	if message_input != null:
		message_input.text = "Live state survives close"
		message_input.text_changed.emit()
	_check(String(block.get(&"message")) == "Live state survives close", "Generic edits remain live before closing Flusso.")
	options = _node(_property, "BlockOptionsPanel") as PanelContainer
	var close_button: Button = _node(options, "CloseBlockOptions") as Button
	if close_button != null:
		close_button.pressed.emit()
	await _frames()
	_check(String(block.get(&"message")) == "Live state survives close", "Closing Flusso does not cancel generic live edits.")
	await _open_block(0)
	_check(String(_snapshot(block_id).get(&"message", "")) == "Live state survives close",
		"Reopening starts a new generic Revertir session from the current live value.")
	await _unmount_surface()


func _test_process_timer_equivalence() -> void:
	var process_block: FlowBlock = PROPERTY_FIXTURE_SCRIPT.new() as FlowBlock
	var process_context: RefCounted = AUTHORING_CONTEXT_SCRIPT.new(PROPERTY_FIXTURE_ROOT) as RefCounted
	await _mount_surface([process_block], process_context, false)
	await _open_block(0)
	var process_options: PanelContainer = _node(_property, "BlockOptionsPanel") as PanelContainer
	var process_signature: Array[String] = _generic_signature(process_options)
	await _unmount_surface()

	var timer_block: FlowBlock = PROPERTY_FIXTURE_SCRIPT.new() as FlowBlock
	var timer_context: RefCounted = AUTHORING_CONTEXT_SCRIPT.new(PROPERTY_FIXTURE_ROOT) as RefCounted
	await _mount_surface([timer_block], timer_context, true)
	await _open_block(0)
	var timer_options: PanelContainer = _node(_property, "BlockOptionsPanel") as PanelContainer
	var timer_signature: Array[String] = _generic_signature(timer_options)
	_check(not process_signature.is_empty() and process_signature == timer_signature,
		"Process and Timer render the same generic descriptor controls for the same block.")
	await _unmount_surface()


func _test_builtin_boundaries_and_call_method() -> void:
	var print_block: FlowBlock = FlowPrintBlock.new()
	var context: RefCounted = AUTHORING_CONTEXT_SCRIPT.new(PROPERTY_FIXTURE_ROOT) as RefCounted
	await _mount_surface([print_block], context)
	var editor: FlowReadyProcessEditor = _editor()
	_check(_button(editor, "Add Call Method") != null, "Add Call Method remains a separate Flow action.")
	await _open_block(0)
	var options: PanelContainer = _node(_property, "BlockOptionsPanel") as PanelContainer
	_check(_node(options, "ReadyPrintText") != null, "Built-in Print keeps its existing text control.")
	_check(_node(options, "GenericPropertyText_text") == null,
		"Built-in Print text is not duplicated by the generic descriptor renderer.")
	_check(_node(options, "GenericPropertyMultiline_user_note") != null,
		"A non-owned built-in property can enter through the ordinary generic descriptor path.")
	await _unmount_surface()

	var method_call: FlowBlock = FlowMethodCallBlock.new()
	var method_context: RefCounted = AUTHORING_CONTEXT_SCRIPT.new(PROPERTY_FIXTURE_ROOT) as RefCounted
	await _mount_surface([method_call], method_context)
	await _open_block(0)
	options = _node(_property, "BlockOptionsPanel") as PanelContainer
	_check(_node(options, "ReadyMethodTarget") != null, "Call Method keeps its existing selector control.")
	_check(_node(options, "GenericPropertyText_method_id") == null,
		"The storage-only method_id remains separate from generic controls.")
	await _unmount_surface()


func _test_invalid_metadata_fallback() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_METADATA_ROOT))
	var metadata: FileAccess = FileAccess.open(
		TEMP_METADATA_ROOT.path_join(FlowBlockPropertyPresentationLoader.FILE_NAME),
		FileAccess.WRITE
	)
	if metadata != null:
		metadata.store_string(JSON.stringify({
			"format_version": 1,
			"block_type_id": "output",
			"properties": [{"property": "does_not_exist", "label": "Phantom"}],
		}))
		metadata.close()
	var block: FlowBlock = PROPERTY_FIXTURE_SCRIPT.new() as FlowBlock
	await _mount_surface([block], DescriptorOnlyContext.new(TEMP_METADATA_ROOT))
	await _open_block(0)
	var options: PanelContainer = _node(_property, "BlockOptionsPanel") as PanelContainer
	_check(_node(options, "GenericPropertyText_does_not_exist") == null,
		"Invalid metadata cannot create a phantom generic control.")
	_check(_node(options, "GenericPropertyDiagnostics") != null,
		"Invalid metadata diagnostics remain visible without crashing Flusso.")
	await _unmount_surface()


func _mount_surface(
		blocks: Array[FlowBlock],
		context: RefCounted,
		is_timer: bool = false
) -> void:
	_host = Control.new()
	_host.name = "GenericFlussoPropertyHost"
	_host.size = Vector2(1400.0, 1000.0)
	get_root().add_child(_host)
	_container = FlowTimerDefinition.new() if is_timer else FlowProcess.new()
	var typed_blocks: Array[FlowBlock] = []
	for block: FlowBlock in blocks:
		typed_blocks.append(block)
	_container.blocks = typed_blocks
	_controller = PVController.new()
	_controller.name = "GenericFlussoPropertyController"
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	graph.processes = [_container]
	_controller.flow_graph = graph
	_host.add_child(_controller)
	_property = FlowGraphInspectorProperty.new()
	_property.configure(_undo_redo, context)
	_property.configure_for_fluo()
	_property.size = Vector2(1200.0, 900.0)
	_host.add_child(_property)
	_property.set_dock_controller(_controller)
	_property.set_dock_variable_selection(
		_controller,
		FlowGraphEditorCommands.Collection.PROCESSES,
		_container.get_internal_id()
	)
	_history = _undo_redo.get_history_undo_redo(_undo_redo.get_object_history_id(_controller))
	await _frames()


func _unmount_surface() -> void:
	if is_instance_valid(_host):
		_host.queue_free()
	await _frames()
	_host = null
	_property = null
	_controller = null
	_container = null
	_history = null


func _open_block(index: int) -> void:
	var list: ItemList = _node(_property, "ReadyBlocksList") as ItemList
	if list == null or index < 0 or index >= list.item_count:
		_failures.append("Could not open generic test block row %d." % index)
		return
	list.item_activated.emit(index)
	await _frames()


func _editor() -> FlowReadyProcessEditor:
	return _property.find_child("ReadyProcessEditor", true, false) as FlowReadyProcessEditor


func _generic_signature(options: PanelContainer) -> Array[String]:
	var signature: Array[String] = []
	var generic: VBoxContainer = _node(options, "GenericBlockProperties") as VBoxContainer
	if generic == null:
		return signature
	for child: Node in generic.get_children():
		if String(child.name).begins_with("GenericProperty"):
			signature.append(String(child.name))
	return signature


func _generic_property_order(generic: VBoxContainer) -> Array[String]:
	var order: Array[String] = []
	for child: Node in generic.get_children():
		var name: String = String(child.name)
		if name.begins_with("GenericPropertyLabel_"):
			order.append(name.trim_prefix("GenericPropertyLabel_"))
	return order


func _owned(block_id: String) -> Dictionary:
	var owned: Dictionary = _property.get("_flusso_owned_properties") as Dictionary
	return owned.get(block_id, {}) as Dictionary


func _snapshot(block_id: String) -> Dictionary:
	var snapshots: Dictionary = _property.get("_flusso_snapshots") as Dictionary
	return snapshots.get(block_id, {}) as Dictionary


func _node(root: Node, node_name: String) -> Node:
	if root == null:
		return null
	if root.name == node_name:
		return root
	return root.find_child(node_name, true, false)


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


func _frames(count: int = 4) -> void:
	for _index: int in count:
		await process_frame


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
		push_error(message)


func _cleanup_temp_metadata() -> void:
	var absolute_root: String = ProjectSettings.globalize_path(TEMP_METADATA_ROOT)
	if not DirAccess.dir_exists_absolute(absolute_root):
		return
	var access: DirAccess = DirAccess.open(absolute_root)
	if access == null:
		return
	for file_name: String in access.get_files():
		DirAccess.remove_absolute(absolute_root.path_join(file_name))
	DirAccess.remove_absolute(absolute_root)


func _finish() -> void:
	if is_instance_valid(_host):
		_host.queue_free()
	await _frames(3)
	if _failures.is_empty():
		print("[Flujo] Generic Flusso property editor test passed")
	quit(0)
	return
	quit(1)
