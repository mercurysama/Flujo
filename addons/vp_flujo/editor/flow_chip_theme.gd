@tool
## Editor-owned Theme adapter for semantic chip roles.
class_name FlowChipTheme
extends RefCounted


## Semantic roles are resolved through the active Godot Theme. The control does
## not own a palette and runtime/model code never receives a concrete color.
static func apply_chip_style(
		control: Control,
		semantic_role: StringName,
		selected: bool,
		invalid: bool = false,
		locked: bool = false
) -> void:
	if not is_instance_valid(control):
		return
	control.add_theme_stylebox_override(
		&"panel",
		create_chip_style(control, semantic_role, selected, invalid, locked)
	)


static func create_chip_style(
		control: Control,
		semantic_role: StringName,
		selected: bool,
		invalid: bool = false,
		locked: bool = false
) -> StyleBoxFlat:
	var style: StyleBoxFlat = null
	var source: StyleBox = control.get_theme_stylebox(&"normal", &"Button")
	if source is StyleBoxFlat:
		style = source.duplicate() as StyleBoxFlat
	if style == null:
		style = StyleBoxFlat.new()

	var background: Color = style.bg_color
	if background.a <= 0.01:
		background = control.get_theme_color(&"base_color", &"LineEdit")
	if background.a <= 0.01:
		background = control.get_theme_color(&"accent_color", &"Editor")
	background.a = 1.0
	style.bg_color = background

	var accent: Color = _role_color(control, semantic_role)
	if accent.a <= 0.01:
		accent = control.get_theme_color(&"font_color", &"Button")
	accent.a = 1.0
	if invalid:
		var error_color: Color = control.get_theme_color(&"error_color", &"Editor")
		if error_color.a > 0.01:
			accent = error_color
	elif locked:
		var disabled_color: Color = control.get_theme_color(&"font_disabled_color", &"Editor")
		if disabled_color.a > 0.01:
			accent = disabled_color
	style.border_color = accent.lightened(0.12) if selected else accent
	var border_width: int = 2 if selected else 1
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_right = 3
	style.corner_radius_bottom_left = 3
	style.content_margin_left = 5.0
	style.content_margin_top = 2.0
	style.content_margin_right = 5.0
	style.content_margin_bottom = 2.0
	return style


static func _role_color(control: Control, semantic_role: StringName) -> Color:
	var color_name: StringName = StringName("chip_%s_color" % String(semantic_role))
	if control.has_theme_color(color_name, &"FlowChipControl"):
		return control.get_theme_color(color_name, &"FlowChipControl")
	if semantic_role == &"variable" and control.has_theme_color(&"link_color", &"Editor"):
		return control.get_theme_color(&"link_color", &"Editor")
	return control.get_theme_color(&"accent_color", &"Editor")
