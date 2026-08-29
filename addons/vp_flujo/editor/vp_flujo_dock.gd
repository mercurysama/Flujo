@tool
extends EditorDock

## Vista del editor. No busca nodos ni administra el ciclo de vida del plugin.

var _controller_present: bool
var _controller_presence_initialized: bool = false
var _is_open: bool = false


func _init() -> void:
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
	var content := VBoxContainer.new()
	content.name = "VPFlujo"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	add_child(content)

	var title_label := Label.new()
	title_label.text = "Flujo"
	title_label.add_theme_font_size_override("font_size", 18)
	content.add_child(title_label)

	var description_label := Label.new()
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.text = "Sistema de programación visual"
	content.add_child(description_label)
