@tool
class_name NagareWorkspace
extends FlowDrawerWorkspace

## Instantiable Nagare workspace: node browser (left) + Akis/Tok editor area (right).
## First cycle: infrastructure, layout, and minimal browser<->editor communication.
## No chip contract migration; no runtime/Potok/Fluo changes.

signal node_selected(node_id: String, node_data: Dictionary)
signal edit_requested(node_id: String, field: String, value: Variant)

var _browser_list: ItemList
var _editor_title: Label
var _editor_placeholder: RichTextLabel
var _editor_field: LineEdit
var _editor_apply_button: Button
var _status_label: Label

var _nodes: Array[Dictionary] = []
var _selected_node_id: String = ""
var _draft_value: String = ""


func _init() -> void:
	name = "NagareWorkspace"
	workspace_title = "Nagare"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_ui()


func _build_ui() -> void:
	var root: HBoxContainer = HBoxContainer.new()
	root.name = &"NagareRoot"
	root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)

	# Left: node browser
	var browser_panel: VBoxContainer = VBoxContainer.new()
	browser_panel.name = &"BrowserPanel"
	browser_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	browser_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	browser_panel.size_flags_stretch_ratio = 0.9
	browser_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(browser_panel)

	var browser_title: Label = Label.new()
	browser_title.text = "Nodos"
	browser_panel.add_child(browser_title)

	_browser_list = ItemList.new()
	_browser_list.name = &"NodeBrowserList"
	_browser_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_browser_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_browser_list.select_mode = ItemList.SELECT_SINGLE
	_browser_list.item_selected.connect(_on_browser_item_selected)
	browser_panel.add_child(_browser_list)

	# Right: Akis/Tok editor area
	var editor_panel: VBoxContainer = VBoxContainer.new()
	editor_panel.name = &"EditorPanel"
	editor_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	editor_panel.size_flags_stretch_ratio = 1.3
	editor_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(editor_panel)

	_editor_title = Label.new()
	_editor_title.name = &"EditorTitle"
	_editor_title.text = "Editor Akis/Tok"
	_editor_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	editor_panel.add_child(_editor_title)

	_editor_placeholder = RichTextLabel.new()
	_editor_placeholder.name = &"EditorDetails"
	_editor_placeholder.fit_content = true
	_editor_placeholder.scroll_active = true
	_editor_placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor_placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_editor_placeholder.bbcode_enabled = false
	_editor_placeholder.text = "Selecciona un nodo para ver detalles.\nInfraestructura mínima: sin migración de chips ni cambios de contratos."
	editor_panel.add_child(_editor_placeholder)

	var edit_label: Label = Label.new()
	edit_label.text = "Valor (señal de edición, sin modificar contratos)"
	editor_panel.add_child(edit_label)

	_editor_field = LineEdit.new()
	_editor_field.name = &"DraftField"
	_editor_field.placeholder_text = "Borrador local..."
	_editor_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_editor_field.text_changed.connect(_on_draft_changed)
	editor_panel.add_child(_editor_field)

	_editor_apply_button = Button.new()
	_editor_apply_button.name = &"ApplyEditButton"
	_editor_apply_button.text = "Emitir solicitud de edición"
	_editor_apply_button.disabled = true
	_editor_apply_button.pressed.connect(_on_apply_edit_pressed)
	editor_panel.add_child(_editor_apply_button)

	_status_label = Label.new()
	_status_label.name = &"NagareStatus"
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.text = ""
	editor_panel.add_child(_status_label)


func activate(context: Dictionary = {}) -> void:
	if context.has("nodes"):
		set_nodes(context.get("nodes", []))
	if context.has("selected_node_id"):
		select_node_by_id(String(context.get("selected_node_id", "")), false)
	if _nodes.is_empty():
		set_nodes(_default_nodes())
	_refresh_editor()


func deactivate() -> void:
	pass


func set_nodes(nodes: Variant) -> void:
	_nodes.clear()
	if nodes is Array:
		for item: Variant in nodes as Array:
			var normalized: Dictionary = _normalize_node(item)
			if not normalized.is_empty():
				_nodes.append(normalized)
	_rebuild_browser()


func get_nodes() -> Array[Dictionary]:
	var copy: Array[Dictionary] = []
	for node_data: Dictionary in _nodes:
		copy.append(node_data.duplicate(true))
	return copy


func capture_state() -> Variant:
	return {
		"nodes": get_nodes(),
		"selected_node_id": _selected_node_id,
		"draft_value": _draft_value,
	}


func restore_state(state: Variant) -> void:
	if not state is Dictionary:
		return
	var data: Dictionary = state as Dictionary
	if data.has("nodes"):
		set_nodes(data.get("nodes", []))
	_draft_value = String(data.get("draft_value", ""))
	if _editor_field != null:
		_editor_field.text = _draft_value
	var wanted: String = String(data.get("selected_node_id", ""))
	select_node_by_id(wanted, false)
	_refresh_editor()


func select_node_by_id(node_id: String, emit_signal: bool = true) -> void:
	_selected_node_id = node_id
	_sync_browser_selection()
	var node_data: Dictionary = _find_node(node_id)
	_refresh_editor()
	_editor_apply_button.disabled = node_data.is_empty()
	if node_data.is_empty():
		_set_status("")
	else:
		_set_status("Selección comunicada al editor: %s" % String(node_data.get("label", node_id)))
	if emit_signal and not node_data.is_empty():
		node_selected.emit(node_id, node_data.duplicate(true))


func _normalize_node(item: Variant) -> Dictionary:
	if item is String:
		var text: String = String(item)
		return {"id": text, "label": text, "kind": "placeholder", "akis": [], "tok": []}
	if item is Dictionary:
		var d: Dictionary = item as Dictionary
		var id: String = String(d.get("id", d.get("label", "")))
		if id.is_empty():
			return {}
		return {
			"id": id,
			"label": String(d.get("label", id)),
			"kind": String(d.get("kind", "placeholder")),
			"akis": (d.get("akis", []) as Array).duplicate(true) if d.get("akis", []) is Array else [],
			"tok": (d.get("tok", []) as Array).duplicate(true) if d.get("tok", []) is Array else [],
		}
	return {}


func _default_nodes() -> Array:
	return [
		{"id": "node:example_1", "label": "Nodo ejemplo A", "kind": "placeholder", "akis": ["input"], "tok": ["output"]},
		{"id": "node:example_2", "label": "Nodo ejemplo B", "kind": "placeholder", "akis": ["flow"], "tok": ["value"]},
	]


func _rebuild_browser() -> void:
	if _browser_list == null:
		return
	_browser_list.clear()
	for node_data: Dictionary in _nodes:
		_browser_list.add_item(String(node_data.get("label", node_data.get("id", "Nodo"))))
	_sync_browser_selection()


func _sync_browser_selection() -> void:
	if _browser_list == null:
		return
	_browser_list.deselect_all()
	for index: int in _nodes.size():
		if String(_nodes[index].get("id", "")) == _selected_node_id:
			_browser_list.select(index)
			_browser_list.ensure_current_is_visible()
			return


func _find_node(node_id: String) -> Dictionary:
	for node_data: Dictionary in _nodes:
		if String(node_data.get("id", "")) == node_id:
			return node_data
	return {}


func _on_browser_item_selected(index: int) -> void:
	if index < 0 or index >= _nodes.size():
		return
	select_node_by_id(String(_nodes[index].get("id", "")), true)


func _on_draft_changed(new_text: String) -> void:
	_draft_value = new_text


func _on_apply_edit_pressed() -> void:
	var node_data: Dictionary = _find_node(_selected_node_id)
	if node_data.is_empty():
		_set_status("Sin nodo seleccionado.")
		return
	# Signal-only communication: no chip contract mutation in this cycle.
	edit_requested.emit(_selected_node_id, "draft", _draft_value)
	_set_status("Solicitud de edición emitida (infraestructura).")


func _refresh_editor() -> void:
	if _editor_title == null or _editor_placeholder == null:
		return
	var node_data: Dictionary = _find_node(_selected_node_id)
	if node_data.is_empty():
		_editor_title.text = "Editor Akis/Tok"
		_editor_placeholder.text = "Selecciona un nodo para ver detalles.\nInfraestructura mínima: sin migración de chips ni cambios de contratos."
		return
	_editor_title.text = "Editor Akis/Tok — %s" % String(node_data.get("label", _selected_node_id))
	var lines: PackedStringArray = PackedStringArray()
	lines.append("ID: %s" % String(node_data.get("id", "")))
	lines.append("Tipo: %s" % String(node_data.get("kind", "")))
	lines.append("Akis: %s" % _format_list(node_data.get("akis", [])))
	lines.append("Tok: %s" % _format_list(node_data.get("tok", [])))
	lines.append("")
	lines.append("Edición real de contratos de chips diferida (primer ciclo: infraestructura/comunicación).")
	_editor_placeholder.text = "\n".join(lines)


func _format_list(value: Variant) -> String:
	if value is Array:
		var arr: Array = value as Array
		if arr.is_empty():
			return "(vacío)"
		var parts: PackedStringArray = PackedStringArray()
		for item: Variant in arr:
			parts.append(String(item))
		return ", ".join(parts)
	return "(vacío)"


func _set_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message
