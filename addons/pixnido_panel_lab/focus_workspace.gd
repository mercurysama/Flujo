@tool
extends PanelContainer

## NidoLab Focus: opaque, full-editor overlay owned by this optional addon.
## Only addon-owned PixNido/References widgets are reparented; Godot's UI
## remains structurally untouched and is recovered by closing this Control.

signal exit_requested
signal pane_visibility_changed(panel: StringName, visible: bool)
signal swap_requested
signal add_reference_requested

var _split: HBoxContainer
var _pix_pane: PanelContainer
var _refs_pane: PanelContainer
var _pix_mount: VBoxContainer
var _refs_mount: VBoxContainer
var _pix_placeholder: CenterContainer
var _refs_placeholder: CenterContainer
var _pix_toggle: Button
var _refs_toggle: Button

var _pix_body: Control
var _refs_body: Control
var _pix_home: Node
var _refs_home: Node
var _pix_open: bool = true
var _refs_open: bool = false
var _swapped: bool = false
var _attached: bool = false


func _init() -> void:
	name = "NidoLabFocusWorkspace"
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.09, 0.10, 0.12, 1.0)
	background.content_margin_left = 10.0
	background.content_margin_right = 10.0
	background.content_margin_top = 8.0
	background.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", background)
	_build_ui()


func attach_contents(pix: Control, references: Control, pix_open: bool, references_open: bool, swapped: bool) -> bool:
	if _attached or not is_instance_valid(pix) or not is_instance_valid(references):
		return false
	if pix.get_parent() == null or references.get_parent() == null:
		return false
	_pix_body = pix
	_refs_body = references
	_pix_home = pix.get_parent()
	_refs_home = references.get_parent()
	_pix_body.reparent(_pix_mount, false)
	_refs_body.reparent(_refs_mount, false)
	_attached = true
	set_pane_visibility(&"pixnido", pix_open)
	set_pane_visibility(&"references", references_open)
	set_swapped(swapped)
	return true


func restore_contents() -> void:
	if not _attached:
		return
	# These controls belong to the original addon docks, not to the overlay.
	if is_instance_valid(_pix_body) and is_instance_valid(_pix_home):
		_pix_body.reparent(_pix_home, false)
		_pix_body.show()
	if is_instance_valid(_refs_body) and is_instance_valid(_refs_home):
		_refs_body.reparent(_refs_home, false)
		_refs_body.show()
	_pix_body = null
	_refs_body = null
	_pix_home = null
	_refs_home = null
	_attached = false


func set_pane_visibility(panel: StringName, is_open: bool) -> void:
	if panel == &"pixnido":
		_pix_open = is_open
		if is_instance_valid(_pix_body):
			_pix_body.visible = is_open
		_pix_placeholder.visible = not is_open
		_pix_toggle.text = "Hide" if is_open else "Show"
	elif panel == &"references":
		_refs_open = is_open
		if is_instance_valid(_refs_body):
			_refs_body.visible = is_open
		_refs_placeholder.visible = not is_open
		_refs_toggle.text = "Hide" if is_open else "Show"


func set_swapped(swapped: bool) -> void:
	_swapped = swapped
	if _swapped:
		_split.move_child(_refs_pane, 0)
	else:
		_split.move_child(_pix_pane, 0)


func get_pane_widths() -> Vector2:
	# Useful for a focused layout regression without accessing editor internals.
	return Vector2(_pix_pane.size.x, _refs_pane.size.x)


func is_attached() -> bool:
	return _attached


func _build_ui() -> void:
	var shell := VBoxContainer.new()
	shell.name = "WorkspaceLayout"
	shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(shell)

	var header := HBoxContainer.new()
	header.name = "FocusHeader"
	shell.add_child(header)

	var heading := Label.new()
	heading.name = "Title"
	heading.text = "NidoLab  |  Pixel art workspace"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.clip_text = true
	header.add_child(heading)

	var swap_button := Button.new()
	swap_button.name = "SwapPanels"
	swap_button.text = "Swap"
	swap_button.tooltip_text = "Swap PixNido and References without losing their content"
	swap_button.pressed.connect(func() -> void: swap_requested.emit())
	header.add_child(swap_button)

	var exit_button := Button.new()
	exit_button.name = "BackToGodot"
	exit_button.text = "Back to Godot"
	exit_button.tooltip_text = "Return to Godot (Ctrl+Alt+N)"
	exit_button.focus_mode = Control.FOCUS_ALL
	exit_button.pressed.connect(func() -> void: exit_requested.emit())
	header.add_child(exit_button)

	_split = HBoxContainer.new()
	_split.name = "FocusColumns"
	_split.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_split.add_theme_constant_override("separation", 8)
	shell.add_child(_split)

	_pix_pane = _make_pane("PixNido", 1.0)
	_pix_pane.name = "PixNidoColumn"
	_split.add_child(_pix_pane)
	_refs_pane = _make_pane("References", 2.0)
	_refs_pane.name = "ReferencesColumn"
	_split.add_child(_refs_pane)

	_pix_mount = _make_mount(_pix_pane, &"pixnido")
	_refs_mount = _make_mount(_refs_pane, &"references")


func _make_pane(title_text: String, stretch: float) -> PanelContainer:
	var pane := PanelContainer.new()
	pane.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pane.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pane.size_flags_stretch_ratio = stretch
	pane.custom_minimum_size = Vector2.ZERO
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.14, 0.15, 0.18, 1.0)
	panel_style.content_margin_left = 4.0
	panel_style.content_margin_right = 4.0
	panel_style.content_margin_top = 4.0
	panel_style.content_margin_bottom = 4.0
	pane.add_theme_stylebox_override("panel", panel_style)
	pane.set_meta(&"label", title_text)
	return pane


func _make_mount(pane: PanelContainer, panel_id: StringName) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pane.add_child(column)

	var header := HBoxContainer.new()
	header.name = "PaneHeader"
	column.add_child(header)

	var caption := Label.new()
	caption.text = String(pane.get_meta(&"label"))
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(caption)

	if panel_id == &"references":
		var add_button := Button.new()
		add_button.text = "+"
		add_button.name = "AddReference"
		add_button.tooltip_text = "Add reference images"
		add_button.pressed.connect(func() -> void: add_reference_requested.emit())
		header.add_child(add_button)

	var toggle := Button.new()
	toggle.name = "TogglePane"
	toggle.text = "Hide"
	toggle.tooltip_text = "Hide or show this panel in NidoLab"
	toggle.pressed.connect(_on_pane_toggle.bind(panel_id))
	header.add_child(toggle)

	var mount := VBoxContainer.new()
	mount.name = "PaneBody"
	mount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mount.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(mount)

	var placeholder := CenterContainer.new()
	placeholder.name = "HiddenPane"
	placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	placeholder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mount.add_child(placeholder)
	var restore_button := Button.new()
	restore_button.text = "Show " + String(pane.get_meta(&"label"))
	restore_button.pressed.connect(_on_pane_toggle.bind(panel_id))
	placeholder.add_child(restore_button)
	if panel_id == &"pixnido":
		_pix_placeholder = placeholder
		_pix_toggle = toggle
	else:
		_refs_placeholder = placeholder
		_refs_toggle = toggle
	return mount


func _on_pane_toggle(panel: StringName) -> void:
	var opening: bool = not (_pix_open if panel == &"pixnido" else _refs_open)
	set_pane_visibility(panel, opening)
	pane_visibility_changed.emit(panel, opening)
