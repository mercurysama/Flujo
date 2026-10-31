@tool
## One stable String-keyed entry owned by FlowDictionaryValueSource.
class_name FlowDictionaryEntry
extends Resource


@export_storage var entry_id: String = FlowId.create()
@export_storage var key: String = ""
@export_storage var value_source: FlowValueSource


func _init(new_key: String = "", new_value_source: FlowValueSource = null) -> void:
	key = new_key
	value_source = new_value_source


func duplicate_with_new_id() -> FlowDictionaryEntry:
	var copy: FlowDictionaryEntry = duplicate(false) as FlowDictionaryEntry
	copy.entry_id = FlowId.create()
	copy.value_source = value_source.duplicate_with_new_id() 		if value_source != null else null
	return copy
