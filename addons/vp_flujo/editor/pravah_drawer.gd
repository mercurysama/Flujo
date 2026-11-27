@tool
class_name PravahDrawer
extends FlowDrawerHost

## Bottom drawer host for future Pravah tools. Starts empty by design.


func _init() -> void:
	super._init()
	name = "PravahDrawer"
	slide_direction = SlideDirection.BOTTOM
	panel_ratio = 0.5


func get_drawer_title() -> String:
	return "Pravah"
