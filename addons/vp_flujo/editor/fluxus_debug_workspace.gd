@tool
class_name FluxusDebugWorkspace
extends FlowDrawerWorkspace

## Default Fluxus debugging workspace. Instantiable and host-agnostic.

var _title_label: Label
var _context_label: Label
var _tasks_container: VBoxContainer
var _status_label: Label
var _observations_edit: TextEdit
var _generate_button: Button
var _tasks: Array[Dictionary] = []
var _session_title: String = "Fluxus Debug Session"


func _init() -> void:
	name = "FluxusDebugWorkspace"
	workspace_title = "Fluxus Debug"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_ui()


func _build_ui() -> void:
	# Header (inside mounted workspace; host provides its own close button).
	var header: VBoxContainer = VBoxContainer.new()
	header.name = &"WorkspaceHeader"
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(header)

	_title_label = Label.new()
	_title_label.text = workspace_title
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(_title_label)

	_context_label = Label.new()
	_context_label.text = "Contexto: sesión de depuración"
	_context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	header.add_child(_context_label)

	# Content: scrollable checklist + observations so footer remains visible.
	var content_scroll: ScrollContainer = ScrollContainer.new()
	content_scroll.name = &"ContentScroll"
	content_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(content_scroll)

	var content: VBoxContainer = VBoxContainer.new()
	content.name = &"Content"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_PASS
	content_scroll.add_child(content)

	var tasks_title: Label = Label.new()
	tasks_title.text = "Tareas"
	content.add_child(tasks_title)

	_tasks_container = VBoxContainer.new()
	_tasks_container.name = &"TasksContainer"
	_tasks_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tasks_container.mouse_filter = Control.MOUSE_FILTER_PASS
	content.add_child(_tasks_container)

	var obs_label: Label = Label.new()
	obs_label.text = "Observaciones"
	content.add_child(obs_label)

	_observations_edit = TextEdit.new()
	_observations_edit.name = &"ObservationsEdit"
	_observations_edit.custom_minimum_size = Vector2(0.0, 96.0)
	_observations_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_observations_edit.size_flags_vertical = Control.SIZE_FILL
	_observations_edit.scroll_fit_content_height = false
	_observations_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_observations_edit.placeholder_text = "Notas u observaciones de la sesión..."
	content.add_child(_observations_edit)

	# Footer: report action always visible and interactable.
	var footer: VBoxContainer = VBoxContainer.new()
	footer.name = &"Footer"
	footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.size_flags_vertical = Control.SIZE_SHRINK_END
	footer.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(footer)

	_generate_button = Button.new()
	_generate_button.name = &"GenerateReportButton"
	_generate_button.text = "Generar reporte"
	_generate_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_generate_button.custom_minimum_size = Vector2(0.0, 40.0)
	_generate_button.pressed.connect(_on_generate_report_pressed)
	footer.add_child(_generate_button)

	_status_label = Label.new()
	_status_label.name = &"StatusLabel"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.text = ""
	footer.add_child(_status_label)

	_refresh_task_rows()


func activate(context: Dictionary = {}) -> void:
	if context.has("session_title"):
		_session_title = String(context.get("session_title", _session_title))
	if context.has("observations") and _observations_edit != null:
		_observations_edit.text = String(context.get("observations", ""))
	_update_context_label(context)
	# Siempre iniciar con la checklist vigente de esta iteración, sin marcar.
	_ensure_manual_test_tasks()
	_refresh_task_rows()


func deactivate() -> void:
	pass


func set_tasks(tasks: Variant) -> void:
	_tasks.clear()
	if tasks is Array:
		for item: Variant in tasks as Array:
			var entry: Dictionary = _normalize_task(item)
			if not entry.is_empty():
				_tasks.append(entry)
	_refresh_task_rows()


func _ensure_manual_test_tasks() -> void:
	# Política: solo checklist de la iteración actual (nueva, sin marcar) en UI y reporte.
	_tasks.clear()
	for manual_task: Dictionary in _current_visual_test_tasks():
		_tasks.append(manual_task.duplicate(true))


func get_tasks() -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for task: Dictionary in _tasks:
		copy.append(task.duplicate(true))
	return copy


func capture_state() -> Variant:
	return {
		"session_title": _session_title,
		"tasks": get_tasks(),
		"observations": _observations_edit.text if _observations_edit != null else "",
	}


func restore_state(state: Variant) -> void:
	if not state is Dictionary:
		return
	var data: Dictionary = state as Dictionary
	_session_title = String(data.get("session_title", _session_title))
	if data.has("observations") and _observations_edit != null:
		_observations_edit.text = String(data.get("observations", ""))
	# Solo checklist vigente de la iteración actual.
	_ensure_manual_test_tasks()
	_refresh_task_rows()


func _normalize_task(item: Variant) -> Dictionary:
	if item is String:
		return {"text": String(item), "done": false, "id": String(item)}
	if item is Dictionary:
		var dict: Dictionary = item as Dictionary
		var text: String = String(dict.get("text", dict.get("title", "")))
		if text.is_empty():
			return {}
		return {
			"id": String(dict.get("id", text)),
			"text": text,
			"done": bool(dict.get("done", false)),
		}
	return {}


func _default_tasks() -> Array:
	return [
		"Flujo carga sin Parse Error",
		"Botón Fluxus visible y atajo funciona",
		"Fluxus abre/cierra sin duplicar controles",
		"Generar reporte y copiar al portapapeles",
		"Pravah abre/cierra independientemente",
	]


func _current_visual_test_tasks() -> Array[Dictionary]:
	# Checklist vigente de esta iteración únicamente (Administrador de Variables en Flow). IDs propios, sin marcar.
	return [
		{"id": "var_flow_v1.01.section_list", "text": "Flow muestra sección Variables con listado de variables existentes.", "done": false},
		{"id": "var_flow_v1.02.create", "text": "Crear variable añade una variable con ID interno estable.", "done": false},
		{"id": "var_flow_v1.03.rename_stable", "text": "Renombrar variable conserva referencias (ID estable).", "done": false},
		{"id": "var_flow_v1.04.edit_type_initial", "text": "Editar tipo y valor inicial funciona y se valida.", "done": false},
		{"id": "var_flow_v1.05.delete_confirm", "text": "Eliminar variable solicita confirmación.", "done": false},
		{"id": "var_flow_v1.06.delete_referenced_warning", "text": "Eliminar variable referenciada muestra advertencia y diagnósticos claros.", "done": false},
		{"id": "var_flow_v1.07.tok_fset_select", "text": "Toks Variable y FSet permiten seleccionar variables existentes sin editores duplicados.", "done": false},
		{"id": "var_flow_v1.08.scope_undo_persist", "text": "Ámbitos, referencias, Undo/Redo y serialización se respetan.", "done": false},
		{"id": "var_flow_v1.09.flow_flusso_independent", "text": "Flow y Flusso permanecen independientes sin cambios de dimensiones/rediseño.", "done": false},
		{"id": "var_flow_v1.10.no_potok_changes", "text": "Sin cambios en Potok/FSM ni regresiones visibles.", "done": false},
		{"id": "var_flow_v1.11.no_console_errors", "text": "No aparecen errores de consola en pruebas manuales.", "done": false},
		{"id": "var_flow_v1.12.no_manual_pass_claim", "text": "No se declaran pruebas manuales aprobadas sin evidencia humana.", "done": false},
	]





func _refresh_task_rows() -> void:
	if _tasks_container == null:
		return
	for child: Node in _tasks_container.get_children():
		_tasks_container.remove_child(child)
		child.queue_free()
	for index: int in _tasks.size():
		var task: Dictionary = _tasks[index]
		var checkbox: CheckBox = CheckBox.new()
		checkbox.focus_mode = Control.FOCUS_NONE
		checkbox.mouse_filter = Control.MOUSE_FILTER_STOP
		checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		checkbox.text = String(task.get("text", ""))
		checkbox.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		checkbox.button_pressed = bool(task.get("done", false))
		checkbox.toggled.connect(_on_task_toggled.bind(index))
		_tasks_container.add_child(checkbox)


func _on_task_toggled(pressed: bool, index: int) -> void:
	if index < 0 or index >= _tasks.size():
		return
	_tasks[index]["done"] = pressed


func _update_context_label(context: Dictionary) -> void:
	if _context_label == null:
		return
	var label_text: String = "Contexto: %s" % _session_title
	if context.has("context_label"):
		label_text = String(context.get("context_label", label_text))
	_context_label.text = label_text


func _on_generate_report_pressed() -> void:
	var report: String = _build_report()
	var clipboard_state: String = _copy_report_to_clipboard(report)
	match clipboard_state:
		"copied":
			_set_status("Reporte copiado al portapapeles.")
		"unverified":
			_set_status("Copia no verificada. Reporte generado.")
		_:
			_set_status("No se pudo acceder al portapapeles. Reporte generado.")


func _build_report() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("== %s ==" % _session_title)
	lines.append("Fecha/hora: %s" % _report_datetime())
	lines.append("")
	var completed_count: int = 0
	var total: int = _tasks.size()
	lines.append("Tareas completadas:")
	for task: Dictionary in _tasks:
		if bool(task.get("done", false)):
			completed_count += 1
			lines.append("- [x] %s" % String(task.get("text", "")))
	if completed_count == 0:
		lines.append("- (ninguna)")
	lines.append("")
	lines.append("Tareas pendientes:")
	var pending_count: int = 0
	for task: Dictionary in _tasks:
		if not bool(task.get("done", false)):
			pending_count += 1
			lines.append("- [ ] %s" % String(task.get("text", "")))
	if pending_count == 0:
		lines.append("- (ninguna)")
	lines.append("")
	lines.append("Total: %d/%d completadas (%d pendientes)" % [completed_count, total, pending_count])
	lines.append("")
	lines.append("Observaciones:")
	var observations: String = _observations_edit.text.strip_edges() if _observations_edit != null else ""
	if observations.is_empty():
		lines.append("- (sin observaciones)")
	else:
		lines.append(observations)
	return "\n".join(lines)


func _report_datetime() -> String:
	var dt: Dictionary = Time.get_datetime_dict_from_system()
	if dt.is_empty():
		return "no disponible"
	return "%04d-%02d-%02d %02d:%02d:%02d" % [
		int(dt.get("year", 0)),
		int(dt.get("month", 0)),
		int(dt.get("day", 0)),
		int(dt.get("hour", 0)),
		int(dt.get("minute", 0)),
		int(dt.get("second", 0)),
	]


func _copy_report_to_clipboard(text: String) -> String:
	if text.is_empty():
		return "unavailable"
	if not ClassDB.class_has_method(&"DisplayServer", &"clipboard_set"):
		return "unavailable"
	DisplayServer.clipboard_set(text)
	# On some platforms (including Android/editor contexts) immediate readback
	# may be unavailable or not match; do not claim failure or success without
	# sufficient evidence.
	if ClassDB.class_has_method(&"DisplayServer", &"clipboard_get"):
		var current: String = DisplayServer.clipboard_get()
		if current == text:
			return "copied"
		return "unverified"
	return "unverified"


func _set_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message
