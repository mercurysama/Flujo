@tool
extends SceneTree

## Headless NidoLab tabs and stored note/task behavior (no native Servo needed).
const HUB := preload("res://addons/pixnido_panel_lab/reference_hub.gd")


func _initialize() -> void:
	call_deferred(&"_check")


func _check() -> void:
	var failures: Array[String] = []
	var hub: TabContainer = HUB.new()
	root.add_child(hub)
	hub.size = Vector2(760, 480)
	await process_frame

	if hub.get_tab_count() != 3:
		failures.append("Expected exactly Images, Notes, Tasks tabs")
	for i in range(3):
		if hub.get_tab_title(i).length() > 1:
			failures.append("Tab " + str(i) + " is not icon-only")

	var original_images: Dictionary = hub.call(&"get_images_state")
	hub.call(&"set_active_section", 1)
	hub.call(&"add_for_current_tab")
	var notes: Dictionary = hub.call(&"get_notes_state")
	var note_items: Array = notes.get("items", [])
	if note_items.size() != 1:
		failures.append("Adding a text note failed")
	else:
		var first_note: Dictionary = note_items[0]
		first_note["text"] = "Idea: sprite walking north"
		first_note["x"] = 55.0
		first_note["w"] = 260.0
		note_items[0] = first_note
		notes["items"] = note_items
		hub.call(&"set_notes_state", notes)
		notes = hub.call(&"get_notes_state")
		if (notes.get("items", []) as Array)[0].get("text") != "Idea: sprite walking north":
			failures.append("Note content did not survive serialization")

	hub.call(&"set_active_section", 2)
	var task_list: Node = hub.get_node("TaskChecklist")
	task_list.call(&"add_task", "Draw walking sprite", false)
	task_list.call(&"add_task", "Make run cycle", false)
	task_list.call(&"add_task", "Export sprite sheet", false)
	task_list.call(&"set_task_complete", "task_2", true)
	task_list.call(&"reorder_task", "task_3", "task_1", true)
	var tasks: Dictionary = hub.call(&"get_tasks_state")
	var list: Array = tasks.get("items", [])
	if list.size() != 3:
		failures.append("Adding tasks failed")
	else:
		if list[0].get("id") != "task_3" or list[1].get("id") != "task_1":
			failures.append("Drag reordering model failed")
		if not bool(list[2].get("completed", false)):
			failures.append("Completed checkbox state was not saved")
		var row: Node = task_list.get_node("TaskScroll/TaskItems/TaskRow_task_1")
		var source: Control = row.get_node("HBoxContainer/DragTask")
		var data: Variant = source.call(&"_get_drag_data", Vector2.ZERO)
		var target: Node = task_list.get_node("TaskScroll/TaskItems/TaskRow_task_2")
		if not data is Dictionary or not bool(target.call(&"_can_drop_data", Vector2(3, 3), data)):
			failures.append("Native drag-and-drop payload was rejected")

	var hub_2: TabContainer = HUB.new()
	root.add_child(hub_2)
	hub_2.size = Vector2(760, 480)
	hub_2.call(&"set_images_state", original_images)
	hub_2.call(&"set_notes_state", notes)
	hub_2.call(&"set_tasks_state", tasks)
	hub_2.call(&"set_active_section", 2)
	await process_frame
	if hub_2.call(&"get_images_state") != original_images:
		failures.append("Legacy image-reference data was modified")
	if hub_2.call(&"get_notes_state") != notes:
		failures.append("Note data did not survive reopen")
	if hub_2.call(&"get_tasks_state") != tasks:
		failures.append("Task order/text/completion did not survive reopen")
	if int(hub_2.call(&"current_section")) != 2:
		failures.append("Last active tab not restored")

	hub.queue_free()
	hub_2.queue_free()
	await process_frame
	if failures.is_empty():
		print("[NidoLab] References tabs smoke test passed")
		quit(0)
	else:
		for problem in failures:
			printerr("[NidoLab] " + problem)
		quit(1)
