@tool
class_name FlowDrawerWorkspace
extends VBoxContainer

## Lightweight base contract for tool workspaces mounted into FlowDrawerHost.

signal close_requested
signal title_changed(new_title: String)

var workspace_title: String = "Workspace":
	set(value):
		if workspace_title == value:
			return
		workspace_title = value
		title_changed.emit(workspace_title)


func activate(_context: Dictionary = {}) -> void:
	pass


func deactivate() -> void:
	pass


func capture_state() -> Variant:
	return null


func restore_state(_state: Variant) -> void:
	pass


func request_close() -> void:
	close_requested.emit()
