class_name FlowRuntimeOutput
extends RefCounted

## Per-controller output boundary. Observers receive context without a debugger dependency.
signal message_emitted(controller: Node, process_id: String, block_id: String, message: String)


func write(controller: Node, process_id: String, block_id: String, message: String) -> void:
	print(message)
	message_emitted.emit(controller, process_id, block_id, message)
