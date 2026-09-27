@tool
class_name FlowPrintBlock
extends FlowOutputBlock

@export_multiline var text: String = ""


func _init() -> void:
	display_name = "Print"


func get_output_message() -> String:
	return text
