@tool
## Native TextEdit marker used by the Akis editor.
class_name FlowChipTextEdit
extends TextEdit

## History shortcuts are intercepted by FlowChipFieldEditor._input(), before
## this native control's GUI input phase. The override below handles only the
## document shortcut; all other events keep TextEdit's built-in typing, caret,
## selection, navigation, paste, and multiline behavior. Godot 4.7 has no
## script parent implementation that can be called with super._gui_input().


func _gui_input(event: InputEvent) -> void:
	if _is_history_shortcut(event):
		# The Akis action already ran in the owner _input() phase. This is only
		# the native Control boundary that prevents TextEdit's local history from
		# consuming the same shortcut. Never call super._gui_input() in Godot 4.7.
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
