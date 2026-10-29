@tool
class_name FluoTheme
extends RefCounted

## Host-owned semantic presentation boundary for the Fluo editor surface.
##
## This helper intentionally does not install a Theme resource. Fluo controls
## keep inheriting the active Godot editor theme, while host-owned semantic
## roles provide a stable place for later presentation work.

const ROLE_DRAWER_SHELL: StringName = &"drawer_shell"
const ROLE_DRAWER_PANEL: StringName = &"drawer_panel"
const ROLE_FLOW_ROW: StringName = &"flow_row"
const ROLE_FLUSSO_FIELD: StringName = &"flusso_field"
const ROLE_BUTTON: StringName = &"button"
const ROLE_DIAGNOSTIC: StringName = &"diagnostic"
const ROLE_SELECTED: StringName = &"selected"
const ROLE_FOCUSED: StringName = &"focused"
const ROLE_SELECTED_UNFOCUSED: StringName = &"selected_unfocused"
const ROLE_DISABLED: StringName = &"disabled"
const ROLE_ERROR: StringName = &"error"
const ROLE_WARNING: StringName = &"warning"

## Existing Fluo DrawerPanel appearance. D2-B2 moves ownership without
## intentionally changing the preview surface.
const DRAWER_PANEL_BACKGROUND: Color = Color(0.08, 0.08, 0.10, 0.94)


static func semantic_roles() -> Array[StringName]:
	return [
		ROLE_DRAWER_SHELL,
		ROLE_DRAWER_PANEL,
		ROLE_FLOW_ROW,
		ROLE_FLUSSO_FIELD,
		ROLE_BUTTON,
		ROLE_DIAGNOSTIC,
		ROLE_SELECTED,
		ROLE_FOCUSED,
		ROLE_SELECTED_UNFOCUSED,
		ROLE_DISABLED,
		ROLE_ERROR,
		ROLE_WARNING,
	]


static func create_drawer_panel_style() -> StyleBoxFlat:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = DRAWER_PANEL_BACKGROUND
	return panel_style


static func apply_drawer_panel_style(panel: PanelContainer) -> void:
	if not is_instance_valid(panel):
		return
	panel.add_theme_stylebox_override(&"panel", create_drawer_panel_style())
