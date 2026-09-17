class_name FlowRuntimeOutput
extends RefCounted

## Per-controller output boundary. Observers receive context without a debugger dependency.
signal message_emitted(controller: Node, process_id: String, block_id: String, message: String)
signal entry_message_emitted(controller: Node, process_id: String, block_id: String, message: String, entry_point: StringName)
signal contextual_message_emitted(controller: Node, container_id: String, block_id: String, message: String, entry_point: StringName, method_id: String, call_id: String)


func write(controller: Node, process_id: String, block_id: String, message: String, entry_point: StringName = &"Ready", method_id: String = "", call_id: String = "") -> void:
	print(message)
	message_emitted.emit(controller, process_id, block_id, message)
	entry_message_emitted.emit(controller, process_id, block_id, message, entry_point)
	contextual_message_emitted.emit(controller, process_id, block_id, message, entry_point, method_id, call_id)
