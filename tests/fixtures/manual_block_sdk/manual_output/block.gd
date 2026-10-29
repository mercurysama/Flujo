@tool
extends FlowOutputBlock

@export var message: String = "Hello from the manual SDK"


func get_output_message() -> String:
	return message
