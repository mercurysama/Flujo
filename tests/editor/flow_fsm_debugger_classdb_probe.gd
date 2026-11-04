@tool
extends SceneTree

## Potok 10A-14: read-only Godot 4.7.2 native debugger API capability probe.
## No EditorDebuggerPlugin instance, session, message, runtime or UI is created.
var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(ClassDB.class_exists(&"EditorPlugin"), "EditorPlugin class is available")
	_check(ClassDB.class_exists(&"EditorDebuggerPlugin"), "EditorDebuggerPlugin class is available")
	_check(ClassDB.class_exists(&"EditorDebuggerSession"), "EditorDebuggerSession class is available")
	_check(ClassDB.class_has_method(&"EditorPlugin", &"add_debugger_plugin"),
			"EditorPlugin can register a debugger adapter")
	_check(ClassDB.class_has_method(&"EditorPlugin", &"remove_debugger_plugin"),
			"EditorPlugin can unregister a debugger adapter")
	_check(ClassDB.class_has_method(&"EditorDebuggerPlugin", &"get_session"),
			"EditorDebuggerPlugin can resolve an editor debugger session")
	_check(ClassDB.class_has_method(&"EditorDebuggerSession", &"add_session_tab"),
			"EditorDebuggerSession can mount a dedicated debug tab")
	_check(ClassDB.class_has_method(&"EditorDebuggerSession", &"remove_session_tab"),
			"EditorDebuggerSession can remove its tab")
	_check(ClassDB.class_has_method(&"EditorDebuggerSession", &"send_message"),
			"EditorDebuggerSession exposes a message send method")
	_check(ClassDB.class_has_method(&"EditorDebuggerSession", &"is_active"),
			"EditorDebuggerSession provides active state")
	_check(ClassDB.class_has_method(&"EditorDebuggerSession", &"is_breaked"),
			"EditorDebuggerSession exposes the break-loop state")

	# The documented game-side EngineDebugger singleton may not be exposed to
	# ClassDB identically across engine versions; report instead of inventing
	# proof of a connected game session or weakening the editor-side requirements.
	var transport_class_exists: bool = ClassDB.class_exists(&"EngineDebugger")
	var send_available: bool = false
	var receive_available: bool = false
	if transport_class_exists:
		send_available = ClassDB.class_has_method(&"EngineDebugger", &"send_message")
		receive_available = ClassDB.class_has_method(&"EngineDebugger", &"register_message_capture")
	print("[Flujo] Potok-10A14 engine transport ClassDB probe: exists=%s send=%s receive=%s"
			% [str(transport_class_exists), str(send_available), str(receive_available)])
	print("[Flujo] Potok-10A14 protocol and live session: NOT RUN")
	print("[Flujo] Potok-10A14 editor debugger API probe result: %s"
			% ["passed" if _failures.is_empty() else "failed"])
	quit(0 if _failures.is_empty() else 1)


func _check(ok: bool, description: String) -> void:
	if not ok:
		_failures.append(description)
		push_error("[Flujo] Potok-10A14: " + description)
