@tool
## Runtime-safe structured tooltip data for one semantic chip.
class_name FlowChipTooltipData
extends RefCounted


const FIELD_LABEL_KEY: String = "label"
const FIELD_VALUE_KEY: String = "value"


## Short title/type heading. The host decides how to present it.
var title: String = ""
## Ordered, UI-neutral label/value rows.
var fields: Array[Dictionary] = []


func _init(new_title: String = "") -> void:
	title = new_title


func add_field(label: String, value: String) -> void:
	fields.append({
		FIELD_LABEL_KEY: label,
		FIELD_VALUE_KEY: value,
	})


func get_field(index: int) -> Dictionary:
	if index < 0 or index >= fields.size():
		return {}
	return fields[index]
