@tool
class_name FlowCustomHelloBlock
extends FlowOutputBlock

const MESSAGE: String = "Hola desde un bloque personalizado"


func _init() -> void:
	display_name = "Custom Hello"


func get_output_message() -> String:
	return MESSAGE
