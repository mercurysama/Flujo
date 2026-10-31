@tool
## Native LineEdit marker used by the Akis editor.
class_name FlowChipLineEdit
extends LineEdit

## History shortcuts are intercepted by FlowChipFieldEditor._input(), before
## this native control's GUI input phase. The override handles only the
## document shortcut and never calls super._gui_input(), which Godot 4.7 does
## not expose for this native parent. All other events keep LineEdit's native
## text editing, caret, selection, paste, and navigation behavior.


func _gui_input(event: InputEvent) -> void:
	if _is_history_shortcut(event):
		accept_event()


func _is_history_shortcut(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var key: InputEventKey = event as InputEventKey
	if not key.pressed or key.echo or not key.ctrl_pressed:
		return false
	var is_z: bool = key.keycode == KEY_Z or key.physical_keycode == KEY_Z
	var is_y: bool = key.keycode == KEY_Y or key.physical_keycode == KEY_Y
	return is_z or (is_y and not key.shift_pressed)
