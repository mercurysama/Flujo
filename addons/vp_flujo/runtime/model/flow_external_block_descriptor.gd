@tool
class_name FlowExternalBlockDescriptor
extends RefCounted

## In-memory projection of one v1 external block manifest entry.
## The future package loader owns JSON parsing and script loading; this value
## object deliberately performs neither operation.

var package_id: String = ""
var type_id: String = ""
var script_path: String = ""
var display_name: String = ""


func _init(
		new_package_id: String = "",
		new_type_id: String = "",
		new_script_path: String = "",
		new_display_name: String = ""
) -> void:
	package_id = new_package_id.strip_edges()
	type_id = new_type_id.strip_edges()
	script_path = new_script_path.strip_edges()
	display_name = new_display_name.strip_edges()


func global_type_id() -> String:
	return "%s:%s" % [package_id, type_id]


func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if package_id.is_empty():
		errors.append("empty_package_id")
	if type_id.is_empty():
		errors.append("empty_type_id")
	if script_path.is_empty():
		errors.append("empty_script_path")
	if display_name.is_empty():
		errors.append("empty_display_name")
	return errors


func is_valid() -> bool:
	return validation_errors().is_empty()
