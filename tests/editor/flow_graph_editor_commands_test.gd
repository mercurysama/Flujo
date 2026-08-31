@tool
extends SceneTree


var _failures: Array[String] = []
var _changes: int = 0


func _init() -> void:
	call_deferred(&"_run")


func _run() -> void:
	var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if undo_redo == null:
		_failures.append("Editor undo/redo manager is unavailable.")
		_finish()
		return
	var history: UndoRedo = undo_redo.get_history_undo_redo(EditorUndoRedoManager.GLOBAL_HISTORY)
	var commands: FlowGraphEditorCommands = FlowGraphEditorCommands.new(undo_redo)
	commands.changed.connect(_on_changed)
	var controller: PVController = PVController.new()
	controller.flow_graph = null

	_expect(commands.create_schema_2_graph(controller), "A missing graph can be created.")
	var created_graph: FlowGraph = controller.flow_graph
	_expect(created_graph != null and created_graph.schema_version == FlowGraph.SCHEMA_VERSION_2, "Created graph is schema 2.")
	history.undo()
	_expect(controller.flow_graph == null, "Undo restores the missing graph reference.")
	history.redo()
	_expect(controller.flow_graph == created_graph, "Redo restores the same graph instance.")

	_expect(commands.add_resource(created_graph, FlowGraphEditorCommands.Collection.PROCESSES), "A process can be added.")
	var process: FlowProcess = created_graph.processes[0]
	var process_id: String = process.get_internal_id()
	_expect(commands.rename_resource(created_graph, FlowGraphEditorCommands.Collection.PROCESSES, process_id, "Tick"), "A process can be renamed.")
	_expect(process.display_name == "Tick", "Rename is applied through the action.")
	history.undo()
	_expect(process.display_name == "_ready", "Undo preserves the same process instance.")
	history.redo()
	_expect(process.display_name == "Tick", "Redo preserves the process ID and instance.")
	_expect(commands.add_resource(created_graph, FlowGraphEditorCommands.Collection.PROCESSES), "A second process can be added.")
	var second_process: FlowProcess = created_graph.processes[1]
	_expect(commands.move_resource(created_graph, FlowGraphEditorCommands.Collection.PROCESSES, second_process.get_internal_id(), -1), "A process can move one position.")
	_expect(created_graph.processes[0] == second_process and created_graph.processes[1] == process, "Move keeps instances and order deterministically.")
	_expect(commands.delete_resource(created_graph, FlowGraphEditorCommands.Collection.PROCESSES, process_id), "An unreferenced process can be deleted.")
	_expect(created_graph.processes[1] == null, "Delete preserves the deliberate array slot.")

	_expect(commands.add_resource(created_graph, FlowGraphEditorCommands.Collection.VARIABLES), "A variable can be added.")
	var global_variable: FlowVariableDefinition = created_graph.variables[0]
	global_variable.scope = FlowVariableDefinition.Scope.GLOBAL
	_expect(commands.add_resource(created_graph, FlowGraphEditorCommands.Collection.STATE_MACHINES), "A state machine can be added.")
	_expect(created_graph.state_machines[0] is FlowStateMachineDefinition, "Added state machine has the expected type.")
	_expect(commands.add_resource(created_graph, FlowGraphEditorCommands.Collection.VARIABLES), "A second variable can be added.")
	var reference_variable: FlowVariableDefinition = created_graph.variables[1]
	reference_variable.global_variable_id = global_variable.get_internal_id()
	_expect(not commands.delete_resource(created_graph, FlowGraphEditorCommands.Collection.VARIABLES, global_variable.get_internal_id()), "Deleting a referenced global variable is rejected.")
	_expect(created_graph.variables[0] == global_variable, "Rejected deletion does not mutate the graph.")
	_expect(not commands.get_last_diagnostics().is_empty(), "Rejected deletion exposes diagnostics.")

	var legacy_graph: FlowGraph = FlowGraph.new()
	var legacy_process: FlowProcess = FlowProcess.new()
	legacy_graph.containers.append(legacy_process)
	controller.flow_graph = legacy_graph
	_expect(commands.migrate_to_schema_2(controller), "A valid legacy graph can be migrated.")
	var migrated_graph: FlowGraph = controller.flow_graph
	_expect(migrated_graph != legacy_graph and migrated_graph.schema_version == FlowGraph.SCHEMA_VERSION_2, "Migration replaces only with a valid schema 2 copy.")
	history.undo()
	_expect(controller.flow_graph == legacy_graph, "Undo restores the exact legacy graph instance.")
	history.redo()
	_expect(controller.flow_graph == migrated_graph, "Redo restores the same migrated graph instance.")
	_expect(_changes > 0, "Commands notify the presenter after actions.")
	var presentation: Dictionary = FlowGraphInspectorPresenter.present(migrated_graph)
	_expect(presentation["active_source"] == "Typed collections", "Presenter refreshes from the active schema 2 source.")
	_expect(not FlowGraphValidator.validate(migrated_graph).has_errors(), "Migrated graph stays valid without mixed sources.")

	_finish()


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] FlowGraph editor commands test passed")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _on_changed() -> void:
	_changes += 1
