@tool
## Drag source used by FlowSceneNodePanel.
class_name FlowSceneNodeTree
extends Tree


signal node_payload_activated(payload: Dictionary)


func _init() -> void:
	item_activated.connect(_on_item_activated)


func _get_drag_data(at_position: Vector2) -> Variant:
	var item: TreeItem = get_item_at_position(at_position)
	if item == null:
		return null
	var payload: Variant = item.get_metadata(0)
	if not payload is Dictionary:
		return null
	var data: Dictionary = (payload as Dictionary).duplicate(true)
	if String(data.get("type", "")) != "flujo_scene_node":
		return null
	var preview: Label = Label.new()
	preview.text = "  %s  " % String(data.get("node_name", "Node"))
	set_drag_preview(preview)
	return data


func _on_item_activated() -> void:
	var item: TreeItem = get_selected()
	if item == null:
		return
	var payload: Variant = item.get_metadata(0)
	if payload is Dictionary 			and String((payload as Dictionary).get("type", "")) == "flujo_scene_node":
		node_payload_activated.emit((payload as Dictionary).duplicate(true))
