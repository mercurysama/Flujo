@tool
## Encapsulates atomic, undoable Inspector edits for supported FlowGraph collections.
class_name FlowGraphEditorCommands
extends RefCounted


signal changed


const DEFAULT_DISPLAY_NAME: String = "Flujo"


enum Collection {
	PROCESSES,
	VARIABLES,
	STATE_MACHINES,
}


var _undo_redo: EditorUndoRedoManager
var _last_diagnostics: Array[FlowDiagnostic] = []


## Creates an editor-only command adapter around Godot's undo/redo manager.
func _init(undo_redo: EditorUndoRedoManager) -> void:
	_undo_redo = undo_redo


## Returns the diagnostics from the latest rejected command or completed action.
func get_last_diagnostics() -> Array[FlowDiagnostic]:
	return _last_diagnostics.duplicate()


## Creates and assigns one empty schema 2 graph when the controller has no graph.
func create_schema_2_graph(controller: PVController) -> bool:
	if controller == null or controller.flow_graph != null or _undo_redo == null:
		return false

	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_2
	_commit_graph_replacement("Create FlowGraph", controller, graph, null)
	return true


## Migrates a valid schema 1 graph and makes replacing the controller reference undoable.
func migrate_to_schema_2(controller: PVController) -> bool:
	if controller == null or controller.flow_graph == null or _undo_redo == null:
		return false

	var original_graph: FlowGraph = controller.flow_graph
	var migration: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_1_to_2(original_graph)
	_last_diagnostics = migration.diagnostics.duplicate()
	if not migration.is_successful():
		emit_signal(&"changed")
		return false

	_commit_graph_replacement("Migrate FlowGraph to Schema 2", controller, migration.migrated_graph, original_graph)
	return true


## Migrates a valid schema 2 graph and makes replacing the controller reference undoable.
func migrate_to_schema_3(controller: PVController) -> bool:
	if controller == null or controller.flow_graph == null or _undo_redo == null:
		return false

	var original_graph: FlowGraph = controller.flow_graph
	var migration: FlowGraphMigrationResult = FlowGraphMigrator.migrate_schema_2_to_3(original_graph)
	_last_diagnostics = migration.diagnostics.duplicate()
	if not migration.is_successful():
		emit_signal(&"changed")
		return false

	_commit_graph_replacement("Migrate FlowGraph to Schema 3", controller, migration.migrated_graph, original_graph)
	return true


## Adds a resource to an editable schema 2 or schema 3 structural collection.
func add_resource(controller: PVController, collection: Collection) -> bool:
	var graph: FlowGraph = controller.flow_graph if controller != null else null
	if not _can_edit_collection(graph, collection):
		return false

	var updated: Array = _collection_values(graph, collection)
	updated.append(_new_resource(collection, updated, graph.schema_version == FlowGraph.SCHEMA_VERSION_3))
	_commit_collection("Add %s" % _collection_name(collection), controller, collection, updated)
	return true


## Renames the resource identified by its stable internal ID.
func rename_resource(controller: PVController, collection: Collection, internal_id: String, display_name: String) -> bool:
	var graph: FlowGraph = controller.flow_graph if controller != null else null
	if not _can_edit_collection(graph, collection) \
			or internal_id.is_empty():
		return false

	var resource: Resource = _find_resource(graph, collection, internal_id)
	if resource == null:
		return false

	var previous_name: String = _display_name(resource)
	if previous_name == display_name:
		return false
	_undo_redo.create_action("Rename %s" % _resource_action_name(collection, resource), UndoRedo.MERGE_DISABLE, controller, false, true)
	_undo_redo.add_do_method(self, &"_set_display_name", resource, display_name)
	_undo_redo.add_undo_method(self, &"_set_display_name", resource, previous_name)
	_undo_redo.commit_action()
	return true


## Updates one explicitly supported schema 3 variable property by stable ID.
func set_variable_property(
		controller: PVController,
		internal_id: String,
		property_name: StringName,
		value: Variant
) -> bool:
	var graph: FlowGraph = controller.flow_graph if controller != null else null
	if not _can_edit_schema_3_variable(graph, Collection.VARIABLES) or internal_id.is_empty():
		return false
	var variable: FlowVariableDefinition = _find_resource(
		graph,
		Collection.VARIABLES,
		internal_id
	) as FlowVariableDefinition
	if variable == null or not _is_supported_variable_property(property_name, value):
		return false
	var previous_value: Variant = _variable_property_value(variable, property_name)
	if previous_value == value:
		return false
	_undo_redo.create_action(
		"Edit Variable %s" % _variable_property_label(property_name),
		UndoRedo.MERGE_DISABLE,
		controller,
		false,
		true
	)
	_undo_redo.add_do_method(self, &"_assign_variable_property", controller, variable, property_name, value)
	_undo_redo.add_undo_method(
		self,
		&"_assign_variable_property",
		controller,
		variable,
		property_name,
		previous_value
	)
	_undo_redo.commit_action()
	return true


## Moves a selected resource by one array position, including across deliberate null slots.
func move_resource(controller: PVController, collection: Collection, internal_id: String, direction: int) -> bool:
	var graph: FlowGraph = controller.flow_graph if controller != null else null
	if not _can_edit_collection(graph, collection) \
			or internal_id.is_empty() or direction == 0:
		return false

	var values: Array = _collection_values(graph, collection)
	var source_index: int = _find_index(values, internal_id)
	var target_index: int = source_index + (1 if direction > 0 else -1)
	if source_index == -1 or target_index < 0 or target_index >= values.size():
		return false

	var moved: Array = values.duplicate()
	var displaced: Variant = moved[target_index]
	moved[target_index] = moved[source_index]
	moved[source_index] = displaced
	_commit_collection("Move %s" % _resource_action_name(collection, moved[target_index] as Resource), controller, collection, moved)
	return true


## Removes a resource only when the candidate graph remains structurally valid.
func delete_resource(controller: PVController, collection: Collection, internal_id: String) -> bool:
	var graph: FlowGraph = controller.flow_graph if controller != null else null
	if not _can_edit_collection(graph, collection) \
			or internal_id.is_empty():
		return false

	var updated: Array = _collection_values(graph, collection)
	var index: int = _find_index(updated, internal_id)
	if index == -1:
		return false
	var resource: Resource = updated[index] as Resource
	if resource == null:
		return false
	updated.remove_at(index)
	var validation: FlowValidationResult = FlowGraphValidator.validate(_candidate_with_collection(graph, collection, updated))
	_last_diagnostics = validation.diagnostics.duplicate()
	if validation.has_errors():
		emit_signal(&"changed")
		return false

	_commit_collection("Delete %s" % _resource_action_name(collection, resource), controller, collection, updated)
	return true


func _commit_graph_replacement(
		action_name: String,
		controller: PVController,
		do_graph: FlowGraph,
		undo_graph: FlowGraph
) -> void:
	_undo_redo.create_action(action_name, UndoRedo.MERGE_DISABLE, controller, false, true)
	_undo_redo.add_do_method(self, &"_assign_graph", controller, do_graph)
	_undo_redo.add_undo_method(self, &"_assign_graph", controller, undo_graph)
	_undo_redo.commit_action()


## Resolves the existing Ready process by stable identity; no parallel process collection.
func find_ready_process(controller: PVController, process_id: String) -> FlowProcess:
	if not is_instance_valid(controller) or _undo_redo == null:
		return null
	if controller.flow_graph == null or controller.flow_graph.schema_version != FlowGraph.SCHEMA_VERSION_3:
		return null
	if not _can_edit_collection(controller.flow_graph, Collection.PROCESSES):
		return null
	var process: FlowProcess = _find_resource(controller.flow_graph, Collection.PROCESSES, process_id) as FlowProcess
	return process if process != null and (process.process_type == FlowProcess.ProcessType.READY or process is FlowTimerDefinition) else null


func add_timer(controller: PVController) -> String:
	if not is_instance_valid(controller) or controller.flow_graph == null \
			or controller.flow_graph.schema_version != FlowGraph.SCHEMA_VERSION_3:
		return ""
	var values: Array = controller.flow_graph.processes.duplicate()
	var existing_timers: Array = []
	for process: FlowProcess in controller.flow_graph.processes:
		if process is FlowTimerDefinition:
			existing_timers.append(process)
	var timer: FlowTimerDefinition = FlowTimerDefinition.new()
	timer.display_name = _first_available_display_name(existing_timers, true)
	values.append(timer)
	_commit_collection("Add Timer", controller, Collection.PROCESSES, values)
	return timer.get_internal_id()


func set_ready_property(controller: PVController, process_id: String, block_id: String, property: StringName, value: Variant) -> bool:
	var process: FlowProcess = find_ready_process(controller, process_id)
	if process == null:
		return false
	var target: Resource = process if block_id.is_empty() else _ready_block(process, block_id)
	if target == null:
		return false
	var allowed: bool = (property == &"enabled" and value is bool) \
		or (block_id.is_empty() and property == &"display_name" and value is String) \
		or (target is FlowBlock and property == &"display_name" and value is String) \
		or (target is FlowTimerDefinition and property == &"repeat" and value is bool) \
		or (target is FlowTimerDefinition and property == &"interval_seconds" and value is float and is_finite(value) and value > 0.0) \
		or (target is FlowPrintBlock and property == &"text" and value is String)
	if not allowed or target.get(property) == value:
		return false
	var action_name: String = "Rename %s Block" % _entry_point_action_name(process) \
		if target is FlowBlock and property == &"display_name" \
		else "Edit %s %s" % [_entry_point_action_name(process), property.capitalize()]
	_commit_ready_property(action_name, controller, target, property, value)
	return true


func add_ready_block(controller: PVController, process_id: String, print_block: bool) -> String:
	var process: FlowProcess = find_ready_process(controller, process_id)
	if process == null:
		return ""
	var block: FlowBlock = FlowPrintBlock.new() if print_block else FlowEverythingFlowsBlock.new()
	block.display_name = _first_available_block_display_name(process.blocks, block)
	var updated: Array[FlowBlock] = process.blocks.duplicate()
	updated.append(block)
	_commit_ready_property("Add %s %s Block" % [_entry_point_action_name(process), block.display_name], controller, process, &"blocks", updated)
	return block.get_internal_id()


func move_ready_block(controller: PVController, process_id: String, block_id: String, direction: int) -> bool:
	var process: FlowProcess = find_ready_process(controller, process_id)
	if process == null or direction == 0:
		return false
	var block: FlowBlock = _ready_block(process, block_id)
	if block == null:
		return false
	var index: int = process.blocks.find(block)
	var destination: int = index + (1 if direction > 0 else -1)
	if destination < 0 or destination >= process.blocks.size():
		return false
	var updated: Array[FlowBlock] = process.blocks.duplicate()
	updated[index] = updated[destination]
	updated[destination] = block
	_commit_ready_property("Move %s Block" % _entry_point_action_name(process), controller, process, &"blocks", updated)
	return true


func delete_ready_block(controller: PVController, process_id: String, block_id: String) -> bool:
	var process: FlowProcess = find_ready_process(controller, process_id)
	if process == null:
		return false
	var block: FlowBlock = _ready_block(process, block_id)
	if block == null:
		return false
	var updated: Array[FlowBlock] = process.blocks.duplicate()
	updated.remove_at(updated.find(block))
	_commit_ready_property("Delete %s Block" % _entry_point_action_name(process), controller, process, &"blocks", updated)
	return true


func _ready_block(process: FlowProcess, block_id: String) -> FlowBlock:
	for block: FlowBlock in process.blocks:
		if block != null and block.get_internal_id() == block_id:
			return block
	return null


func _commit_ready_property(action: String, controller: PVController, resource: Resource, property: StringName, value: Variant) -> void:
	_undo_redo.create_action(action, UndoRedo.MERGE_DISABLE, controller, false, true)
	_undo_redo.add_do_method(self, &"_assign_ready_property", controller, resource, property, value)
	_undo_redo.add_undo_method(self, &"_assign_ready_property", controller, resource, property, resource.get(property))
	_undo_redo.commit_action()


func _assign_ready_property(controller: PVController, resource: Resource, property: StringName, value: Variant) -> void:
	resource.set(property, value)
	controller.notify_property_list_changed()
	_refresh_diagnostics(controller.flow_graph)
	changed.emit()


func _commit_collection(action_name: String, controller: PVController, collection: Collection, updated: Array) -> void:
	var graph: FlowGraph = controller.flow_graph
	var original: Array = _collection_values(graph, collection)
	_undo_redo.create_action(action_name, UndoRedo.MERGE_DISABLE, controller, false, true)
	_undo_redo.add_do_method(self, &"_assign_collection", controller, graph, collection, updated)
	_undo_redo.add_undo_method(self, &"_assign_collection", controller, graph, collection, original)
	_undo_redo.commit_action()


func _assign_graph(controller: PVController, graph: FlowGraph) -> void:
	controller.flow_graph = graph
	controller.notify_property_list_changed()
	_refresh_diagnostics(graph)
	emit_signal(&"changed")


func _assign_collection(controller: PVController, graph: FlowGraph, collection: Collection, values: Array) -> void:
	match collection:
		Collection.PROCESSES:
			graph.processes.assign(values)
		Collection.VARIABLES:
			graph.variables.assign(values)
		Collection.STATE_MACHINES:
			graph.state_machines.assign(values)
	if controller != null:
		controller.notify_property_list_changed()
	_refresh_diagnostics(graph)
	emit_signal(&"changed")


func _set_display_name(resource: Resource, display_name: String) -> void:
	_assign_display_name(resource, display_name)
	_refresh_diagnostics_for_resource(resource)
	emit_signal(&"changed")


func _assign_variable_property(
		controller: PVController,
		variable: FlowVariableDefinition,
		property_name: StringName,
		value: Variant
) -> void:
	match property_name:
		&"display_name":
			variable.display_name = value as String
		&"scope":
			variable.scope = int(value)
		&"binding":
			variable.binding = int(value)
		&"value_type":
			variable.value_type = int(value)
		&"bool_value":
			variable.bool_value = value as bool
		&"int_value":
			variable.int_value = int(value)
		&"float_value":
			variable.float_value = float(value)
		&"string_value":
			variable.string_value = value as String
		&"vector2_value":
			variable.vector2_value = value as Vector2
		&"vector3_value":
			variable.vector3_value = value as Vector3
		&"color_value":
			variable.color_value = value as Color
		&"persistent":
			variable.persistent = value as bool
		&"user_note":
			variable.user_note = value as String
	controller.notify_property_list_changed()
	_refresh_diagnostics(controller.flow_graph)
	emit_signal(&"changed")


func _assign_display_name(resource: Resource, display_name: String) -> void:
	if resource is FlowBlockContainer:
		(resource as FlowBlockContainer).display_name = display_name
	elif resource is FlowVariableDefinition:
		(resource as FlowVariableDefinition).display_name = display_name
	elif resource is FlowStateMachineDefinition:
		(resource as FlowStateMachineDefinition).display_name = display_name


func _can_edit_collection(graph: FlowGraph, collection: Collection) -> bool:
	if graph == null or not graph.containers.is_empty():
		return false
	if graph.schema_version != FlowGraph.SCHEMA_VERSION_2 \
			and graph.schema_version != FlowGraph.SCHEMA_VERSION_3:
		return false
	return collection >= Collection.PROCESSES and collection <= Collection.STATE_MACHINES


func _can_edit_schema_3_variable(graph: FlowGraph, collection: Collection) -> bool:
	return graph != null \
		and graph.schema_version == FlowGraph.SCHEMA_VERSION_3 \
		and graph.containers.is_empty() \
		and collection == Collection.VARIABLES


func _is_supported_variable_property(property_name: StringName, value: Variant) -> bool:
	match property_name:
		&"display_name", &"string_value", &"user_note":
			return value is String
		&"scope":
			return value is int and FlowVariableDefinition.is_valid_scope(value as int)
		&"binding":
			return value is int and FlowVariableDefinition.is_valid_binding(value as int)
		&"value_type":
			return value is int and FlowVariableDefinition.is_valid_value_type(value as int)
		&"bool_value", &"persistent":
			return value is bool
		&"int_value", &"float_value":
			return value is int or value is float
		&"vector2_value":
			return value is Vector2
		&"vector3_value":
			return value is Vector3
		&"color_value":
			return value is Color
	return false


func _variable_property_value(variable: FlowVariableDefinition, property_name: StringName) -> Variant:
	match property_name:
		&"display_name": return variable.display_name
		&"scope": return variable.scope
		&"binding": return variable.binding
		&"value_type": return variable.value_type
		&"bool_value": return variable.bool_value
		&"int_value": return variable.int_value
		&"float_value": return variable.float_value
		&"string_value": return variable.string_value
		&"vector2_value": return variable.vector2_value
		&"vector3_value": return variable.vector3_value
		&"color_value": return variable.color_value
		&"persistent": return variable.persistent
		&"user_note": return variable.user_note
	return null


func _variable_property_label(property_name: StringName) -> String:
	return property_name.capitalize().replace("_", " ")


func _collection_values(graph: FlowGraph, collection: Collection) -> Array:
	match collection:
		Collection.PROCESSES:
			return graph.processes.duplicate()
		Collection.VARIABLES:
			return graph.variables.duplicate()
		Collection.STATE_MACHINES:
			return graph.state_machines.duplicate()
	return []


func _new_resource(collection: Collection, existing_values: Array, schema_3: bool) -> Resource:
	var resource: Resource = null
	match collection:
		Collection.PROCESSES:
			resource = FlowProcess.new()
		Collection.VARIABLES:
			resource = FlowVariableDefinition.new()
		Collection.STATE_MACHINES:
			resource = FlowStateMachineDefinition.new()
	if resource != null:
		_assign_display_name(resource, _first_available_display_name(existing_values, schema_3))
	return resource


## Schema 3 uses zero-based visible suffixes; schema 2 retains its compatibility naming.
func _first_available_display_name(values: Array, schema_3: bool = false) -> String:
	var existing_names: Dictionary[String, bool] = {}
	for value: Variant in values:
		if value is Resource:
			existing_names[_display_name(value as Resource)] = true
	if not existing_names.has(DEFAULT_DISPLAY_NAME):
		return DEFAULT_DISPLAY_NAME
	var suffix: int = 1 if schema_3 else 2
	while existing_names.has("%s %d" % [DEFAULT_DISPLAY_NAME, suffix]):
		suffix += 1
	return "%s %d" % [DEFAULT_DISPLAY_NAME, suffix]


func _first_available_block_display_name(blocks: Array[FlowBlock], template: FlowBlock) -> String:
	var base_name: String = _default_block_display_name(template)
	var existing_names: Dictionary[String, bool] = {}
	for block: FlowBlock in blocks:
		if block != null and block.get_script() == template.get_script():
			existing_names[_block_display_name(block)] = true
	var suffix: int = 0
	while existing_names.has(base_name if suffix == 0 else "%s %d" % [base_name, suffix]):
		suffix += 1
	return base_name if suffix == 0 else "%s %d" % [base_name, suffix]


func _default_block_display_name(block: FlowBlock) -> String:
	if block is FlowPrintBlock:
		return "Print"
	if block is FlowEverythingFlowsBlock:
		return "Everything Flows"
	return block.display_name


func _block_display_name(block: FlowBlock) -> String:
	return block.display_name if not block.display_name.strip_edges().is_empty() else _default_block_display_name(block)


func _resource_action_name(collection: Collection, resource: Resource) -> String:
	if collection == Collection.PROCESSES and resource is FlowTimerDefinition:
		return "Timer"
	return _collection_name(collection)


func _entry_point_action_name(process: FlowProcess) -> String:
	return "Timer" if process is FlowTimerDefinition else "Ready"


func _find_resource(graph: FlowGraph, collection: Collection, internal_id: String) -> Resource:
	var values: Array = _collection_values(graph, collection)
	for value: Variant in values:
		if value is Resource and _resource_id(value as Resource) == internal_id:
			return value as Resource
	return null


func _find_index(values: Array, internal_id: String) -> int:
	for index: int in values.size():
		var value: Variant = values[index]
		if value is Resource and _resource_id(value as Resource) == internal_id:
			return index
	return -1


func _candidate_with_collection(graph: FlowGraph, collection: Collection, values: Array) -> FlowGraph:
	var candidate: FlowGraph = FlowGraph.new()
	candidate._internal_id = graph.get_internal_id()
	candidate.schema_version = graph.schema_version
	candidate.containers.assign(graph.containers)
	candidate.processes.assign(graph.processes)
	candidate.variables.assign(graph.variables)
	candidate.state_machines.assign(graph.state_machines)
	candidate.constructor = graph.constructor
	candidate.methods.assign(graph.methods)
	match collection:
		Collection.PROCESSES:
			candidate.processes.assign(values)
		Collection.VARIABLES:
			candidate.variables.assign(values)
		Collection.STATE_MACHINES:
			candidate.state_machines.assign(values)
	return candidate


func _resource_id(resource: Resource) -> String:
	if resource is FlowBlockContainer:
		return (resource as FlowBlockContainer).get_internal_id()
	if resource is FlowVariableDefinition:
		return (resource as FlowVariableDefinition).get_internal_id()
	if resource is FlowStateMachineDefinition:
		return (resource as FlowStateMachineDefinition).get_internal_id()
	return ""


func _display_name(resource: Resource) -> String:
	if resource is FlowBlockContainer:
		return (resource as FlowBlockContainer).display_name
	if resource is FlowVariableDefinition:
		return (resource as FlowVariableDefinition).display_name
	if resource is FlowStateMachineDefinition:
		return (resource as FlowStateMachineDefinition).display_name
	return ""


func _collection_name(collection: Collection) -> String:
	match collection:
		Collection.PROCESSES:
			return "Process"
		Collection.VARIABLES:
			return "Variable"
		Collection.STATE_MACHINES:
			return "State Machine"
	return "Resource"


func _refresh_diagnostics(graph: FlowGraph) -> void:
	if graph == null:
		_last_diagnostics = []
		return
	_last_diagnostics = FlowGraphValidator.validate(graph).diagnostics.duplicate()


func _refresh_diagnostics_for_resource(_resource: Resource) -> void:
	# Resource renames do not affect validation, but the Inspector still refreshes.
	_last_diagnostics = _last_diagnostics.duplicate()
