@tool
## Reusable editor-only inline surface for one schema-backed chip field.
class_name FlowChipFieldEditor
extends VBoxContainer


signal segment_selected(segment_id: String)
signal document_changed
signal caret_changed(segment_id: String, offset: int)
signal operation_feedback(message: String)


const FLOW_CHIP_CONTROL_SCRIPT: Script = preload(
	"res://addons/vp_flujo/editor/flow_chip_control.gd"
)
const FLOW_CHIP_TEXT_EDIT_SCRIPT: Script = preload(
	"res://addons/vp_flujo/editor/flow_chip_text_edit.gd"
)
const FLOW_CHIP_LINE_EDIT_SCRIPT: Script = preload(
	"res://addons/vp_flujo/editor/flow_chip_line_edit.gd"
)
const FLOW_VARIABLE_SELECTOR_SCRIPT: Script = preload(
	"res://addons/vp_flujo/editor/flow_variable_selector.gd"
)
const FLOW_EXPRESSION_EDITOR_SCRIPT: Script = preload(
	"res://addons/vp_flujo/editor/flow_expression_editor.gd"
)
const FLOW_CONDITION_EDITOR_SCRIPT: Script = preload(
	"res://addons/vp_flujo/editor/flow_condition_editor.gd"
)
const FLOW_OPERATION_EDITOR_SCRIPT: Script = preload(
	"res://addons/vp_flujo/editor/flow_operation_editor.gd"
)
const FLOW_SEMANTIC_INSERTION_ANCHOR_SCRIPT: Script = preload(
	"res://addons/vp_flujo/editor/flow_chip_semantic_insertion_anchor.gd"
)

const FEEDBACK_INVALID_CHIP_POSITION: String = "A chip cannot be inserted at this position."
const FEEDBACK_NO_COMPATIBLE_LITERAL: String = "No compatible literal type is available here."
const FEEDBACK_MAX_CHIP_COUNT: String = "Maximum chip count reached (%d)."
const FEEDBACK_NO_COMPATIBLE_VARIABLE: String = "No compatible variable is available here."
const FEEDBACK_TOK_IMMUTABLE: String = "This Tok is immutable in the current schema."
const FEEDBACK_TOK_TYPE_LOCKED: String = "This Tok's type is locked by the current schema."
const FEEDBACK_TOK_SOURCE_KIND_LOCKED: String = \
	"This Tok's source kind is locked by the current schema."
const FEEDBACK_NO_COMPATIBLE_EXPRESSION: String = \
	"No compatible expression signature is available here."
const FEEDBACK_NO_COMPATIBLE_OPERATION: String = \
	"No compatible Operation source is available here."


var _schema: FlowChipFieldSchema
var _document: FlowStructuredDocument
var _variable_graph: FlowGraph
var _undo_redo: EditorUndoRedoManager
var _action_owner: Object

var _surface: FlowContainer
var _add_value_button: Button
var _literal_type_menu: PopupMenu
var _variable_selector: FlowVariableSelector
var _expression_editor: FlowExpressionEditor
var _condition_editor: FlowConditionEditor
var _operation_editor: FlowOperationEditor
var _validation_label: Label
var _feedback_label: Label
var _details_panel: PanelContainer
var _details: VBoxContainer

var _selected_segment_id: String = ""
var _current_position_id: String = ""
var _caret_segment_id: String = ""
var _caret_offset: int = 0
var _caret_boundary_index: int = -1
var _focus_restore_id: String = ""
var _focus_restore_offset: int = 0
var _preserve_selection_during_focus_restore: bool = false

var _visual_elements: Array[Control] = []
var _visual_by_id: Dictionary[String, Control] = {}
var _rebuild_queued: bool = false
var _rebuild_generation: int = 0
var _suppress_input: bool = false
var _text_history_sessions: Dictionary[String, Dictionary] = {}
var _value_history_sessions: Dictionary[String, Dictionary] = {}
var _validation_result: FlowValidationResult = FlowValidationResult.new()
var _feedback_text: String = ""

var _variable_trigger_active: bool = false
var _variable_trigger_segment_id: String = ""
var _variable_trigger_start: int = -1
var _variable_trigger_end: int = -1
var _variable_trigger_before_segments: Array[FlowDocumentSegment] = []
var _variable_trigger_before_text_states: Array[Dictionary] = []
var _variable_trigger_anchor: FlowChipSemanticInsertionAnchor
var _variable_edit_active: bool = false
var _variable_edit_segment_id: String = ""
var _expression_trigger_active: bool = false
var _expression_trigger_segment_id: String = ""
var _expression_trigger_start: int = -1
var _expression_trigger_end: int = -1
var _expression_trigger_before_segments: Array[FlowDocumentSegment] = []
var _expression_trigger_before_text_states: Array[Dictionary] = []
var _expression_trigger_anchor: FlowChipSemanticInsertionAnchor
var _expression_edit_active: bool = false
var _expression_edit_segment_id: String = ""
var _condition_trigger_active: bool = false
var _condition_trigger_segment_id: String = ""
var _condition_trigger_start: int = -1
var _condition_trigger_end: int = -1
var _condition_trigger_anchor: FlowChipSemanticInsertionAnchor
var _condition_edit_active: bool = false
var _condition_edit_segment_id: String = ""
var _operation_trigger_active: bool = false
var _operation_trigger_segment_id: String = ""
var _operation_trigger_start: int = -1
var _operation_trigger_end: int = -1
var _operation_trigger_before_segments: Array[FlowDocumentSegment] = []
var _operation_trigger_before_text_states: Array[Dictionary] = []
var _operation_trigger_anchor: FlowChipSemanticInsertionAnchor
var _operation_edit_active: bool = false
var _operation_edit_segment_id: String = ""


var schema: FlowChipFieldSchema:
	get:
		return _schema
	set(value):
		set_schema(value)


var document: FlowStructuredDocument:
	get:
		return _document
	set(value):
		set_document(value)


func _init() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	# The Akis owns one chronological history. Capture document shortcuts at
	# the Node input phase, before a focused TextEdit/LineEdit can consume them
	# in its native local history.
	set_process_input(true)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override(&"separation", 6)

	var header: HBoxContainer = HBoxContainer.new()
	header.name = &"ChipFieldToolbar"
	add_child(header)

	var title: Label = Label.new()
	title.name = &"ChipFieldTitle"
	title.text = "Inline chip field"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	_add_value_button = Button.new()
	_add_value_button.name = &"AddValue"
	_add_value_button.text = "+ Value"
	_add_value_button.tooltip_text = "Temporary harness/debug tool: insert a typed value at the caret."
	_add_value_button.set_meta(&"temporary_harness_debug", true)
	_add_value_button.focus_mode = Control.FOCUS_ALL
	_add_value_button.pressed.connect(_open_literal_type_selector)
	_literal_type_menu = PopupMenu.new()
	_literal_type_menu.name = &"LiteralTypeSelector"
	_literal_type_menu.id_pressed.connect(_on_literal_type_selected)
	_add_value_button.add_child(_literal_type_menu)
	header.add_child(_add_value_button)

	_variable_selector = FLOW_VARIABLE_SELECTOR_SCRIPT.new() as FlowVariableSelector
	_variable_selector.variable_selected.connect(_on_variable_selected)
	_variable_selector.cancelled.connect(_on_variable_selector_cancelled)
	add_child(_variable_selector)
	_expression_editor = FLOW_EXPRESSION_EDITOR_SCRIPT.new() as FlowExpressionEditor
	_expression_editor.expression_confirmed.connect(_on_expression_confirmed)
	_expression_editor.cancelled.connect(_on_expression_editor_cancelled)
	add_child(_expression_editor)
	_condition_editor = FLOW_CONDITION_EDITOR_SCRIPT.new() as FlowConditionEditor
	_condition_editor.condition_confirmed.connect(_on_condition_confirmed)
	_condition_editor.cancelled.connect(_on_condition_editor_cancelled)
	add_child(_condition_editor)
	_operation_editor = FLOW_OPERATION_EDITOR_SCRIPT.new() as FlowOperationEditor
	_operation_editor.operation_confirmed.connect(_on_operation_confirmed)
	_operation_editor.cancelled.connect(_on_operation_editor_cancelled)
	add_child(_operation_editor)

	_validation_label = Label.new()
	_validation_label.name = &"ChipFieldValidation"
	_validation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_validation_label.add_theme_color_override(
		&"font_color",
		Color(1.0, 0.55, 0.35)
	)
	_validation_label.visible = false
	add_child(_validation_label)

	_feedback_label = Label.new()
	_feedback_label.name = &"ChipFieldFeedback"
	_feedback_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback_label.add_theme_color_override(
		&"font_color",
		Color(1.0, 0.78, 0.35)
	)
	_feedback_label.visible = false
	add_child(_feedback_label)

	var surface_scroll: ScrollContainer = ScrollContainer.new()
	surface_scroll.name = &"ChipFieldScroll"
	surface_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	surface_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	surface_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	surface_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(surface_scroll)

	_surface = FlowContainer.new()
	_surface.name = &"ChipFieldSurface"
	_surface.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_surface.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_surface.custom_minimum_size = Vector2(0.0, 72.0)
	_surface.add_theme_constant_override(&"h_separation", 3)
	_surface.add_theme_constant_override(&"v_separation", 3)
	surface_scroll.add_child(_surface)

	_details_panel = PanelContainer.new()
	_details_panel.name = &"ChipEditorPanel"
	_details_panel.visible = false
	_details_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(_details_panel)
	_details = VBoxContainer.new()
	_details.name = &"ChipEditorContent"
	_details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_details.add_theme_constant_override(&"separation", 4)
	_details_panel.add_child(_details)


## Accepts both the new `(schema, document, undo_redo, owner)` form and the
## K4 compatibility `(document, undo_redo, owner)` form.
func configure(
		first: Variant = null,
		second: Variant = null,
		third: Variant = null,
		fourth: Variant = null
) -> void:
	var next_schema: FlowChipFieldSchema = null
	var next_document: FlowStructuredDocument = null
	var next_undo_redo: EditorUndoRedoManager = null
	var next_owner: Object = null
	if first is FlowChipFieldSchema or (first == null and second is FlowStructuredDocument):
		next_schema = first as FlowChipFieldSchema
		next_document = second as FlowStructuredDocument
		next_undo_redo = third as EditorUndoRedoManager
		next_owner = fourth as Object if fourth is Object else null
	else:
		next_document = first as FlowStructuredDocument
		next_undo_redo = second as EditorUndoRedoManager
		next_owner = third as Object if third is Object else null

	_schema = next_schema
	_undo_redo = next_undo_redo
	_action_owner = next_owner
	if next_document == null and _schema != null:
		var creation: FlowChipFieldCreationResult = FlowChipFieldFactory.new().create(_schema)
		next_document = creation.document
		if next_document == null:
			next_document = FlowStructuredDocument.new()
	_document = next_document if next_document != null else FlowStructuredDocument.new()
	_selected_segment_id = ""
	_current_position_id = ""
	_caret_segment_id = ""
	_caret_offset = 0
	_caret_boundary_index = -1
	_clear_variable_trigger_state()
	_clear_variable_edit_state()
	_clear_expression_trigger_state()
	_clear_expression_edit_state()
	_clear_condition_trigger_state()
	_clear_condition_edit_state()
	_clear_operation_trigger_state()
	_clear_operation_edit_state()
	_clear_feedback()
	_refresh()


func configure_field(
		field_schema: FlowChipFieldSchema,
		field_document: FlowStructuredDocument = null,
		undo_redo: EditorUndoRedoManager = null,
		action_owner: Object = null
) -> void:
	configure(field_schema, field_document, undo_redo, action_owner)


## Routes Ctrl+Z/Ctrl+Shift+Z/Ctrl+Y to the owning Akis history before
## TextEdit or LineEdit native undo handling can consume the event. Native
## controls remain editable; their local histories are simply not the public
## document history for this composite control.
func _input(event: InputEvent) -> void:
	if _undo_redo == null or _document == null or not is_visible_in_tree():
		return
	if not _is_document_history_shortcut(event):
		return
	if _route_document_history_shortcut(event):
		# _input runs before the focused Control's GUI phase.  One handled-event
		# barrier is sufficient to keep TextEdit/LineEdit from consuming the same
		# shortcut in their native local history.
		get_viewport().set_input_as_handled()


func _is_document_history_shortcut(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo or not key.ctrl_pressed:
		return false
	var is_z: bool = key.keycode == KEY_Z or key.physical_keycode == KEY_Z
	var is_y: bool = key.keycode == KEY_Y or key.physical_keycode == KEY_Y
	return is_z or (is_y and not key.shift_pressed)


func _is_focus_inside_editor() -> bool:
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return false
	var focus_owner: Control = viewport.gui_get_focus_owner() as Control
	return focus_owner == self or (focus_owner != null and is_ancestor_of(focus_owner))


func _document_history() -> UndoRedo:
	if _undo_redo == null:
		return null
	var owner: Object = _history_owner()
	if owner == null or not is_instance_valid(owner):
		return null
	return _undo_redo.get_history_undo_redo(_undo_redo.get_object_history_id(owner))


func _route_document_history_shortcut(event: InputEvent) -> bool:
	if not _is_focus_inside_editor():
		return false
	var key: InputEventKey = event as InputEventKey
	var is_z: bool = key.keycode == KEY_Z or key.physical_keycode == KEY_Z
	var is_y: bool = key.keycode == KEY_Y or key.physical_keycode == KEY_Y
	var redo_requested: bool = is_y or (is_z and key.shift_pressed)
	var history: UndoRedo = _document_history()
	if history == null:
		return false
	if redo_requested:
		history.redo()
	else:
		history.undo()
	return true


func set_schema(value: FlowChipFieldSchema) -> void:
	_schema = value
	if _document == null:
		var creation: FlowChipFieldCreationResult = FlowChipFieldFactory.new().create(_schema)
		_document = creation.document if creation.document != null else FlowStructuredDocument.new()
	_refresh()


func set_document(value: FlowStructuredDocument) -> void:
	_document = value if value != null else FlowStructuredDocument.new()
	_refresh()


## Supplies the existing graph-owned variable collection to the contextual
## selector. The graph remains the sole source of truth; the editor retains no
## copied variable database.
func set_variable_graph(value: FlowGraph) -> void:
	_variable_graph = value
	_refresh()


func get_variable_graph() -> FlowGraph:
	return _variable_graph


func get_schema() -> FlowChipFieldSchema:
	return _schema


func get_document() -> FlowStructuredDocument:
	return _document


func get_validation_result() -> FlowValidationResult:
	return _validation_result


func is_document_valid() -> bool:
	return not _validation_result.has_errors()


func get_feedback_text() -> String:
	return _feedback_text


func get_selected_segment_id() -> String:
	return _selected_segment_id


func get_current_position_id() -> String:
	return _current_position_id


func get_caret_segment_id() -> String:
	return _caret_segment_id


func get_caret_offset() -> int:
	return _caret_offset


func get_visual_elements() -> Array[Control]:
	return _visual_elements.duplicate()


func get_segment_control(segment_id: String) -> Control:
	return _visual_by_id.get(segment_id, null) as Control


func get_chip_control(segment_id: String) -> FlowChipControl:
	return get_segment_control(segment_id) as FlowChipControl


func get_text_control(segment_id: String) -> TextEdit:
	return get_segment_control(segment_id) as TextEdit


func get_variable_selector() -> FlowVariableSelector:
	return _variable_selector


func get_expression_editor() -> FlowExpressionEditor:
	return _expression_editor


func get_condition_editor() -> FlowConditionEditor:
	return _condition_editor


func get_operation_editor() -> FlowOperationEditor:
	return _operation_editor


func get_variable_edit_segment_id() -> String:
	return _variable_edit_segment_id if _variable_edit_active else ""


func get_expression_edit_segment_id() -> String:
	return _expression_edit_segment_id if _expression_edit_active else ""


func get_condition_edit_segment_id() -> String:
	return _condition_edit_segment_id if _condition_edit_active else ""


func get_operation_edit_segment_id() -> String:
	return _operation_edit_segment_id if _operation_edit_active else ""


## Exposes the pending semantic position for deterministic editor tests and
## future trigger types. The returned object is detached from editor state.
func get_pending_insertion_anchor() -> FlowChipSemanticInsertionAnchor:
	return _variable_trigger_anchor.duplicate_anchor() \
		if _variable_trigger_anchor != null else null


## Opens the shared graph-variable selector for a VariableRef segment. The
## selector context is derived from the segment's schema slot, not from its
## displayed label or array position.
func open_variable_selector_for_segment(segment_id: String) -> bool:
	if _variable_trigger_active or _variable_selector == null:
		return false
	var segment: FlowVariableRefSegment = _find_segment(segment_id) as FlowVariableRefSegment
	if segment == null:
		return false
	if not _can_change_variable_reference(segment):
		_on_chip_selected(segment_id)
		_reject(FEEDBACK_TOK_IMMUTABLE)
		_focus_chip(segment_id)
		return false
	var candidates: Array[FlowVariableDefinition] = \
		get_available_variable_definitions_for_segment(segment_id)
	if candidates.is_empty():
		_reject(FEEDBACK_NO_COMPATIBLE_VARIABLE)
		return false
	_on_chip_selected(segment_id)
	_variable_edit_active = true
	_variable_edit_segment_id = segment_id
	var chip: FlowChipControl = get_chip_control(segment_id)
	if chip == null:
		_clear_variable_edit_state()
		return false
	_variable_selector.open_for_variables(
		candidates,
		chip.get_global_rect(),
		"",
		_variable_selector_context_for_segment(segment)
	)
	return true


## Public contextual-editor boundary for a deliberate VariableRef replacement.
## Normal UI callers use the shared selector, while tests and future hosts can
## exercise the same schema/policy checks without editing a visible label.
func change_variable_reference(segment_id: String, variable_id: String) -> bool:
	return _change_variable_reference(segment_id, variable_id)


func refresh() -> void:
	_refresh()


func set_current_position(segment_id: String) -> bool:
	var segment: FlowDocumentSegment = _find_segment(segment_id)
	if segment == null:
		return false
	_current_position_id = segment_id
	if segment is FlowTextSegment:
		var text_segment: FlowTextSegment = segment as FlowTextSegment
		_caret_segment_id = segment_id
		_caret_offset = text_segment.text.length()
		_caret_boundary_index = -1
		_focus_text_control(segment_id, _caret_offset)
	else:
		_caret_segment_id = ""
		_caret_boundary_index = _find_segment_index(segment_id) + 1
	return true


## Places the real text caret at a codepoint offset inside one text segment.
func set_caret_position(segment_id: String, offset: int) -> bool:
	var text_segment: FlowTextSegment = _find_segment(segment_id) as FlowTextSegment
	if text_segment == null:
		return false
	_current_position_id = segment_id
	_caret_segment_id = segment_id
	_caret_offset = clampi(offset, 0, text_segment.text.length())
	_caret_boundary_index = -1
	_focus_text_control(segment_id, _caret_offset)
	# TextEdit may emit caret_changed while it is acquiring focus. Restore the
	# requested semantic anchor after that native focus notification.
	_caret_segment_id = segment_id
	_current_position_id = segment_id
	_caret_offset = clampi(offset, 0, text_segment.text.length())
	caret_changed.emit(segment_id, _caret_offset)
	return true


func set_caret_before_segment(segment_id: String) -> bool:
	var index: int = _find_segment_index(segment_id)
	if index < 0:
		return false
	var segment: FlowDocumentSegment = _find_segment(segment_id)
	if segment is FlowTextSegment:
		return set_caret_position(segment_id, 0)
	_caret_segment_id = ""
	_caret_offset = 0
	_caret_boundary_index = index
	_current_position_id = segment_id
	return true


func set_caret_after_segment(segment_id: String) -> bool:
	var index: int = _find_segment_index(segment_id)
	if index < 0:
		return false
	var segment: FlowDocumentSegment = _find_segment(segment_id)
	if segment is FlowTextSegment:
		return set_caret_position(segment_id, (segment as FlowTextSegment).text.length())
	_caret_segment_id = ""
	_caret_offset = 0
	_caret_boundary_index = index + 1
	_current_position_id = segment_id
	return true


## The future drag/drop boundary. The editor accepts a semantic source and does
## not inspect nodes, node paths, or package/block types.
func insert_value_source_at_caret(source: FlowValueSource) -> String:
	if _document == null or source == null:
		_reject("A value source is required.")
		return ""
	if not source.is_valid():
		_reject("The value source is structurally invalid.")
		return ""
	if not _can_insert_source(source):
		return ""
	if source is FlowVariableRefValueSource:
		return _insert_variable_source_at_caret(source as FlowVariableRefValueSource)

	var chip: FlowChipSegment = _chip_from_source(source)
	if chip == null:
		_reject("The value source cannot create a chip.")
		return ""
	var insertion_slot: FlowChipSlotDefinition = _insertion_slot_definition()
	if insertion_slot != null:
		chip.set_slot_id(insertion_slot.slot_id)
		chip.set_slot_kind(FlowChipSegment.SLOT_KIND_VARIADIC)
	var insert_index: int = _insertion_index()
	var before_segments: Array[FlowDocumentSegment] = _copy_segments(_document.segments)
	var before_text_states: Array[Dictionary] = _text_states_for_segments(before_segments)
	var after_segments: Array[FlowDocumentSegment] = _copy_segments(before_segments)
	var after_text_states: Array[Dictionary] = []
	var focus_id: String = ""
	var focus_offset: int = 0

	var caret_text: FlowTextSegment = _find_segment(_caret_segment_id) as FlowTextSegment
	if caret_text != null:
		var text_index: int = _find_segment_index(_caret_segment_id)
		var split_offset: int = clampi(_caret_offset, 0, caret_text.text.length())
		var prefix: String = caret_text.text.substr(0, split_offset)
		var suffix: String = caret_text.text.substr(split_offset)
		var following_text: FlowTextSegment = FlowTextSegment.new()
		following_text.text = suffix
		after_segments[text_index] = caret_text
		after_segments.insert(text_index + 1, chip)
		after_segments.insert(text_index + 2, following_text)
		after_text_states.append(_text_state(caret_text, prefix))
		after_text_states.append(_text_state(following_text, suffix))
		focus_id = following_text.get_segment_id()
		focus_offset = 0
	else:
		insert_index = clampi(insert_index, 0, after_segments.size())
		after_segments.insert(insert_index, chip)
		var following: FlowTextSegment = null
		if insert_index < after_segments.size() - 1:
			following = after_segments[insert_index + 1] as FlowTextSegment
		if following == null:
			following = FlowTextSegment.new()
			after_segments.insert(insert_index + 1, following)
		focus_id = following.get_segment_id()
		focus_offset = 0

	_selected_segment_id = chip.get_segment_id()
	_current_position_id = chip.get_segment_id()
	_caret_segment_id = focus_id
	_caret_offset = focus_offset
	_caret_boundary_index = -1
	_focus_restore_id = focus_id
	_focus_restore_offset = focus_offset
	_preserve_selection_during_focus_restore = true
	_clear_feedback()
	_commit_state_action(
		"Insert Chip",
		before_segments,
		before_text_states,
		after_segments,
		after_text_states
	)
	segment_selected.emit(chip.get_segment_id())
	return chip.get_segment_id()


func insert_value() -> String:
	# Keep the compatibility API's original diagnostic path (including the
	# schema max-count feedback); the visible + Value action uses the selector.
	return insert_value_source_at_caret(
		FlowLiteralValueSource.new(FlowLiteralValueSource.TYPE_INT, 0)
	)


## Inserts a graph-owned VariableRef through the same semantic source boundary
## used by the contextual @ trigger. The visible name is never accepted as the
## binding identity.
func insert_variable_ref_at_caret(variable_id: String) -> String:
	var variable: FlowVariableDefinition = _find_variable(variable_id)
	if variable == null:
		_reject(FEEDBACK_NO_COMPATIBLE_VARIABLE)
		return ""
	var source: FlowVariableRefValueSource = FlowVariableRefValueSource.new(
		variable.get_internal_id(),
		variable.value_type
	)
	return insert_value_source_at_caret(source)


func _insert_variable_source_at_caret(source: FlowVariableRefValueSource) -> String:
	if source == null:
		_reject(FEEDBACK_NO_COMPATIBLE_VARIABLE)
		return ""
	var variable: FlowVariableDefinition = _find_variable(source.variable_id)
	if _variable_graph != null and not _is_selectable_variable(variable):
		_reject(FEEDBACK_NO_COMPATIBLE_VARIABLE)
		return ""
	if variable != null and variable.get_declared_variant_type() != source.get_value_type():
		_reject(FEEDBACK_NO_COMPATIBLE_VARIABLE)
		return ""

	var context: Dictionary = _variable_insertion_context()
	var replacement_index: int = int(context.get("replacement_index", -1))
	var slot: FlowChipSlotDefinition = context.get("slot", null) as FlowChipSlotDefinition
	var before_segments: Array[FlowDocumentSegment] = _copy_segments(_document.segments)
	var before_text_states: Array[Dictionary] = _text_states_for_segments(before_segments)
	if _variable_trigger_active and not _variable_trigger_before_segments.is_empty():
		before_segments = _copy_segments(_variable_trigger_before_segments)
		before_text_states = _variable_trigger_before_text_states.duplicate()

	if replacement_index >= 0:
		var replacement_target: FlowChipSegment = _segment_at(replacement_index) as FlowChipSegment
		if replacement_target == null or slot == null:
			_cancel_variable_trigger(true)
			_reject(FEEDBACK_INVALID_CHIP_POSITION)
			return ""
		var replacement: FlowVariableRefSegment = FlowVariableRefSegment.new(source)
		# The fixed slot occurrence remains the same semantic location and
		# segment identity. Only its source changes from literal to VariableRef.
		replacement.segment_id = replacement_target.get_segment_id()
		replacement.set_slot_id(replacement_target.get_slot_id())
		replacement.set_slot_kind(replacement_target.get_slot_kind())
		var after_segments: Array[FlowDocumentSegment] = _copy_segments(before_segments)
		after_segments[replacement_index] = replacement
		var after_text_states: Array[Dictionary] = _text_states_for_segments(after_segments)
		if _variable_trigger_active:
			var trigger_text: FlowTextSegment = _find_segment(_variable_trigger_segment_id) as FlowTextSegment
			if trigger_text != null:
				var clean_text: String = _text_without_variable_trigger(trigger_text.text)
				after_text_states = [_text_state(trigger_text, clean_text)]
		_clear_variable_trigger_state()
		if _variable_selector != null and _variable_selector.visible:
			_variable_selector.hide()
		_selected_segment_id = replacement.get_segment_id()
		_current_position_id = replacement.get_segment_id()
		_caret_segment_id = ""
		_caret_boundary_index = replacement_index + 1
		_clear_feedback()
		_commit_state_action(
			"Insert Variable Reference",
			before_segments,
			before_text_states,
			after_segments,
			after_text_states
		)
		segment_selected.emit(replacement.get_segment_id())
		return replacement.get_segment_id()

	if not bool(context.get("allowed", false)):
		_cancel_variable_trigger(true)
		_reject(FEEDBACK_INVALID_CHIP_POSITION)
		return ""
	if slot != null:
		if not slot.accepts_value_type(source.get_value_type()) \
				or not slot.accepts_source_kind(source.get_source_kind()):
			_cancel_variable_trigger(true)
			_reject(FEEDBACK_NO_COMPATIBLE_VARIABLE)
			return ""

	var chip: FlowVariableRefSegment = FlowVariableRefSegment.new(source)
	if slot != null:
		chip.set_slot_id(slot.slot_id)
		chip.set_slot_kind(FlowChipSegment.SLOT_KIND_VARIADIC)
	var after_segments: Array[FlowDocumentSegment] = _copy_segments(before_segments)
	var after_text_states: Array[Dictionary] = []
	var focus_id: String = ""
	var focus_offset: int = 0
	if _variable_trigger_active:
		var trigger_text: FlowTextSegment = _find_segment(_variable_trigger_segment_id) as FlowTextSegment
		var text_index: int = _find_segment_index(_variable_trigger_segment_id)
		if trigger_text == null or text_index < 0:
			_cancel_variable_trigger(true)
			_reject(FEEDBACK_INVALID_CHIP_POSITION)
			return ""
		var trigger_start: int = clampi(_variable_trigger_start, 0, trigger_text.text.length())
		var trigger_end: int = clampi(_variable_trigger_end, trigger_start, trigger_text.text.length())
		var clean_prefix: String = trigger_text.text.substr(0, trigger_start)
		var clean_suffix: String = trigger_text.text.substr(trigger_end)
		var following_text: FlowTextSegment = FlowTextSegment.new()
		following_text.text = clean_suffix
		after_segments[text_index] = trigger_text
		after_segments.insert(text_index + 1, chip)
		after_segments.insert(text_index + 2, following_text)
		after_text_states.append(_text_state(trigger_text, clean_prefix))
		after_text_states.append(_text_state(following_text, clean_suffix))
		focus_id = following_text.get_segment_id()
	else:
		var caret_text: FlowTextSegment = _find_segment(_caret_segment_id) as FlowTextSegment
		if caret_text != null:
			var text_index: int = _find_segment_index(_caret_segment_id)
			var split_offset: int = clampi(_caret_offset, 0, caret_text.text.length())
			var prefix: String = caret_text.text.substr(0, split_offset)
			var suffix: String = caret_text.text.substr(split_offset)
			var following_text: FlowTextSegment = FlowTextSegment.new()
			following_text.text = suffix
			after_segments[text_index] = caret_text
			after_segments.insert(text_index + 1, chip)
			after_segments.insert(text_index + 2, following_text)
			after_text_states.append(_text_state(caret_text, prefix))
			after_text_states.append(_text_state(following_text, suffix))
			focus_id = following_text.get_segment_id()
		else:
			var insert_index: int = _insertion_index()
			after_segments.insert(insert_index, chip)
			var following: FlowTextSegment = null
			if insert_index < after_segments.size() - 1:
				following = after_segments[insert_index + 1] as FlowTextSegment
			if following == null:
				following = FlowTextSegment.new()
				after_segments.insert(insert_index + 1, following)
			focus_id = following.get_segment_id()

	_clear_variable_trigger_state()
	if _variable_selector != null and _variable_selector.visible:
		_variable_selector.hide()
	_selected_segment_id = chip.get_segment_id()
	_current_position_id = chip.get_segment_id()
	_caret_segment_id = focus_id
	_caret_offset = focus_offset
	_caret_boundary_index = -1
	_focus_restore_id = focus_id
	_focus_restore_offset = focus_offset
	_preserve_selection_during_focus_restore = true
	_clear_feedback()
	_commit_state_action(
		"Insert Variable Reference",
		before_segments,
		before_text_states,
		after_segments,
		after_text_states
	)
	segment_selected.emit(chip.get_segment_id())
	return chip.get_segment_id()


func _text_without_variable_trigger(text: String) -> String:
	if not _variable_trigger_active:
		return text
	var start: int = clampi(_variable_trigger_start, 0, text.length())
	var end: int = clampi(_variable_trigger_end, start, text.length())
	return text.substr(0, start) + text.substr(end)


func _complete_variable_trigger(variable_id: String) -> void:
	var variable: FlowVariableDefinition = _find_variable(variable_id)
	if not _is_selectable_variable(variable):
		_cancel_variable_trigger(true)
		_reject(FEEDBACK_NO_COMPATIBLE_VARIABLE)
		return
	var source: FlowVariableRefValueSource = FlowVariableRefValueSource.new(
		variable.get_internal_id(),
		variable.value_type
	)
	if _schema != null and not _schema.accepts_value_type(source.get_value_type()):
		_cancel_variable_trigger(true)
		_reject(FEEDBACK_NO_COMPATIBLE_VARIABLE)
		return
	_insert_variable_source_at_caret(source)


func get_available_variable_definitions() -> Array[FlowVariableDefinition]:
	var result: Array[FlowVariableDefinition] = []
	if _variable_graph == null:
		return result
	var context: Dictionary = _variable_insertion_context()
	if not bool(context.get("allowed", false)):
		return result
	if not _variable_insertion_policy_allows(context):
		return result
	var slot: FlowChipSlotDefinition = context.get("slot", null) as FlowChipSlotDefinition
	return _available_variables_for_context(
		slot,
		_accepted_value_types_for_slot(slot),
		_accepted_source_kinds_for_slot(slot)
	)


## Returns compatible definitions for an existing VariableRef, including an
## unresolved reference. Replacement does not consume another variadic slot.
func get_available_variable_definitions_for_segment(segment_id: String) -> Array[FlowVariableDefinition]:
	var segment: FlowVariableRefSegment = _find_segment(segment_id) as FlowVariableRefSegment
	if segment == null or _variable_graph == null:
		return []
	var slot: FlowChipSlotDefinition = _slot_definition_for(segment)
	var accepted_types: Array[Variant.Type] = _accepted_value_types_for_slot(slot)
	if _is_value_type_locked_for_segment(segment):
		accepted_types = [segment.get_value_source().get_value_type()]
	return _available_variables_for_context(
		slot,
		accepted_types,
		_accepted_source_kinds_for_slot(slot)
	)


func _available_variables_for_context(
		slot: FlowChipSlotDefinition,
		accepted_types: Array[Variant.Type],
		accepted_sources: Array[StringName]
) -> Array[FlowVariableDefinition]:
	var result: Array[FlowVariableDefinition] = []
	if _variable_graph == null:
		return result
	for variable: FlowVariableDefinition in _variable_graph.variables:
		if not _is_selectable_variable(variable):
			continue
		var candidate_type: Variant.Type = variable.get_declared_variant_type()
		if not accepted_types.is_empty() and not accepted_types.has(candidate_type):
			continue
		if not accepted_sources.is_empty() \
				and not accepted_sources.has(FlowValueSource.SOURCE_KIND_VARIABLE_REF):
			continue
		if slot != null and not slot.accepts_value_type(candidate_type):
			continue
		if slot != null and not slot.accepts_source_kind(FlowValueSource.SOURCE_KIND_VARIABLE_REF):
			continue
		result.append(variable)
	return result


func _accepted_value_types_for_slot(slot: FlowChipSlotDefinition) -> Array[Variant.Type]:
	var schema_types: Array[Variant.Type] = []
	if _schema != null:
		schema_types = _schema.accepted_value_types.duplicate()
	if slot == null or slot.accepted_value_types.is_empty():
		return schema_types
	if schema_types.is_empty():
		return slot.accepted_value_types.duplicate()
	var result: Array[Variant.Type] = []
	for candidate: Variant.Type in schema_types:
		if slot.accepted_value_types.has(candidate):
			result.append(candidate)
	return result


func _accepted_source_kinds_for_slot(slot: FlowChipSlotDefinition) -> Array[StringName]:
	var schema_sources: Array[StringName] = []
	if _schema != null:
		schema_sources = _schema.accepted_source_kinds.duplicate()
	if slot == null or slot.accepted_source_kinds.is_empty():
		return schema_sources
	if schema_sources.is_empty():
		return slot.accepted_source_kinds.duplicate()
	var result: Array[StringName] = []
	for candidate: StringName in schema_sources:
		if slot.accepted_source_kinds.has(candidate):
			result.append(candidate)
	return result


func _variable_selector_context_for_insertion(slot: FlowChipSlotDefinition) -> Dictionary:
	var context: Dictionary = {
		"schema": _schema,
		"slot": slot,
		"zone": FlowChipSegment.SLOT_KIND_NAMED if _schema != null \
				and _schema.mode == FlowChipFieldSchema.Mode.FIXED \
			else FlowChipSegment.SLOT_KIND_VARIADIC,
		"value_type": Variant.Type.TYPE_NIL,
		"accepted_value_types": _accepted_value_types_for_slot(slot),
		"accepted_source_kinds": _accepted_source_kinds_for_slot(slot),
		"current_variable_id": "",
	}
	var insertion_context: Dictionary = _variable_insertion_context()
	var replacement_index: int = int(insertion_context.get("replacement_index", -1))
	var replacement: FlowChipSegment = _segment_at(replacement_index) as FlowChipSegment
	if replacement != null:
		var replacement_source: FlowValueSource = replacement.get_value_source()
		if replacement_source != null:
			context["value_type"] = replacement_source.get_value_type()
			context["value_type_locked"] = _is_value_type_locked_for_segment(replacement)
			context["source_kind_locked"] = _is_source_kind_locked_for_segment(replacement)
	return context


func _variable_selector_context_for_segment(segment: FlowVariableRefSegment) -> Dictionary:
	var source: FlowVariableRefValueSource = \
		segment.get_value_source() as FlowVariableRefValueSource
	var slot: FlowChipSlotDefinition = _slot_definition_for(segment)
	return {
		"schema": _schema,
		"slot": slot,
		"zone": segment.get_slot_kind(),
		"value_type": source.get_value_type() if source != null else Variant.Type.TYPE_NIL,
		"accepted_value_types": _accepted_value_types_for_slot(slot),
		"accepted_source_kinds": _accepted_source_kinds_for_slot(slot),
		"current_variable_id": source.variable_id if source != null else "",
		"value_type_locked": _is_value_type_locked_for_segment(segment),
		"source_kind_locked": _is_source_kind_locked_for_segment(segment),
	}


func get_variable_insertion_feedback() -> String:
	if _document == null:
		return FEEDBACK_INVALID_CHIP_POSITION
	var context: Dictionary = _variable_insertion_context()
	if not bool(context.get("allowed", false)):
		return FEEDBACK_INVALID_CHIP_POSITION
	if not _variable_insertion_policy_allows(context):
		return _variable_insertion_policy_feedback(context)
	var slot: FlowChipSlotDefinition = context.get("slot", null) as FlowChipSlotDefinition
	if _schema != null and not _schema.accepts_source_kind(FlowValueSource.SOURCE_KIND_VARIABLE_REF):
		return FEEDBACK_NO_COMPATIBLE_VARIABLE
	if slot != null and not slot.accepts_source_kind(FlowValueSource.SOURCE_KIND_VARIABLE_REF):
		return FEEDBACK_NO_COMPATIBLE_VARIABLE
	if int(context.get("replacement_index", -1)) < 0 and _insertion_limit_reached(slot):
		return FEEDBACK_MAX_CHIP_COUNT % _insertion_maximum(slot)
	if _variable_graph == null or get_available_variable_definitions().is_empty():
		return FEEDBACK_NO_COMPATIBLE_VARIABLE
	return ""


func _variable_insertion_policy_allows(context: Dictionary) -> bool:
	var replacement_index: int = int(context.get("replacement_index", -1))
	if replacement_index < 0:
		if not _schema_can_change_reference():
			return false
		var insertion_slot: FlowChipSlotDefinition = context.get("slot", null) as FlowChipSlotDefinition
		return insertion_slot == null or insertion_slot.can_change_reference()
	var target: FlowChipSegment = _segment_at(replacement_index) as FlowChipSegment
	if target == null:
		return false
	var source: FlowValueSource = target.get_value_source()
	if source is FlowVariableRefValueSource:
		return _can_change_variable_reference(target as FlowVariableRefSegment)
	if not _schema_can_change_reference():
		return false
	var definition: FlowChipSlotDefinition = context.get("slot", null) as FlowChipSlotDefinition
	return definition == null or definition.can_change_source_kind()


func _variable_insertion_policy_feedback(context: Dictionary) -> String:
	var replacement_index: int = int(context.get("replacement_index", -1))
	var target: FlowChipSegment = _segment_at(replacement_index) as FlowChipSegment
	if target != null and target.get_value_source() is FlowVariableRefValueSource:
		return FEEDBACK_TOK_IMMUTABLE if not _can_change_variable_reference(target as FlowVariableRefSegment) \
			else FEEDBACK_NO_COMPATIBLE_VARIABLE
	if replacement_index < 0:
		var insertion_slot: FlowChipSlotDefinition = context.get("slot", null) as FlowChipSlotDefinition
		if not _schema_can_change_reference() \
				or (insertion_slot != null and not insertion_slot.can_change_reference()):
			return FEEDBACK_TOK_IMMUTABLE
	return FEEDBACK_TOK_SOURCE_KIND_LOCKED


## Returns the graph-owned definition for a stable variable ID. Display names
## are intentionally not accepted as lookup keys.
func _find_variable(variable_id: String) -> FlowVariableDefinition:
	if _variable_graph == null or variable_id.is_empty():
		return null
	for variable: FlowVariableDefinition in _variable_graph.variables:
		if variable != null and variable.get_internal_id() == variable_id:
			return variable
	return null


func _is_selectable_variable(variable: FlowVariableDefinition) -> bool:
	if variable == null or not FlowId.is_valid(variable.get_internal_id()):
		return false
	return FlowVariableDefinition.is_valid_value_type(variable.value_type) \
		and variable.get_declared_variant_type() != Variant.Type.TYPE_NIL


## Computes the semantic insertion context without copying graph variables into
## editor state. The replacement index is used only by FIXED fields; FLEXIBLE
## and HYBRID fields insert a new occurrence in their variadic zone.
func _variable_insertion_context() -> Dictionary:
	var context: Dictionary = {
		"allowed": false,
		"slot": null,
		"replacement_index": -1,
	}
	if _document == null:
		return context
	if _schema == null:
		context["allowed"] = true
		return context
	if not FlowChipFieldSchema.is_valid_mode(_schema.mode):
		return context

	match _schema.mode:
		FlowChipFieldSchema.Mode.FIXED:
			var replacement_index: int = _fixed_replacement_index()
			var replacement: FlowChipSegment = _segment_at(replacement_index) as FlowChipSegment
			var replacement_slot: FlowChipSlotDefinition = _slot_definition_for(replacement)
			if replacement != null and replacement_slot != null:
				context["allowed"] = true
				context["slot"] = replacement_slot
				context["replacement_index"] = replacement_index
		FlowChipFieldSchema.Mode.FLEXIBLE:
			context["allowed"] = true
			context["slot"] = _schema.variadic_slot_definition
		FlowChipFieldSchema.Mode.HYBRID:
			var variadic: FlowChipSlotDefinition = _insertion_slot_definition()
			if variadic != null:
				context["allowed"] = true
				context["slot"] = variadic
	return context


## Finds the fixed chip adjacent to the active semantic caret. Typing at the
## end of the preceding text selects the following chip; typing at the start of
## following text selects the preceding chip. This keeps replacement stable for
## both sides of a generated FIXED token.
func _fixed_replacement_index() -> int:
	if _schema == null or _schema.mode != FlowChipFieldSchema.Mode.FIXED \
			or _document == null:
		return -1
	var text_segment_id: String = _variable_trigger_segment_id \
		if _variable_trigger_active else _caret_segment_id
	if not text_segment_id.is_empty():
		var text_index: int = _find_segment_index(text_segment_id)
		var text_segment: FlowTextSegment = _find_segment(text_segment_id) as FlowTextSegment
		if text_index >= 0 and text_segment != null:
			var offset: int = _variable_trigger_start \
				if _variable_trigger_active else _caret_offset
			if _variable_trigger_active:
				if _is_fixed_replacement_chip(_neighbor_non_null(text_index, -1)) \
						and offset == 0:
					return _find_segment_index(_neighbor_non_null(text_index, -1).get_segment_id())
				if _is_fixed_replacement_chip(_neighbor_non_null(text_index, 1)) \
						and _variable_trigger_end >= text_segment.text.length():
					return _find_segment_index(_neighbor_non_null(text_index, 1).get_segment_id())
			else:
				if _is_fixed_replacement_chip(_neighbor_non_null(text_index, -1)) \
						and offset == 0:
					return _find_segment_index(_neighbor_non_null(text_index, -1).get_segment_id())
				if _is_fixed_replacement_chip(_neighbor_non_null(text_index, 1)) \
						and offset == text_segment.text.length():
					return _find_segment_index(_neighbor_non_null(text_index, 1).get_segment_id())
	if _caret_boundary_index >= 0:
		var left: FlowDocumentSegment = _neighbor_non_null(_caret_boundary_index, -1)
		var right: FlowDocumentSegment = _neighbor_non_null(_caret_boundary_index - 1, 1)
		if _is_fixed_replacement_chip(left):
			return _find_segment_index(left.get_segment_id())
		if _is_fixed_replacement_chip(right):
			return _find_segment_index(right.get_segment_id())
	if not _current_position_id.is_empty():
		var current: FlowDocumentSegment = _find_segment(_current_position_id)
		if _is_fixed_replacement_chip(current):
			return _find_segment_index(_current_position_id)
	return -1


func _is_fixed_replacement_chip(segment: FlowDocumentSegment) -> bool:
	var chip: FlowChipSegment = segment as FlowChipSegment
	if chip == null or chip.get_slot_kind() == FlowChipSegment.SLOT_KIND_VARIADIC:
		return false
	return _slot_definition_for(chip) != null


## Returns the literal Variant.Type values that are valid at the current
## semantic caret. The list is deliberately derived from the schema instead of
## being a fixture-specific menu definition.
func get_insertable_literal_types() -> Array[Variant.Type]:
	if not get_literal_insertion_feedback().is_empty():
		return []
	return _literal_types_allowed_by_schema(_insertion_slot_definition())


## Returns the schema-derived reason why + Value cannot offer a literal selector.
## An empty result means that at least one literal type is currently insertable.
func get_literal_insertion_feedback() -> String:
	if _document == null:
		return FEEDBACK_INVALID_CHIP_POSITION
	if _schema == null:
		return ""
	if not FlowChipFieldSchema.is_valid_mode(_schema.mode) \
			or _schema.mode == FlowChipFieldSchema.Mode.FIXED:
		return FEEDBACK_INVALID_CHIP_POSITION
	if not _schema.accepts_source_kind(FlowValueSource.SOURCE_KIND_LITERAL):
		return FEEDBACK_NO_COMPATIBLE_LITERAL
	var definition: FlowChipSlotDefinition = _insertion_slot_definition()
	if _schema.mode == FlowChipFieldSchema.Mode.HYBRID and definition == null:
		return FEEDBACK_INVALID_CHIP_POSITION
	if not _schema_can_change_content() \
			or (definition != null and not definition.can_change_content()):
		return FEEDBACK_TOK_IMMUTABLE
	if definition != null \
			and not definition.accepts_source_kind(FlowValueSource.SOURCE_KIND_LITERAL):
		return FEEDBACK_NO_COMPATIBLE_LITERAL
	if _insertion_limit_reached(definition):
		return FEEDBACK_MAX_CHIP_COUNT % _insertion_maximum(definition)
	if _literal_types_allowed_by_schema(definition).is_empty():
		return FEEDBACK_NO_COMPATIBLE_LITERAL
	return ""


## Public typed insertion boundary used by the reusable literal selector and
## focal tests. Defaults come from the generic descriptor contract.
func insert_literal_type_at_caret(value_type: Variant.Type) -> String:
	var available: Array[Variant.Type] = get_insertable_literal_types()
	if available.is_empty():
		var feedback: String = get_literal_insertion_feedback()
		_reject(feedback if not feedback.is_empty() else FEEDBACK_NO_COMPATIBLE_LITERAL)
		return ""
	if not available.has(value_type):
		_reject("Literal type %s is not accepted at the current caret." % _literal_type_label(value_type))
		return ""
	var default_value: Variant = FlowChipTypeDescriptor.default_value_for_type(value_type)
	return insert_value_source_at_caret(FlowLiteralValueSource.new(value_type, default_value))


func _open_literal_type_selector() -> void:
	if _literal_type_menu == null:
		return
	_literal_type_menu.clear()
	var feedback: String = get_literal_insertion_feedback()
	if not feedback.is_empty():
		_reject(feedback)
		return
	var available: Array[Variant.Type] = get_insertable_literal_types()
	if available.is_empty():
		_reject(FEEDBACK_NO_COMPATIBLE_LITERAL)
		return
	for value_type: Variant.Type in available:
		_literal_type_menu.add_item(_literal_type_label(value_type), int(value_type))
	_literal_type_menu.popup_on_parent(Rect2i(
		0,
		int(_add_value_button.size.y),
		int(_add_value_button.size.x),
		0
	))


func _on_literal_type_selected(item_id: int) -> void:
	insert_literal_type_at_caret(item_id)


func _literal_type_label(value_type: Variant.Type) -> String:
	match value_type:
		FlowLiteralValueSource.TYPE_BOOL:
			return "Bool"
		FlowLiteralValueSource.TYPE_INT:
			return "Int"
		FlowLiteralValueSource.TYPE_FLOAT:
			return "Float"
		FlowLiteralValueSource.TYPE_STRING:
			return "String"
		FlowLiteralValueSource.TYPE_STRING_NAME:
			return "StringName"
	return "Unknown"


func select_segment(segment_id: String) -> bool:
	var segment: FlowDocumentSegment = _find_segment(segment_id)
	if segment == null:
		return false
	if segment is FlowChipSegment:
		_on_chip_selected(segment_id)
	else:
		_current_position_id = segment_id
		_selected_segment_id = ""
		_update_chip_selection()
		_render_details()
		segment_selected.emit("")
	return true


func delete_selected_chip() -> bool:
	return delete_chip(_selected_segment_id)


func delete_chip(segment_id: String) -> bool:
	var segment: FlowChipSegment = _find_segment(segment_id) as FlowChipSegment
	var index: int = _find_segment_index(segment_id)
	if segment == null or index < 0:
		return false
	if not _can_delete_chip(segment):
		return false

	var focus_target: Dictionary = _focus_target_after_removal(index)
	var before_segments: Array[FlowDocumentSegment] = _copy_segments(_document.segments)
	var before_text_states: Array[Dictionary] = _text_states_for_segments(before_segments)
	var after_segments: Array[FlowDocumentSegment] = _copy_segments(before_segments)
	after_segments.remove_at(index)
	_selected_segment_id = ""
	_current_position_id = String(focus_target.get("id", ""))
	_caret_segment_id = _current_position_id if focus_target.get("is_text", false) else ""
	_caret_offset = int(focus_target.get("offset", 0))
	_caret_boundary_index = -1
	_focus_restore_id = _caret_segment_id
	_focus_restore_offset = _caret_offset
	_clear_feedback()
	_commit_state_action(
		"Delete Chip",
		before_segments,
		before_text_states,
		after_segments,
		_text_states_for_segments(after_segments)
	)
	segment_selected.emit("")
	return true


func change_selected_chip_type(new_type: Variant.Type) -> bool:
	var segment: FlowChipSegment = _selected_chip()
	if segment == null:
		return false
	var descriptor: FlowChipTypeDescriptor = segment.get_chip_type_descriptor()
	if descriptor == null or not descriptor.editable \
			or not descriptor.supports_variant_type(new_type) \
			or not _accepts_chip_type(segment, new_type):
		return false
	if not _can_change_chip_content(segment):
		_reject(FEEDBACK_TOK_IMMUTABLE)
		return false
	if not _can_change_chip_type(segment, new_type):
		_reject(FEEDBACK_TOK_TYPE_LOCKED)
		return false
	var previous_type: Variant.Type = segment.get_editable_value_type()
	var previous_value: Variant = segment.get_editable_value()
	if previous_type == new_type:
		return false
	var next_value: Variant = segment.get_default_editable_value(new_type)
	if not segment.can_set_editable_value(new_type, next_value):
		return false
	if _undo_redo == null:
		_apply_chip_value(segment, new_type, next_value)
	else:
		_undo_redo.create_action("Change Chip Type", UndoRedo.MERGE_DISABLE, _history_owner(), false, true)
		_undo_redo.force_fixed_history()
		_undo_redo.add_do_method(self, &"_apply_chip_value", segment, new_type, next_value)
		_undo_redo.add_undo_method(self, &"_apply_chip_value", segment, previous_type, previous_value)
		_undo_redo.commit_action()
	_clear_feedback()
	return true


func set_selected_chip_value(value: Variant) -> bool:
	var segment: FlowChipSegment = _selected_chip()
	return _set_chip_value(segment, value)


func _set_chip_value(segment: FlowChipSegment, value: Variant) -> bool:
	if segment == null:
		return false
	if not _can_change_chip_content(segment):
		_reject(FEEDBACK_TOK_IMMUTABLE)
		return false
	var value_type: Variant.Type = typeof(value)
	if value_type != segment.get_editable_value_type() \
			or not _accepts_chip_type(segment, value_type) \
			or not segment.can_set_editable_value(value_type, value):
		return false
	var previous_value: Variant = segment.get_editable_value()
	if previous_value == value:
		return false
	if _undo_redo == null:
		_apply_chip_value(segment, value_type, value)
	else:
		_undo_redo.create_action("Change Chip Value", UndoRedo.MERGE_DISABLE, _history_owner(), false, true)
		_undo_redo.force_fixed_history()
		_undo_redo.add_do_method(self, &"_apply_chip_value", segment, value_type, value)
		_undo_redo.add_undo_method(
			self,
			&"_apply_chip_value",
			segment,
			value_type,
			previous_value
		)
		_undo_redo.commit_action()
	_clear_feedback()
	return true


func set_text_segment_text(segment_id: String, text: String) -> bool:
	var segment: FlowTextSegment = _find_segment(segment_id) as FlowTextSegment
	if segment == null or segment.text == text:
		return false
	var previous_text: String = segment.text
	if _undo_redo == null:
		_apply_text(segment, text)
	else:
		_undo_redo.create_action("Edit Structured Text", UndoRedo.MERGE_DISABLE, _history_owner(), false, true)
		_undo_redo.force_fixed_history()
		_undo_redo.add_do_method(self, &"_apply_text", segment, text)
		_undo_redo.add_undo_method(self, &"_apply_text", segment, previous_text)
		_undo_redo.commit_action()
	_clear_feedback()
	return true


func move_selected_chip(direction: int) -> bool:
	var segment: FlowChipSegment = _selected_chip()
	if segment == null or direction == 0:
		return false
	return move_chip(segment.get_segment_id(), direction)


func move_chip(segment_id: String, direction: int) -> bool:
	var segment: FlowChipSegment = _find_segment(segment_id) as FlowChipSegment
	var from_index: int = _find_segment_index(segment_id)
	if segment == null or from_index < 0 or direction == 0:
		return false
	if not _can_reorder_chip(segment):
		return false
	var target_index: int = from_index + (1 if direction > 0 else -1)
	while target_index >= 0 and target_index < _document.segments.size() \
			and _document.segments[target_index] == null:
		target_index += 1 if direction > 0 else -1
	if target_index < 0 or target_index >= _document.segments.size():
		return false
	var neighbor: FlowDocumentSegment = _document.segments[target_index]
	if neighbor is FlowChipSegment and not _can_reorder_chip(neighbor as FlowChipSegment):
		_reject("The neighboring chip cannot be reordered by this schema.")
		return false
	var before_segments: Array[FlowDocumentSegment] = _copy_segments(_document.segments)
	var after_segments: Array[FlowDocumentSegment] = _copy_segments(before_segments)
	after_segments.remove_at(from_index)
	after_segments.insert(target_index, segment)
	_commit_state_action(
		"Move Chip",
		before_segments,
		_text_states_for_segments(before_segments),
		after_segments,
		_text_states_for_segments(after_segments)
	)
	_selected_segment_id = segment_id
	_current_position_id = segment_id
	_clear_feedback()
	return true


func _refresh() -> void:
	_rebuild_generation += 1
	_rebuild_interface(_rebuild_generation)


func _queue_refresh() -> void:
	_rebuild_generation += 1
	if _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred(&"_rebuild_interface", _rebuild_generation)


func _rebuild_interface(generation: int) -> void:
	if generation != _rebuild_generation:
		_rebuild_queued = false
		_queue_refresh()
		return
	_rebuild_queued = false
	if _surface == null:
		return
	_capture_focus_anchor()
	_text_history_sessions.clear()
	_value_history_sessions.clear()
	_suppress_input = true
	for child: Node in _surface.get_children():
		_surface.remove_child(child)
		child.free()
	_visual_elements.clear()
	_visual_by_id.clear()

	if _document != null:
		_refresh_variable_resolutions()
		for segment: FlowDocumentSegment in _document.segments:
			if segment == null:
				continue
			var control: Control = _create_segment_control(segment)
			if control == null:
				continue
			_surface.add_child(control)
			_visual_elements.append(control)
			_visual_by_id[segment.get_segment_id()] = control
	_suppress_input = false
	if not _id_exists(_selected_segment_id):
		_selected_segment_id = ""
	if not _id_exists(_caret_segment_id):
		_caret_segment_id = ""
	_update_chip_selection()
	_render_details()
	_refresh_validation()
	_update_toolbar_state()
	_restore_focus_anchor()


func _create_segment_control(segment: FlowDocumentSegment) -> Control:
	if segment is FlowChipSegment:
		var chip: FlowChipControl = FLOW_CHIP_CONTROL_SCRIPT.new() as FlowChipControl
		chip.name = "FlowChip_" + segment.get_segment_id()
		chip.set_segment(segment as FlowChipSegment)
		chip.set_editability(
			_can_edit_chip(segment as FlowChipSegment),
			_is_value_type_locked_for_segment(segment as FlowChipSegment),
			_is_source_kind_locked_for_segment(segment as FlowChipSegment)
		)
		chip.chip_selected.connect(_on_chip_selected)
		chip.chip_edit_requested.connect(_on_chip_edit_requested)
		chip.delete_requested.connect(_on_chip_delete_requested)
		chip.focus_previous_requested.connect(_on_chip_focus_previous.bind(segment.get_segment_id()))
		chip.focus_next_requested.connect(_on_chip_focus_next.bind(segment.get_segment_id()))
		chip.focus_entered.connect(_on_chip_focus_entered.bind(segment.get_segment_id()))
		return chip
	if segment is FlowTextSegment:
		var text_segment: FlowTextSegment = segment as FlowTextSegment
		var text_control: TextEdit = FLOW_CHIP_TEXT_EDIT_SCRIPT.new() as TextEdit
		text_control.name = "FlowText_" + segment.get_segment_id()
		text_control.focus_mode = Control.FOCUS_ALL
		text_control.mouse_default_cursor_shape = Control.CURSOR_IBEAM
		text_control.wrap_mode = TextEdit.LINE_WRAPPING_NONE
		text_control.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		text_control.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		text_control.text = text_segment.text
		text_control.custom_minimum_size = _text_minimum_size(text_control, text_control.text)
		text_control.add_theme_stylebox_override(&"normal", StyleBoxEmpty.new())
		text_control.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
		text_control.text_changed.connect(_on_text_control_changed.bind(segment.get_segment_id(), text_control))
		text_control.caret_changed.connect(_on_text_caret_changed.bind(segment.get_segment_id(), text_control))
		text_control.focus_entered.connect(_on_text_control_focused.bind(segment.get_segment_id(), text_control))
		text_control.focus_exited.connect(_on_text_control_focus_exited.bind(segment.get_segment_id(), text_control))
		text_control.gui_input.connect(_on_text_gui_input.bind(segment.get_segment_id(), text_control))
		return text_control
	var unsupported: Label = Label.new()
	unsupported.text = "[Unsupported segment]"
	unsupported.tooltip_text = "This segment cannot be displayed by the chip field editor."
	return unsupported


func _text_minimum_size(input: TextEdit, text: String) -> Vector2:
	var font: Font = input.get_theme_font(&"font")
	var font_size: int = input.get_theme_font_size(&"font_size")
	if font == null:
		return Vector2(maxf(24.0, float(text.length() * 8)), 24.0)
	var lines: PackedStringArray = text.split("\n", true)
	var width: float = 18.0
	for line: String in lines:
		width = maxf(width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 4.0)
	var line_height: float = font.get_height(font_size)
	return Vector2(width, maxf(line_height + 4.0, line_height * float(maxi(lines.size(), 1)) + 4.0))


func _on_text_control_focused(segment_id: String, input: TextEdit) -> void:
	if _suppress_input:
		return
	_current_position_id = segment_id
	_caret_segment_id = segment_id
	_caret_offset = _text_offset(input)
	_caret_boundary_index = -1
	if not _preserve_selection_during_focus_restore:
		_selected_segment_id = ""
	_update_chip_selection()
	_render_details()
	segment_selected.emit("")


func _on_text_control_focus_exited(_segment_id: String, _input: TextEdit) -> void:
	# The live model is already current. Clearing only the coalescing handle
	# makes the next separately focused edit start a fresh Undo/Redo action.
	_text_history_sessions.erase(_segment_id)


func _on_text_caret_changed(segment_id: String, input: TextEdit) -> void:
	if _suppress_input:
		return
	_caret_segment_id = segment_id
	_current_position_id = segment_id
	_caret_offset = _text_offset(input)
	_caret_boundary_index = -1
	caret_changed.emit(segment_id, _caret_offset)


func _on_text_control_changed(segment_id: String, input: TextEdit) -> void:
	if _suppress_input or _document == null:
		return
	var segment: FlowTextSegment = _find_segment(segment_id) as FlowTextSegment
	if segment == null or segment.text == input.text:
		return
	_caret_segment_id = segment_id
	_current_position_id = segment_id
	var text_offset: int = _text_offset(input)
	if _variable_trigger_active and segment_id == _variable_trigger_segment_id:
		if not _pending_variable_trigger_exists(input.text):
			_cancel_variable_trigger(true)
			return
		_variable_trigger_end = maxi(_variable_trigger_start + 1, text_offset)
		_set_document_text_without_history(segment, input.text, input, text_offset)
		return
	if _expression_trigger_active and segment_id == _expression_trigger_segment_id:
		if not _pending_expression_trigger_exists(input.text):
			_cancel_expression_trigger(true)
			return
		_expression_trigger_end = maxi(_expression_trigger_start + 1, text_offset)
		_set_document_text_without_history(segment, input.text, input, text_offset)
		return
	if _condition_trigger_active and segment_id == _condition_trigger_segment_id:
		if not _pending_condition_trigger_exists(input.text):
			_cancel_condition_trigger(true)
			return
		_condition_trigger_end = maxi(_condition_trigger_start + 1, text_offset)
		_set_document_text_without_history(segment, input.text, input, text_offset)
		return
	# A host may assign TextEdit.text and emit text_changed while the native
	# control keeps its old column (usually zero). Real typing/paste updates the
	# caret with the edit, so only the stale non-empty zero-column case defaults
	# to the end for this programmatic compatibility path.
	if text_offset == 0 and not input.text.is_empty() and input.text != segment.text:
		text_offset = input.text.length()
	var change: Dictionary = _changed_text_span(segment.text, input.text)
	var normalized: Dictionary = _normalize_active_escapes(
		input.text,
		int(change.get("start", 0)),
		int(change.get("end", input.text.length())),
		text_offset
	)
	var normalized_text: String = String(normalized.get("text", input.text))
	var normalized_caret: int = int(normalized.get("caret", text_offset))
	var trigger_start: int = _find_unescaped_trigger(
		normalized_text,
		int(change.get("start", 0)),
		int(change.get("end", normalized_text.length())),
		normalized.get("escaped_positions", []) as Array[int],
		"@"
	)
	if trigger_start >= 0:
		var before_segments: Array[FlowDocumentSegment] = _copy_segments(_document.segments)
		var before_text_states: Array[Dictionary] = _text_states_for_segments(before_segments)
		_set_text_control_value(input, normalized_text, normalized_caret)
		_begin_variable_trigger(
			segment,
			input,
			normalized_text,
			trigger_start,
			normalized_caret,
			before_segments,
			before_text_states
		)
		return
	var condition_start: int = _find_unescaped_trigger(
		normalized_text,
		int(change.get("start", 0)),
		int(change.get("end", normalized_text.length())),
		normalized.get("escaped_positions", []) as Array[int],
		"#"
	)
	if condition_start >= 0:
		var condition_before_segments: Array[FlowDocumentSegment] = _copy_segments(_document.segments)
		var condition_before_text_states: Array[Dictionary] = _text_states_for_segments(
			condition_before_segments
		)
		_set_text_control_value(input, normalized_text, normalized_caret)
		_begin_condition_trigger(
			segment,
			input,
			normalized_text,
			condition_start,
			normalized_caret,
			condition_before_segments,
			condition_before_text_states
		)
		return
	var operation_start: int = _find_unescaped_trigger(
		normalized_text,
		int(change.get("start", 0)),
		int(change.get("end", normalized_text.length())),
		normalized.get("escaped_positions", []) as Array[int],
		"~"
	)
	if operation_start >= 0:
		var operation_before_segments: Array[FlowDocumentSegment] = _copy_segments(_document.segments)
		var operation_before_text_states: Array[Dictionary] = _text_states_for_segments(
			operation_before_segments
		)
		_set_text_control_value(input, normalized_text, normalized_caret)
		_begin_operation_trigger(
			segment,
			input,
			normalized_text,
			operation_start,
			normalized_caret,
			operation_before_segments,
			operation_before_text_states
		)
		return
	if normalized_text != input.text:
		var before_segments: Array[FlowDocumentSegment] = _copy_segments(_document.segments)
		var before_text_states: Array[Dictionary] = _text_states_for_segments(before_segments)
		var after_segments: Array[FlowDocumentSegment] = _copy_segments(before_segments)
		var after_text_states: Array[Dictionary] = [_text_state(segment, normalized_text)]
		_commit_state_action(
			"Edit Structured Text",
			before_segments,
			before_text_states,
			after_segments,
			after_text_states
		)
		_set_text_control_value(input, normalized_text, normalized_caret)
		_caret_offset = normalized_caret
		return
	_caret_offset = text_offset
	_record_native_text_change(segment_id, input, input.text)
	input.custom_minimum_size = _text_minimum_size(input, input.text)
	_surface.queue_sort()


func _changed_text_span(before: String, after: String) -> Dictionary:
	var prefix: int = 0
	var common_limit: int = mini(before.length(), after.length())
	while prefix < common_limit and before[prefix] == after[prefix]:
		prefix += 1
	var suffix: int = 0
	while suffix < before.length() - prefix and suffix < after.length() - prefix \
			and before[before.length() - 1 - suffix] == after[after.length() - 1 - suffix]:
		suffix += 1
	return {
		"start": prefix,
		"end": after.length() - suffix,
	}


## Normalizes only active escape pairs that intersect the current native edit.
## Future trigger characters can be added to this small scanner without making
## the document parser aware of them. $ is intentionally not active.
func _normalize_active_escapes(
		text: String,
		changed_start: int,
		changed_end: int,
		raw_caret: int
) -> Dictionary:
	var normalized: String = ""
	var escaped_positions: Array[int] = []
	var normalized_caret: int = 0
	var index: int = 0
	while index < text.length():
		var pair_is_active: bool = index + 1 < text.length() \
			and text[index] == "\\" \
		and (text[index + 1] == "@" or text[index + 1] == "#" \
			or text[index + 1] == "~" or text[index + 1] == "\\")
		var pair_intersects_change: bool = pair_is_active \
			and index < changed_end \
			and index + 2 > changed_start
		if pair_intersects_change:
			if index < raw_caret:
				normalized_caret += 1
			var output_index: int = normalized.length()
			normalized += text[index + 1]
			if text[index + 1] == "@" or text[index + 1] == "#" \
					or text[index + 1] == "~":
				escaped_positions.append(output_index)
			index += 2
			continue
		if index < raw_caret:
			normalized_caret += 1
		normalized += text[index]
		index += 1
	return {
		"text": normalized,
		"caret": normalized_caret,
		"escaped_positions": escaped_positions,
	}


func _find_unescaped_trigger(
		text: String,
		changed_start: int,
		changed_end: int,
		escaped_positions: Array[int],
		trigger: String = "@"
) -> int:
	var first: int = maxi(0, changed_start)
	var last: int = mini(text.length(), changed_end)
	for index: int in range(first, last):
		if text[index] != trigger or escaped_positions.has(index):
			continue
		var slash_count: int = 0
		var previous: int = index - 1
		while previous >= 0 and text[previous] == "\\":
			slash_count += 1
			previous -= 1
		if slash_count % 2 == 0:
			return index
	return -1


func _set_document_text_without_history(
		segment: FlowTextSegment,
		text: String,
		input: TextEdit,
		caret_offset: int
) -> void:
	if segment == null:
		return
	segment.text = text
	_notify_document_changed(false)
	_set_text_control_value(input, text, caret_offset)
	_caret_segment_id = segment.get_segment_id()
	_current_position_id = segment.get_segment_id()
	_caret_offset = caret_offset


func _set_text_control_value(input: TextEdit, text: String, offset: int) -> void:
	if input == null:
		return
	_suppress_input = true
	if input.text != text:
		input.text = text
	_set_text_offset(input, offset)
	_suppress_input = false
	input.custom_minimum_size = _text_minimum_size(input, text)
	_surface.queue_sort()


func _begin_variable_trigger(
		segment: FlowTextSegment,
		input: TextEdit,
		text: String,
		trigger_start: int,
		trigger_end: int,
		before_segments: Array[FlowDocumentSegment],
		before_text_states: Array[Dictionary]
) -> void:
	_variable_trigger_active = true
	_variable_trigger_segment_id = segment.get_segment_id()
	_variable_trigger_start = trigger_start
	_variable_trigger_end = maxi(trigger_start + 1, trigger_end)
	_variable_trigger_before_segments = before_segments
	_variable_trigger_before_text_states = before_text_states
	_variable_trigger_anchor = FLOW_SEMANTIC_INSERTION_ANCHOR_SCRIPT.capture(
		_document,
		segment.get_segment_id(),
		trigger_start
	) as FlowChipSemanticInsertionAnchor
	_set_document_text_without_history(segment, text, input, _variable_trigger_end)
	var candidates: Array[FlowVariableDefinition] = get_available_variable_definitions()
	if candidates.is_empty():
		_cancel_variable_trigger(true)
		_reject(get_variable_insertion_feedback())
		return
	_open_variable_selector(input, candidates)


func _pending_variable_trigger_exists(text: String) -> bool:
	return _variable_trigger_start >= 0 \
		and _variable_trigger_start < text.length() \
		and text[_variable_trigger_start] == "@"


func _open_variable_selector(input: TextEdit, candidates: Array[FlowVariableDefinition]) -> void:
	if _variable_selector == null or input == null:
		return
	var caret_local: Vector2 = input.get_caret_draw_pos()
	var caret_global: Vector2 = input.get_global_transform_with_canvas() * caret_local
	var insertion_context: Dictionary = _variable_insertion_context()
	var slot: FlowChipSlotDefinition = insertion_context.get("slot", null) as FlowChipSlotDefinition
	_variable_selector.open_for_variables(
		candidates,
		Rect2(caret_global, Vector2(1.0, maxf(input.get_line_height(), 24.0))),
		"",
		_variable_selector_context_for_insertion(slot)
	)


func _on_variable_selected(variable_id: String) -> void:
	if _variable_trigger_active:
		_complete_variable_trigger(variable_id)
	elif _variable_edit_active:
		_change_variable_reference(_variable_edit_segment_id, variable_id)


func _on_variable_selector_cancelled() -> void:
	if _variable_trigger_active:
		_cancel_variable_trigger(true)
	elif _variable_edit_active:
		var segment_id: String = _variable_edit_segment_id
		_clear_variable_edit_state()
		_focus_chip(segment_id)
		call_deferred(&"_restore_chip_focus_deferred", segment_id)


func _begin_expression_trigger(
		segment: FlowTextSegment,
		input: TextEdit,
		text: String,
		trigger_start: int,
		trigger_end: int,
		before_segments: Array[FlowDocumentSegment],
		before_text_states: Array[Dictionary]
) -> void:
	if not _expression_insertion_allowed():
		_reject(get_expression_insertion_feedback())
		return
	_expression_trigger_active = true
	_expression_trigger_segment_id = segment.get_segment_id()
	_expression_trigger_start = trigger_start
	_expression_trigger_end = maxi(trigger_start + 1, trigger_end)
	_expression_trigger_before_segments = before_segments
	_expression_trigger_before_text_states = before_text_states
	_expression_trigger_anchor = FLOW_SEMANTIC_INSERTION_ANCHOR_SCRIPT.capture(
		_document,
		segment.get_segment_id(),
		trigger_start
	) as FlowChipSemanticInsertionAnchor
	_set_document_text_without_history(segment, text, input, _expression_trigger_end)
	_open_expression_editor(input)


func _open_expression_editor(input: TextEdit) -> void:
	if _expression_editor == null or input == null:
		return
	var caret_local: Vector2 = input.get_caret_draw_pos()
	var caret_global: Vector2 = input.get_global_transform_with_canvas() * caret_local
	var context: Dictionary = _expression_insertion_context()
	_expression_editor.open_for_expression(
		null,
		_variable_graph,
		Rect2(caret_global, Vector2(1.0, maxf(input.get_line_height(), 24.0))),
		context
	)


func _begin_condition_trigger(
		segment: FlowTextSegment,
		input: TextEdit,
		text: String,
		trigger_start: int,
		trigger_end: int,
		before_segments: Array[FlowDocumentSegment],
		before_text_states: Array[Dictionary]
) -> void:
	if not _condition_insertion_allowed():
		_reject(get_condition_insertion_feedback())
		return
	_condition_trigger_active = true
	_condition_trigger_segment_id = segment.get_segment_id()
	_condition_trigger_start = trigger_start
	_condition_trigger_end = maxi(trigger_start + 1, trigger_end)
	_condition_trigger_anchor = FLOW_SEMANTIC_INSERTION_ANCHOR_SCRIPT.capture(
		_document, segment.get_segment_id(), trigger_start
	) as FlowChipSemanticInsertionAnchor
	_condition_trigger_before_segments_storage = before_segments.duplicate()
	_condition_trigger_before_text_states_storage = before_text_states.duplicate()
	# The trigger stays in the detached draft boundary until Confirm or Cancel.
	_set_document_text_without_history(segment, text, input, _condition_trigger_end)
	_open_condition_editor(input)


func _open_condition_editor(input: TextEdit) -> void:
	if _condition_editor == null or input == null:
		return
	var caret_local: Vector2 = input.get_caret_draw_pos()
	var caret_global: Vector2 = input.get_global_transform_with_canvas() * caret_local
	_condition_editor.open_for_condition(
		null,
		_variable_graph,
		Rect2(caret_global, Vector2(1.0, maxf(input.get_line_height(), 24.0))),
		_condition_insertion_context()
	)


func _condition_insertion_context() -> Dictionary:
	var context: Dictionary = _variable_insertion_context()
	context["schema"] = _schema
	var slot: FlowChipSlotDefinition = context.get("slot", null) as FlowChipSlotDefinition
	if slot == null:
		var replacement: FlowChipSegment = _segment_at(
			int(context.get("replacement_index", -1))
		) as FlowChipSegment
		slot = _slot_definition_for(replacement)
	context["slot"] = slot
	return context


func _condition_insertion_allowed() -> bool:
	if _schema == null:
		return true
	if not _schema.accepts_source_kind(FlowValueSource.SOURCE_KIND_CONDITION):
		return false
	var slot: FlowChipSlotDefinition = _insertion_slot_definition()
	if slot == null and _schema.mode == FlowChipFieldSchema.Mode.FIXED:
		slot = _slot_definition_for(_segment_at(_fixed_replacement_index()) as FlowChipSegment)
	if _schema.mode == FlowChipFieldSchema.Mode.HYBRID and slot == null and _fixed_replacement_index() < 0:
		return false
	return slot == null or slot.accepts_source_kind(FlowValueSource.SOURCE_KIND_CONDITION)


func get_condition_insertion_feedback() -> String:
	if _document == null:
		return FEEDBACK_INVALID_CHIP_POSITION
	if not _condition_insertion_allowed():
		return "No compatible Condition source is available here."
	var slot: FlowChipSlotDefinition = _insertion_slot_definition()
	if _fixed_replacement_index() < 0 and _insertion_limit_reached(slot):
		return FEEDBACK_MAX_CHIP_COUNT % _insertion_maximum(slot)
	return ""


func _pending_condition_trigger_exists(text: String) -> bool:
	return _condition_trigger_start >= 0 \
		and _condition_trigger_start < text.length() \
		and text[_condition_trigger_start] == "#"


func _on_condition_confirmed(source: FlowConditionValueSource) -> void:
	if _condition_trigger_active:
		_insert_condition_source_at_caret(source)
	elif _condition_edit_active:
		_replace_condition_segment(_condition_edit_segment_id, source)


func _on_condition_editor_cancelled() -> void:
	if _condition_trigger_active:
		_cancel_condition_trigger(true)
	elif _condition_edit_active:
		var segment_id: String = _condition_edit_segment_id
		_clear_condition_edit_state()
		_focus_chip(segment_id)
		call_deferred(&"_restore_chip_focus_deferred", segment_id)


func _insert_condition_source_at_caret(source: FlowConditionValueSource) -> String:
	if source == null or not source.is_valid(_variable_graph):
		_cancel_condition_trigger(true)
		_reject("Condition is invalid.")
		return ""
	var context: Dictionary = _variable_insertion_context()
	var slot: FlowChipSlotDefinition = context.get("slot", null) as FlowChipSlotDefinition
	var replacement_index: int = int(context.get("replacement_index", -1))
	if _schema != null and (not _schema.accepts_value_type(source.get_value_type()) \
			or not _schema.accepts_source_kind(source.get_source_kind())):
		_cancel_condition_trigger(true)
		_reject("Condition is incompatible with this field.")
		return ""
	if slot != null and (not slot.accepts_value_type(source.get_value_type()) \
			or not slot.accepts_source_kind(source.get_source_kind())):
		_cancel_condition_trigger(true)
		_reject("Condition is incompatible with this slot.")
		return ""
	var before_segments: Array[FlowDocumentSegment] = _copy_segments(_document.segments)
	var before_text_states: Array[Dictionary] = _text_states_for_segments(before_segments)
	if _condition_trigger_active and not _condition_trigger_anchor == null:
		before_segments = _copy_segments(_condition_trigger_before_segments())
		before_text_states = _condition_trigger_before_text_states()
	var after_segments: Array[FlowDocumentSegment] = _copy_segments(_document.segments)
	var after_text_states: Array[Dictionary] = []
	var chip: FlowConditionSegment = FlowConditionSegment.new(source)
	var focus_id: String = ""
	if replacement_index < 0 and slot != null:
		chip.set_slot_id(slot.slot_id)
		chip.set_slot_kind(FlowChipSegment.SLOT_KIND_VARIADIC if _is_variadic_slot_definition(slot) else FlowChipSegment.SLOT_KIND_NAMED)
	if replacement_index >= 0:
		var target: FlowChipSegment = _segment_at(replacement_index) as FlowChipSegment
		if target == null or slot == null:
			_cancel_condition_trigger(true)
			_reject(FEEDBACK_INVALID_CHIP_POSITION)
			return ""
		chip.segment_id = target.get_segment_id()
		chip.set_slot_id(target.get_slot_id())
		chip.set_slot_kind(target.get_slot_kind())
		after_segments[replacement_index] = chip
		focus_id = chip.get_segment_id()
	else:
		var trigger_text: FlowTextSegment = _find_segment(_condition_trigger_segment_id) as FlowTextSegment
		var text_index: int = _find_segment_index(_condition_trigger_segment_id)
		if trigger_text == null or text_index < 0:
			_cancel_condition_trigger(true)
			return ""
		var start: int = clampi(_condition_trigger_start, 0, trigger_text.text.length())
		var end: int = clampi(_condition_trigger_end, start, trigger_text.text.length())
		var prefix: String = trigger_text.text.substr(0, start)
		var suffix: String = trigger_text.text.substr(end)
		var following: FlowTextSegment = FlowTextSegment.new()
		following.text = suffix
		after_segments[text_index] = trigger_text
		after_segments.insert(text_index + 1, chip)
		after_segments.insert(text_index + 2, following)
		after_text_states = [_text_state(trigger_text, prefix), _text_state(following, suffix)]
		focus_id = following.get_segment_id()
	_clear_condition_trigger_state()
	_clear_condition_edit_state()
	if _condition_editor != null and _condition_editor.visible:
		_condition_editor.hide()
	_selected_segment_id = chip.get_segment_id()
	_current_position_id = chip.get_segment_id()
	_caret_segment_id = focus_id
	_caret_offset = 0
	_caret_boundary_index = -1
	_focus_restore_id = focus_id
	_preserve_selection_during_focus_restore = true
	_commit_state_action("Insert Condition", before_segments, before_text_states, after_segments, after_text_states)
	segment_selected.emit(chip.get_segment_id())
	return chip.get_segment_id()


func _condition_trigger_before_segments() -> Array[FlowDocumentSegment]:
	return _condition_trigger_before_segments_storage.duplicate()


var _condition_trigger_before_segments_storage: Array[FlowDocumentSegment] = []
var _condition_trigger_before_text_states_storage: Array[Dictionary] = []


func _condition_trigger_before_text_states() -> Array[Dictionary]:
	return _condition_trigger_before_text_states_storage.duplicate()


func _replace_condition_segment(segment_id: String, source: FlowConditionValueSource) -> bool:
	var existing: FlowConditionSegment = _find_segment(segment_id) as FlowConditionSegment
	if existing == null or source == null or not source.is_valid(_variable_graph):
		return false
	var index: int = _find_segment_index(segment_id)
	if index < 0:
		return false
	var before_segments: Array[FlowDocumentSegment] = _copy_segments(_document.segments)
	var after_segments: Array[FlowDocumentSegment] = _copy_segments(before_segments)
	var replacement: FlowConditionSegment = FlowConditionSegment.new(source)
	replacement.segment_id = existing.segment_id
	replacement.set_slot_id(existing.get_slot_id())
	replacement.set_slot_kind(existing.get_slot_kind())
	after_segments[index] = replacement
	_clear_condition_edit_state()
	if _condition_editor != null and _condition_editor.visible:
		_condition_editor.hide()
	_selected_segment_id = segment_id
	_current_position_id = segment_id
	_focus_restore_id = segment_id
	_preserve_selection_during_focus_restore = true
	_commit_state_action("Edit Condition", before_segments, _text_states_for_segments(before_segments), after_segments, _text_states_for_segments(after_segments))
	segment_selected.emit(segment_id)
	return true


func _cancel_condition_trigger(remove_trigger: bool) -> void:
	if not _condition_trigger_active:
		return
	var segment: FlowTextSegment = _find_segment(_condition_trigger_segment_id) as FlowTextSegment
	var input: TextEdit = get_text_control(_condition_trigger_segment_id)
	var restore_offset: int = _condition_trigger_start
	if segment != null and remove_trigger:
		var start: int = clampi(_condition_trigger_start, 0, segment.text.length())
		var end: int = clampi(_condition_trigger_end, start, segment.text.length())
		var text: String = segment.text.substr(0, start) + segment.text.substr(end)
		restore_offset = clampi(start, 0, text.length())
		_set_document_text_without_history(segment, text, input, restore_offset)
	_clear_condition_trigger_state()
	if _condition_editor != null and _condition_editor.visible:
		_condition_editor.hide()
	if segment != null:
		_focus_text_control(segment.get_segment_id(), restore_offset)
		call_deferred(&"_restore_text_focus_deferred", segment.get_segment_id(), restore_offset)
	_clear_feedback()


func _on_condition_edit_requested(segment_id: String) -> bool:
	var condition: FlowConditionSegment = _find_segment(segment_id) as FlowConditionSegment
	if condition == null:
		return false
	if not _can_edit_chip(condition):
		_on_chip_selected(segment_id)
		_reject(FEEDBACK_TOK_IMMUTABLE)
		return false
	var source: FlowConditionValueSource = condition.get_value_source() as FlowConditionValueSource
	if source == null:
		return false
	_condition_edit_active = true
	_condition_edit_segment_id = segment_id
	_on_chip_selected(segment_id)
	_condition_editor.open_for_condition(
		source, _variable_graph,
		(get_chip_control(segment_id).get_global_rect() if get_chip_control(segment_id) != null else Rect2()),
		{"schema": _schema, "slot": _slot_definition_for(condition)}
	)
	return true


func _clear_condition_trigger_state() -> void:
	_condition_trigger_active = false
	_condition_trigger_segment_id = ""
	_condition_trigger_start = -1
	_condition_trigger_end = -1
	_condition_trigger_anchor = null
	_condition_trigger_before_segments_storage.clear()
	_condition_trigger_before_text_states_storage.clear()


func _clear_condition_edit_state() -> void:
	_condition_edit_active = false
	_condition_edit_segment_id = ""




func _begin_operation_trigger(
		segment: FlowTextSegment,
		input: TextEdit,
		text: String,
		trigger_start: int,
		trigger_end: int,
		before_segments: Array[FlowDocumentSegment],
		before_text_states: Array[Dictionary]
) -> void:
	if not _operation_insertion_allowed():
		_reject(get_operation_insertion_feedback())
		return
	_operation_trigger_active = true
	_operation_trigger_segment_id = segment.get_segment_id()
	_operation_trigger_start = trigger_start
	_operation_trigger_end = maxi(trigger_start + 1, trigger_end)
	_operation_trigger_before_segments = before_segments
	_operation_trigger_before_text_states = before_text_states
	_operation_trigger_anchor = FLOW_SEMANTIC_INSERTION_ANCHOR_SCRIPT.capture(
		_document, segment.get_segment_id(), trigger_start
	) as FlowChipSemanticInsertionAnchor
	_set_document_text_without_history(segment, text, input, _operation_trigger_end)
	_open_operation_editor(input)


func _open_operation_editor(input: TextEdit) -> void:
	if _operation_editor == null or input == null:
		return
	var caret_local: Vector2 = input.get_caret_draw_pos()
	var caret_global: Vector2 = input.get_global_transform_with_canvas() * caret_local
	_operation_editor.open_for_operation(
		null,
		_variable_graph,
		Rect2(caret_global, Vector2(1.0, maxf(input.get_line_height(), 24.0))),
		_operation_insertion_context()
	)


func _operation_insertion_context() -> Dictionary:
	var context: Dictionary = _variable_insertion_context()
	context["schema"] = _schema
	var slot: FlowChipSlotDefinition = context.get("slot", null) as FlowChipSlotDefinition
	if slot == null:
		var replacement: FlowChipSegment = _segment_at(
			int(context.get("replacement_index", -1))
		) as FlowChipSegment
		slot = _slot_definition_for(replacement)
	context["slot"] = slot
	return context


func _operation_insertion_allowed() -> bool:
	if _schema == null:
		return true
	if not _schema.accepts_source_kind(FlowValueSource.SOURCE_KIND_OPERATION):
		return false
	var slot: FlowChipSlotDefinition = _insertion_slot_definition()
	if slot == null and _schema.mode == FlowChipFieldSchema.Mode.FIXED:
		slot = _slot_definition_for(_segment_at(_fixed_replacement_index()) as FlowChipSegment)
	if _schema.mode == FlowChipFieldSchema.Mode.HYBRID 			and slot == null and _fixed_replacement_index() < 0:
		return false
	return slot == null or slot.accepts_source_kind(FlowValueSource.SOURCE_KIND_OPERATION)


func get_operation_insertion_feedback() -> String:
	if _document == null:
		return FEEDBACK_INVALID_CHIP_POSITION
	if not _operation_insertion_allowed():
		return FEEDBACK_NO_COMPATIBLE_OPERATION
	var slot: FlowChipSlotDefinition = _insertion_slot_definition()
	if _fixed_replacement_index() < 0 and _insertion_limit_reached(slot):
		return FEEDBACK_MAX_CHIP_COUNT % _insertion_maximum(slot)
	return ""


func _on_operation_confirmed(source: FlowOperationValueSource) -> void:
	if _operation_trigger_active:
		_insert_operation_source_at_caret(source)
	elif _operation_edit_active:
		_replace_operation_segment(_operation_edit_segment_id, source)


func _on_operation_editor_cancelled() -> void:
	if _operation_trigger_active:
		_cancel_operation_trigger(true)
	elif _operation_edit_active:
		var segment_id: String = _operation_edit_segment_id
		_clear_operation_edit_state()
		_focus_chip(segment_id)
		call_deferred(&"_restore_chip_focus_deferred", segment_id)


func _insert_operation_source_at_caret(source: FlowOperationValueSource) -> String:
	if source == null or not source.is_valid():
		_cancel_operation_trigger(true)
		_reject("Operation is invalid.")
		return ""
	var graph_validation: FlowValidationResult = FlowValidationResult.new()
	source.validate_against_graph(graph_validation, "operation", _variable_graph)
	if graph_validation.has_errors():
		_cancel_operation_trigger(true)
		_reject((graph_validation.diagnostics[0] as FlowDiagnostic).message)
		return ""
	var context: Dictionary = _variable_insertion_context()
	var slot: FlowChipSlotDefinition = context.get("slot", null) as FlowChipSlotDefinition
	var replacement_index: int = int(context.get("replacement_index", -1))
	if _schema != null and (not _schema.accepts_value_type(source.get_value_type()) 			or not _schema.accepts_source_kind(source.get_source_kind())):
		_cancel_operation_trigger(true)
		_reject("Operation is incompatible with this field.")
		return ""
	if slot != null and (not slot.accepts_value_type(source.get_value_type()) 			or not slot.accepts_source_kind(source.get_source_kind())):
		_cancel_operation_trigger(true)
		_reject("Operation is incompatible with this slot.")
		return ""
	var before_segments: Array[FlowDocumentSegment] = _copy_segments(
		_operation_trigger_before_segments if _operation_trigger_active else _document.segments
	)
	var before_text_states: Array[Dictionary] = 		_operation_trigger_before_text_states.duplicate() 		if _operation_trigger_active else _text_states_for_segments(before_segments)
	var after_segments: Array[FlowDocumentSegment] = _copy_segments(_document.segments)
	var after_text_states: Array[Dictionary] = []
	var chip: FlowOperationSegment = FlowOperationSegment.new(source)
	var focus_id: String = ""
	if replacement_index < 0 and slot != null:
		chip.set_slot_id(slot.slot_id)
		chip.set_slot_kind(
			FlowChipSegment.SLOT_KIND_VARIADIC 			if _is_variadic_slot_definition(slot) else FlowChipSegment.SLOT_KIND_NAMED
		)
	if replacement_index >= 0:
		var target: FlowChipSegment = _segment_at(replacement_index) as FlowChipSegment
		if target == null or slot == null:
			_cancel_operation_trigger(true)
			_reject(FEEDBACK_INVALID_CHIP_POSITION)
			return ""
		chip.segment_id = target.get_segment_id()
		chip.set_slot_id(target.get_slot_id())
		chip.set_slot_kind(target.get_slot_kind())
		after_segments[replacement_index] = chip
		focus_id = chip.get_segment_id()
	else:
		var trigger_text: FlowTextSegment = _find_segment(
			_operation_trigger_segment_id
		) as FlowTextSegment
		var text_index: int = _find_segment_index(_operation_trigger_segment_id)
		if trigger_text == null or text_index < 0:
			_cancel_operation_trigger(true)
			return ""
		var start: int = clampi(_operation_trigger_start, 0, trigger_text.text.length())
		var end: int = clampi(_operation_trigger_end, start, trigger_text.text.length())
		var prefix: String = trigger_text.text.substr(0, start)
		var suffix: String = trigger_text.text.substr(end)
		var following: FlowTextSegment = FlowTextSegment.new()
		following.text = suffix
		after_segments[text_index] = trigger_text
		after_segments.insert(text_index + 1, chip)
		after_segments.insert(text_index + 2, following)
		after_text_states = [
			_text_state(trigger_text, prefix),
			_text_state(following, suffix),
		]
		focus_id = following.get_segment_id()
	_clear_operation_trigger_state()
	_clear_operation_edit_state()
	if _operation_editor != null and _operation_editor.visible:
		_operation_editor.hide()
	_selected_segment_id = chip.get_segment_id()
	_current_position_id = chip.get_segment_id()
	_caret_segment_id = focus_id
	_caret_offset = 0
	_caret_boundary_index = -1
	_focus_restore_id = focus_id
	_preserve_selection_during_focus_restore = true
	_commit_state_action(
		"Insert Operation",
		before_segments,
		before_text_states,
		after_segments,
		after_text_states
	)
	segment_selected.emit(chip.get_segment_id())
	return chip.get_segment_id()


func _replace_operation_segment(
		segment_id: String,
		source: FlowOperationValueSource
) -> bool:
	var existing: FlowOperationSegment = _find_segment(segment_id) as FlowOperationSegment
	if existing == null or source == null or not source.is_valid():
		return false
	var index: int = _find_segment_index(segment_id)
	if index < 0:
		return false
	var before_segments: Array[FlowDocumentSegment] = _copy_segments(_document.segments)
	var after_segments: Array[FlowDocumentSegment] = _copy_segments(before_segments)
	var replacement: FlowOperationSegment = FlowOperationSegment.new(source)
	replacement.segment_id = existing.segment_id
	replacement.set_slot_id(existing.get_slot_id())
	replacement.set_slot_kind(existing.get_slot_kind())
	after_segments[index] = replacement
	_clear_operation_edit_state()
	_commit_state_action(
		"Edit Operation",
		before_segments,
		_text_states_for_segments(before_segments),
		after_segments,
		[]
	)
	_on_chip_selected(segment_id)
	_focus_chip(segment_id)
	segment_selected.emit(segment_id)
	return true


func _cancel_operation_trigger(remove_trigger: bool) -> void:
	if not _operation_trigger_active:
		return
	var segment: FlowTextSegment = _find_segment(
		_operation_trigger_segment_id
	) as FlowTextSegment
	var input: TextEdit = get_text_control(_operation_trigger_segment_id)
	var restore_offset: int = _operation_trigger_start
	if segment != null and remove_trigger:
		var start: int = clampi(_operation_trigger_start, 0, segment.text.length())
		var end: int = clampi(_operation_trigger_end, start, segment.text.length())
		var text: String = segment.text.substr(0, start) + segment.text.substr(end)
		restore_offset = clampi(start, 0, text.length())
		_set_document_text_without_history(segment, text, input, restore_offset)
	_clear_operation_trigger_state()
	if _operation_editor != null and _operation_editor.visible:
		_operation_editor.hide()
	if segment != null:
		_focus_text_control(segment.get_segment_id(), restore_offset)
		call_deferred(
			&"_restore_text_focus_deferred",
			segment.get_segment_id(),
			restore_offset
		)
	_clear_feedback()


func _on_operation_edit_requested(segment_id: String) -> bool:
	var operation: FlowOperationSegment = _find_segment(segment_id) as FlowOperationSegment
	if operation == null:
		return false
	if not _can_edit_chip(operation):
		_on_chip_selected(segment_id)
		_reject(FEEDBACK_TOK_IMMUTABLE)
		return false
	var source: FlowOperationValueSource = 		operation.get_value_source() as FlowOperationValueSource
	if source == null:
		return false
	_operation_edit_active = true
	_operation_edit_segment_id = segment_id
	_on_chip_selected(segment_id)
	_operation_editor.open_for_operation(
		source,
		_variable_graph,
		get_chip_control(segment_id).get_global_rect() 			if get_chip_control(segment_id) != null else Rect2(),
		{"schema": _schema, "slot": _slot_definition_for(operation)}
	)
	return true


func _clear_operation_trigger_state() -> void:
	_operation_trigger_active = false
	_operation_trigger_segment_id = ""
	_operation_trigger_start = -1
	_operation_trigger_end = -1
	_operation_trigger_before_segments.clear()
	_operation_trigger_before_text_states.clear()
	_operation_trigger_anchor = null


func _clear_operation_edit_state() -> void:
	_operation_edit_active = false
	_operation_edit_segment_id = ""


func _expression_insertion_context() -> Dictionary:
	var context: Dictionary = _variable_insertion_context()
	context["schema"] = _schema
	var slot: FlowChipSlotDefinition = context.get("slot", null) as FlowChipSlotDefinition
	if slot == null:
		var replacement: FlowChipSegment = _segment_at(
			int(context.get("replacement_index", -1))
		) as FlowChipSegment
		slot = _slot_definition_for(replacement)
	context["slot"] = slot
	return context


func _expression_insertion_allowed() -> bool:
	if _schema == null:
		return true
	if not _schema.accepts_source_kind(FlowValueSource.SOURCE_KIND_EXPRESSION):
		return false
	var slot: FlowChipSlotDefinition = _insertion_slot_definition()
	if slot == null and _schema.mode == FlowChipFieldSchema.Mode.FIXED:
		slot = _slot_definition_for(_segment_at(_fixed_replacement_index()) as FlowChipSegment)
	if _schema.mode == FlowChipFieldSchema.Mode.HYBRID and slot == null and _fixed_replacement_index() < 0:
		return false
	return slot == null or slot.accepts_source_kind(FlowValueSource.SOURCE_KIND_EXPRESSION)


func get_expression_insertion_feedback() -> String:
	if _document == null:
		return FEEDBACK_INVALID_CHIP_POSITION
	if not _expression_insertion_allowed():
		return FEEDBACK_NO_COMPATIBLE_EXPRESSION
	var slot: FlowChipSlotDefinition = _insertion_slot_definition()
	if _fixed_replacement_index() < 0 and _insertion_limit_reached(slot):
		return FEEDBACK_MAX_CHIP_COUNT % _insertion_maximum(slot)
	return ""


func _pending_expression_trigger_exists(text: String) -> bool:
	return _expression_trigger_start >= 0 \
		and _expression_trigger_start < text.length() \
		and text[_expression_trigger_start] == "#"


func _on_expression_confirmed(source: FlowExpressionValueSource) -> void:
	if _expression_trigger_active:
		_insert_expression_source_at_caret(source)
	elif _expression_edit_active:
		_replace_expression_segment(_expression_edit_segment_id, source)


func _on_expression_editor_cancelled() -> void:
	if _expression_trigger_active:
		_cancel_expression_trigger(true)
	elif _expression_edit_active:
		var segment_id: String = _expression_edit_segment_id
		_clear_expression_edit_state()
		_focus_chip(segment_id)
		call_deferred(&"_restore_chip_focus_deferred", segment_id)


func _insert_expression_source_at_caret(source: FlowExpressionValueSource) -> String:
	if source == null or not source.is_valid():
		_cancel_expression_trigger(true)
		_reject(FEEDBACK_NO_COMPATIBLE_EXPRESSION)
		return ""
	var context: Dictionary = _variable_insertion_context()
	var slot: FlowChipSlotDefinition = context.get("slot", null) as FlowChipSlotDefinition
	var replacement_index: int = int(context.get("replacement_index", -1))
	if _schema != null and (not _schema.accepts_value_type(source.get_value_type()) \
			or not _schema.accepts_source_kind(source.get_source_kind())):
		_cancel_expression_trigger(true)
		_reject(FEEDBACK_NO_COMPATIBLE_EXPRESSION)
		return ""
	if slot != null and (not slot.accepts_value_type(source.get_value_type()) \
			or not slot.accepts_source_kind(source.get_source_kind())):
		_cancel_expression_trigger(true)
		_reject(FEEDBACK_NO_COMPATIBLE_EXPRESSION)
		return ""
	var before_segments: Array[FlowDocumentSegment] = _copy_segments(_document.segments)
	var before_text_states: Array[Dictionary] = _text_states_for_segments(before_segments)
	if _expression_trigger_active and not _expression_trigger_before_segments.is_empty():
		before_segments = _copy_segments(_expression_trigger_before_segments)
		before_text_states = _expression_trigger_before_text_states.duplicate()
	var after_segments: Array[FlowDocumentSegment] = _copy_segments(_document.segments)
	var after_text_states: Array[Dictionary] = []
	var chip: FlowExpressionSegment = FlowExpressionSegment.new(source)
	var focus_id: String = ""
	var focus_offset: int = 0
	if replacement_index < 0 and slot != null:
		chip.set_slot_id(slot.slot_id)
		chip.set_slot_kind(
			FlowChipSegment.SLOT_KIND_VARIADIC
			if _is_variadic_slot_definition(slot)
			else FlowChipSegment.SLOT_KIND_NAMED
		)
	if replacement_index >= 0:
		var target: FlowChipSegment = _segment_at(replacement_index) as FlowChipSegment
		if target == null or slot == null:
			_cancel_expression_trigger(true)
			_reject(FEEDBACK_INVALID_CHIP_POSITION)
			return ""
		chip.segment_id = target.get_segment_id()
		chip.set_slot_id(target.get_slot_id())
		chip.set_slot_kind(target.get_slot_kind())
		after_segments[replacement_index] = chip
		focus_id = target.get_segment_id()
	else:
		if _expression_trigger_active:
			var trigger_text: FlowTextSegment = _find_segment(_expression_trigger_segment_id) as FlowTextSegment
			var text_index: int = _find_segment_index(_expression_trigger_segment_id)
			if trigger_text == null or text_index < 0:
				_cancel_expression_trigger(true)
				return ""
			var start: int = clampi(_expression_trigger_start, 0, trigger_text.text.length())
			var end: int = clampi(_expression_trigger_end, start, trigger_text.text.length())
			var prefix: String = trigger_text.text.substr(0, start)
			var suffix: String = trigger_text.text.substr(end)
			var following: FlowTextSegment = FlowTextSegment.new()
			following.text = suffix
			after_segments[text_index] = trigger_text
			after_segments.insert(text_index + 1, chip)
			after_segments.insert(text_index + 2, following)
			after_text_states = [_text_state(trigger_text, prefix), _text_state(following, suffix)]
			focus_id = following.get_segment_id()
		else:
			var insert_index: int = _insertion_index()
			after_segments.insert(insert_index, chip)
			var following_text: FlowTextSegment = FlowTextSegment.new()
			after_segments.insert(insert_index + 1, following_text)
			focus_id = following_text.get_segment_id()
	if after_text_states.is_empty():
		after_text_states = _text_states_for_segments(after_segments)
	_clear_expression_trigger_state()
	_clear_expression_edit_state()
	if _expression_editor != null and _expression_editor.visible:
		_expression_editor.hide()
	_selected_segment_id = chip.get_segment_id()
	_current_position_id = chip.get_segment_id()
	_caret_segment_id = focus_id
	_caret_offset = focus_offset
	_caret_boundary_index = -1
	_focus_restore_id = focus_id
	_focus_restore_offset = focus_offset
	_preserve_selection_during_focus_restore = true
	_commit_state_action("Insert Expression", before_segments, before_text_states, after_segments, after_text_states)
	segment_selected.emit(chip.get_segment_id())
	return chip.get_segment_id()


func _replace_expression_segment(segment_id: String, source: FlowExpressionValueSource) -> bool:
	var existing: FlowExpressionSegment = _find_segment(segment_id) as FlowExpressionSegment
	if existing == null or source == null or not source.is_valid():
		return false
	var index: int = _find_segment_index(segment_id)
	if index < 0:
		return false
	var before_segments: Array[FlowDocumentSegment] = _copy_segments(_document.segments)
	var after_segments: Array[FlowDocumentSegment] = _copy_segments(before_segments)
	var replacement: FlowExpressionSegment = FlowExpressionSegment.new(source)
	replacement.segment_id = existing.segment_id
	replacement.set_slot_id(existing.get_slot_id())
	replacement.set_slot_kind(existing.get_slot_kind())
	after_segments[index] = replacement
	_clear_expression_edit_state()
	if _expression_editor != null and _expression_editor.visible:
		_expression_editor.hide()
	_selected_segment_id = segment_id
	_current_position_id = segment_id
	_focus_restore_id = segment_id
	_preserve_selection_during_focus_restore = true
	_commit_state_action("Edit Expression", before_segments, _text_states_for_segments(before_segments), after_segments, _text_states_for_segments(after_segments))
	segment_selected.emit(segment_id)
	return true


func _is_variadic_slot_definition(slot: FlowChipSlotDefinition) -> bool:
	if slot == null or _schema == null:
		return false
	return _schema.variadic_slot_definition == slot \
		or (_schema.mode == FlowChipFieldSchema.Mode.FLEXIBLE \
		and _schema.variadic_slot_definition != null \
		and slot.slot_id == _schema.variadic_slot_definition.slot_id)


func _cancel_expression_trigger(remove_trigger: bool) -> void:
	if not _expression_trigger_active:
		return
	var anchor: FlowChipSemanticInsertionAnchor = _expression_trigger_anchor
	var segment_id: String = _expression_trigger_segment_id
	var segment: FlowTextSegment = _find_segment(segment_id) as FlowTextSegment
	var input: TextEdit = get_text_control(segment_id)
	var restore_offset: int = _expression_trigger_start
	if anchor != null:
		var resolved: Dictionary = anchor.resolve(_document)
		var resolved_segment: FlowTextSegment = resolved.get("segment", null) as FlowTextSegment
		if resolved_segment != null:
			segment = resolved_segment
			segment_id = resolved_segment.get_segment_id()
			input = get_text_control(segment_id)
			restore_offset = int(resolved.get("offset", restore_offset))
	if segment != null and remove_trigger:
		var start: int = clampi(_expression_trigger_start, 0, segment.text.length())
		var end: int = clampi(_expression_trigger_end, start, segment.text.length())
		var text: String = segment.text.substr(0, start) + segment.text.substr(end)
		restore_offset = clampi(start, 0, text.length())
		_set_document_text_without_history(segment, text, input, restore_offset)
	_clear_expression_trigger_state()
	if _expression_editor != null and _expression_editor.visible:
		_expression_editor.hide()
	if segment != null:
		_focus_text_control(segment.get_segment_id(), restore_offset)
		call_deferred(&"_restore_text_focus_deferred", segment.get_segment_id(), restore_offset)
	_clear_feedback()


func _on_expression_edit_requested(segment_id: String) -> bool:
	var expression: FlowExpressionSegment = _find_segment(segment_id) as FlowExpressionSegment
	if expression == null:
		return false
	if not _can_edit_chip(expression):
		_on_chip_selected(segment_id)
		_reject(FEEDBACK_TOK_IMMUTABLE)
		return false
	var source: FlowExpressionValueSource = expression.get_value_source() as FlowExpressionValueSource
	if source == null:
		return false
	_expression_edit_active = true
	_expression_edit_segment_id = segment_id
	_on_chip_selected(segment_id)
	var chip: FlowChipControl = get_chip_control(segment_id)
	_expression_editor.open_for_expression(
		source,
		_variable_graph,
		chip.get_global_rect() if chip != null else Rect2(),
		{"schema": _schema, "slot": _slot_definition_for(expression)}
	)
	return true


func _clear_expression_trigger_state() -> void:
	_expression_trigger_active = false
	_expression_trigger_segment_id = ""
	_expression_trigger_start = -1
	_expression_trigger_end = -1
	_expression_trigger_before_segments.clear()
	_expression_trigger_before_text_states.clear()
	_expression_trigger_anchor = null


func _clear_expression_edit_state() -> void:
	_expression_edit_active = false
	_expression_edit_segment_id = ""


func _on_chip_edit_requested(segment_id: String) -> void:
	var variable_segment: FlowVariableRefSegment = _find_segment(segment_id) as FlowVariableRefSegment
	if variable_segment != null:
		open_variable_selector_for_segment(segment_id)
		return
	if _find_segment(segment_id) is FlowExpressionSegment:
		_on_expression_edit_requested(segment_id)
		return
	if _find_segment(segment_id) is FlowConditionSegment:
		_on_condition_edit_requested(segment_id)
		return
	if _find_segment(segment_id) is FlowOperationSegment:
		_on_operation_edit_requested(segment_id)
		return
	var chip: FlowChipSegment = _find_segment(segment_id) as FlowChipSegment
	if chip != null and not _can_edit_chip(chip):
		_on_chip_selected(segment_id)
		_reject(FEEDBACK_TOK_IMMUTABLE)


func _cancel_variable_trigger(remove_trigger: bool) -> void:
	if not _variable_trigger_active:
		return
	var anchor: FlowChipSemanticInsertionAnchor = _variable_trigger_anchor
	var trigger_segment_id: String = _variable_trigger_segment_id
	var segment: FlowTextSegment = _find_segment(trigger_segment_id) as FlowTextSegment
	var input: TextEdit = get_text_control(trigger_segment_id)
	var restore_offset: int = _variable_trigger_start
	var remove_from_current_segment: bool = remove_trigger
	if anchor != null:
		var resolved: Dictionary = anchor.resolve(_document)
		var resolved_segment: FlowTextSegment = resolved.get("segment", null) as FlowTextSegment
		if resolved_segment != null:
			segment = resolved_segment
			trigger_segment_id = segment.get_segment_id()
			input = get_text_control(trigger_segment_id)
			restore_offset = int(resolved.get("offset", restore_offset))
			# A neighbour fallback identifies where focus should return after a
			# rebuild, but it does not carry the pending trigger. Never remove
			# characters from that neighbour as if it were the original segment.
			remove_from_current_segment = remove_trigger \
				and trigger_segment_id == _variable_trigger_segment_id
	var next_text: String = segment.text if segment != null else ""
	if remove_from_current_segment and segment != null:
		var start: int = clampi(_variable_trigger_start, 0, segment.text.length())
		var end: int = clampi(_variable_trigger_end, start, segment.text.length())
		next_text = segment.text.substr(0, start) + segment.text.substr(end)
	restore_offset = clampi(restore_offset, 0, next_text.length())
	_clear_variable_trigger_state()
	if _variable_selector != null and _variable_selector.visible:
		_variable_selector.hide()
	if segment != null:
		_set_document_text_without_history(segment, next_text, input, restore_offset)
		if input == null:
			_queue_refresh()
		_focus_text_control(segment.get_segment_id(), restore_offset)
		call_deferred(&"_restore_text_focus_deferred", segment.get_segment_id(), restore_offset)
	_clear_feedback()


func _clear_variable_edit_state() -> void:
	_variable_edit_active = false
	_variable_edit_segment_id = ""


func _on_change_variable_pressed(segment_id: String) -> void:
	open_variable_selector_for_segment(segment_id)


func _change_variable_reference(segment_id: String, variable_id: String) -> bool:
	var segment: FlowVariableRefSegment = _find_segment(segment_id) as FlowVariableRefSegment
	var variable: FlowVariableDefinition = _find_variable(variable_id)
	if segment == null or not _is_selectable_variable(variable):
		_clear_variable_edit_state()
		_reject(FEEDBACK_NO_COMPATIBLE_VARIABLE)
		return false
	if not _can_change_variable_reference(segment):
		_clear_variable_edit_state()
		_reject(FEEDBACK_TOK_IMMUTABLE)
		_focus_chip(segment_id)
		return false
	var candidates: Array[FlowVariableDefinition] = \
		get_available_variable_definitions_for_segment(segment_id)
	if not candidates.has(variable):
		_clear_variable_edit_state()
		_reject(FEEDBACK_NO_COMPATIBLE_VARIABLE)
		return false
	var previous_source: FlowVariableRefValueSource = \
		segment.get_value_source() as FlowVariableRefValueSource
	if previous_source == null:
		_clear_variable_edit_state()
		_reject(FEEDBACK_NO_COMPATIBLE_VARIABLE)
		return false
	if _is_value_type_locked_for_segment(segment) \
			and variable.get_declared_variant_type() != previous_source.get_value_type():
		_clear_variable_edit_state()
		_reject(FEEDBACK_TOK_TYPE_LOCKED)
		_focus_chip(segment_id)
		return false
	if previous_source.variable_id == variable.get_internal_id():
		_clear_variable_edit_state()
		if _variable_selector != null and _variable_selector.visible:
			_variable_selector.hide()
		_focus_chip(segment_id)
		return true

	var segment_index: int = _find_segment_index(segment_id)
	if segment_index < 0:
		_clear_variable_edit_state()
		return false
	var before_segments: Array[FlowDocumentSegment] = _copy_segments(_document.segments)
	var after_segments: Array[FlowDocumentSegment] = _copy_segments(before_segments)
	var next_source: FlowVariableRefValueSource = FlowVariableRefValueSource.new(
		variable.get_internal_id(),
		variable.value_type
	)
	# The source remains the same semantic VariableRef while its graph binding
	# changes. Its source_id is therefore stable just like segment_id and slot_id.
	next_source.source_id = previous_source.get_source_id()
	var replacement: FlowVariableRefSegment = FlowVariableRefSegment.new(next_source)
	replacement.segment_id = segment.get_segment_id()
	replacement.set_slot_id(segment.get_slot_id())
	replacement.set_slot_kind(segment.get_slot_kind())
	after_segments[segment_index] = replacement
	_clear_variable_edit_state()
	if _variable_selector != null and _variable_selector.visible:
		_variable_selector.hide()
	_selected_segment_id = replacement.get_segment_id()
	_current_position_id = replacement.get_segment_id()
	_caret_segment_id = ""
	_caret_boundary_index = segment_index + 1
	_focus_restore_id = replacement.get_segment_id()
	_focus_restore_offset = 0
	_preserve_selection_during_focus_restore = true
	_clear_feedback()
	_commit_state_action(
		"Change Variable Reference",
		before_segments,
		_text_states_for_segments(before_segments),
		after_segments,
		_text_states_for_segments(after_segments)
	)
	segment_selected.emit(replacement.get_segment_id())
	return true


func _clear_variable_trigger_state() -> void:
	_variable_trigger_active = false
	_variable_trigger_segment_id = ""
	_variable_trigger_start = -1
	_variable_trigger_end = -1
	_variable_trigger_before_segments.clear()
	_variable_trigger_before_text_states.clear()
	_variable_trigger_anchor = null


func _on_text_gui_input(event: InputEvent, segment_id: String, input: TextEdit) -> void:
	if not event is InputEventKey or not (event as InputEventKey).pressed:
		return
	var key: InputEventKey = event as InputEventKey
	var offset: int = _text_offset(input)
	var segment_index: int = _find_segment_index(segment_id)
	if segment_index < 0:
		return
	var previous: FlowDocumentSegment = _neighbor_non_null(segment_index, -1)
	var next: FlowDocumentSegment = _neighbor_non_null(segment_index, 1)
	if key.keycode == KEY_BACKSPACE and offset == 0 and previous is FlowChipSegment:
		input.accept_event()
		_focus_chip((previous as FlowChipSegment).get_segment_id())
		return
	if key.keycode == KEY_DELETE and offset == input.text.length() and next is FlowChipSegment:
		input.accept_event()
		_focus_chip((next as FlowChipSegment).get_segment_id())
		return
	if key.keycode == KEY_LEFT and offset == 0 and previous is FlowChipSegment:
		input.accept_event()
		_focus_chip((previous as FlowChipSegment).get_segment_id())
		return
	if key.keycode == KEY_RIGHT and offset == input.text.length() and next is FlowChipSegment:
		input.accept_event()
		_focus_chip((next as FlowChipSegment).get_segment_id())


func _on_chip_selected(segment_id: String) -> void:
	if _find_segment(segment_id) == null:
		return
	_selected_segment_id = segment_id
	_current_position_id = segment_id
	_caret_segment_id = ""
	_caret_boundary_index = _find_segment_index(segment_id) + 1
	_update_chip_selection()
	_render_details()
	segment_selected.emit(segment_id)


func _on_chip_focus_entered(segment_id: String) -> void:
	_on_chip_selected(segment_id)


func _on_chip_delete_requested(segment_id: String) -> void:
	delete_chip(segment_id)


func _on_chip_focus_previous(segment_id: String) -> void:
	var index: int = _find_segment_index(segment_id)
	var previous: FlowDocumentSegment = _neighbor_non_null(index, -1)
	if previous is FlowTextSegment:
		_focus_text_control(previous.get_segment_id(), (previous as FlowTextSegment).text.length())
	elif previous is FlowChipSegment:
		_focus_chip(previous.get_segment_id())


func _on_chip_focus_next(segment_id: String) -> void:
	var index: int = _find_segment_index(segment_id)
	var next: FlowDocumentSegment = _neighbor_non_null(index, 1)
	if next is FlowTextSegment:
		_focus_text_control(next.get_segment_id(), 0)
	elif next is FlowChipSegment:
		_focus_chip(next.get_segment_id())


func _selected_chip() -> FlowChipSegment:
	var segment: FlowDocumentSegment = _find_segment(_selected_segment_id)
	return segment as FlowChipSegment if segment is FlowChipSegment else null


func _update_chip_selection() -> void:
	for control: Control in _visual_elements:
		var chip: FlowChipControl = control as FlowChipControl
		if chip != null:
			chip.set_selected(chip.get_segment_id() == _selected_segment_id)


func _render_details() -> void:
	if _details == null or _details_panel == null:
		return
	for child: Node in _details.get_children():
		_details.remove_child(child)
		child.free()
	var segment: FlowChipSegment = _selected_chip()
	_details_panel.visible = segment != null
	if segment == null:
		return

	var descriptor: FlowChipTypeDescriptor = segment.get_chip_type_descriptor()
	if descriptor == null:
		var unsupported: Label = Label.new()
		unsupported.text = "Selected chip has no editable descriptor."
		_details.add_child(unsupported)
		return
	var heading: Label = Label.new()
	heading.text = descriptor.display_name if not descriptor.display_name.is_empty() else "Chip"
	_details.add_child(heading)
	var role: Label = Label.new()
	role.name = &"ChipSemanticRole"
	role.text = "Semantic role: " + String(descriptor.semantic_style_role)
	_details.add_child(role)
	var slot: FlowChipSlotDefinition = _slot_definition_for(segment)
	if slot != null:
		var slot_label: Label = Label.new()
		slot_label.name = &"ChipSlotID"
		slot_label.text = "Slot: " + slot.slot_id
		_details.add_child(slot_label)
	var chip_editable: bool = _can_edit_chip(segment)
	var type_locked: bool = _is_value_type_locked_for_segment(segment)
	var source_kind_locked: bool = _is_source_kind_locked_for_segment(segment)
	var variable_segment: FlowVariableRefSegment = segment as FlowVariableRefSegment
	var variable_source: FlowVariableRefValueSource = \
		segment.get_value_source() as FlowVariableRefValueSource
	if variable_source != null:
		var source_label: Label = Label.new()
		source_label.name = &"VariableSourceKind"
		source_label.text = "Source: Variable"
		_details.add_child(source_label)
		var definition: FlowVariableDefinition = _find_variable(variable_source.variable_id)
		var name_label: Label = Label.new()
		name_label.name = &"VariableName"
		name_label.text = "Name: " + (definition.display_name if definition != null else "Unresolved")
		_details.add_child(name_label)
		var id_label: Label = Label.new()
		id_label.name = &"VariableID"
		id_label.text = "Variable ID: " + variable_source.variable_id
		_details.add_child(id_label)
		var declared_type_label: Label = Label.new()
		declared_type_label.name = &"VariableDeclaredType"
		declared_type_label.text = "Declared Type: " + \
			FlowVariableDefinition.value_type_display_name(
				variable_segment.get_declared_value_type()
			)
		_details.add_child(declared_type_label)
		var change_button: Button = Button.new()
		change_button.name = &"ChangeVariable"
		change_button.text = "Change Variable"
		change_button.disabled = not chip_editable
		change_button.tooltip_text = (
			"Choose another graph variable without editing the stable ID directly."
			if chip_editable else FEEDBACK_TOK_IMMUTABLE
		)
		change_button.focus_mode = Control.FOCUS_ALL
		change_button.pressed.connect(_on_change_variable_pressed.bind(segment.get_segment_id()))
		_details.add_child(change_button)
		_add_policy_detail_labels(chip_editable, type_locked, source_kind_locked)
		return
	var expression_segment: FlowExpressionSegment = segment as FlowExpressionSegment
	var expression_source: FlowExpressionValueSource = \
		segment.get_value_source() as FlowExpressionValueSource
	if expression_segment != null and expression_source != null:
		var preview: Label = Label.new()
		preview.name = &"ExpressionPreview"
		preview.text = "Preview: " + expression_source.get_preview(_variable_graph)
		preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_details.add_child(preview)
		var result_type: Label = Label.new()
		result_type.name = &"ExpressionResultType"
		result_type.text = "Result Type: " + \
			FlowChipTypeDescriptor.variant_type_display_name(expression_source.get_value_type())
		_details.add_child(result_type)
		var edit_expression: Button = Button.new()
		edit_expression.name = &"EditExpression"
		edit_expression.text = "Edit Expression"
		edit_expression.disabled = not chip_editable
		edit_expression.focus_mode = Control.FOCUS_ALL
		edit_expression.pressed.connect(_on_expression_edit_requested.bind(segment.get_segment_id()))
		_details.add_child(edit_expression)
		_add_policy_detail_labels(chip_editable, type_locked, source_kind_locked)
		return
	var condition_segment: FlowConditionSegment = segment as FlowConditionSegment
	var condition_source: FlowConditionValueSource = \
		segment.get_value_source() as FlowConditionValueSource
	if condition_segment != null and condition_source != null:
		var condition_preview: Label = Label.new()
		condition_preview.name = &"ConditionPreview"
		condition_preview.text = "Preview: " + condition_source.get_preview(_variable_graph)
		condition_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_details.add_child(condition_preview)
		var condition_type: Label = Label.new()
		condition_type.name = &"ConditionResultType"
		condition_type.text = "Produced Type: bool"
		_details.add_child(condition_type)
		var edit_condition: Button = Button.new()
		edit_condition.name = &"EditCondition"
		edit_condition.text = "Edit Condition"
		edit_condition.disabled = not chip_editable
		edit_condition.focus_mode = Control.FOCUS_ALL
		edit_condition.pressed.connect(_on_condition_edit_requested.bind(segment.get_segment_id()))
		_details.add_child(edit_condition)
		_add_policy_detail_labels(chip_editable, type_locked, source_kind_locked)
		return
	var operation_segment: FlowOperationSegment = segment as FlowOperationSegment
	var operation_source: FlowOperationValueSource = 		segment.get_value_source() as FlowOperationValueSource
	if operation_segment != null and operation_source != null:
		var operation_preview: Label = Label.new()
		operation_preview.name = &"OperationPreview"
		operation_preview.text = "Preview: " + operation_source.get_preview(_variable_graph)
		operation_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_details.add_child(operation_preview)
		var operation_type: Label = Label.new()
		operation_type.name = &"OperationResultType"
		operation_type.text = "Result Type: " + 			FlowChipTypeDescriptor.variant_type_display_name(operation_source.get_value_type())
		_details.add_child(operation_type)
		var edit_operation: Button = Button.new()
		edit_operation.name = &"EditOperation"
		edit_operation.text = "Edit Operation"
		edit_operation.disabled = not chip_editable
		edit_operation.focus_mode = Control.FOCUS_ALL
		edit_operation.pressed.connect(_on_operation_edit_requested.bind(segment.get_segment_id()))
		_details.add_child(edit_operation)
		_add_policy_detail_labels(chip_editable, type_locked, source_kind_locked)
		return
	if not descriptor.editable:
		_add_policy_detail_labels(false, type_locked, source_kind_locked)
		return
	if not chip_editable:
		_add_policy_detail_labels(false, type_locked, source_kind_locked)
		return

	var supported_types: Array[Variant.Type] = descriptor.get_supported_variant_types()
	var accepted_types: Array[Variant.Type] = []
	for candidate: Variant.Type in supported_types:
		if _accepts_chip_type(segment, candidate):
			accepted_types.append(candidate)
	if accepted_types.size() > 1 and not type_locked:
		var type_label: Label = Label.new()
		type_label.text = "Variant.Type"
		_details.add_child(type_label)
		var type_selector: OptionButton = OptionButton.new()
		type_selector.name = &"FlowChipTypeSelector"
		type_selector.focus_mode = Control.FOCUS_ALL
		var current_type: Variant.Type = segment.get_editable_value_type()
		for candidate: Variant.Type in accepted_types:
			var item_index: int = type_selector.item_count
			type_selector.add_item(FlowChipTypeDescriptor.variant_type_display_name(candidate))
			type_selector.set_item_metadata(item_index, int(candidate))
			if candidate == current_type:
				type_selector.select(item_index)
		type_selector.item_selected.connect(_on_type_selected.bind(type_selector))
		_details.add_child(type_selector)

	var value_label: Label = Label.new()
	value_label.text = "Value"
	_details.add_child(value_label)
	var value_control: Control = _create_value_control(segment)
	if value_control != null:
		_details.add_child(value_control)

	var movement: HBoxContainer = HBoxContainer.new()
	var earlier: Button = Button.new()
	earlier.name = &"MoveEarlier"
	earlier.text = "Move earlier"
	earlier.disabled = not _can_reorder_chip(segment)
	earlier.pressed.connect(move_selected_chip.bind(-1))
	movement.add_child(earlier)
	var later: Button = Button.new()
	later.name = &"MoveLater"
	later.text = "Move later"
	later.disabled = not _can_reorder_chip(segment)
	later.pressed.connect(move_selected_chip.bind(1))
	movement.add_child(later)
	_details.add_child(movement)
	_add_policy_detail_labels(chip_editable, type_locked, source_kind_locked)


func _add_policy_detail_labels(
		chip_editable: bool,
		type_locked: bool,
		source_kind_locked: bool
) -> void:
	if not chip_editable:
		var immutable_label: Label = Label.new()
		immutable_label.name = &"TokEditability"
		immutable_label.text = "Editing: immutable"
		_details.add_child(immutable_label)
	if type_locked:
		var type_lock_label: Label = Label.new()
		type_lock_label.name = &"TokTypeLock"
		type_lock_label.text = "Constraint: type locked"
		_details.add_child(type_lock_label)
	if source_kind_locked:
		var source_lock_label: Label = Label.new()
		source_lock_label.name = &"TokSourceKindLock"
		source_lock_label.text = "Constraint: source kind locked"
		_details.add_child(source_lock_label)


func _create_value_control(segment: FlowChipSegment) -> Control:
	var value_type: Variant.Type = segment.get_editable_value_type()
	var value: Variant = segment.get_editable_value()
	match value_type:
		Variant.Type.TYPE_BOOL:
			if typeof(value) != Variant.Type.TYPE_BOOL:
				return null
			var boolean_input: CheckBox = CheckBox.new()
			boolean_input.name = &"FlowChipBoolValue"
			boolean_input.focus_mode = Control.FOCUS_ALL
			boolean_input.text = "true / false"
			boolean_input.button_pressed = bool(value)
			boolean_input.toggled.connect(_on_boolean_value_changed)
			return boolean_input
		Variant.Type.TYPE_INT, Variant.Type.TYPE_FLOAT:
			if typeof(value) != value_type:
				return null
			var numeric_input: SpinBox = SpinBox.new()
			numeric_input.name = &"FlowChipNumericValue"
			numeric_input.focus_mode = Control.FOCUS_ALL
			numeric_input.allow_greater = true
			numeric_input.allow_lesser = true
			numeric_input.step = 1.0 if value_type == Variant.Type.TYPE_INT else 0.01
			numeric_input.rounded = value_type == Variant.Type.TYPE_INT
			numeric_input.value = float(value)
			numeric_input.value_changed.connect(_on_numeric_value_changed)
			numeric_input.get_line_edit().gui_input.connect(
				_on_native_history_gui_input.bind(numeric_input.get_line_edit())
			)
			return numeric_input
		Variant.Type.TYPE_STRING, Variant.Type.TYPE_STRING_NAME, Variant.Type.TYPE_NODE_PATH:
			if typeof(value) != value_type:
				return null
			var text_input: LineEdit = FLOW_CHIP_LINE_EDIT_SCRIPT.new() as LineEdit
			text_input.name = &"FlowChipTextValue"
			text_input.focus_mode = Control.FOCUS_ALL
			text_input.text = String(value)
			text_input.text_changed.connect(
				_on_text_value_changed.bind(segment.get_segment_id(), value_type, text_input)
			)
			text_input.text_submitted.connect(
				_on_text_value_submitted.bind(segment.get_segment_id(), value_type, text_input)
			)
			text_input.focus_exited.connect(
				_on_text_value_focus_exited.bind(segment.get_segment_id(), value_type, text_input)
			)
			return text_input
		Variant.Type.TYPE_VECTOR2, Variant.Type.TYPE_VECTOR2I, 		Variant.Type.TYPE_VECTOR3, Variant.Type.TYPE_VECTOR3I:
			if typeof(value) != value_type:
				return null
			return _create_vector_value_control(value_type, value)
		Variant.Type.TYPE_COLOR:
			if typeof(value) != Variant.Type.TYPE_COLOR:
				return null
			var color_input: ColorPickerButton = ColorPickerButton.new()
			color_input.name = &"FlowChipColorValue"
			color_input.focus_mode = Control.FOCUS_ALL
			var color_value: Color = value
			color_input.color = color_value
			color_input.color_changed.connect(_on_color_value_changed)
			return color_input
	return null


func _create_vector_value_control(
		value_type: Variant.Type,
		value: Variant
) -> Control:
	var box: HBoxContainer = HBoxContainer.new()
	box.name = &"FlowChipVectorValue"
	var component_count: int = 2 		if value_type == Variant.Type.TYPE_VECTOR2 or value_type == Variant.Type.TYPE_VECTOR2I else 3
	var values: Array[float] = []
	if value_type == Variant.Type.TYPE_VECTOR2:
		var v2: Vector2 = value
		values = [v2.x, v2.y]
	elif value_type == Variant.Type.TYPE_VECTOR2I:
		var v2i: Vector2i = value
		values = [float(v2i.x), float(v2i.y)]
	elif value_type == Variant.Type.TYPE_VECTOR3:
		var v3: Vector3 = value
		values = [v3.x, v3.y, v3.z]
	else:
		var v3i: Vector3i = value
		values = [float(v3i.x), float(v3i.y), float(v3i.z)]
	for index: int in component_count:
		var spin: SpinBox = SpinBox.new()
		spin.name = "Component%d" % index
		spin.focus_mode = Control.FOCUS_ALL
		spin.allow_greater = true
		spin.allow_lesser = true
		spin.step = 1.0 if value_type == Variant.Type.TYPE_VECTOR2I 			or value_type == Variant.Type.TYPE_VECTOR3I else 0.01
		spin.rounded = value_type == Variant.Type.TYPE_VECTOR2I 			or value_type == Variant.Type.TYPE_VECTOR3I
		spin.value = values[index]
		spin.custom_minimum_size.x = 90.0
		spin.value_changed.connect(_on_vector_value_changed.bind(value_type, box))
		box.add_child(spin)
	return box


## The Akis action is already executed by _input(). This phase only accepts the
## same shortcut at the focused native boundary; it never calls undo/redo again.
func _on_native_history_gui_input(event: InputEvent, input: Control) -> void:
	if _undo_redo != null and _document != null and _is_document_history_shortcut(event):
		input.accept_event()


func _on_type_selected(index: int, selector: OptionButton) -> void:
	if index < 0 or index >= selector.item_count:
		return
	change_selected_chip_type(int(selector.get_item_metadata(index)))


func _on_boolean_value_changed(value: bool) -> void:
	set_selected_chip_value(value)


func _on_numeric_value_changed(value: float) -> void:
	var segment: FlowChipSegment = _selected_chip()
	if segment == null:
		return
	var value_type: Variant.Type = segment.get_editable_value_type()
	set_selected_chip_value(int(value) if value_type == Variant.Type.TYPE_INT else value)


func _on_vector_value_changed(
		_value: float,
		value_type: Variant.Type,
		box: HBoxContainer
) -> void:
	var components: Array[float] = []
	for child: Node in box.get_children():
		var spin: SpinBox = child as SpinBox
		if spin != null:
			components.append(spin.value)
	var next: Variant
	match value_type:
		Variant.Type.TYPE_VECTOR2:
			next = Vector2(components[0], components[1])
		Variant.Type.TYPE_VECTOR2I:
			next = Vector2i(int(components[0]), int(components[1]))
		Variant.Type.TYPE_VECTOR3:
			next = Vector3(components[0], components[1], components[2])
		Variant.Type.TYPE_VECTOR3I:
			next = Vector3i(int(components[0]), int(components[1]), int(components[2]))
	set_selected_chip_value(next)


func _on_color_value_changed(value: Color) -> void:
	set_selected_chip_value(value)


func _on_text_value_changed(
		value: String,
		segment_id: String,
		value_type: Variant.Type,
		input: LineEdit
) -> void:
	_commit_text_value(segment_id, value, value_type, input, false)


func _on_text_value_submitted(
		value: String,
		segment_id: String,
		value_type: Variant.Type,
		input: LineEdit
) -> void:
	_commit_text_value(segment_id, value, value_type, input, true)


func _on_text_value_focus_exited(
		segment_id: String,
		value_type: Variant.Type,
		input: LineEdit
) -> void:
	if input == null:
		return
	_commit_text_value(segment_id, input.text, value_type, input, true)


func _commit_text_value(
		segment_id: String,
		value: String,
		value_type: Variant.Type,
		input: LineEdit,
		finalize: bool
) -> void:
	if _suppress_input:
		return
	var segment: FlowChipSegment = _find_segment(segment_id) as FlowChipSegment
	if segment == null:
		return
	var typed_value: Variant = StringName(value) 		if value_type == Variant.Type.TYPE_STRING_NAME 		else NodePath(value) if value_type == Variant.Type.TYPE_NODE_PATH else value
	if typeof(typed_value) != value_type:
		return
	_record_native_value_change(segment, input, typed_value)
	if finalize:
		_value_history_sessions.erase(segment_id)


func _refresh_validation() -> void:
	if _schema == null:
		_validation_result = FlowStructuredDocumentValidator.validate(_document, _variable_graph)
		if _validation_result.has_errors() and not _validation_result.diagnostics.is_empty():
			var document_diagnostic: FlowDiagnostic = _validation_result.diagnostics[0]
			_validation_label.text = "Invalid chip field: %s" % document_diagnostic.message
			_validation_label.tooltip_text = "%s (%s)" % [
				document_diagnostic.element_path,
				document_diagnostic.code,
			]
			_validation_label.visible = true
		else:
			_validation_label.text = ""
			_validation_label.tooltip_text = ""
			_validation_label.visible = false
		return
	_validation_result = FlowChipFieldValidator.validate(_schema, _document, _variable_graph)
	if _validation_result.has_errors() and not _validation_result.diagnostics.is_empty():
		var diagnostic: FlowDiagnostic = _validation_result.diagnostics[0]
		_validation_label.text = "Invalid chip field: %s" % diagnostic.message
		_validation_label.tooltip_text = "%s (%s)" % [diagnostic.element_path, diagnostic.code]
		_validation_label.visible = true
	else:
		_validation_label.text = ""
		_validation_label.tooltip_text = ""
		_validation_label.visible = false


func _update_toolbar_state() -> void:
	if _add_value_button == null:
		return
	var fixed: bool = _schema != null and _schema.mode == FlowChipFieldSchema.Mode.FIXED
	_add_value_button.disabled = fixed
	_add_value_button.tooltip_text = (
		"FIXED fields generate their declared chips; no extra chip can be inserted."
		if fixed else "Insert a compatible literal at the real caret."
	)


func _notify_document_changed(rebuild_visual: bool = true) -> void:
	_refresh_validation()
	document_changed.emit()
	_update_chip_controls()
	if rebuild_visual:
		_queue_refresh()


func _update_chip_controls() -> void:
	for control: Control in _visual_elements:
		var chip: FlowChipControl = control as FlowChipControl
		if chip != null:
			chip.refresh()


func _apply_text(segment: FlowTextSegment, text: String) -> void:
	if segment == null or segment.text == text:
		return
	var input: TextEdit = get_text_control(segment.get_segment_id())
	var had_focus: bool = input != null and input.has_focus()
	var previous_offset: int = _text_offset(input) if input != null else 0
	segment.text = text
	# TextEdit is the native input owner. Keep its instance alive for text/value
	# changes so a text_changed signal cannot strand focus or an IME caret.
	_notify_document_changed(false)
	if input == null:
		_queue_refresh()
		return
	if input.text != text:
		_suppress_input = true
		input.text = text
		_suppress_input = false
		if had_focus:
			_set_text_offset(input, previous_offset)
	input.custom_minimum_size = _text_minimum_size(input, text)
	_surface.queue_sort()


func _record_native_text_change(segment_id: String, input: TextEdit, text: String) -> void:
	var segment: FlowTextSegment = _find_segment(segment_id) as FlowTextSegment
	if segment == null or segment.text == text:
		return
	if _undo_redo == null:
		_apply_text(segment, text)
		return
	var session: Dictionary = _text_history_sessions.get(segment_id, {}) as Dictionary
	if session.is_empty() or session.get("control", null) != input:
		session = {
			"control": input,
			"before": segment.text,
			"after": text,
		}
		_text_history_sessions[segment_id] = session
		_undo_redo.create_action(
			"Edit Structured Text",
			UndoRedo.MERGE_DISABLE,
			_history_owner(),
			false,
			true
		)
		_undo_redo.force_fixed_history()
		_undo_redo.add_do_method(
			self,
			&"_apply_text_history_state",
			segment,
			session
		)
		_undo_redo.add_undo_method(self, &"_apply_text_history_undo", segment, session)
		_undo_redo.commit_action()
		return
	session["after"] = text
	_apply_text(segment, text)


func _record_native_value_change(
		segment: FlowChipSegment,
		input: LineEdit,
		value: Variant
) -> void:
	if segment == null or segment.get_editable_value() == value:
		return
	var value_type: Variant.Type = segment.get_editable_value_type()
	if _undo_redo == null:
		_apply_chip_value(segment, value_type, value)
		return
	var segment_id: String = segment.get_segment_id()
	var session: Dictionary = _value_history_sessions.get(segment_id, {}) as Dictionary
	if session.is_empty() or session.get("control", null) != input \
			or int(session.get("value_type", -1)) != int(value_type):
		session = {
			"control": input,
			"value_type": int(value_type),
			"before": segment.get_editable_value(),
			"after": value,
		}
		_value_history_sessions[segment_id] = session
		_undo_redo.create_action(
			"Change Chip Value",
			UndoRedo.MERGE_DISABLE,
			_history_owner(),
			false,
			true
		)
		_undo_redo.force_fixed_history()
		_undo_redo.add_do_method(
			self,
			&"_apply_value_history_state",
			segment,
			session
		)
		_undo_redo.add_undo_method(
			self,
			&"_apply_value_history_undo",
			segment,
			session
		)
		_undo_redo.commit_action()
		return
	session["after"] = value
	_apply_chip_value(segment, value_type, value)


func _apply_value_history_state(
		segment: FlowChipSegment,
		session: Dictionary
) -> void:
	if segment == null or session.is_empty():
		return
	var value_type: Variant.Type = int(session.get(
		"value_type",
		segment.get_editable_value_type()
	))
	_apply_chip_value(segment, value_type, session.get("after", null))


func _apply_value_history_undo(
		segment: FlowChipSegment,
		session: Dictionary
) -> void:
	if segment == null or session.is_empty():
		return
	_value_history_sessions.erase(segment.get_segment_id())
	var value_type: Variant.Type = int(session.get(
		"value_type",
		segment.get_editable_value_type()
	))
	_apply_chip_value(segment, value_type, session.get("before", null))


func _apply_text_history_state(
		segment: FlowTextSegment,
		session: Dictionary
) -> void:
	if segment == null or session.is_empty():
		return
	_apply_text(segment, String(session.get("after", "")))


func _apply_text_history_undo(segment: FlowTextSegment, session: Dictionary) -> void:
	if segment == null or session.is_empty():
		return
	_text_history_sessions.erase(segment.get_segment_id())
	_apply_text(segment, String(session.get("before", "")))


func _apply_chip_value(
		segment: FlowChipSegment,
		value_type: Variant.Type,
		value: Variant
) -> void:
	if segment == null:
		return
	var previous_type: Variant.Type = segment.get_editable_value_type()
	if not segment.set_editable_value(value_type, value):
		return
	# Update the existing chip/details controls in place. In particular, a
	# String or StringName LineEdit must not be recreated for every character.
	_notify_document_changed(false)
	if segment.get_segment_id() == _selected_segment_id and previous_type != value_type:
		_render_details()
	else:
		_sync_selected_value_control(segment)


func _sync_selected_value_control(segment: FlowChipSegment) -> void:
	if segment == null or _details == null:
		return
	var value_type: Variant.Type = segment.get_editable_value_type()
	var value: Variant = segment.get_editable_value()
	match value_type:
		Variant.Type.TYPE_BOOL:
			var boolean_input: CheckBox = _details.find_child("FlowChipBoolValue", true, false) as CheckBox
			if boolean_input != null and typeof(value) == Variant.Type.TYPE_BOOL:
				boolean_input.set_block_signals(true)
				boolean_input.button_pressed = bool(value)
				boolean_input.set_block_signals(false)
		Variant.Type.TYPE_INT, Variant.Type.TYPE_FLOAT:
			var numeric_input: SpinBox = _details.find_child("FlowChipNumericValue", true, false) as SpinBox
			if numeric_input != null and typeof(value) == value_type:
				numeric_input.set_block_signals(true)
				numeric_input.value = float(value)
				numeric_input.set_block_signals(false)
		Variant.Type.TYPE_STRING, Variant.Type.TYPE_STRING_NAME:
			var text_input: LineEdit = _details.find_child("FlowChipTextValue", true, false) as LineEdit
			if text_input != null and typeof(value) == value_type:
				var had_focus: bool = text_input.has_focus()
				var previous_column: int = text_input.caret_column
				var next_text: String = String(value)
				if text_input.text != next_text:
					text_input.set_block_signals(true)
					text_input.text = next_text
					text_input.set_block_signals(false)
					if had_focus:
						text_input.caret_column = mini(previous_column, next_text.length())


func _commit_state_action(
		action_name: String,
		before_segments: Array[FlowDocumentSegment],
		before_text_states: Array[Dictionary],
		after_segments: Array[FlowDocumentSegment],
		after_text_states: Array[Dictionary]
) -> void:
	if _undo_redo == null:
		_apply_segment_state(_document, after_segments, after_text_states)
		return
	_undo_redo.create_action(action_name, UndoRedo.MERGE_DISABLE, _history_owner(), false, true)
	# The document is an external Resource without a scene path. Pin the action
	# to the history selected by the custom context before registering the editor
	# node operations; otherwise a Popup/Focus transition can make Godot deduce
	# a different scene history between commit and the next undo lookup.
	_undo_redo.force_fixed_history()
	_undo_redo.add_do_method(
		self,
		&"_apply_segment_state",
		_document,
		after_segments,
		after_text_states
	)
	_undo_redo.add_undo_method(
		self,
		&"_apply_segment_state",
		_document,
		before_segments,
		before_text_states
	)
	_undo_redo.commit_action()


func _apply_segment_state(
		document: FlowStructuredDocument,
		segments: Array[FlowDocumentSegment],
		text_states: Array[Dictionary]
) -> void:
	if document == null:
		return
	_text_history_sessions.clear()
	_value_history_sessions.clear()
	for state: Dictionary in text_states:
		var segment: FlowTextSegment = state.get("segment") as FlowTextSegment
		if segment != null:
			segment.text = String(state.get("text", ""))
	document.segments = segments.duplicate()
	if not _id_exists(_selected_segment_id):
		_selected_segment_id = ""
	if not _id_exists(_caret_segment_id):
		_caret_segment_id = ""
	_notify_document_changed()


func _apply_insert(document: FlowStructuredDocument, index: int, segment: FlowDocumentSegment) -> void:
	if document == null or segment == null or _find_segment_in(document, segment.get_segment_id()) != null:
		return
	var segments: Array[FlowDocumentSegment] = _copy_segments(document.segments)
	segments.insert(clampi(index, 0, segments.size()), segment)
	document.segments = segments
	_notify_document_changed()


func _apply_remove(document: FlowStructuredDocument, segment_id: String) -> void:
	if document == null:
		return
	var segments: Array[FlowDocumentSegment] = _copy_segments(document.segments)
	for index: int in segments.size():
		var segment: FlowDocumentSegment = segments[index]
		if segment != null and segment.get_segment_id() == segment_id:
			segments.remove_at(index)
			document.segments = segments
			_notify_document_changed()
			return


func _can_insert_source(source: FlowValueSource) -> bool:
	if _schema == null:
		return true
	if _schema.mode == FlowChipFieldSchema.Mode.FIXED:
		if not source is FlowVariableRefValueSource \
				and not source is FlowExpressionValueSource \
				and not source is FlowConditionValueSource \
				and not source is FlowOperationValueSource:
			_reject("FIXED fields do not accept additional chips.")
			return false
		var fixed_context: Dictionary = _variable_insertion_context()
		var fixed_index: int = int(fixed_context.get("replacement_index", -1))
		var fixed_slot: FlowChipSlotDefinition = fixed_context.get("slot", null) as FlowChipSlotDefinition
		if fixed_index < 0 or fixed_slot == null:
			_reject(FEEDBACK_INVALID_CHIP_POSITION)
			return false
		if not _schema.accepts_value_type(source.get_value_type()) \
				or not _schema.accepts_source_kind(source.get_source_kind()) \
				or not fixed_slot.accepts_value_type(source.get_value_type()) \
				or not fixed_slot.accepts_source_kind(source.get_source_kind()):
			_reject(
				FEEDBACK_NO_COMPATIBLE_VARIABLE if source is FlowVariableRefValueSource
				else FEEDBACK_NO_COMPATIBLE_EXPRESSION if source is FlowExpressionValueSource
				else FEEDBACK_NO_COMPATIBLE_OPERATION if source is FlowOperationValueSource
				else "No compatible Condition source is available here."
			)
			return false
		var fixed_chip: FlowChipSegment = _segment_at(fixed_index) as FlowChipSegment
		if fixed_chip == null:
			_reject(FEEDBACK_INVALID_CHIP_POSITION)
			return false
		var current_source: FlowValueSource = fixed_chip.get_value_source()
		if current_source == null:
			_reject(FEEDBACK_TOK_IMMUTABLE)
			return false
		if current_source.get_source_kind() == FlowValueSource.SOURCE_KIND_VARIABLE_REF \
				and source.get_source_kind() == FlowValueSource.SOURCE_KIND_VARIABLE_REF:
			var current_variable: FlowVariableRefSegment = fixed_chip as FlowVariableRefSegment
			if current_variable == null or not _can_change_variable_reference(current_variable):
				_reject(FEEDBACK_TOK_IMMUTABLE)
				return false
		elif current_source.get_source_kind() != source.get_source_kind():
			if not _can_change_source_kind_for_segment(fixed_chip):
				_reject(FEEDBACK_TOK_SOURCE_KIND_LOCKED)
				return false
		if current_source.get_value_type() != source.get_value_type() \
				and not _can_change_value_type_for_segment(
					fixed_chip,
					current_source.get_value_type(),
					source.get_value_type()
				):
			_reject(FEEDBACK_TOK_TYPE_LOCKED)
			return false
		return true
	if not _schema.accepts_value_type(source.get_value_type()) \
			or not _schema.accepts_source_kind(source.get_source_kind()):
		_reject("This value source is incompatible with the field schema.")
		return false
	var definition: FlowChipSlotDefinition = _insertion_slot_definition()
	if _schema.mode == FlowChipFieldSchema.Mode.HYBRID and definition == null:
		_reject("Place the caret in the schema's optional value zone.")
		return false
	if source is FlowVariableRefValueSource:
		if not _schema_can_change_reference() \
				or (definition != null and not definition.can_change_reference()):
			_reject(FEEDBACK_TOK_IMMUTABLE)
			return false
	elif source is FlowExpressionValueSource:
		if not _schema_can_change_content() \
				or (definition != null and not definition.can_change_content()):
			_reject(FEEDBACK_TOK_IMMUTABLE)
			return false
	elif source is FlowConditionValueSource:
		if not _schema_can_change_content() \
				or (definition != null and not definition.can_change_content()):
			_reject(FEEDBACK_TOK_IMMUTABLE)
			return false
	elif source is FlowOperationValueSource:
		if not _schema_can_change_content() \
				or (definition != null and not definition.can_change_content()):
			_reject(FEEDBACK_TOK_IMMUTABLE)
			return false
	else:
		if not _schema_can_change_content() \
				or (definition != null and not definition.can_change_content()):
			_reject(FEEDBACK_TOK_IMMUTABLE)
			return false
	var maximum: int = _insertion_maximum(definition)
	if definition != null:
		if not definition.accepts_value_type(source.get_value_type()) \
				or not definition.accepts_source_kind(source.get_source_kind()):
			_reject("This value source is incompatible with the variadic slot.")
			return false
	if maximum >= 0 and _count_insertable_chips() >= maximum:
		_reject(FEEDBACK_MAX_CHIP_COUNT % maximum)
		return false
	return true


func _refresh_variable_resolutions() -> void:
	if _document == null:
		return
	for segment: FlowDocumentSegment in _document.segments:
		var variable_segment: FlowVariableRefSegment = segment as FlowVariableRefSegment
		if segment is FlowExpressionSegment:
			(segment as FlowExpressionSegment).set_variable_graph(_variable_graph)
			continue
		if segment is FlowConditionSegment:
			(segment as FlowConditionSegment).set_variable_graph(_variable_graph)
			continue
		if segment is FlowOperationSegment:
			(segment as FlowOperationSegment).set_variable_graph(_variable_graph)
			continue
		if variable_segment == null:
			continue
		if _variable_graph == null:
			variable_segment.clear_resolution()
			continue
		var source: FlowVariableRefValueSource = \
			variable_segment.get_value_source() as FlowVariableRefValueSource
		variable_segment.set_resolved_variable(
			source.resolve_definition(_variable_graph) if source != null else null
		)


func _literal_types_allowed_by_schema(
		definition: FlowChipSlotDefinition
) -> Array[Variant.Type]:
	var available: Array[Variant.Type] = []
	var candidates: Array[Variant.Type] = [
		FlowLiteralValueSource.TYPE_BOOL,
		FlowLiteralValueSource.TYPE_INT,
		FlowLiteralValueSource.TYPE_FLOAT,
		FlowLiteralValueSource.TYPE_STRING,
		FlowLiteralValueSource.TYPE_STRING_NAME,
		FlowLiteralValueSource.TYPE_VECTOR2,
		FlowLiteralValueSource.TYPE_VECTOR2I,
		FlowLiteralValueSource.TYPE_VECTOR3,
		FlowLiteralValueSource.TYPE_VECTOR3I,
		FlowLiteralValueSource.TYPE_COLOR,
		FlowLiteralValueSource.TYPE_NODE_PATH,
	]
	for candidate: Variant.Type in candidates:
		if _schema != null and not _schema.accepts_value_type(candidate):
			continue
		if definition != null and not definition.accepts_value_type(candidate):
			continue
		available.append(candidate)
	return available


func _insertion_maximum(definition: FlowChipSlotDefinition) -> int:
	if _schema == null:
		return FlowChipSlotDefinition.UNLIMITED_COUNT
	var maximum: int = _schema.flexible_max_count
	if definition != null and definition.max_count >= 0:
		maximum = definition.max_count if maximum < 0 else mini(maximum, definition.max_count)
	return maximum


func _insertion_limit_reached(definition: FlowChipSlotDefinition) -> bool:
	var maximum: int = _insertion_maximum(definition)
	return maximum >= 0 and _count_insertable_chips() >= maximum


func _chip_from_source(source: FlowValueSource) -> FlowChipSegment:
	if source is FlowLiteralValueSource:
		var literal: FlowLiteralValueSource = source as FlowLiteralValueSource
		if not FlowLiteralValueSource.is_valid_literal(literal.get_value_type(), literal.get_value()):
			return null
		return FlowLiteralValueSegment.new(literal.get_value_type(), literal.get_value())
	if source is FlowExpressionValueSource:
		return FlowExpressionSegment.new(source as FlowExpressionValueSource)
	if source is FlowConditionValueSource:
		return FlowConditionSegment.new(source as FlowConditionValueSource)
	if source is FlowOperationValueSource:
		return FlowOperationSegment.new(source as FlowOperationValueSource)
	var generic: FlowChipSegment = FlowChipSegment.new()
	generic.set_value_source(source)
	return generic


func _insertion_slot_definition() -> FlowChipSlotDefinition:
	if _schema == null:
		return null
	if _schema.mode == FlowChipFieldSchema.Mode.FLEXIBLE:
		return _schema.variadic_slot_definition
	if _schema.mode != FlowChipFieldSchema.Mode.HYBRID \
			or _schema.variadic_slot_definition == null:
		return null
	return _schema.variadic_slot_definition if _caret_is_in_variadic_zone() else null


func _caret_is_in_variadic_zone() -> bool:
	if _schema == null or _schema.variadic_slot_definition == null or _document == null:
		return false
	var variadic_slot_id: String = _schema.variadic_slot_definition.slot_id
	if _caret_boundary_index >= 0:
		var left: FlowDocumentSegment = _segment_at(_caret_boundary_index - 1)
		var right: FlowDocumentSegment = _segment_at(_caret_boundary_index)
		if _is_variadic_chip(left, variadic_slot_id) or _is_variadic_chip(right, variadic_slot_id):
			return true
		if _caret_boundary_index == _expected_variadic_segment_index():
			return true
	if _caret_segment_id.is_empty():
		return false
	var text_index: int = _find_segment_index(_caret_segment_id)
	var text_segment: FlowTextSegment = _find_segment(_caret_segment_id) as FlowTextSegment
	if text_index < 0 or text_segment == null:
		return false
	var previous: FlowDocumentSegment = _neighbor_non_null(text_index, -1)
	var next: FlowDocumentSegment = _neighbor_non_null(text_index, 1)
	if _is_variadic_chip(previous, variadic_slot_id):
		return _caret_offset == 0
	if _is_variadic_chip(next, variadic_slot_id):
		return _caret_offset == text_segment.text.length()
	return text_index == _expected_variadic_segment_index() - 1 \
		and _caret_offset == text_segment.text.length()


func _expected_variadic_segment_index() -> int:
	if _schema == null or _schema.variadic_slot_definition == null:
		return -1
	var segment_index: int = 0
	for part: FlowChipFieldTemplatePart in _schema.template_parts:
		if part == null:
			continue
		if part.is_text_part():
			if _schema.text_mode != FlowChipFieldSchema.TextMode.DISABLED and not part.text.is_empty():
				segment_index += 1
		elif part.is_slot_part():
			if part.slot_id == _schema.variadic_slot_definition.slot_id:
				return segment_index
			segment_index += _count_slot_chips(part.slot_id)
	return segment_index


func _segment_at(index: int) -> FlowDocumentSegment:
	if _document == null or index < 0 or index >= _document.segments.size():
		return null
	return _document.segments[index]


func _is_variadic_chip(segment: FlowDocumentSegment, slot_id: String) -> bool:
	var chip: FlowChipSegment = segment as FlowChipSegment
	return chip != null and chip.get_slot_id() == slot_id


func _count_insertable_chips() -> int:
	var count: int = 0
	if _document == null:
		return 0
	for segment: FlowDocumentSegment in _document.segments:
		var chip: FlowChipSegment = segment as FlowChipSegment
		if chip == null:
			continue
		if _schema == null:
			count += 1
		elif _schema.mode == FlowChipFieldSchema.Mode.FLEXIBLE:
			count += 1
		elif _schema.variadic_slot_definition != null \
				and chip.get_slot_id() == _schema.variadic_slot_definition.slot_id:
			count += 1
	return count


func _schema_can_change_content() -> bool:
	return _schema == null or _schema.can_change_content()


func _schema_can_change_reference() -> bool:
	return _schema == null or _schema.can_change_reference()


func _schema_can_change_type() -> bool:
	return _schema == null or _schema.can_change_type()


func _schema_can_change_source_kind() -> bool:
	return _schema == null or _schema.can_change_source_kind()


func _can_edit_chip(chip: FlowChipSegment) -> bool:
	if chip == null:
		return false
	var descriptor: FlowChipTypeDescriptor = chip.get_chip_type_descriptor()
	if chip is FlowVariableRefSegment:
		return _can_change_variable_reference(chip as FlowVariableRefSegment)
	if chip is FlowExpressionSegment:
		return _can_change_chip_content(chip)
	if chip is FlowConditionSegment:
		return _can_change_chip_content(chip)
	return descriptor != null and descriptor.editable and _can_change_chip_content(chip)


func _can_change_chip_content(chip: FlowChipSegment) -> bool:
	if chip == null or not _schema_can_change_content():
		return false
	var definition: FlowChipSlotDefinition = _slot_definition_for(chip)
	return definition == null or definition.can_change_content()


func _can_change_variable_reference(segment: FlowVariableRefSegment) -> bool:
	if segment == null or not _schema_can_change_reference():
		return false
	var definition: FlowChipSlotDefinition = _slot_definition_for(segment)
	return definition == null or definition.can_change_reference()


func _can_change_chip_type(chip: FlowChipSegment, candidate: Variant.Type) -> bool:
	if chip == null or not _schema_can_change_type():
		return false
	var definition: FlowChipSlotDefinition = _slot_definition_for(chip)
	if definition != null and not definition.can_change_type():
		return false
	if not _can_change_value_type_for_segment(
			chip,
			chip.get_editable_value_type(),
			candidate
	):
		return false
	return _can_change_chip_content(chip)


func _can_change_value_type_for_segment(
		chip: FlowChipSegment,
		current_type: Variant.Type,
		candidate: Variant.Type
) -> bool:
	if chip == null or current_type == Variant.Type.TYPE_NIL:
		return false
	if current_type == candidate:
		return true
	if not _schema_can_change_type():
		return false
	var definition: FlowChipSlotDefinition = _slot_definition_for(chip)
	if definition != null and not definition.can_change_type():
		return false
	return not _is_value_type_locked_for_segment(chip)


func _can_change_source_kind_for_segment(chip: FlowChipSegment) -> bool:
	if chip == null or not _schema_can_change_source_kind():
		return false
	var definition: FlowChipSlotDefinition = _slot_definition_for(chip)
	return definition == null or definition.can_change_source_kind()


func _accepted_types_for_segment(chip: FlowChipSegment) -> Array[Variant.Type]:
	var definition: FlowChipSlotDefinition = _slot_definition_for(chip)
	return _accepted_value_types_for_slot(definition)


func _is_value_type_locked_for_segment(chip: FlowChipSegment) -> bool:
	if chip == null:
		return true
	var definition: FlowChipSlotDefinition = _slot_definition_for(chip)
	if not _schema_can_change_type():
		return true
	if definition != null and definition.is_value_type_locked():
		return true
	var accepted: Array[Variant.Type] = _accepted_types_for_segment(chip)
	return accepted.size() == 1


func _is_source_kind_locked_for_segment(chip: FlowChipSegment) -> bool:
	if chip == null:
		return true
	var definition: FlowChipSlotDefinition = _slot_definition_for(chip)
	if not _schema_can_change_source_kind():
		return true
	if definition != null and definition.is_source_kind_locked():
		return true
	var accepted: Array[StringName] = _accepted_source_kinds_for_slot(definition)
	return accepted.size() == 1


func _can_delete_chip(chip: FlowChipSegment) -> bool:
	if _schema == null:
		return true
	var definition: FlowChipSlotDefinition = _slot_definition_for(chip)
	if definition != null and not definition.can_delete():
		_reject("This chip is required and cannot be deleted.")
		return false
	var count: int = _count_slot_chips(chip.get_slot_id())
	var minimum: int = _minimum_for_insertion_slot(definition)
	if count <= minimum:
		_reject("The minimum chip count for this slot has been reached.")
		return false
	return true


func _can_reorder_chip(chip: FlowChipSegment) -> bool:
	if _schema == null:
		return true
	var definition: FlowChipSlotDefinition = _slot_definition_for(chip)
	if definition != null and not definition.allow_reorder:
		_reject("This chip cannot be reordered by its schema.")
		return false
	return true


func _accepts_chip_type(chip: FlowChipSegment, candidate: Variant.Type) -> bool:
	if _schema != null and not _schema.accepts_value_type(candidate):
		return false
	var definition: FlowChipSlotDefinition = _slot_definition_for(chip)
	return definition == null or definition.accepts_value_type(candidate)


func _slot_definition_for(chip: FlowChipSegment) -> FlowChipSlotDefinition:
	if _schema == null or chip == null:
		return null
	return _schema.get_slot_definition(chip.get_slot_id())


func _count_slot_chips(slot_id: String) -> int:
	var count: int = 0
	if _document == null:
		return 0
	for segment: FlowDocumentSegment in _document.segments:
		var chip: FlowChipSegment = segment as FlowChipSegment
		if chip != null and chip.get_slot_id() == slot_id:
			count += 1
	return count


func _minimum_for_insertion_slot(definition: FlowChipSlotDefinition) -> int:
	if definition == null:
		return _schema.flexible_min_count \
			if _schema != null and _schema.mode == FlowChipFieldSchema.Mode.FLEXIBLE else 0
	var minimum: int = definition.get_effective_min_count()
	if _schema != null and _schema.mode == FlowChipFieldSchema.Mode.FLEXIBLE:
		minimum = maxi(minimum, _schema.flexible_min_count)
	return minimum


func _insertion_index() -> int:
	if _caret_segment_id != "":
		var caret_index: int = _find_segment_index(_caret_segment_id)
		if caret_index >= 0:
			return caret_index
	if _caret_boundary_index >= 0:
		return clampi(_caret_boundary_index, 0, _document.segments.size())
	if _current_position_id != "":
		var current_index: int = _find_segment_index(_current_position_id)
		if current_index >= 0:
			return current_index + 1
	return _document.segments.size()


func _focus_target_after_removal(index: int) -> Dictionary:
	var previous: FlowDocumentSegment = _neighbor_non_null(index, -1)
	if previous is FlowTextSegment:
		return {
			"id": previous.get_segment_id(),
			"is_text": true,
			"offset": (previous as FlowTextSegment).text.length(),
		}
	var next: FlowDocumentSegment = _neighbor_non_null(index, 1)
	if next is FlowTextSegment:
		return {"id": next.get_segment_id(), "is_text": true, "offset": 0}
	if next is FlowChipSegment:
		return {"id": next.get_segment_id(), "is_text": false, "offset": 0}
	if previous is FlowChipSegment:
		return {"id": previous.get_segment_id(), "is_text": false, "offset": 0}
	return {"id": "", "is_text": false, "offset": 0}


func _neighbor_non_null(index: int, direction: int) -> FlowDocumentSegment:
	var candidate_index: int = index + direction
	while candidate_index >= 0 and candidate_index < _document.segments.size():
		var candidate: FlowDocumentSegment = _document.segments[candidate_index]
		if candidate != null:
			return candidate
		candidate_index += direction
	return null


func _find_segment(segment_id: String) -> FlowDocumentSegment:
	if _document == null or segment_id.is_empty():
		return null
	for segment: FlowDocumentSegment in _document.segments:
		if segment != null and segment.get_segment_id() == segment_id:
			return segment
	return null


func _find_segment_in(document: FlowStructuredDocument, segment_id: String) -> FlowDocumentSegment:
	if document == null:
		return null
	for segment: FlowDocumentSegment in document.segments:
		if segment != null and segment.get_segment_id() == segment_id:
			return segment
	return null


func _find_segment_index(segment_id: String) -> int:
	if _document == null or segment_id.is_empty():
		return -1
	for index: int in _document.segments.size():
		var segment: FlowDocumentSegment = _document.segments[index]
		if segment != null and segment.get_segment_id() == segment_id:
			return index
	return -1


func _id_exists(segment_id: String) -> bool:
	return not segment_id.is_empty() and _find_segment(segment_id) != null


func _copy_segments(source: Array[FlowDocumentSegment]) -> Array[FlowDocumentSegment]:
	var copy: Array[FlowDocumentSegment] = []
	for segment: FlowDocumentSegment in source:
		copy.append(segment)
	return copy


func _text_states_for_segments(segments: Array[FlowDocumentSegment]) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	for segment: FlowDocumentSegment in segments:
		if segment is FlowTextSegment:
			states.append(_text_state(segment as FlowTextSegment, (segment as FlowTextSegment).text))
	return states


func _text_state(segment: FlowTextSegment, text: String) -> Dictionary:
	return {"segment": segment, "text": text}


func _text_offset(input: TextEdit) -> int:
	var line: int = input.get_caret_line()
	var column: int = input.get_caret_column()
	var lines: PackedStringArray = input.text.split("\n", true)
	var offset: int = 0
	for line_index: int in mini(line, lines.size()):
		offset += lines[line_index].length() + 1
	if line >= 0 and line < lines.size():
		offset += mini(column, lines[line].length())
	return clampi(offset, 0, input.text.length())


func _set_text_offset(input: TextEdit, offset: int) -> void:
	var target: int = clampi(offset, 0, input.text.length())
	var lines: PackedStringArray = input.text.split("\n", true)
	var remaining: int = target
	var target_line: int = 0
	for line_index: int in lines.size():
		var line_length: int = lines[line_index].length()
		if remaining <= line_length:
			target_line = line_index
			break
		remaining -= line_length + 1
		target_line = line_index
	input.set_caret_line(target_line)
	input.set_caret_column(clampi(remaining, 0, lines[target_line].length()))


func _capture_focus_anchor() -> void:
	if _focus_restore_id != "":
		return
	var viewport: Viewport = get_viewport()
	if viewport == null:
		return
	var focus_owner: Control = viewport.gui_get_focus_owner() as Control
	if focus_owner == null or not is_ancestor_of(focus_owner):
		return
	if focus_owner is FlowChipControl:
		_focus_restore_id = (focus_owner as FlowChipControl).get_segment_id()
		_focus_restore_offset = 0
	elif focus_owner is TextEdit:
		for segment_id: String in _visual_by_id.keys():
			if _visual_by_id[segment_id] == focus_owner:
				_focus_restore_id = segment_id
				_focus_restore_offset = _text_offset(focus_owner as TextEdit)
				break


func _restore_focus_anchor() -> void:
	if _focus_restore_id.is_empty():
		return
	var restore_id: String = _focus_restore_id
	var restore_offset: int = _focus_restore_offset
	var control: Control = get_segment_control(restore_id)
	if control == null or not control.is_inside_tree():
		_focus_restore_id = ""
		_focus_restore_offset = 0
		_preserve_selection_during_focus_restore = false
		return
	if control is TextEdit:
		var text_control: TextEdit = control as TextEdit
		text_control.grab_focus()
		_set_text_offset(text_control, restore_offset)
		# Rebuilding a TextEdit can emit focus/caret notifications in either
		# order. Keep the semantic anchor authoritative after both callbacks.
		_caret_segment_id = restore_id
		_current_position_id = restore_id
		_caret_offset = restore_offset
		_caret_boundary_index = -1
	elif control is FlowChipControl:
		(control as FlowChipControl).grab_focus()
	_focus_restore_id = ""
	_focus_restore_offset = 0
	_preserve_selection_during_focus_restore = false


func _focus_text_control(segment_id: String, offset: int) -> void:
	_caret_segment_id = segment_id
	_caret_offset = offset
	_caret_boundary_index = -1
	_focus_restore_id = segment_id
	_focus_restore_offset = offset
	var control: TextEdit = get_text_control(segment_id)
	if control != null:
		control.grab_focus()
		_set_text_offset(control, offset)
	_caret_segment_id = segment_id
	_caret_offset = offset


func _focus_chip(segment_id: String) -> void:
	var chip: FlowChipControl = get_chip_control(segment_id)
	if chip == null:
		return
	_on_chip_selected(segment_id)
	chip.grab_focus()


func _restore_text_focus_deferred(segment_id: String, offset: int) -> void:
	if not is_inside_tree():
		return
	_focus_text_control(segment_id, offset)
	if _focus_restore_id == segment_id:
		_focus_restore_id = ""
		_focus_restore_offset = 0


func _restore_chip_focus_deferred(segment_id: String) -> void:
	if not is_inside_tree():
		return
	_focus_chip(segment_id)


func _reject(message: String) -> void:
	_feedback_text = message
	if _feedback_label != null:
		_feedback_label.text = message
		_feedback_label.visible = true
	operation_feedback.emit(message)


func _clear_feedback() -> void:
	_feedback_text = ""
	if _feedback_label != null:
		_feedback_label.text = ""
		_feedback_label.visible = false


func _history_owner() -> Object:
	return _action_owner if is_instance_valid(_action_owner) else _document
