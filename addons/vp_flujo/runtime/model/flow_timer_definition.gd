@tool
class_name FlowTimerDefinition
extends FlowProcess

@export var interval_seconds: float = 1.0
@export var repeat: bool = false


func _init() -> void:
	process_type = ProcessType.TIMER
	display_name = "Timer"


func has_valid_interval() -> bool:
	return is_finite(interval_seconds) and interval_seconds > 0.0
