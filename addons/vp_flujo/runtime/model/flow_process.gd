class_name FlowProcess
extends FlowBlockContainer

enum ProcessType {
	READY,
	PROCESS,
	PHYSICS_PROCESS,
	INPUT,
	UNHANDLED_INPUT,
}

@export var process_type: ProcessType = ProcessType.READY

func _init() -> void:
	display_name = "_ready"

func duplicate_process_with_new_ids() -> FlowProcess:
	return duplicate_with_new_ids() as FlowProcess
