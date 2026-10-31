@tool
## Neutral editor-only review harness for FIXED, FLEXIBLE, and HYBRID fields.
class_name FlowStructuredDocumentEditorHarness
extends Window


var _status: Label
var _editors: Array[FlowChipFieldEditor] = []
var _undo_redo: EditorUndoRedoManager
var _tabs: TabContainer
var _graph: FlowGraph
var _fixture_documents: Dictionary = {}

const REVIEW_SAVE_ROOT: String = "res://.godot/flujo_tests/expression_harness"
const REVIEW_DOCUMENT_PATH: String = REVIEW_SAVE_ROOT + "/expression_document.tres"
const REVIEW_GRAPH_PATH: String = REVIEW_SAVE_ROOT + "/expression_graph.tres"


func configure(undo_redo: EditorUndoRedoManager) -> void:
	_undo_redo = undo_redo
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	title = "Flow Chip Field Harness"
	size = Vector2i(1080, 760)
	min_size = Vector2i(760, 560)
	close_requested.connect(_on_close_requested)

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override(&"margin_left", 18)
	margin.add_theme_constant_override(&"margin_top", 18)
	margin.add_theme_constant_override(&"margin_right", 18)
	margin.add_theme_constant_override(&"margin_bottom", 18)
	add_child(margin)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override(&"separation", 8)
	margin.add_child(content)

	var heading: Label = Label.new()
	heading.text = "Universal Chip Field — inline text and tokens"
	heading.add_theme_font_size_override(&"font_size", 18)
	content.add_child(heading)

	var instructions: Label = Label.new()
	instructions.text = "Click inside text to place the real caret. Type @ to choose a graph variable, # to build a CONDITION, or use + Value to insert a literal at that caret. Click a chip to edit it. Backspace/Delete selects or removes a whole token."
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(instructions)

	var persistence_actions: HBoxContainer = HBoxContainer.new()
	var save_button: Button = Button.new()
	save_button.text = "Save Expression Fixture"
	save_button.tooltip_text = "Save the EXPRESSION document and graph to the controlled review fixture."
	save_button.pressed.connect(_save_expression_fixture)
	persistence_actions.add_child(save_button)
	var reload_button: Button = Button.new()
	reload_button.text = "Reload Saved Expression"
	reload_button.tooltip_text = "Reopen the saved EXPRESSION Resource and rebuild the tab."
	reload_button.pressed.connect(_reload_expression_fixture)
	persistence_actions.add_child(reload_button)
	var reset_button: Button = Button.new()
	reset_button.text = "Reset Saved Expression"
	reset_button.tooltip_text = "Delete the controlled review save and restore the factory fixture."
	reset_button.pressed.connect(_reset_expression_fixture)
	persistence_actions.add_child(reset_button)
	content.add_child(persistence_actions)

	_tabs = TabContainer.new()
	_tabs.name = &"FieldFixtures"
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_tabs)
	_graph = _load_saved_graph()
	_build_fixture_pages(_load_saved_expression_document())

	_status = Label.new()
	_status.name = &"HarnessStatus"
	_status.text = "Select a token or place the caret in text."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status)


func _add_fixture(
		tabs: TabContainer,
		label: String,
		field_schema: FlowChipFieldSchema,
	variable_graph: FlowGraph,
	undo_redo: EditorUndoRedoManager,
	initial_document: FlowStructuredDocument = null
) -> void:
	var page: VBoxContainer = VBoxContainer.new()
	page.name = label + "Fixture"
	page.add_theme_constant_override(&"separation", 6)
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_child(page)
	page.set_meta(&"fixture_schema", field_schema)

	var description: Label = Label.new()
	description.text = _fixture_description(label)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	page.add_child(description)

	var editor: FlowChipFieldEditor = FlowChipFieldEditor.new()
	editor.name = "FlowChipFieldEditor_" + label
	editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor.segment_selected.connect(_on_segment_selected.bind(label))
	editor.operation_feedback.connect(_on_feedback.bind(label))
	page.add_child(editor)
	var creation: FlowChipFieldCreationResult = FlowChipFieldFactory.new().create(field_schema)
	var document: FlowStructuredDocument = initial_document if initial_document != null else creation.document
	editor.configure_field(field_schema, document, undo_redo, document)
	editor.set_variable_graph(variable_graph)
	_editors.append(editor)
	_fixture_documents[label] = document


func _build_fixture_pages(expression_document: FlowStructuredDocument = null) -> void:
	if _tabs == null:
		return
	for child: Node in _tabs.get_children():
		child.free()
	_editors.clear()
	_fixture_documents.clear()
	_add_fixture(_tabs, "FIXED", _fixed_schema(), _graph, _undo_redo)
	_add_fixture(_tabs, "FLEXIBLE", _flexible_schema(), _graph, _undo_redo)
	_add_fixture(_tabs, "HYBRID", _hybrid_schema(), _graph, _undo_redo)
	_add_fixture(_tabs, "CONDITION", _condition_schema(), _graph, _undo_redo)
	_add_fixture(_tabs, "EXPRESSION", _expression_schema(), _graph, _undo_redo, expression_document)


func _save_expression_fixture() -> void:
	var document: FlowStructuredDocument = _fixture_documents.get("EXPRESSION", null) as FlowStructuredDocument
	if document == null or _graph == null:
		_set_status("EXPRESSION — no document is available to save.")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW_SAVE_ROOT))
	var graph_error: Error = ResourceSaver.save(_graph, REVIEW_GRAPH_PATH)
	var document_error: Error = ResourceSaver.save(document, REVIEW_DOCUMENT_PATH)
	if graph_error != OK or document_error != OK:
		_set_status("EXPRESSION — save failed (graph=%s, document=%s)." % [graph_error, document_error])
		return
	_set_status("EXPRESSION — saved. Close and reopen the harness, or press Reload Saved Expression.")


func _reload_expression_fixture() -> void:
	var graph: FlowGraph = _load_saved_graph()
	var document: FlowStructuredDocument = _load_saved_expression_document()
	if graph == null or document == null:
		_set_status("EXPRESSION — no saved Resource exists. Use Save Expression Fixture first.")
		return
	_graph = graph
	_build_fixture_pages(document)
	_set_status("EXPRESSION — reloaded from ResourceSaver/ResourceLoader.")


func _reset_expression_fixture() -> void:
	for path: String in [REVIEW_DOCUMENT_PATH, REVIEW_GRAPH_PATH]:
		var absolute_path: String = ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(absolute_path):
			DirAccess.remove_absolute(absolute_path)
	_graph = _manual_graph()
	_build_fixture_pages()
	_set_status("EXPRESSION — saved review fixture removed; factory document restored.")


func _load_saved_graph() -> FlowGraph:
	if ResourceLoader.exists(REVIEW_GRAPH_PATH):
		var loaded: FlowGraph = ResourceLoader.load(
			REVIEW_GRAPH_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
		) as FlowGraph
		if loaded != null and not loaded.variables.is_empty():
			return loaded
	return _manual_graph()


func _load_saved_expression_document() -> FlowStructuredDocument:
	if not ResourceLoader.exists(REVIEW_DOCUMENT_PATH):
		return null
	return ResourceLoader.load(
		REVIEW_DOCUMENT_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as FlowStructuredDocument


func _set_status(message: String) -> void:
	if _status != null:
		_status.text = message


func _fixture_description(label: String) -> String:
	match label:
		"FIXED":
			return "Factory-generated required structure: Inicio: [0] Condición: [true] Incremento: [1]. Type @ beside a compatible fixed token to replace its source while preserving its slot and segment ID."
		"FLEXIBLE":
			return "Optional values in one variadic zone. This fixture allows at most three chips; + Value inserts literals and @ inserts compatible graph variables."
		"HYBRID":
			return "One required token plus an optional variadic zone. @ inserts graph variables only in the optional zone."
		"EXPRESSION":
			return "Legacy compatibility fixture. Expression remains available to existing callers; # now opens CONDITION."
		"CONDITION":
			return "Type # to open CONDITION. Try Health > 0, Lives == 1, Enabled == true, Message != \"hola\", then add AND/OR rows."
	return ""


func _fixed_schema() -> FlowChipFieldSchema:
	var field: FlowChipFieldSchema = FlowChipFieldSchema.new()
	field.mode = FlowChipFieldSchema.Mode.FIXED
	field.text_mode = FlowChipFieldSchema.TextMode.DOCUMENTATION
	field.slots = [
		_fixed_slot("start", "Start", FlowLiteralValueSource.TYPE_INT, 0, true),
		_fixed_slot("condition", "Condition", FlowLiteralValueSource.TYPE_BOOL, true, true),
		_fixed_slot("increment", "Increment", FlowLiteralValueSource.TYPE_INT, 1, true),
	]
	field.add_text_part("Inicio: ")
	field.add_slot_part("start")
	field.add_text_part(" Condición: ")
	field.add_slot_part("condition")
	field.add_text_part(" Incremento: ")
	field.add_slot_part("increment")
	return field


func _flexible_schema() -> FlowChipFieldSchema:
	var field: FlowChipFieldSchema = FlowChipFieldSchema.new()
	field.mode = FlowChipFieldSchema.Mode.FLEXIBLE
	field.text_mode = FlowChipFieldSchema.TextMode.DOCUMENTATION
	field.flexible_min_count = 0
	field.flexible_max_count = 3
	field.accepted_value_types = [
		FlowLiteralValueSource.TYPE_BOOL,
		FlowLiteralValueSource.TYPE_INT,
		FlowLiteralValueSource.TYPE_FLOAT,
		FlowLiteralValueSource.TYPE_STRING,
		FlowLiteralValueSource.TYPE_STRING_NAME,
	]
	field.variadic_slot_definition = _variadic_slot("value", "Value", 0, 3)
	field.add_text_part("Valores: ")
	field.add_slot_part("value")
	field.add_text_part(" — texto literal @ # $ y Unicode: ñ 日本")
	return field


func _hybrid_schema() -> FlowChipFieldSchema:
	var field: FlowChipFieldSchema = FlowChipFieldSchema.new()
	field.mode = FlowChipFieldSchema.Mode.HYBRID
	field.text_mode = FlowChipFieldSchema.TextMode.DOCUMENTATION
	field.accepted_value_types = [FlowLiteralValueSource.TYPE_INT, FlowLiteralValueSource.TYPE_BOOL]
	var required: FlowChipSlotDefinition = _fixed_slot(
		"required",
		"Required",
		FlowLiteralValueSource.TYPE_INT,
		0
	)
	required.allow_delete = false
	required.allow_reorder = false
	field.slots = [required]
	field.variadic_slot_definition = _variadic_slot("optional", "Optional", 0, 2)
	field.add_text_part("Obligatorio: ")
	field.add_slot_part("required")
	field.add_text_part(" Opcionales: ")
	field.add_slot_part("optional")
	return field


func _expression_schema() -> FlowChipFieldSchema:
	var field: FlowChipFieldSchema = FlowChipFieldSchema.new()
	field.mode = FlowChipFieldSchema.Mode.FLEXIBLE
	field.text_mode = FlowChipFieldSchema.TextMode.RUNTIME_CONTENT
	field.accepted_value_types = [
		FlowLiteralValueSource.TYPE_BOOL,
		FlowLiteralValueSource.TYPE_INT,
		FlowLiteralValueSource.TYPE_FLOAT,
		FlowLiteralValueSource.TYPE_STRING,
	]
	field.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_EXPRESSION]
	field.flexible_max_count = 4
	field.variadic_slot_definition = FlowChipSlotDefinition.new("expression", "Expression")
	field.variadic_slot_definition.repeatable = true
	field.variadic_slot_definition.max_count = 4
	field.variadic_slot_definition.accepted_value_types = field.accepted_value_types.duplicate()
	field.variadic_slot_definition.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_EXPRESSION]
	field.add_text_part("Expression: ")
	field.add_slot_part("expression")
	return field


func _condition_schema() -> FlowChipFieldSchema:
	var field: FlowChipFieldSchema = FlowChipFieldSchema.new()
	field.mode = FlowChipFieldSchema.Mode.FIXED
	field.text_mode = FlowChipFieldSchema.TextMode.RUNTIME_CONTENT
	field.accepted_value_types = [Variant.Type.TYPE_BOOL]
	field.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_CONDITION]
	var slot: FlowChipSlotDefinition = FlowChipSlotDefinition.new("condition", "Condition", true)
	slot.accepted_value_types = [Variant.Type.TYPE_BOOL]
	slot.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_CONDITION]
	slot.initial_value_source = _condition_source()
	slot.allow_delete = false
	slot.allow_reorder = false
	slot.min_count = 1
	slot.max_count = 1
	field.slots = [slot]
	field.add_text_part("Condition: ")
	field.add_slot_part("condition")
	return field


func _condition_source() -> FlowConditionValueSource:
	var health: FlowVariableDefinition = null
	for candidate: FlowVariableDefinition in _graph.variables:
		if candidate != null and candidate.display_name == "Health":
			health = candidate
			break
	if health == null:
		health = _manual_variable("Health", FlowVariableDefinition.ValueType.INT)
	var graph_health: FlowVariableRefValueSource = FlowVariableRefValueSource.new(
		health.get_internal_id(), health.value_type
	)
	return FlowConditionValueSource.new([
		FlowConditionComparison.new(
			FlowConditionOperatorCatalog.OPERATOR_GREATER_THAN,
			graph_health,
			FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_INT, 0)
		)
	], [])


func _fixed_slot(
		slot_id: String,
		label: String,
		value_type: Variant.Type,
		value: Variant,
		allow_variable: bool = false
) -> FlowChipSlotDefinition:
	var slot: FlowChipSlotDefinition = FlowChipSlotDefinition.new(slot_id, label, true)
	slot.accepted_value_types = [value_type]
	slot.accepted_source_kinds = [FlowValueSource.SOURCE_KIND_LITERAL]
	if allow_variable:
		slot.accepted_source_kinds.append(FlowValueSource.SOURCE_KIND_VARIABLE_REF)
	slot.initial_value_source = FlowLiteralValueSource.new(value_type, value)
	slot.allow_delete = false
	slot.allow_reorder = false
	slot.repeatable = false
	slot.min_count = 1
	slot.max_count = 1
	return slot


func _variadic_slot(
		slot_id: String,
		label: String,
		minimum: int,
		maximum: int
) -> FlowChipSlotDefinition:
	var slot: FlowChipSlotDefinition = FlowChipSlotDefinition.new(slot_id, label, false)
	slot.accepted_value_types = [
		FlowLiteralValueSource.TYPE_BOOL,
		FlowLiteralValueSource.TYPE_INT,
		FlowLiteralValueSource.TYPE_FLOAT,
		FlowLiteralValueSource.TYPE_STRING,
		FlowLiteralValueSource.TYPE_STRING_NAME,
	]
	slot.accepted_source_kinds = [
		FlowValueSource.SOURCE_KIND_LITERAL,
		FlowValueSource.SOURCE_KIND_VARIABLE_REF,
	]
	slot.allow_delete = true
	slot.allow_reorder = true
	slot.repeatable = true
	slot.min_count = minimum
	slot.max_count = maximum
	return slot


func _manual_graph() -> FlowGraph:
	var graph: FlowGraph = FlowGraph.new()
	graph.variables = [
		_manual_variable("Count", FlowVariableDefinition.ValueType.INT),
		_manual_variable("Health", FlowVariableDefinition.ValueType.INT),
		_manual_variable("Speed", FlowVariableDefinition.ValueType.FLOAT),
		_manual_variable("Enabled", FlowVariableDefinition.ValueType.BOOL),
		_manual_variable("Visible", FlowVariableDefinition.ValueType.BOOL),
		_manual_variable("Message", FlowVariableDefinition.ValueType.STRING),
		_manual_variable("Position", FlowVariableDefinition.ValueType.VECTOR2),
		_manual_variable("Tint", FlowVariableDefinition.ValueType.COLOR),
	]
	return graph


func _manual_variable(
		variable_name: String,
		value_type: FlowVariableDefinition.ValueType
) -> FlowVariableDefinition:
	var variable: FlowVariableDefinition = FlowVariableDefinition.new()
	variable.display_name = variable_name
	variable.value_type = value_type
	return variable


func _on_segment_selected(segment_id: String, label: String) -> void:
	if _status == null:
		return
	_status.text = "%s — selected segment_id: %s" % [label, segment_id if not segment_id.is_empty() else "none"]


func _on_feedback(message: String, label: String) -> void:
	if _status == null:
		return
	_status.text = "%s — %s" % [label, message]


func _on_close_requested() -> void:
	queue_free()
