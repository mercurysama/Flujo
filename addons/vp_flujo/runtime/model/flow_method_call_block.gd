@tool
class_name FlowMethodCallBlock
extends FlowBlock


@export_storage var method_id: String = ""
## Schema 5 only. Schemas 1–4 retain method_id; never synchronize the two.
@export_storage var method_reference: FlowMethodReferenceDefinition


func _init() -> void:
	display_name = "Call Method"


func duplicate_with_new_id() -> FlowBlock:
	if method_reference != null:
		return FlowSchema5Model.duplicate_owned(self) as FlowMethodCallBlock
	var copy: FlowMethodCallBlock = duplicate(false) as FlowMethodCallBlock
	copy._internal_id = FlowId.create()
	return copy
