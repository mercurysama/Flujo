@tool
extends FlowOutputBlock

@export_multiline var message: String = ""


func _init() -> void:
	display_name = "FLog"


func get_output_message() -> String:
	return message
