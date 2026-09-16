@tool
extends EditorDock

## Vista del editor. No busca nodos ni administra el ciclo de vida del plugin.

signal schema_3_variable_list_focus_requested(controller: PVController, variable_id: String)

var _controller_present: bool
var _controller_presence_initialized: bool = false
var _is_open: bool = false
var _controller: PVController
var _variable_editor: FlowGraphInspectorProperty
var _content: VBoxContainer


func _init() -> void:
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	_configure_dock()
	_build_interface()


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


func _on_variable_editor_list_focus_requested(controller: PVController, variable_id: String) -> void:
	emit_signal(&"schema_3_variable_list_focus_requested", controller, variable_id)


func _on_controller_property_list_changed() -> void:
	if _variable_editor != null:
		_variable_editor.refresh_dock_controller()


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

	var description_label := Label.new()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.text = "Schema 3 variable authoring for the selected PVController."
	_content.add_child(description_label)
