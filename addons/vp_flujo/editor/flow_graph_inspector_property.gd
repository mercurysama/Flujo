@tool
class_name FlowGraphInspectorProperty
extends EditorProperty


var _content: VBoxContainer


func _init() -> void:
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 6)
	add_child(_content)


func update_property() -> void:
	var controller: PVController = get_edited_object() as PVController
	var graph: FlowGraph = null
	if controller != null:
		graph = controller.flow_graph
	_render(FlowGraphInspectorPresenter.present(graph))


func _render(presentation: Dictionary) -> void:
	for child: Node in _content.get_children():
		child.queue_free()

	var summary: Label = Label.new()
	summary.text = "Schema %s — Active source: %s" % [
		presentation["schema_version"],
		presentation["active_source"],
	]
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(summary)

	var sections: Array = presentation["sections"] as Array
	for section: Dictionary in sections:
		_render_section(section)

	var diagnostics: Array = presentation["diagnostics"] as Array
	if not diagnostics.is_empty():
		var diagnostics_title: Label = Label.new()
		diagnostics_title.text = "Diagnostics"
		diagnostics_title.add_theme_font_size_override("font_size", 14)
		_content.add_child(diagnostics_title)
		for diagnostic: Dictionary in diagnostics:
			var diagnostic_label: Label = Label.new()
			diagnostic_label.text = "%s: %s (%s)" % [
				_severity_name(diagnostic["severity"]),
				diagnostic["message"],
				diagnostic["element_path"],
			]
			diagnostic_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_content.add_child(diagnostic_label)


func _render_section(section: Dictionary) -> void:
	var title: Label = Label.new()
	title.text = section["title"]
	title.add_theme_font_size_override("font_size", 14)
	_content.add_child(title)

	var list: ItemList = ItemList.new()
	list.select_mode = ItemList.SELECT_SINGLE
	list.allow_reselect = true
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var entries: Array = section["entries"] as Array
	for entry: Dictionary in entries:
		var item_index: int = list.add_item(_format_entry(entry))
		list.set_item_metadata(item_index, entry)
	_content.add_child(list)


func _format_entry(entry: Dictionary) -> String:
	var internal_id: String = entry["internal_id"]
	var id_text: String = "No ID" if internal_id.is_empty() else "ID: %s" % internal_id
	return "[%d] %s — %s\n%s" % [
		entry["index"],
		entry["type"],
		entry["name"],
		id_text,
	]


func _severity_name(severity: int) -> String:
	if severity == FlowDiagnostic.Severity.ERROR:
		return "Error"
	if severity == FlowDiagnostic.Severity.WARNING:
		return "Warning"
	return "Info"
