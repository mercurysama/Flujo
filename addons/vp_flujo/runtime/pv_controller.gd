@tool
class_name PVController
extends Node

## Punto de entrada de VPFlujo para una escena.
## Actuará como fachada entre la escena y el futuro modelo visual.

signal visual_program_enabled_changed(is_enabled: bool)

@export var visual_program_enabled: bool = true:
	set(value):
		if visual_program_enabled == value:
			return
		visual_program_enabled = value
		visual_program_enabled_changed.emit(value)


func can_execute_visual_program() -> bool:
	return visual_program_enabled and is_inside_tree()

