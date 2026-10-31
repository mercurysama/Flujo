@tool
extends SceneTree


const AUTHORING_CONTEXT_SCRIPT: Script = preload(
	"res://addons/vp_flujo/editor/flow_editor_block_authoring_context.gd"
)
const FPRINT_PACKAGE_ROOT: String = "res://flow_packages/mercury.fprint"
const FPRINT_SCRIPT_PATH: String = FPRINT_PACKAGE_ROOT + "/block.gd"
const FPRINT_AUTHORING_ID: String = "mercury.fprint:fprint"


var _failures: Array[String] = []
var _host: Control
var _property: FlowGraphInspectorProperty
var _controller: PVController
var _process: FlowProcess
var _undo_redo: EditorUndoRedoManager


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
	await _test_fprint_process_authoring(_undo_redo)
	_finish()


func _test_fprint_process_authoring(undo_redo: EditorUndoRedoManager) -> void:
	var context: RefCounted = AUTHORING_CONTEXT_SCRIPT.new() as RefCounted
	var entries: Array[FlowEditorBlockCatalogEntry] = context.call(&"get_entries") as Array[FlowEditorBlockCatalogEntry]
	var entry: FlowEditorBlockCatalogEntry = null
	for candidate: FlowEditorBlockCatalogEntry in entries:
		if candidate.authoring_id == FPRINT_AUTHORING_ID:
			entry = candidate
			break
	_check(entry != null and entry.is_external(), "FPrint is available through the public external catalog.")
	_check(entry != null and entry.display_name == "FPrint", "FPrint catalog entry keeps the approved display name.")
	if entry == null:
		return

	await _mount_surface(undo_redo, context)
	var editor: FlowReadyProcessEditor = _editor()
	var add_button: Button = _authoring_button(editor, FPRINT_AUTHORING_ID)
	_check(add_button != null and add_button.text == "Add FPrint", "FPrint is exposed by the normal Process Add row.")
	if add_button == null:
		await _unmount_surface()
		return
	add_button.pressed.emit()
	await _frames()

	_check(_process.blocks.size() == 1, "Public catalog Add inserts one FPrint into Process.")
	var first: FlowBlock = _process.blocks[0] if _process.blocks.size() == 1 else null
	_check(first != null and first is FlowOutputBlock, "Catalog Add creates a FlowOutputBlock instance.")
	if first == null:
		await _unmount_surface()
		return
	_check(FlowId.is_valid(first.get_internal_id()), "Catalog Add gives FPrint a valid FlowId.")
	_check(first.display_name == "FPrint", "Catalog Add applies the manifest display name.")
	_check(first.get_script().resource_path == FPRINT_SCRIPT_PATH, "Catalog Add preserves the package script path.")
	_check(_value(first, &"prefix").is_empty() and _value(first, &"message").is_empty() \
			and _value(first, &"suffix").is_empty() and first.get(&"document") == null,
		"Catalog Add preserves FPrint's legacy defaults and null structured document.")

	editor = _editor()
	var list: ItemList = _node(editor, "ReadyBlocksList") as ItemList
	_check(list != null and list.item_count == 1, "Process Flow displays the newly added FPrint row.")
	if list == null:
		await _unmount_surface()
		return
	list.item_activated.emit(0)
	await _frames()
	var options: PanelContainer = _node(_property, "BlockOptionsPanel") as PanelContainer
	_check(options != null and options.visible, "FPrint opens the normal Flusso configuration panel.")
	if options == null:
		await _unmount_surface()
		return
	var generic: VBoxContainer = _node(options, "GenericBlockProperties") as VBoxContainer
	var prefix_input: LineEdit = _node(generic, "GenericPropertyText_prefix") as LineEdit
	var message_input: TextEdit = _node(generic, "GenericPropertyMultiline_message") as TextEdit
	var document_button: Button = _node(generic, "GenericPropertyStructuredDocument_document") as Button
	var suffix_input: LineEdit = _node(generic, "GenericPropertyText_suffix") as LineEdit
	_check(prefix_input != null, "Flusso renders Prefix through the generic text control.")
	_check(message_input != null, "Flusso renders Message through the generic multiline control.")
	_check(document_button != null and document_button.text == "Enable Structured Document",
		"Flusso renders a generic enable control for a null structured document.")
	_check(suffix_input != null, "Flusso renders Suffix through the generic text control.")
	_check(_label(options, "prefix") == "Prefix", "Flusso uses the friendly Prefix label.")
	_check(_label(options, "message") == "Message", "Flusso uses the friendly Message label.")
	_check(_label(options, "document") == "Structured Document", "Flusso uses the friendly Structured Document label.")
	_check(_label(options, "suffix") == "Suffix", "Flusso uses the friendly Suffix label.")
	var generic_order: Array[String] = _generic_property_order(generic)
	_check(generic_order.size() >= 4 and generic_order.slice(0, 4) == ["prefix", "message", "document", "suffix"],
		"Flusso renders FPrint properties in Prefix, Message, Structured Document, Suffix order.")

	if prefix_input != null:
		prefix_input.text = "<"
		prefix_input.text_changed.emit(prefix_input.text)
	if message_input != null:
		message_input.text = "line one\nline two"
		message_input.text_changed.emit()
	if suffix_input != null:
		suffix_input.text = ">"
		suffix_input.text_changed.emit(suffix_input.text)
	await _frames()
	_check(_value(first, &"prefix") == "<" and _value(first, &"message") == "line one\nline two" \
			and _value(first, &"suffix") == ">", "FPrint generic edits apply live to the model.")
	_check((first as FlowOutputBlock).get_output_message() == "<line one\nline two>",
		"FPrint output composition is exact after live editing.")

	options = _node(_property, "BlockOptionsPanel") as PanelContainer
	var revert_button: Button = _button(options, "Revertir")
	_check(revert_button != null, "FPrint Flusso exposes the host-owned Revertir action.")
	if revert_button != null:
		revert_button.pressed.emit()
	await _frames()
	_check(_value(first, &"prefix").is_empty() and _value(first, &"message").is_empty() \
			and _value(first, &"suffix").is_empty() and first.get(&"document") == null,
		"Revertir restores FPrint's opening legacy values and null document.")
	options = _node(_property, "BlockOptionsPanel") as PanelContainer
	_check(options != null and options.visible, "Revertir keeps the FPrint Flusso panel open.")

	if options != null:
		generic = _node(options, "GenericBlockProperties") as VBoxContainer
		document_button = _node(generic, "GenericPropertyStructuredDocument_document") as Button
		_check(document_button != null, "Revertir restores the generic structured-document enable state.")
		if document_button != null:
			document_button.pressed.emit()
			await _frames()
			var enabled_document: FlowStructuredDocument = first.get(&"document") as FlowStructuredDocument
			_check(enabled_document != null, "Enable Structured Document creates a FlowStructuredDocument resource.")
			options = _node(_property, "BlockOptionsPanel") as PanelContainer
			generic = _node(options, "GenericBlockProperties") as VBoxContainer
			var document_editor: FlowStructuredDocumentEditor = _node(
				generic,
				"GenericPropertyStructuredDocument_document"
			) as FlowStructuredDocumentEditor
			_check(document_editor != null, "A present document uses the reusable structured-document editor.")
			if document_editor != null and enabled_document != null:
				var exact_text: String = "  línea 1\n\tUnicode: ñ 日本 \\@ # $  "
				var normalized_exact_text: String = "  línea 1\n\tUnicode: ñ 日本 @ # $  "
				var text_segment: FlowTextSegment = FlowTextSegment.new()
				text_segment.text = "seed"
				enabled_document.segments = [text_segment]
				document_editor.refresh()
				await _frames()
				var text_control: TextEdit = document_editor.get_text_control(text_segment.get_segment_id())
				_check(text_control != null, "The generic structured editor renders a text segment control.")
				if text_control != null:
					text_control.text = exact_text
					text_control.text_changed.emit()
					await _frames()
					_check(text_segment.text == normalized_exact_text,
						"Structured Flusso text editing preserves multiline Unicode and @/#/$ literally.")
				var inserted_id: String = document_editor.insert_value()
				_check(FlowId.is_valid(inserted_id), "Structured Flusso + Value creates a public typed chip.")
				await _frames()
				var chip: FlowLiteralValueSegment = _find_segment(enabled_document, inserted_id) as FlowLiteralValueSegment
				_check(chip != null and chip.value == 0, "Structured Flusso + Value starts with typed int 0.")
				if chip != null:
					document_editor.select_segment(inserted_id)
					_check(document_editor.set_selected_chip_value(9), "Structured Flusso edits a typed chip through the public contract.")
					_check(chip.value == 9 and (first as FlowOutputBlock).get_output_message() == "  línea 1\n\tUnicode: ñ 日本 @ # $  9",
						"Structured FPrint output uses the rendered document and replaces Message.")
					var history: UndoRedo = _history_for_controller()
					_check(history != null, "Structured document edits use the owning controller undo history.")
					if history != null:
						history.undo()
						_check(chip.value == 0, "Undo restores the typed chip value in the owning controller history.")
						history.redo()
						_check(chip.value == 9, "Redo reapplies the typed chip value in the owning controller history.")
					_check(document_editor.delete_selected_chip(), "Structured Flusso deletes the selected typed chip.")
					_check(_find_segment(enabled_document, inserted_id) == null, "Chip deletion removes the selected segment by stable ID.")
					if history != null:
						history.undo()
						_check(_find_segment(enabled_document, inserted_id) != null,
							"Undo restores the deleted structured chip with its stable ID.")
						history.redo()
						_check(_find_segment(enabled_document, inserted_id) == null,
							"Redo removes the same structured chip again.")

				options = _node(_property, "BlockOptionsPanel") as PanelContainer
				var structured_revert: Button = _button(options, "Revertir")
				_check(structured_revert != null, "Structured FPrint Flusso retains the host-owned Revertir action.")
				if structured_revert != null:
					structured_revert.pressed.emit()
					await _frames()
					_check(first.get(&"document") == null,
						"Revertir restores the null document snapshot after structured editing.")

				options = _node(_property, "BlockOptionsPanel") as PanelContainer
				if options != null:
					var close_structured: Button = _node(options, "CloseBlockOptions") as Button
					if close_structured != null:
						close_structured.pressed.emit()
					await _frames()

	var close_button: Button = _node(options, "CloseBlockOptions") as Button
	if close_button != null:
		close_button.pressed.emit()
	await _frames()
	editor = _editor()
	add_button = _authoring_button(editor, FPRINT_AUTHORING_ID)
	_check(add_button != null, "FPrint Add remains available after Revertir and close.")
	if add_button != null:
		add_button.pressed.emit()
		await _frames()
	_check(_process.blocks.size() == 2, "A second FPrint can be added to the same Process.")
	if _process.blocks.size() == 2:
		var second: FlowBlock = _process.blocks[1]
		_check(second != first and second.get_internal_id() != first.get_internal_id(),
			"Two FPrint instances remain independent by object and FlowId.")
		_check(second.display_name == "FPrint 1", "Repeated FPrint Add uses the existing unique-name policy.")
		second.set(&"message", "second instance")
		_check(_value(first, &"message").is_empty() and _value(second, &"message") == "second instance",
			"Editing a second FPrint does not change the first instance.")
		var second_document: FlowStructuredDocument = _make_document("snapshot", 3)
		second.set(&"document", second_document)
		var original_text_id: String = second_document.segments[0].get_segment_id()
		var original_value_id: String = second_document.segments[1].get_segment_id()
		editor = _editor()
		list = _node(editor, "ReadyBlocksList") as ItemList
		_check(list != null and list.item_count == 2, "The second FPrint remains addressable through the same Flow list.")
		if list != null and list.item_count == 2:
			list.item_activated.emit(1)
			await _frames()
			options = _node(_property, "BlockOptionsPanel") as PanelContainer
			var second_generic: VBoxContainer = _node(options, "GenericBlockProperties") as VBoxContainer
			var second_editor: FlowStructuredDocumentEditor = _node(
				second_generic,
				"GenericPropertyStructuredDocument_document"
			) as FlowStructuredDocumentEditor
			_check(second_editor != null, "A second FPrint can open the same generic structured editor independently.")
			if second_editor != null:
				second_editor.select_segment(original_value_id)
				second_editor.set_selected_chip_value(8)
				var second_revert: Button = _button(options, "Revertir")
				_check(second_revert != null, "The second structured FPrint exposes Revertir.")
				if second_revert != null:
					second_revert.pressed.emit()
					await _frames()
					var restored_document: FlowStructuredDocument = second.get(&"document") as FlowStructuredDocument
					_check(restored_document != null and restored_document != second_document,
						"Revertir restores an independent structured-document snapshot.")
					if restored_document != null:
						_check(restored_document.segments.size() == 2 \
								and restored_document.segments[0].get_segment_id() == original_text_id \
								and restored_document.segments[1].get_segment_id() == original_value_id \
								and (restored_document.segments[0] as FlowTextSegment).text == "snapshot" \
								and (restored_document.segments[1] as FlowLiteralValueSegment).value == 3,
							"Revertir preserves structured segment IDs, order, and opening values.")
	await _unmount_surface()


func _mount_surface(undo_redo: EditorUndoRedoManager, context: RefCounted) -> void:
	_host = Control.new()
	_host.name = "FPrintDogfoodHost"
	_host.size = Vector2(1200.0, 900.0)
	get_root().add_child(_host)
	_process = FlowProcess.new()
	_process.display_name = "FPrint Process"
	_controller = PVController.new()
	_controller.name = "FPrintDogfoodController"
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
	return _property.find_child("ReadyProcessEditor", true, false) as FlowReadyProcessEditor if _property != null else null


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


func _generic_property_order(generic: VBoxContainer) -> Array[String]:
	var order: Array[String] = []
	if generic == null:
		return order
	for child: Node in generic.get_children():
		var child_name: String = String(child.name)
		if child_name.begins_with("GenericPropertyLabel_"):
			order.append(child_name.trim_prefix("GenericPropertyLabel_"))
	return order


func _label(options: Node, property: String) -> String:
	var label: Label = _node(options, "GenericPropertyLabel_" + property) as Label
	return label.text if label != null else ""


func _value(block: FlowBlock, property: StringName) -> String:
	return String(block.get(property)) if block != null else ""


func _find_segment(document: FlowStructuredDocument, segment_id: String) -> FlowDocumentSegment:
	if document == null or segment_id.is_empty():
		return null
	for segment: FlowDocumentSegment in document.segments:
		if segment != null and segment.get_segment_id() == segment_id:
			return segment
	return null


func _make_document(text_value: String, integer_value: int) -> FlowStructuredDocument:
	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	var text: FlowTextSegment = FlowTextSegment.new()
	text.text = text_value
	var literal: FlowLiteralValueSegment = FlowLiteralValueSegment.new(
		FlowLiteralValueSegment.TYPE_INT,
		integer_value
	)
	document.segments = [text, literal]
	return document


func _history_for_controller() -> UndoRedo:
	if _undo_redo == null or _controller == null:
		return null
	return _undo_redo.get_history_undo_redo(_undo_redo.get_object_history_id(_controller))


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


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_failures.append(message)
		push_error(message)
	return condition


func _finish() -> void:
	if is_instance_valid(_host):
		_host.queue_free()
	if _failures.is_empty():
		print("[Flujo] FPrint dogfood editor test passed")
	quit(0 if _failures.is_empty() else 1)
