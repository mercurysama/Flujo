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
	updated.append(_new_resource(collection, updated))
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
	_undo_redo.create_action("Rename %s" % _collection_name(collection), UndoRedo.MERGE_DISABLE, controller, false, true)
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
	_commit_collection("Move %s" % _collection_name(collection), controller, collection, moved)
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
	updated.remove_at(index)
	var validation: FlowValidationResult = FlowGraphValidator.validate(_candidate_with_collection(graph, collection, updated))
	_last_diagnostics = validation.diagnostics.duplicate()
	if validation.has_errors():
		emit_signal(&"changed")
		return false

	_commit_collection("Delete %s" % _collection_name(collection), controller, collection, updated)
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


func _new_resource(collection: Collection, existing_values: Array) -> Resource:
	var resource: Resource = null
	match collection:
		Collection.PROCESSES:
			resource = FlowProcess.new()
		Collection.VARIABLES:
			resource = FlowVariableDefinition.new()
		Collection.STATE_MACHINES:
			resource = FlowStateMachineDefinition.new()
	if resource != null:
		_assign_display_name(resource, _first_available_display_name(existing_values))
	return resource


func _first_available_display_name(values: Array) -> String:
	var existing_names: Dictionary[String, bool] = {}
	for value: Variant in values:
		if value is Resource:
			existing_names[_display_name(value as Resource)] = true
	if not existing_names.has(DEFAULT_DISPLAY_NAME):
		return DEFAULT_DISPLAY_NAME
	var suffix: int = 2
	while existing_names.has("%s %d" % [DEFAULT_DISPLAY_NAME, suffix]):
		suffix += 1
	return "%s %d" % [DEFAULT_DISPLAY_NAME, suffix]


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
