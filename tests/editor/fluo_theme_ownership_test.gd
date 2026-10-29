@tool
extends SceneTree

const FLUO_DRAWER_SCRIPT: Script = preload("res://addons/vp_flujo/editor/fluo_drawer.gd")
const FLUO_THEME_SCRIPT: Script = preload("res://addons/vp_flujo/editor/fluo_theme.gd")

var _failures: Array[String] = []
var _drawer: Control


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	await _frames(2)
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame

	var helper_path: String = FLUO_THEME_SCRIPT.get_path()
	var helper_source: String = FileAccess.get_file_as_string(helper_path)
	var drawer_source: String = FileAccess.get_file_as_string("res://addons/vp_flujo/editor/fluo_drawer.gd")

	_check(
		helper_path.begins_with("res://addons/vp_flujo/editor/"),
		"FluoTheme is owned by the editor-side Fluo host."
	)
	_check(helper_source.begins_with("@tool"), "FluoTheme is an editor-only @tool script.")
	_check(
		not helper_source.contains("res://flow_packages/") \
			and not helper_source.contains("res://addons/"),
		"FluoTheme has no dependency toward external or package-owned presentation code."
	)
	_check(
		not helper_source.contains("Theme.new") \
			and not helper_source.contains("set_theme"),
		"FluoTheme does not install a global Theme."
	)

	var required_roles: Array[StringName] = [
		&"drawer_shell",
		&"drawer_panel",
		&"flow_row",
		&"flusso_field",
		&"button",
		&"diagnostic",
		&"selected",
		&"focused",
		&"selected_unfocused",
		&"disabled",
		&"error",
		&"warning",
	]
	var semantic_roles: Array[StringName] = FLUO_THEME_SCRIPT.semantic_roles()
	for role: StringName in required_roles:
		_check(semantic_roles.has(role), "FluoTheme owns the semantic role %s." % role)

	_check(
		not drawer_source.contains("StyleBoxFlat.new"),
		"fluo_drawer.gd no longer constructs DrawerPanel's StyleBoxFlat directly."
	)
	_check(
		drawer_source.contains("FluoTheme.apply_drawer_panel_style"),
		"fluo_drawer.gd delegates DrawerPanel styling to FluoTheme."
	)
	_check(
		not drawer_source.contains("Theme.new") \
			and not drawer_source.contains("set_theme"),
		"fluo_drawer.gd does not install a global Theme."
	)

	_drawer = FLUO_DRAWER_SCRIPT.new() as Control
	get_root().add_child(_drawer)
	await _frames(3)

	var panel: PanelContainer = _drawer.get_node("DrawerMotionShell/DrawerPanel") as PanelContainer
	var panel_style: StyleBoxFlat = panel.get_theme_stylebox(&"panel") as StyleBoxFlat
	var expected_style: StyleBoxFlat = FLUO_THEME_SCRIPT.create_drawer_panel_style()
	_check(panel != null, "DrawerPanel exists under the Fluo motion shell.")
	_check(panel_style != null, "DrawerPanel receives a StyleBoxFlat from the host helper.")
	if panel_style != null and expected_style != null:
		_check(
			_color_close(panel_style.bg_color, expected_style.bg_color),
			"DrawerPanel preserves the helper's current visual background color."
		)
		_check(
			_color_close(panel_style.bg_color, Color(0.08, 0.08, 0.10, 0.94)),
			"DrawerPanel preserves Color(0.08, 0.08, 0.10, 0.94)."
		)

	var helper_panel := PanelContainer.new()
	FLUO_THEME_SCRIPT.apply_drawer_panel_style(helper_panel)
	var helper_panel_style: StyleBoxFlat = helper_panel.get_theme_stylebox(&"panel") as StyleBoxFlat
	_check(
		helper_panel_style != null \
			and panel_style != null \
			and _color_close(helper_panel_style.bg_color, panel_style.bg_color),
		"DrawerPanel and the helper API resolve the same host-owned style."
	)
	_check(_drawer.theme == null, "FluoDrawer does not install a Theme resource globally.")
	_check(panel != null and panel.theme == null, "DrawerPanel keeps inherited editor theming instead of a global Theme.")

	helper_panel.free()
	if is_instance_valid(_drawer):
		_drawer.queue_free()
	await _frames(3)
	if _failures.is_empty():
		print("[Flujo] Fluo theme ownership test passed")
	quit(0 if _failures.is_empty() else 1)


func _color_close(first: Color, second: Color, tolerance: float = 0.0001) -> bool:
	return absf(first.r - second.r) <= tolerance \
		and absf(first.g - second.g) <= tolerance \
		and absf(first.b - second.b) <= tolerance \
		and absf(first.a - second.a) <= tolerance


func _frames(count: int = 3) -> void:
	for _index: int in count:
		await process_frame


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_failures.append(message)
		push_error(message)
	return condition
