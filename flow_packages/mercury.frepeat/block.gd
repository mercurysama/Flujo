@tool
extends FlowOutputBlock

@export_multiline var message: String = ""
@export var count: int = 1


func _init() -> void:
	display_name = "FRepeat"


func get_output_message() -> String:
	return message.repeat(maxi(count, 1))
