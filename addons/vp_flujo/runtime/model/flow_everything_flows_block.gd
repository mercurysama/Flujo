@tool
class_name FlowEverythingFlowsBlock
extends FlowOutputBlock


func _init() -> void:
	display_name = "Everything Flows"


func get_output_message() -> String:
	return "Todo es Flujo; todo fluye."
