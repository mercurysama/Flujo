@tool
extends EditorDock

## Vista del editor. No busca nodos ni administra el ciclo de vida del plugin.

var _status_label: Label


func _init() -> void:
	_configure_dock()
	_build_interface()


func set_controller_present(is_present: bool) -> void:
	if is_present:
		_status_label.text = "PVController detectado. El editor visual está listo."
		open()
	else:
		_status_label.text = "Añade un nodo PVController a la escena para comenzar."
		close()


func _configure_dock() -> void:
	name = "VPFlujoDock"
	title = "VPFlujo"
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
	title_label.text = "Programación visual"
	title_label.add_theme_font_size_override("font_size", 18)
	content.add_child(title_label)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.text = "Añade un nodo PVController a la escena para comenzar."
	content.add_child(_status_label)

	var iteration_label := Label.new()
	iteration_label.text = "Iteración 1 · Base orientada a objetos"
	content.add_child(iteration_label)

