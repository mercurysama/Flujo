@tool
class_name FlowDrawerHost
extends Control

## Generic sliding drawer host for editor-only Flujo tools.
## Mounts independent workspace instances without knowing their internal logic.
## Panel geometry is computed in host-local coordinates (host is full-rect overlay).

enum SlideDirection {
	TOP,
	BOTTOM,
	LEFT,
	RIGHT,
}

signal opened
signal closed
signal instance_mounted(instance: Control)
signal instance_unmounted(instance: Control)

@export var slide_direction: SlideDirection = SlideDirection.TOP
@export var panel_ratio: float = 0.5
@export var animation_duration: float = 0.18

var _panel: PanelContainer
var _panel_root: VBoxContainer
var _header: HBoxContainer
var _title_label: Label
var _close_button: Button
var _mount_container: BoxContainer
var _is_open: bool = false
var _is_animating: bool = false
var _tween: Tween


func _init() -> void:
	name = "FlowDrawerHost"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_build_host()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_apply_layout()
	_apply_closed_transform(false)


func _is_vertical_edge() -> bool:
	return slide_direction == SlideDirection.TOP or slide_direction == SlideDirection.BOTTOM


func _is_lateral() -> bool:
	return slide_direction == SlideDirection.LEFT or slide_direction == SlideDirection.RIGHT


func _build_host() -> void:
	_panel = PanelContainer.new()
	_panel.name = &"DrawerPanel"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.clip_contents = true
	_apply_opaque_panel_style()
	add_child(_panel)

	_panel_root = VBoxContainer.new()
	_panel_root.name = &"PanelRoot"
	_panel_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_panel_root.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel.add_child(_panel_root)

	_header = HBoxContainer.new()
	_header.name = &"DrawerHeader"
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.mouse_filter = Control.MOUSE_FILTER_PASS
	_panel_root.add_child(_header)

	_title_label = Label.new()
	_title_label.name = &"DrawerTitle"
	_title_label.text = get_drawer_title()
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header.add_child(_title_label)

	_close_button = Button.new()
	_close_button.name = &"CloseDrawerButton"
	_close_button.text = "Cerrar"
	_close_button.tooltip_text = "Cerrar drawer"
	_close_button.focus_mode = Control.FOCUS_NONE
	_close_button.pressed.connect(_on_close_button_pressed)
	_header.add_child(_close_button)

	if _is_lateral():
		_mount_container = VBoxContainer.new()
	else:
		_mount_container = HBoxContainer.new()
	_mount_container.name = &"MountContainer"
	_mount_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mount_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_mount_container.mouse_filter = Control.MOUSE_FILTER_PASS
	_mount_container.add_theme_constant_override("separation", 8)
	_panel_root.add_child(_mount_container)


func _apply_opaque_panel_style() -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.16, 0.18, 1.0)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.35, 0.35, 0.4, 1.0)
	style.content_margin_left = 8
	style.content_margin_top = 6
	style.content_margin_right = 8
	style.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", style)


func get_mount_container() -> Container:
	return _mount_container


func mount_instance(instance: Control) -> bool:
	if instance == null or not is_instance_valid(instance):
		return false
	if instance.get_parent() == _mount_container:
		_configure_mounted_instance(instance)
		return true
	if instance.get_parent() != null:
		instance.get_parent().remove_child(instance)
	_configure_mounted_instance(instance)
	_mount_container.add_child(instance)
	if instance.has_method(&"activate"):
		instance.call(&"activate", _build_workspace_context())
	instance_mounted.emit(instance)
	return true


func _configure_mounted_instance(instance: Control) -> void:
	instance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	instance.size_flags_vertical = Control.SIZE_EXPAND_FILL


func unmount_instance(instance: Control) -> bool:
	if instance == null or not is_instance_valid(instance):
		return false
	if not has_instance(instance):
		return false
	if instance.has_method(&"deactivate"):
		instance.call(&"deactivate")
	if instance.get_parent() == _mount_container:
		_mount_container.remove_child(instance)
	if is_instance_valid(instance):
		instance.queue_free()
	instance_unmounted.emit(instance)
	return true


func clear_instances() -> void:
	if _mount_container == null:
		return
	var children: Array = _mount_container.get_children()
	for child: Node in children:
		var control: Control = child as Control
		if control != null:
			unmount_instance(control)
		else:
			_mount_container.remove_child(child)
			child.queue_free()


func has_instance(instance: Control) -> bool:
	return instance != null and is_instance_valid(instance) \
		and instance.get_parent() == _mount_container


func open() -> void:
	if _is_open and not _is_animating:
		_sync_title()
		_apply_layout()
		_panel.position = _open_panel_position()
		return
	_kill_tween()
	_sync_title()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_layout()
	_panel.position = _closed_panel_position()
	_is_open = true
	_is_animating = true
	move_to_front()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_panel, "position", _open_panel_position(), animation_duration)
	_tween.finished.connect(_on_open_finished, CONNECT_ONE_SHOT)


func close() -> void:
	if not _is_open and not _is_animating:
		_release_input_capture()
		return
	_kill_tween()
	_is_open = false
	_is_animating = true
	_apply_layout()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.tween_property(_panel, "position", _closed_panel_position(), animation_duration)
	_tween.finished.connect(_on_close_finished, CONNECT_ONE_SHOT)


func toggle() -> void:
	if is_open():
		close()
	else:
		open()


func is_open() -> bool:
	return _is_open


func get_drawer_title() -> String:
	return name


func set_drawer_title(title: String) -> void:
	if _title_label != null:
		_title_label.text = title


func _sync_title() -> void:
	if _title_label != null:
		_title_label.text = get_drawer_title()


func _on_close_button_pressed() -> void:
	close()


func _build_workspace_context() -> Dictionary:
	return {
		"host": self,
		"mount_container": _mount_container,
		"direction": slide_direction,
	}


func _on_open_finished() -> void:
	_is_animating = false
	if _is_open:
		_apply_layout()
		_panel.position = _open_panel_position()
		opened.emit()


func _on_close_finished() -> void:
	_is_animating = false
	_apply_layout()
	_panel.position = _closed_panel_position()
	_release_input_capture()
	_on_after_closed()
	closed.emit()


func _release_input_capture() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _panel != null:
		_panel.mouse_filter = Control.MOUSE_FILTER_STOP


func _on_after_closed() -> void:
	pass


func _host_size_for_layout() -> Vector2:
	var host_size: Vector2 = size
	if host_size.x <= 0.0 or host_size.y <= 0.0:
		host_size = get_viewport_rect().size
	return host_size


func _panel_extent_for_layout() -> float:
	var host_size: Vector2 = _host_size_for_layout()
	var full_extent: float = host_size.y if _is_vertical_edge() else host_size.x
	return maxf(120.0, full_extent * clampf(panel_ratio, 0.1, 0.95))


func _open_panel_position() -> Vector2:
	var host_size: Vector2 = _host_size_for_layout()
	var extent: float = _panel_extent_for_layout()
	match slide_direction:
		SlideDirection.TOP:
			return Vector2(0.0, 0.0)
		SlideDirection.BOTTOM:
			return Vector2(0.0, maxf(0.0, host_size.y - extent))
		SlideDirection.LEFT:
			return Vector2(0.0, 0.0)
		SlideDirection.RIGHT:
			return Vector2(maxf(0.0, host_size.x - extent), 0.0)
	return Vector2.ZERO


func _closed_panel_position() -> Vector2:
	var host_size: Vector2 = _host_size_for_layout()
	var extent: float = _panel_extent_for_layout()
	match slide_direction:
		SlideDirection.TOP:
			return Vector2(0.0, -extent)
		SlideDirection.BOTTOM:
			return Vector2(0.0, host_size.y)
		SlideDirection.LEFT:
			return Vector2(-extent, 0.0)
		SlideDirection.RIGHT:
			return Vector2(host_size.x, 0.0)
	return Vector2.ZERO


func _apply_layout() -> void:
	if _panel == null:
		return
	var host_size: Vector2 = _host_size_for_layout()
	var extent: float = _panel_extent_for_layout()
	var panel_size: Vector2
	if _is_vertical_edge():
		panel_size = Vector2(host_size.x, extent)
	else:
		panel_size = Vector2(extent, host_size.y)
	# Explicit host-local geometry.
	_panel.anchor_left = 0.0
	_panel.anchor_top = 0.0
	_panel.anchor_right = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left = 0.0
	_panel.offset_top = 0.0
	_panel.offset_right = panel_size.x
	_panel.offset_bottom = panel_size.y
	if _is_open and not _is_animating:
		_panel.position = _open_panel_position()
	elif not _is_open and not _is_animating:
		_panel.position = _closed_panel_position()


func _apply_closed_transform(immediate_show: bool) -> void:
	_apply_layout()
	if _panel != null:
		_panel.position = _closed_panel_position()
	if immediate_show:
		visible = true
		mouse_filter = Control.MOUSE_FILTER_IGNORE


func _kill_tween() -> void:
	if _tween != null and is_instance_valid(_tween):
		_tween.kill()
	_tween = null
	_is_animating = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_on_host_resized()


func _on_host_resized() -> void:
	if _panel == null:
		return
	_apply_layout()
	if _is_open and not _is_animating:
		_panel.position = _open_panel_position()
	elif not _is_open and not _is_animating:
		_panel.position = _closed_panel_position()
	else:
		_panel.position = _open_panel_position() if _is_open else _closed_panel_position()
