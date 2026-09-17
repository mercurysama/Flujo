@tool
class_name VPFlujoDock
extends EditorDock

## Editor surface. It does not locate scene nodes or manage plugin lifecycle.

signal schema_3_variable_list_focus_requested(controller: PVController, variable_id: String)
signal interaction_toggle_requested

var _controller_present: bool
var _controller_presence_initialized: bool = false
var _is_open: bool = false
var _controller: PVController
var _variable_editor: FlowGraphInspectorProperty
var _content: VBoxContainer
var _interaction_state_label: Label
var _interaction_button: Button
var _last_interaction_focus_reference: WeakRef


func _init() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_configure_dock()
	_build_interface()


func _ready() -> void:
	var viewport: Viewport = get_viewport()
	if viewport != null and not viewport.gui_focus_changed.is_connected(_on_gui_focus_changed):
		viewport.gui_focus_changed.connect(_on_gui_focus_changed)


func _exit_tree() -> void:
	var viewport: Viewport = get_viewport()
	if viewport != null and viewport.gui_focus_changed.is_connected(_on_gui_focus_changed):
		viewport.gui_focus_changed.disconnect(_on_gui_focus_changed)


func set_controller_present(is_present: bool) -> void:
	if _controller_presence_initialized and _controller_present == is_present:
		return

	_controller_presence_initialized = true
	_controller_present = is_present

	if is_present:
		open()
		_is_open = true
	else:
		close()
		_is_open = false


## Receives the editor-owned undo/redo manager once from the plugin composition root.
func configure(undo_redo: EditorUndoRedoManager) -> void:
	if _variable_editor != null:
		return
	_variable_editor = FlowGraphInspectorProperty.new()
	_variable_editor.name = &"Schema3VariablesDockEditor"
	_variable_editor.configure(undo_redo)
	_variable_editor.configure_for_dock()
	_variable_editor.schema_3_variable_list_focus_requested.connect(_on_variable_editor_list_focus_requested)
	_variable_editor.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_variable_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(_variable_editor)
	_variable_editor.set_dock_controller(_controller)


## Receives the controller resolved by the plugin's existing selection integration.
func set_controller(controller: PVController) -> void:
	var next_controller: PVController = controller if is_instance_valid(controller) else null
	var current_controller: PVController = _controller if is_instance_valid(_controller) else null
	if current_controller == next_controller:
		return
	_disconnect_controller(current_controller)
	_controller = next_controller
	_connect_controller(_controller)
	if _variable_editor != null:
		_variable_editor.set_dock_controller(_controller)


## Removes the current controller observer before replacing the dock context.
func _disconnect_controller(controller: PVController) -> void:
	if controller != null and controller.property_list_changed.is_connected(_on_controller_property_list_changed):
		controller.property_list_changed.disconnect(_on_controller_property_list_changed)


## Observes exactly one active controller for graph replacement notifications.
func _connect_controller(controller: PVController) -> void:
	if controller != null and not controller.property_list_changed.is_connected(_on_controller_property_list_changed):
		controller.property_list_changed.connect(_on_controller_property_list_changed)


func get_variable_editor() -> FlowGraphInspectorProperty:
	return _variable_editor


## Receives the Inspector-owned stable-ID selection for the active schema 3 graph.
func set_variable_selection(
	controller: PVController,
	collection: FlowGraphEditorCommands.Collection,
	variable_id: String
) -> void:
	if _variable_editor != null:
		_variable_editor.set_dock_variable_selection(controller, collection, variable_id)


func focus_variable_editor(controller: PVController, variable_id: String) -> void:
	if _variable_editor != null:
		_variable_editor.focus_selected_variable_editor(controller, variable_id)


## Returns a semantic Flujo focus destination without exposing internal editor controls to the coordinator.
func get_preferred_interaction_focus_target() -> Control:
	var last_target: Control = _control_from_reference(_last_interaction_focus_reference)
	if _can_focus(last_target):
		return last_target
	if _variable_editor != null:
		return _variable_editor.get_preferred_interaction_focus_target()
	return null


## Activates the dock presentation for explicit Flow interaction.
func activate_flow_interaction() -> void:
	make_visible()
	_is_open = true
	_set_interaction_presentation("Flow", "Leave Flow (F4)", false)


## Leaves explicit Flow interaction while retaining ordinary dock visibility and editor state.
func deactivate_flow_interaction() -> void:
	_set_interaction_presentation("Godot", "Enter Flow (F4)", false)


## Shows or hides only Flujo's editing surface; the state indicator remains accessible.
func set_editing_visible(is_visible: bool) -> void:
	if _variable_editor != null:
		_variable_editor.visible = is_visible


## Closes only transient interfaces owned by the Flujo editing surface.
func close_flow_transient_interfaces() -> void:
	if _variable_editor != null:
		_variable_editor.close_transient_interfaces()


## Presents the suspended game state without destroying the dock or its editor state.
func suspend_for_game() -> void:
	_set_interaction_presentation("Game", "Flow interaction is suspended", true)


func _on_variable_editor_list_focus_requested(controller: PVController, variable_id: String) -> void:
	emit_signal(&"schema_3_variable_list_focus_requested", controller, variable_id)


func _on_controller_property_list_changed() -> void:
	if _variable_editor != null:
		_variable_editor.refresh_dock_controller()


func _on_gui_focus_changed(control: Control) -> void:
	if _variable_editor == null or not is_instance_valid(control):
		return
	if control == _variable_editor or _variable_editor.is_ancestor_of(control):
		_last_interaction_focus_reference = weakref(control)


func toggle_visibility() -> void:
	if _is_open:
		close()
		_is_open = false
	else:
		make_visible()
		_is_open = true


func _configure_dock() -> void:
	name = "VPFlujoDock"
	title = "Flujo"
	default_slot = EditorDock.DOCK_SLOT_RIGHT_BR
	available_layouts = EditorDock.DOCK_LAYOUT_VERTICAL | EditorDock.DOCK_LAYOUT_FLOATING
	transient = true
	global = false
	closable = false
	icon_name = &"VisualShader"


func _build_interface() -> void:
	_content = VBoxContainer.new()
	_content.name = "VPFlujo"
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	add_child(_content)

	var title_label := Label.new()
	title_label.text = "Flujo"
	title_label.add_theme_font_size_override("font_size", 18)
	_content.add_child(title_label)

	var interaction_row: HBoxContainer = HBoxContainer.new()
	interaction_row.name = &"FlowInteractionControls"
	interaction_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(interaction_row)
	_interaction_state_label = Label.new()
	_interaction_state_label.name = &"FlowInteractionState"
	_interaction_state_label.text = "Interaction: Godot"
	_interaction_state_label.tooltip_text = "Current Flujo interaction state."
	_interaction_state_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	interaction_row.add_child(_interaction_state_label)
	_interaction_button = Button.new()
	_interaction_button.name = &"FlowInteractionToggle"
	_interaction_button.focus_mode = Control.FOCUS_ALL
	_interaction_button.text = "Enter Flow (F4)"
	_interaction_button.tooltip_text = "Enter or leave Flow interaction using F4."
	_interaction_button.pressed.connect(_on_interaction_button_pressed)
	interaction_row.add_child(_interaction_button)

	var description_label := Label.new()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.text = "Edit the element selected in the Godot Inspector."
	_content.add_child(description_label)


func _on_interaction_button_pressed() -> void:
	emit_signal(&"interaction_toggle_requested")


func _set_interaction_presentation(state_name: String, button_text: String, disabled: bool) -> void:
	if _interaction_state_label != null:
		_interaction_state_label.text = "Interaction: %s" % state_name
	if _interaction_button != null:
		_interaction_button.text = button_text
		_interaction_button.disabled = disabled


func _control_from_reference(reference: WeakRef) -> Control:
	if reference == null:
		return null
	var candidate: Control = reference.get_ref() as Control
	return candidate if is_instance_valid(candidate) else null


func _can_focus(control: Control) -> bool:
	return is_instance_valid(control) \
		and control.is_inside_tree() \
		and control.is_visible_in_tree() \
		and control.focus_mode != Control.FOCUS_NONE
