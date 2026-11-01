class_name FlowFSMDynamicStateRecord
extends RefCounted

## Runtime metadata only; never an authored FlowGraph Resource.
enum Lifetime { EPHEMERAL, SESSION, PERSISTENT }

var runtime_id: String
var template_state_id: String
var lifetime: Lifetime
var data: Dictionary


func _init(
		new_runtime_id: String = "",
		new_template_id: String = "",
		new_lifetime: Lifetime = Lifetime.EPHEMERAL,
		new_data: Dictionary = {}
) -> void:
	runtime_id = new_runtime_id
	template_state_id = new_template_id
	lifetime = new_lifetime
	data = new_data.duplicate(true)


static func is_valid_lifetime(candidate: int) -> bool:
	return candidate in [Lifetime.EPHEMERAL, Lifetime.SESSION, Lifetime.PERSISTENT]
