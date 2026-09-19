@tool
class_name FlowReferenceDefinition
extends Resource

enum TargetKind { ATTRIBUTE, REQUIREMENT, METHOD }

@export_storage var _internal_id: String = FlowId.create()
@export_storage var target_id: String = ""
@export_storage var target_class_id: String = ""
@export_storage var expected_kind: TargetKind = TargetKind.ATTRIBUTE

func get_internal_id() -> String:
	return _internal_id
