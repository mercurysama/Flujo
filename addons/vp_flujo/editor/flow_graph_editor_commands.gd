@tool
## Encapsulates atomic, undoable Inspector edits for supported FlowGraph collections.
class_name FlowGraphEditorCommands
extends RefCounted


signal changed


const DEFAULT_DISPLAY_NAME: String = "Flujo"
const FLOW_EDITOR_BLOCK_AUTHORING_CONTEXT_SCRIPT: Script = preload(
	"res://addons/vp_flujo/editor/flow_editor_block_authoring_context.gd"
)
const AUTHORING_CONTEXT_RESULT_MISSING: StringName = &"editor_authoring_result_missing"
const AUTHORING_CONTEXT_BLOCK_MISSING: StringName = &"editor_authoring_block_missing"


enum Collection {
	PROCESSES,
	VARIABLES,
	STATE_MACHINES,
	METHODS,
	CONSTRUCTOR,
}


## Separates visible naming collections from their persistent storage. Timers share
## FlowGraph.processes with Ready processes, but must never consume their names.
enum SemanticCollection {
	PROCESSES,
	TIMERS,
	VARIABLES,
	STATE_MACHINES,
	METHODS,
}


var _undo_redo: EditorUndoRedoManager
var _authoring_context: RefCounted
var _last_diagnostics: Array[FlowDiagnostic] = []


## Creates an editor-only command adapter around Godot's undo/redo manager.
func _init(undo_redo: EditorUndoRedoManager, authoring_context: RefCounted = null) -> void:
	_undo_redo = undo_redo
	_authoring_context = authoring_context


## Injects the editor-only authoring snapshot used by generic Add.
func configure_block_authoring_context(authoring_context: RefCounted) -> void:
	_authoring_context = authoring_context


func get_undo_redo() -> EditorUndoRedoManager:
	return _undo_redo


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
	var naming_values: Array = _semantic_values(updated, _semantic_collection_for_collection(collection))
	updated.append(_new_resource(collection, naming_values, graph.schema_version == FlowGraph.SCHEMA_VERSION_3))
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
	if resource is FlowMethodDefinition and not _valid_method_name(graph, resource, display_name):
		return false
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
	if property_name == &"value_type":
		var next_type: int = int(value)
		var previous_source: FlowValueSource = variable.complex_value_source
		var next_source: FlowValueSource = null
		if FlowVariableDefinition.is_complex_value_type(next_type):
			next_source = previous_source
			var expected_kind: StringName = FlowVariableDefinition.expected_complex_source_kind(
				next_type
			)
			if next_source == null 					or next_source.get_source_kind() != expected_kind 					or next_source.get_value_type() != FlowVariableDefinition.to_variant_type(next_type):
				next_source = FlowVariableDefinition.default_complex_source(next_type)
		_undo_redo.create_action(
			"Edit Variable Type",
			UndoRedo.MERGE_DISABLE,
			controller,
			false,
			true
		)
		_undo_redo.add_do_method(
			self,
			&"_assign_variable_type",
			controller,
			variable,
			next_type,
			next_source
		)
		_undo_redo.add_undo_method(
			self,
			&"_assign_variable_type",
			controller,
			variable,
			variable.value_type,
			previous_source
		)
		_undo_redo.commit_action()
		return true
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


func set_variable_complex_source(
		controller: PVController,
		internal_id: String,
		source: FlowValueSource
) -> bool:
	var graph: FlowGraph = controller.flow_graph if controller != null else null
	if not _can_edit_schema_3_variable(graph, Collection.VARIABLES) 			or internal_id.is_empty() or source == null or not source.is_valid():
		return false
	var variable: FlowVariableDefinition = _find_resource(
		graph,
		Collection.VARIABLES,
		internal_id
	) as FlowVariableDefinition
	if variable == null or not FlowVariableDefinition.is_complex_value_type(variable.value_type):
		return false
	if source.get_source_kind() != FlowVariableDefinition.expected_complex_source_kind(variable.value_type) 			or source.get_value_type() != variable.get_declared_variant_type():
		return false
	var previous: FlowValueSource = variable.complex_value_source
	if previous != null:
		source.source_id = previous.source_id
	_undo_redo.create_action(
		"Edit Variable Structured Value",
		UndoRedo.MERGE_DISABLE,
		controller,
		false,
		true
	)
	_undo_redo.add_do_method(
		self,
		&"_assign_variable_complex_source",
		controller,
		variable,
		source
	)
	_undo_redo.add_undo_method(
		self,
		&"_assign_variable_complex_source",
		controller,
		variable,
		previous
	)
	_undo_redo.commit_action()
	return true




## Potok 7C-1: explicit scalar authoring through immutable validation candidates.
func set_fsm_machine_property(
		controller: PVController, machine_id: String,
		property_name: StringName, value: Variant
) -> bool:
	if not _can_edit_fsm_scalar(controller) or machine_id.is_empty():
		return false
	var graph: FlowGraph = controller.flow_graph
	var machine: FlowStateMachineDefinition = _find_resource(
		graph, Collection.STATE_MACHINES, machine_id
	) as FlowStateMachineDefinition
	if machine == null or not _fsm_scalar_valid(property_name, value, true):
		return false
	if property_name == &"initial_state_id" and not _fsm_valid_initial(machine, String(value)):
		return false
	var previous: Variant = machine.get(property_name)
	if previous == value:
		return false
	var draft: FlowStateMachineDefinition = machine.duplicate(false) as FlowStateMachineDefinition
	if draft == null or draft.get_internal_id() != machine_id:
		return false
	draft.set(property_name, value)
	var replacements: Array = graph.state_machines.duplicate()
	var machine_index: int = _find_index(replacements, machine_id)
	if machine_index < 0:
		return false
	replacements[machine_index] = draft
	if not _fsm_candidate_accepted(graph, replacements):
		return false
	_fsm_commit_scalar(controller, machine, property_name, value, previous)
	return true


func set_fsm_state_property(
		controller: PVController, machine_id: String, state_id: String,
		property_name: StringName, value: Variant
) -> bool:
	if not _can_edit_fsm_scalar(controller) or machine_id.is_empty() or state_id.is_empty():
		return false
	var graph: FlowGraph = controller.flow_graph
	var machine: FlowStateMachineDefinition = _find_resource(
		graph, Collection.STATE_MACHINES, machine_id
	) as FlowStateMachineDefinition
	if machine == null or not _fsm_scalar_valid(property_name, value, false):
		return false
	var state: FlowStateDefinition = null
	var state_index: int = -1
	for index: int in machine.states.size():
		var candidate: FlowStateDefinition = machine.states[index]
		if candidate != null and candidate.get_internal_id() == state_id:
			state = candidate
			state_index = index
			break
	if state == null:
		return false
	# Never disable the state currently selected by the owning initial-state ID.
	if property_name == &"enabled" and value == false and machine.initial_state_id == state_id:
		return false
	var previous: Variant = state.get(property_name)
	if previous == value:
		return false
	var state_draft: FlowStateDefinition = state.duplicate(false) as FlowStateDefinition
	var machine_draft: FlowStateMachineDefinition = machine.duplicate(false) as FlowStateMachineDefinition
	if state_draft == null or machine_draft == null or state_draft.get_internal_id() != state_id:
		return false
	state_draft.set(property_name, value)
	var state_replacements: Array[FlowStateDefinition] = []
	state_replacements.assign(machine.states)
	state_replacements[state_index] = state_draft
	machine_draft.states = state_replacements
	var replacements: Array = graph.state_machines.duplicate()
	var machine_index: int = _find_index(replacements, machine_id)
	if machine_index < 0:
		return false
	replacements[machine_index] = machine_draft
	if not _fsm_candidate_accepted(graph, replacements):
		return false
	_fsm_commit_scalar(controller, state, property_name, value, previous)
	return true


func _can_edit_fsm_scalar(controller: PVController) -> bool:
	return is_instance_valid(controller) and _undo_redo != null \
		and controller.flow_graph != null \
		and controller.flow_graph.schema_version == FlowGraph.SCHEMA_VERSION_3 \
		and controller.flow_graph.containers.is_empty()


func _fsm_scalar_valid(property_name: StringName, value: Variant, machine: bool) -> bool:
	match property_name:
		&"display_name":
			return value is String and not String(value).strip_edges().is_empty()
		&"user_note":
			return value is String
		&"enabled":
			return value is bool
		&"auto_start":
			return machine and value is bool
		&"tick_mode":
			return machine and value is int and value in [
				FlowStateMachineDefinition.TickMode.PROCESS,
				FlowStateMachineDefinition.TickMode.PHYSICS,
				FlowStateMachineDefinition.TickMode.MANUAL
			]
		&"initial_state_id":
			return machine and value is String
	return false


func _fsm_valid_initial(machine: FlowStateMachineDefinition, target_id: String) -> bool:
	if target_id.is_empty():
		return machine.states.is_empty()
	for state: FlowStateDefinition in machine.states:
		if state != null and state.enabled and state.get_internal_id() == target_id:
			return true
	return false


func _fsm_candidate_accepted(graph: FlowGraph, replacements: Array) -> bool:
	var existing: Dictionary[String, int] = _diagnostic_counts(
		FlowGraphValidator.validate(graph).diagnostics
	)
	var candidate: FlowGraph = _candidate_with_collection(
		graph, Collection.STATE_MACHINES, replacements
	)
	var validation: FlowValidationResult = FlowGraphValidator.validate(candidate)
	_last_diagnostics = validation.diagnostics.duplicate()
	for diagnostic: FlowDiagnostic in validation.diagnostics:
		if diagnostic.severity != FlowDiagnostic.Severity.ERROR:
			continue
		var identity: String = _diagnostic_identity(diagnostic)
		var existing_count: int = existing.get(identity, 0)
		if existing_count > 0:
			existing[identity] = existing_count - 1
			continue
		changed.emit()
		return false
	return true


func _fsm_commit_scalar(
		controller: PVController, resource: Resource,
		property_name: StringName, value: Variant, previous: Variant
) -> void:
	_undo_redo.create_action(
		"Edit Potok %s" % String(property_name),
		UndoRedo.MERGE_DISABLE, controller, false, true
	)
	_undo_redo.add_do_method(self, &"_assign_fsm_scalar", controller, resource, property_name, value)
	_undo_redo.add_undo_method(self, &"_assign_fsm_scalar", controller, resource, property_name, previous)
	_undo_redo.commit_action()


func _assign_fsm_scalar(
		controller: PVController, resource: Resource,
		property_name: StringName, value: Variant
) -> void:
	if not is_instance_valid(controller) or resource == null:
		return
	resource.set(property_name, value)
	resource.emit_changed()
	controller.notify_property_list_changed()
	_refresh_diagnostics(controller.flow_graph)
	changed.emit()

## Potok 7C-2A: edit one existing transition without touching authored identities.
func set_fsm_transition_property(
		controller: PVController, machine_id: String, state_id: String,
		transition_id: String, property_name: StringName, value: Variant
) -> bool:
	if not _can_edit_fsm_scalar(controller) or machine_id.is_empty() \
			or state_id.is_empty() or transition_id.is_empty():
		return false
	var graph: FlowGraph = controller.flow_graph
	var machine: FlowStateMachineDefinition = _find_resource(
		graph, Collection.STATE_MACHINES, machine_id
	) as FlowStateMachineDefinition
	if machine == null:
		return false
	var source: FlowStateDefinition = null
	var source_index: int = -1
	for i: int in machine.states.size():
		var state: FlowStateDefinition = machine.states[i]
		if state != null and state.get_internal_id() == state_id:
			source = state
			source_index = i
			break
	if source == null:
		return false
	var edge: FlowStateTransitionDefinition = null
	var edge_index: int = -1
	for i: int in source.transitions.size():
		var item: FlowStateTransitionDefinition = source.transitions[i]
		if item != null and item.get_internal_id() == transition_id:
			edge = item
			edge_index = i
			break
	if edge == null or not _fsm_transition_value_valid(machine, edge, property_name, value):
		return false
	var previous: Variant = edge.get(property_name)
	if previous == value:
		return false
	# Shallow detached copies preserve IDs and references to unedited children.
	# The validator sees the proposed change without mutating the live graph.
	var edge_draft: FlowStateTransitionDefinition = edge.duplicate(false) as FlowStateTransitionDefinition
	var source_draft: FlowStateDefinition = source.duplicate(false) as FlowStateDefinition
	var machine_draft: FlowStateMachineDefinition = machine.duplicate(false) as FlowStateMachineDefinition
	if edge_draft == null or source_draft == null or machine_draft == null:
		return false
	if edge_draft.get_internal_id() != transition_id \
			or source_draft.get_internal_id() != state_id \
			or machine_draft.get_internal_id() != machine_id:
		return false
	edge_draft.set(property_name, value)
	var edges: Array[FlowStateTransitionDefinition] = []
	edges.assign(source.transitions)
	edges[edge_index] = edge_draft
	source_draft.transitions = edges
	var states: Array[FlowStateDefinition] = []
	states.assign(machine.states)
	states[source_index] = source_draft
	machine_draft.states = states
	var machines: Array = graph.state_machines.duplicate()
	var machine_index: int = _find_index(machines, machine_id)
	if machine_index < 0:
		return false
	machines[machine_index] = machine_draft
	if not _fsm_candidate_accepted(graph, machines):
		return false
	_fsm_commit_scalar(controller, edge, property_name, value, previous)
	return true


func _fsm_transition_value_valid(
		machine: FlowStateMachineDefinition, edge: FlowStateTransitionDefinition,
		property_name: StringName, value: Variant
) -> bool:
	match property_name:
		&"display_name":
			return value is String and not String(value).strip_edges().is_empty()
		&"user_note":
			return value is String
		&"enabled":
			return value is bool
		&"priority":
			return value is int
		&"target_state_id":
			if not value is String:
				return false
			for state: FlowStateDefinition in machine.states:
				if state != null and state.get_internal_id() == value:
					return true
			return false
		&"event_name":
			return value is StringName and (
				edge.trigger != FlowStateTransitionDefinition.Trigger.EVENT
				or not String(value).strip_edges().is_empty()
			)
		&"condition":
			return value is FlowValueSource \
				and (value as FlowValueSource).get_value_type() == Variant.Type.TYPE_BOOL \
				and (value as FlowValueSource).is_valid()
		&"trigger":
			if not value is int or value not in [
				FlowStateTransitionDefinition.Trigger.EVENT,
				FlowStateTransitionDefinition.Trigger.CONDITION
			]:
				return false
			if value == FlowStateTransitionDefinition.Trigger.EVENT:
				return not String(edge.event_name).strip_edges().is_empty()
			return edge.condition != null \
				and edge.condition.get_value_type() == Variant.Type.TYPE_BOOL \
				and edge.condition.is_valid()
	return false


## Potok 7E-2B2: validate an entire machine/state/edge scalar snapshot
## before creating one atomic UndoRedo action. Existing live editors remain unchanged.
func restore_fsm_properties_snapshot(
		controller: PVController, machine_id: String, state_id: String,
		transition_id: String, snapshot: Dictionary
) -> bool:
	if not _can_edit_fsm_scalar(controller) or machine_id.is_empty():
		return false
	if not transition_id.is_empty() and state_id.is_empty():
		return false
	var graph: FlowGraph = controller.flow_graph
	var machine: FlowStateMachineDefinition = _find_resource(
		graph, Collection.STATE_MACHINES, machine_id
	) as FlowStateMachineDefinition
	if machine == null:
		return false
	var machine_draft: FlowStateMachineDefinition = machine.duplicate(false) as FlowStateMachineDefinition
	if machine_draft == null or machine_draft.get_internal_id() != machine_id:
		return false

	var kind: StringName = &"machine"
	var target: Resource = machine
	var draft: Resource = machine_draft
	var state: FlowStateDefinition = null
	var state_draft: FlowStateDefinition = null
	if not state_id.is_empty():
		var state_index: int = _fsm_state_index(machine.states, state_id)
		if state_index < 0:
			return false
		state = machine.states[state_index]
		state_draft = state.duplicate(false) as FlowStateDefinition
		if state_draft == null or state_draft.get_internal_id() != state_id:
			return false
		var states: Array[FlowStateDefinition] = []
		states.assign(machine.states)
		states[state_index] = state_draft
		machine_draft.states = states
		kind = &"state"
		target = state
		draft = state_draft
		if not transition_id.is_empty():
			var edge_index: int = _fsm_edge_index(state.transitions, transition_id)
			if edge_index < 0:
				return false
			var edge: FlowStateTransitionDefinition = state.transitions[edge_index]
			var edge_draft: FlowStateTransitionDefinition = edge.duplicate(false) as FlowStateTransitionDefinition
			if edge_draft == null or edge_draft.get_internal_id() != transition_id:
				return false
			var edges: Array[FlowStateTransitionDefinition] = []
			edges.assign(state.transitions)
			edges[edge_index] = edge_draft
			state_draft.transitions = edges
			kind = &"transition"
			target = edge
			draft = edge_draft

	var fields: Array[StringName] = []
	match kind:
		&"machine":
			fields = [&"display_name", &"enabled", &"auto_start", &"tick_mode",
				&"user_note", &"initial_state_id"]
		&"state":
			fields = [&"display_name", &"enabled", &"user_note"]
		&"transition":
			fields = [&"display_name", &"enabled", &"priority",
				&"target_state_id", &"trigger", &"event_name", &"user_note"]
	if snapshot.size() != fields.size():
		return false
	var current: Dictionary = {}
	var changed: bool = false
	for field: StringName in fields:
		if not snapshot.has(field):
			return false
		var value: Variant = snapshot[field]
		if kind == &"machine" and not _fsm_scalar_valid(field, value, true):
			return false
		if kind == &"state" and not _fsm_scalar_valid(field, value, false):
			return false
		current[field] = target.get(field)
		if current[field] != value:
			changed = true
		draft.set(field, value)
	if kind == &"machine" and not _fsm_valid_initial(
			machine_draft, machine_draft.initial_state_id
	):
		return false
	if kind == &"state" and not state_draft.enabled \
			and machine_draft.initial_state_id == state_id:
		return false
	if kind == &"transition":
		var proposed: FlowStateTransitionDefinition = draft as FlowStateTransitionDefinition
		for field: StringName in fields:
			if not _fsm_transition_value_valid(machine_draft, proposed, field, snapshot[field]):
				return false
	if not changed:
		return false
	var machines: Array = graph.state_machines.duplicate()
	var machine_index: int = _find_index(machines, machine_id)
	if machine_index < 0:
		return false
	machines[machine_index] = machine_draft
	if not _fsm_candidate_accepted(graph, machines):
		return false

	_undo_redo.create_action(
		"Revert Potok %s" % String(kind).capitalize(),
		UndoRedo.MERGE_DISABLE, controller, false, true
	)
	_undo_redo.add_do_method(
		self, &"_assign_fsm_snapshot", controller, target, snapshot.duplicate(true)
	)
	_undo_redo.add_undo_method(
		self, &"_assign_fsm_snapshot", controller, target, current
	)
	_undo_redo.commit_action()
	return true


func _assign_fsm_snapshot(
		controller: PVController, target: Resource, values: Dictionary
) -> void:
	if not is_instance_valid(controller) or target == null:
		return
	for field: Variant in values:
		target.set(StringName(field), values[field])
	target.emit_changed()
	controller.notify_property_list_changed()
	_refresh_diagnostics(controller.flow_graph)
	changed.emit()


## Potok 7F-1A: add one catalog block to an explicitly named authored phase.
## Update is the inherited FlowBlockContainer.blocks property; Enter and Exit
## are distinct stored arrays. Never infer phase from position or display name.
func add_fsm_phase_block_by_authoring_id(
		controller: PVController, machine_id: String, state_id: String,
		phase: StringName, authoring_id: String
) -> String:
	var property_name: StringName = _fsm_phase_property(phase)
	if property_name.is_empty() or authoring_id.is_empty():
		return ""
	# Resolve ownership before invoking the catalog factory or registering Undo.
	var context: Dictionary = _fsm_edge_context(controller, machine_id, state_id)
	if context.is_empty():
		return ""
	var machine: FlowStateMachineDefinition = context["machine"]
	var state: FlowStateDefinition = context["state"]
	var current: Array[FlowBlock] = []
	current.assign(state.get(property_name))
	var new_block: FlowBlock = _create_authoring_block(authoring_id)
	if new_block == null:
		return ""
	new_block.display_name = _first_available_block_display_name(current, new_block)
	var updated: Array[FlowBlock] = current.duplicate()
	updated.append(new_block)

	# Detached state -> machine -> graph candidate, no mutation of the live model.
	var draft: FlowStateDefinition = state.duplicate(false) as FlowStateDefinition
	if draft == null or draft.get_internal_id() != state_id:
		return ""
	draft.set(property_name, updated)
	var states: Array[FlowStateDefinition] = []
	states.assign(machine.states)
	states[int(context["state_index"])] = draft
	if not _fsm_structure_candidate(
			controller.flow_graph, machine, states, machine.initial_state_id
	):
		return ""

	_undo_redo.create_action(
		"Add Potok %s Block" % String(phase).capitalize(),
		UndoRedo.MERGE_DISABLE, controller, false, true
	)
	_undo_redo.add_do_method(
		self, &"_fsm_assign_phase_blocks", controller, state, property_name, updated
	)
	_undo_redo.add_undo_method(
		self, &"_fsm_assign_phase_blocks", controller, state, property_name, current
	)
	_undo_redo.commit_action()
	return new_block.get_internal_id()


## Potok 7F-1C2C: delete exactly one owned phase block.
## Null holes are preserved as authored slots; a deletion does not replace
## its target with a new hole. No UI confirmation is bypassed here: the caller
## must obtain that confirmation in the later Fluo integration microblock.
func delete_fsm_phase_block(
		controller: PVController, machine_id: String, state_id: String,
		phase: StringName, block_id: String
) -> bool:
	var property_name: StringName = _fsm_phase_property(phase)
	if property_name.is_empty() or block_id.is_empty():
		return false
	var context: Dictionary = _fsm_edge_context(controller, machine_id, state_id)
	if context.is_empty():
		return false
	var machine: FlowStateMachineDefinition = context["machine"]
	var state: FlowStateDefinition = context["state"]
	var original: Array[FlowBlock] = []
	original.assign(state.get(property_name))
	var index: int = -1
	for i: int in original.size():
		var candidate: FlowBlock = original[i]
		if candidate != null and candidate.get_internal_id() == block_id:
			index = i
			break
	if index < 0:
		return false
	var updated: Array[FlowBlock] = original.duplicate()
	updated.remove_at(index)
	# Validate a detached candidate before registering an undo action or
	# changing the live state. Only one phase array can be affected.
	var draft: FlowStateDefinition = state.duplicate(false) as FlowStateDefinition
	if draft == null or draft.get_internal_id() != state_id:
		return false
	draft.set(property_name, updated)
	var states: Array[FlowStateDefinition] = []
	states.assign(machine.states)
	states[int(context["state_index"])] = draft
	if not _fsm_structure_candidate(
			controller.flow_graph, machine, states, machine.initial_state_id
	):
		return false
	_undo_redo.create_action(
		"Delete Potok %s Block" % String(phase).capitalize(),
		UndoRedo.MERGE_DISABLE, controller, false, true
	)
	_undo_redo.add_do_method(
		self, &"_fsm_assign_phase_blocks", controller, state, property_name, updated
	)
	_undo_redo.add_undo_method(
		self, &"_fsm_assign_phase_blocks", controller, state, property_name, original
	)
	_undo_redo.commit_action()
	return true


## Potok 7F-1C2B: duplicate one block within its exact owner phase.
## Uses the model's deep copy with a fresh persistent ID and retains SDK script.
func duplicate_fsm_phase_block(
		controller: PVController, machine_id: String, state_id: String,
		phase: StringName, block_id: String
) -> String:
	var property_name: StringName = _fsm_phase_property(phase)
	if property_name.is_empty() or block_id.is_empty():
		return ""
	var context: Dictionary = _fsm_edge_context(controller, machine_id, state_id)
	if context.is_empty():
		return ""
	var machine: FlowStateMachineDefinition = context["machine"]
	var state: FlowStateDefinition = context["state"]
	var original: Array[FlowBlock] = []
	original.assign(state.get(property_name))
	var index: int = -1
	for i: int in original.size():
		var candidate: FlowBlock = original[i]
		if candidate != null and candidate.get_internal_id() == block_id:
			index = i
			break
	if index < 0:
		return ""
	var source: FlowBlock = original[index]
	var copied: FlowBlock = source.duplicate_with_new_id()
	if copied == null or copied == source or copied.get_internal_id().is_empty() \
			or copied.get_internal_id() == block_id:
		return ""
	# Preserve user-supplied names as the base and choose a unique local copy name.
	var base_name: String = _block_display_name(source).strip_edges() + " Copy"
	var candidate_name: String = base_name
	var suffix: int = 2
	var used: Dictionary[String, bool] = {}
	for block: FlowBlock in original:
		if block != null:
			used[_block_display_name(block)] = true
	while used.has(candidate_name):
		candidate_name = "%s %d" % [base_name, suffix]
		suffix += 1
	copied.display_name = candidate_name
	# Deep copy must not retain the original object's external script pointer as
	# a different package. Resource.duplicate(true) already preserves the script.
	if source.get_script() != copied.get_script():
		return ""
	var updated: Array[FlowBlock] = original.duplicate()
	updated.insert(index + 1, copied)
	var draft: FlowStateDefinition = state.duplicate(false) as FlowStateDefinition
	if draft == null or draft.get_internal_id() != state_id:
		return ""
	draft.set(property_name, updated)
	var states: Array[FlowStateDefinition] = []
	states.assign(machine.states)
	states[int(context["state_index"])] = draft
	if not _fsm_structure_candidate(
			controller.flow_graph, machine, states, machine.initial_state_id
	):
		return ""
	_undo_redo.create_action(
		"Duplicate Potok %s Block" % String(phase).capitalize(),
		UndoRedo.MERGE_DISABLE, controller, false, true
	)
	_undo_redo.add_do_method(
		self, &"_fsm_assign_phase_blocks", controller, state, property_name, updated
	)
	_undo_redo.add_undo_method(
		self, &"_fsm_assign_phase_blocks", controller, state, property_name, original
	)
	_undo_redo.commit_action()
	return copied.get_internal_id()


## Potok 7F-1C2A: adjacent Move in one explicitly owned phase.
## Deliberate null slots are barriers, never silently compacted or skipped.
func move_fsm_phase_block(
		controller: PVController, machine_id: String, state_id: String,
		phase: StringName, block_id: String, direction: int
) -> bool:
	var property_name: StringName = _fsm_phase_property(phase)
	if property_name.is_empty() or block_id.is_empty() \
			or direction not in [-1, 1]:
		return false
	var context: Dictionary = _fsm_edge_context(controller, machine_id, state_id)
	if context.is_empty():
		return false
	var machine: FlowStateMachineDefinition = context["machine"]
	var state: FlowStateDefinition = context["state"]
	var original: Array[FlowBlock] = []
	original.assign(state.get(property_name))
	var index: int = -1
	for i: int in original.size():
		var block: FlowBlock = original[i]
		if block != null and block.get_internal_id() == block_id:
			index = i
			break
	if index < 0:
		return false
	var neighbor: int = index + direction
	if neighbor < 0 or neighbor >= original.size() or original[neighbor] == null:
		return false
	var updated: Array[FlowBlock] = original.duplicate()
	updated[index] = original[neighbor]
	updated[neighbor] = original[index]
	var draft: FlowStateDefinition = state.duplicate(false) as FlowStateDefinition
	if draft == null or draft.get_internal_id() != state_id:
		return false
	draft.set(property_name, updated)
	var states: Array[FlowStateDefinition] = []
	states.assign(machine.states)
	states[int(context["state_index"])] = draft
	if not _fsm_structure_candidate(
			controller.flow_graph, machine, states, machine.initial_state_id
	):
		return false
	_undo_redo.create_action(
		"Move Potok %s Block" % String(phase).capitalize(),
		UndoRedo.MERGE_DISABLE, controller, false, true
	)
	_undo_redo.add_do_method(
		self, &"_fsm_assign_phase_blocks", controller, state, property_name, updated
	)
	_undo_redo.add_undo_method(
		self, &"_fsm_assign_phase_blocks", controller, state, property_name, original
	)
	_undo_redo.commit_action()
	return true


## 7F-1C1C: edit a single authored FSM block in its exact owned phase.
## Reuse the existing property restrictions and UndoRedo boundary, never Ready lookup.
func set_fsm_phase_block_property_live(
		controller: PVController, machine_id: String, state_id: String,
		phase: StringName, block_id: String, property_name: StringName,
		value: Variant
) -> bool:
	var target: FlowBlock = _fsm_owned_phase_block(
		controller, machine_id, state_id, phase, block_id
	)
	if target == null:
		return false
	var supported: bool = (property_name == &"display_name" and value is String
		and not String(value).strip_edges().is_empty()) \
		or (property_name == &"enabled" and value is bool) \
		or (target is FlowPrintBlock and property_name == &"text" and value is String)
	if not supported:
		return false
	return _fsm_commit_phase_block_property(
		controller, machine_id, state_id, phase, target, property_name, value
	)


func set_fsm_phase_block_descriptor_live(
		controller: PVController, machine_id: String, state_id: String,
		phase: StringName, block_id: String, descriptor: FlowBlockPropertyDescriptor,
		value: Variant
) -> bool:
	var block: FlowBlock = _fsm_owned_phase_block(
		controller, machine_id, state_id, phase, block_id
	)
	if block == null or descriptor == null or not descriptor.editable \
			or not descriptor.is_generic_candidate() \
			or not _descriptor_matches_target(block, descriptor, value):
		return false
	if _authoring_context == null:
		_authoring_context = FLOW_EDITOR_BLOCK_AUTHORING_CONTEXT_SCRIPT.new() as RefCounted
	if not _authoring_context.has_method(&"describe_block_properties"):
		return false
	var projection: FlowBlockPropertyCatalogResult = _authoring_context.call(
		&"describe_block_properties", block
	) as FlowBlockPropertyCatalogResult
	if projection == null:
		return false
	var approved: bool = false
	for current: FlowBlockPropertyDescriptor in projection.descriptors:
		if current != null and current.property_name == descriptor.property_name \
				and current.model_type == descriptor.model_type \
				and current.presentation_kind == descriptor.presentation_kind \
				and current.editable and current.is_generic_candidate():
			approved = true
			break
	if not approved:
		return false
	return _fsm_commit_phase_block_property(
		controller, machine_id, state_id, phase, block, descriptor.property_name, value
	)


func _fsm_owned_phase_block(
		controller: PVController, machine_id: String, state_id: String,
		phase: StringName, block_id: String
) -> FlowBlock:
	if not _can_edit_fsm_scalar(controller) or block_id.is_empty() \
			or _fsm_phase_property(phase).is_empty():
		return null
	var context: Dictionary = _fsm_edge_context(controller, machine_id, state_id)
	if context.is_empty():
		return null
	var state: FlowStateDefinition = context["state"]
	var blocks: Array[FlowBlock] = []
	blocks.assign(state.get(_fsm_phase_property(phase)))
	for candidate: FlowBlock in blocks:
		if candidate != null and candidate.get_internal_id() == block_id:
			return candidate
	return null


func _fsm_commit_phase_block_property(
		controller: PVController, machine_id: String, state_id: String,
		phase: StringName, block: FlowBlock, property_name: StringName,
		value: Variant
) -> bool:
	if block.get(property_name) == value:
		return false
	var context: Dictionary = _fsm_edge_context(controller, machine_id, state_id)
	if context.is_empty():
		return false
	var machine: FlowStateMachineDefinition = context["machine"]
	var state: FlowStateDefinition = context["state"]
	var property_of_phase: StringName = _fsm_phase_property(phase)
	var candidate_block: FlowBlock = block.duplicate(false) as FlowBlock
	var candidate_state: FlowStateDefinition = state.duplicate(false) as FlowStateDefinition
	if candidate_block == null or candidate_state == null \
			or candidate_block.get_internal_id() != block.get_internal_id() \
			or candidate_state.get_internal_id() != state_id:
		return false
	candidate_block.set(property_name, value)
	var blocks: Array[FlowBlock] = []
	blocks.assign(state.get(property_of_phase))
	var found: bool = false
	for index: int in blocks.size():
		if blocks[index] == block:
			blocks[index] = candidate_block
			found = true
			break
	if not found:
		return false
	candidate_state.set(property_of_phase, blocks)
	var states: Array[FlowStateDefinition] = []
	states.assign(machine.states)
	states[int(context["state_index"])] = candidate_state
	if not _fsm_structure_candidate(
			controller.flow_graph, machine, states, machine.initial_state_id
	):
		return false
	# Each accepted edit is a single atomic action. No stale callback may author
	# a sibling state because identity and ownership were resolved above.
	_undo_redo.create_action(
		"Edit Potok Block %s" % String(property_name),
		UndoRedo.MERGE_DISABLE, controller, false, true
	)
	_undo_redo.add_do_method(
		self, &"_assign_ready_property_live", controller, block, property_name, value
	)
	_undo_redo.add_undo_method(
		self, &"_assign_ready_property_live", controller, block, property_name,
		block.get(property_name)
	)
	_undo_redo.commit_action()
	return true


## 7F-1C1D: atomic Revertir for properties actually owned by the phase Flusso.
func restore_fsm_phase_block_snapshot(
		controller: PVController, machine_id: String, state_id: String,
		phase: StringName, block_id: String, snapshot: Dictionary
) -> bool:
	var block: FlowBlock = _fsm_owned_phase_block(
		controller, machine_id, state_id, phase, block_id
	)
	if block == null or snapshot.is_empty():
		return false
	var owned: Dictionary = {}
	owned[&"display_name"] = true
	owned[&"enabled"] = true
	if block is FlowPrintBlock:
		owned[&"text"] = true
	if _authoring_context == null:
		_authoring_context = FLOW_EDITOR_BLOCK_AUTHORING_CONTEXT_SCRIPT.new() as RefCounted
	if _authoring_context.has_method(&"describe_block_properties"):
		var result: FlowBlockPropertyCatalogResult = _authoring_context.call(
			&"describe_block_properties", block
		) as FlowBlockPropertyCatalogResult
		if result != null:
			for descriptor: FlowBlockPropertyDescriptor in result.descriptors:
				if descriptor != null and descriptor.editable \
						and descriptor.is_generic_candidate() \
						and not descriptor.is_structured_document_candidate():
					owned[descriptor.property_name] = true
	var original: Dictionary = {}
	var candidate: FlowBlock = block.duplicate(false) as FlowBlock
	if candidate == null or candidate.get_internal_id() != block_id:
		return false
	var different: bool = false
	for key: Variant in snapshot:
		var property_name: StringName = StringName(key)
		var value: Variant = snapshot[key]
		if not owned.has(property_name):
			return false
		var supported: bool = (property_name == &"display_name"
			and value is String and not String(value).strip_edges().is_empty()) \
			or (property_name == &"enabled" and value is bool) \
			or (property_name == &"text" and block is FlowPrintBlock and value is String)
		if not supported:
			var descriptor_ok: bool = false
			if _authoring_context.has_method(&"describe_block_properties"):
				var result: FlowBlockPropertyCatalogResult = _authoring_context.call(
					&"describe_block_properties", block
				) as FlowBlockPropertyCatalogResult
				if result != null:
					for descriptor: FlowBlockPropertyDescriptor in result.descriptors:
						if descriptor != null and descriptor.property_name == property_name \
								and descriptor.editable and descriptor.is_generic_candidate() \
								and not descriptor.is_structured_document_candidate() \
								and _descriptor_matches_target(block, descriptor, value):
							descriptor_ok = true
							break
			if not descriptor_ok:
				return false
		original[property_name] = block.get(property_name)
		candidate.set(property_name, value)
		if original[property_name] != value:
			different = true
	if not different:
		return false
	var context: Dictionary = _fsm_edge_context(controller, machine_id, state_id)
	if context.is_empty():
		return false
	var machine: FlowStateMachineDefinition = context["machine"]
	var state: FlowStateDefinition = context["state"]
	var candidate_state: FlowStateDefinition = state.duplicate(false) as FlowStateDefinition
	if candidate_state == null:
		return false
	var blocks: Array[FlowBlock] = []
	var phase_property: StringName = _fsm_phase_property(phase)
	blocks.assign(state.get(phase_property))
	var found: bool = false
	for i: int in blocks.size():
		if blocks[i] == block:
			blocks[i] = candidate
			found = true
			break
	if not found:
		return false
	candidate_state.set(phase_property, blocks)
	var states: Array[FlowStateDefinition] = []
	states.assign(machine.states)
	states[int(context["state_index"])] = candidate_state
	if not _fsm_structure_candidate(
			controller.flow_graph, machine, states, machine.initial_state_id
	):
		return false
	_undo_redo.create_action(
		"Revert Potok Phase Block", UndoRedo.MERGE_DISABLE, controller, false, true
	)
	_undo_redo.add_do_method(
		self, &"_assign_ready_snapshot", controller, block, snapshot
	)
	_undo_redo.add_undo_method(
		self, &"_assign_ready_snapshot", controller, block, original
	)
	_undo_redo.commit_action()
	return true


func _fsm_phase_property(phase: StringName) -> StringName:
	match phase:
		&"enter":
			return &"enter_blocks"
		&"update":
			return &"blocks"
		&"exit":
			return &"exit_blocks"
	return &""


func _fsm_assign_phase_blocks(
		controller: PVController, state: FlowStateDefinition,
		property_name: StringName, blocks: Array[FlowBlock]
) -> void:
	if not is_instance_valid(controller) or state == null:
		return
	state.set(property_name, blocks.duplicate())
	state.emit_changed()
	controller.notify_property_list_changed()
	_refresh_diagnostics(controller.flow_graph)
	changed.emit()


## Potok 7C-2B: structural authoring on stable state IDs.
func add_fsm_state(controller: PVController, machine_id: String) -> String:
	var machine: FlowStateMachineDefinition = _fsm_structure_machine(controller, machine_id)
	if machine == null:
		return ""
	var state := FlowStateDefinition.new()
	var updated: Array[FlowStateDefinition] = []
	updated.assign(machine.states)
	updated.append(state)
	var first_id: String = machine.initial_state_id
	if first_id.is_empty():
		first_id = state.get_internal_id()
	if not _fsm_structure_candidate(controller.flow_graph, machine, updated, first_id):
		return ""
	_fsm_commit_states(controller, machine, updated, first_id, "Add Potok State")
	return state.get_internal_id()


func duplicate_fsm_state(controller: PVController, machine_id: String, state_id: String) -> String:
	var machine: FlowStateMachineDefinition = _fsm_structure_machine(controller, machine_id)
	if machine == null or state_id.is_empty():
		return ""
	var index: int = _fsm_state_index(machine.states, state_id)
	if index < 0:
		return ""
	var original: FlowStateDefinition = machine.states[index]
	var copied: FlowStateDefinition = original.duplicate_state_with_new_ids()
	if copied == null or copied.get_internal_id() == state_id:
		return ""
	# The new source's own self-loop must continue to refer to itself.
	for edge: FlowStateTransitionDefinition in copied.transitions:
		if edge != null and edge.target_state_id == state_id:
			edge.target_state_id = copied.get_internal_id()
	var updated: Array[FlowStateDefinition] = []
	updated.assign(machine.states)
	updated.insert(index + 1, copied)
	if not _fsm_structure_candidate(controller.flow_graph, machine, updated, machine.initial_state_id):
		return ""
	_fsm_commit_states(controller, machine, updated, machine.initial_state_id, "Duplicate Potok State")
	return copied.get_internal_id()


func move_fsm_state(
		controller: PVController, machine_id: String, state_id: String, direction: int
) -> bool:
	var machine: FlowStateMachineDefinition = _fsm_structure_machine(controller, machine_id)
	if machine == null or direction == 0:
		return false
	var index: int = _fsm_state_index(machine.states, state_id)
	var next: int = index + (1 if direction > 0 else -1)
	if index < 0 or next < 0 or next >= machine.states.size():
		return false
	var updated: Array[FlowStateDefinition] = []
	updated.assign(machine.states)
	var displaced: FlowStateDefinition = updated[next]
	updated[next] = updated[index]
	updated[index] = displaced
	if not _fsm_structure_candidate(controller.flow_graph, machine, updated, machine.initial_state_id):
		return false
	_fsm_commit_states(controller, machine, updated, machine.initial_state_id, "Move Potok State")
	return true


## Read-only dependency preview: incoming edges from all surviving states,
## including disabled states or edges. An outgoing self-loop is not a blocker.
func get_fsm_state_deletion_dependencies(
		controller: PVController, machine_id: String, state_id: String
) -> Array[String]:
	var result: Array[String] = []
	var machine: FlowStateMachineDefinition = _fsm_structure_machine(controller, machine_id)
	if machine == null or _fsm_state_index(machine.states, state_id) < 0:
		return result
	for owner: FlowStateDefinition in machine.states:
		if owner == null or owner.get_internal_id() == state_id:
			continue
		for edge: FlowStateTransitionDefinition in owner.transitions:
			if edge != null and edge.target_state_id == state_id:
				result.append(owner.display_name + " · " + edge.display_name)
	return result


func delete_fsm_state(controller: PVController, machine_id: String, state_id: String) -> bool:
	var machine: FlowStateMachineDefinition = _fsm_structure_machine(controller, machine_id)
	if machine == null:
		return false
	var index: int = _fsm_state_index(machine.states, state_id)
	if index < 0 or not get_fsm_state_deletion_dependencies(controller, machine_id, state_id).is_empty():
		return false
	var updated: Array[FlowStateDefinition] = []
	updated.assign(machine.states)
	updated.remove_at(index)
	var initial_id: String = machine.initial_state_id
	if initial_id == state_id:
		initial_id = ""
		for survivor: FlowStateDefinition in updated:
			if survivor != null and survivor.enabled:
				initial_id = survivor.get_internal_id()
				break
		if initial_id.is_empty():
			for survivor: FlowStateDefinition in updated:
				if survivor != null:
					return false
	if not _fsm_structure_candidate(controller.flow_graph, machine, updated, initial_id):
		return false
	_fsm_commit_states(controller, machine, updated, initial_id, "Delete Potok State")
	return true


func _fsm_structure_machine(controller: PVController, machine_id: String) -> FlowStateMachineDefinition:
	if not _can_edit_fsm_scalar(controller) or machine_id.is_empty():
		return null
	return _find_resource(
		controller.flow_graph, Collection.STATE_MACHINES, machine_id
	) as FlowStateMachineDefinition


func _fsm_state_index(states: Array[FlowStateDefinition], state_id: String) -> int:
	for index: int in states.size():
		var state: FlowStateDefinition = states[index]
		if state != null and state.get_internal_id() == state_id:
			return index
	return -1


func _fsm_structure_candidate(
		graph: FlowGraph, machine: FlowStateMachineDefinition,
		states: Array[FlowStateDefinition], initial_id: String
) -> bool:
	var draft: FlowStateMachineDefinition = machine.duplicate(false) as FlowStateMachineDefinition
	if draft == null or draft.get_internal_id() != machine.get_internal_id():
		return false
	draft.states = states
	draft.initial_state_id = initial_id
	var machines: Array = graph.state_machines.duplicate()
	var index: int = _find_index(machines, machine.get_internal_id())
	if index < 0:
		return false
	machines[index] = draft
	return _fsm_candidate_accepted(graph, machines)


func _fsm_commit_states(
		controller: PVController, machine: FlowStateMachineDefinition,
		states: Array[FlowStateDefinition], initial_id: String, label: String
) -> void:
	var previous: Array[FlowStateDefinition] = []
	previous.assign(machine.states)
	var previous_initial: String = machine.initial_state_id
	_undo_redo.create_action(label, UndoRedo.MERGE_DISABLE, controller, false, true)
	_undo_redo.add_do_method(
		self, &"_fsm_assign_states", controller, machine, states, initial_id
	)
	_undo_redo.add_undo_method(
		self, &"_fsm_assign_states", controller, machine, previous, previous_initial
	)
	_undo_redo.commit_action()


func _fsm_assign_states(
		controller: PVController, machine: FlowStateMachineDefinition,
		states: Array[FlowStateDefinition], initial_id: String
) -> void:
	if not is_instance_valid(controller) or machine == null:
		return
	machine.states = states.duplicate()
	machine.initial_state_id = initial_id
	machine.emit_changed()
	controller.notify_property_list_changed()
	_refresh_diagnostics(controller.flow_graph)
	changed.emit()


## Potok 7C-2B: transition structure belongs to one authored state.
func add_fsm_transition(controller: PVController, machine_id: String, state_id: String) -> String:
	var context: Dictionary = _fsm_edge_context(controller, machine_id, state_id)
	if context.is_empty():
		return ""
	var source: FlowStateDefinition = context["state"]
	var machine: FlowStateMachineDefinition = context["machine"]
	var edge := FlowStateTransitionDefinition.new()
	edge.trigger = FlowStateTransitionDefinition.Trigger.EVENT
	edge.event_name = &"event"
	edge.target_state_id = state_id
	var updated: Array[FlowStateTransitionDefinition] = []
	updated.assign(source.transitions)
	updated.append(edge)
	if not _fsm_edge_candidate(controller.flow_graph, machine, source, updated):
		return ""
	_fsm_commit_edges(controller, source, updated, "Add Potok Transition")
	return edge.get_internal_id()


func duplicate_fsm_transition(
		controller: PVController, machine_id: String, state_id: String, transition_id: String
) -> String:
	var context: Dictionary = _fsm_edge_context(controller, machine_id, state_id)
	if context.is_empty():
		return ""
	var source: FlowStateDefinition = context["state"]
	var index: int = _fsm_edge_index(source.transitions, transition_id)
	if index < 0:
		return ""
	var copied: FlowStateTransitionDefinition = source.transitions[index].duplicate_with_new_id()
	if copied == null or copied.get_internal_id() == transition_id:
		return ""
	var updated: Array[FlowStateTransitionDefinition] = []
	updated.assign(source.transitions)
	updated.insert(index + 1, copied)
	if not _fsm_edge_candidate(controller.flow_graph, context["machine"], source, updated):
		return ""
	_fsm_commit_edges(controller, source, updated, "Duplicate Potok Transition")
	return copied.get_internal_id()


func move_fsm_transition(
		controller: PVController, machine_id: String, state_id: String,
		transition_id: String, direction: int
) -> bool:
	var context: Dictionary = _fsm_edge_context(controller, machine_id, state_id)
	if context.is_empty() or direction == 0:
		return false
	var source: FlowStateDefinition = context["state"]
	var index: int = _fsm_edge_index(source.transitions, transition_id)
	var next: int = index + (1 if direction > 0 else -1)
	if index < 0 or next < 0 or next >= source.transitions.size():
		return false
	var updated: Array[FlowStateTransitionDefinition] = []
	updated.assign(source.transitions)
	var displaced: FlowStateTransitionDefinition = updated[next]
	updated[next] = updated[index]
	updated[index] = displaced
	if not _fsm_edge_candidate(controller.flow_graph, context["machine"], source, updated):
		return false
	_fsm_commit_edges(controller, source, updated, "Move Potok Transition")
	return true


func delete_fsm_transition(
		controller: PVController, machine_id: String, state_id: String, transition_id: String
) -> bool:
	var context: Dictionary = _fsm_edge_context(controller, machine_id, state_id)
	if context.is_empty():
		return false
	var source: FlowStateDefinition = context["state"]
	var index: int = _fsm_edge_index(source.transitions, transition_id)
	if index < 0:
		return false
	var updated: Array[FlowStateTransitionDefinition] = []
	updated.assign(source.transitions)
	updated.remove_at(index)
	if not _fsm_edge_candidate(controller.flow_graph, context["machine"], source, updated):
		return false
	_fsm_commit_edges(controller, source, updated, "Delete Potok Transition")
	return true


func _fsm_edge_context(
		controller: PVController, machine_id: String, state_id: String
) -> Dictionary:
	var machine: FlowStateMachineDefinition = _fsm_structure_machine(controller, machine_id)
	if machine == null or state_id.is_empty():
		return {}
	var index: int = _fsm_state_index(machine.states, state_id)
	if index < 0:
		return {}
	return {"machine": machine, "state": machine.states[index], "state_index": index}


func _fsm_edge_index(edges: Array[FlowStateTransitionDefinition], edge_id: String) -> int:
	if edge_id.is_empty():
		return -1
	for index: int in edges.size():
		var edge: FlowStateTransitionDefinition = edges[index]
		if edge != null and edge.get_internal_id() == edge_id:
			return index
	return -1


func _fsm_edge_candidate(
		graph: FlowGraph, machine: FlowStateMachineDefinition,
		source: FlowStateDefinition, edges: Array[FlowStateTransitionDefinition]
) -> bool:
	var source_draft: FlowStateDefinition = source.duplicate(false) as FlowStateDefinition
	if source_draft == null or source_draft.get_internal_id() != source.get_internal_id():
		return false
	source_draft.transitions = edges
	var states: Array[FlowStateDefinition] = []
	states.assign(machine.states)
	var index: int = _fsm_state_index(states, source.get_internal_id())
	if index < 0:
		return false
	states[index] = source_draft
	return _fsm_structure_candidate(graph, machine, states, machine.initial_state_id)


func _fsm_commit_edges(
		controller: PVController, source: FlowStateDefinition,
		edges: Array[FlowStateTransitionDefinition], label: String
) -> void:
	var previous: Array[FlowStateTransitionDefinition] = []
	previous.assign(source.transitions)
	_undo_redo.create_action(label, UndoRedo.MERGE_DISABLE, controller, false, true)
	_undo_redo.add_do_method(self, &"_fsm_assign_edges", controller, source, edges)
	_undo_redo.add_undo_method(self, &"_fsm_assign_edges", controller, source, previous)
	_undo_redo.commit_action()


func _fsm_assign_edges(
		controller: PVController, source: FlowStateDefinition,
		edges: Array[FlowStateTransitionDefinition]
) -> void:
	if not is_instance_valid(controller) or source == null:
		return
	source.transitions = edges.duplicate()
	source.emit_changed()
	controller.notify_property_list_changed()
	_refresh_diagnostics(controller.flow_graph)
	changed.emit()


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
	var existing_errors: Dictionary[String, int] = _diagnostic_counts(
		FlowGraphValidator.validate(graph).diagnostics
	)
	var validation: FlowValidationResult = FlowGraphValidator.validate(_candidate_with_collection(graph, collection, updated))
	_last_diagnostics = validation.diagnostics.duplicate()
	for diagnostic: FlowDiagnostic in validation.diagnostics:
		if diagnostic.severity == FlowDiagnostic.Severity.ERROR:
			var diagnostic_key: String = _diagnostic_identity(diagnostic)
			var existing_count: int = existing_errors.get(diagnostic_key, 0)
			if existing_count > 0:
				existing_errors[diagnostic_key] = existing_count - 1
				continue
			if collection == Collection.METHODS and diagnostic.code == &"missing_method_reference" and diagnostic.related_id == internal_id:
				continue
			emit_signal(&"changed")
			return false

	_commit_collection("Delete %s" % _resource_action_name(collection, resource), controller, collection, updated)
	return true


func _diagnostic_counts(diagnostics: Array[FlowDiagnostic]) -> Dictionary[String, int]:
	var counts: Dictionary[String, int] = {}
	for diagnostic: FlowDiagnostic in diagnostics:
		if diagnostic.severity != FlowDiagnostic.Severity.ERROR:
			continue
		var key: String = _diagnostic_identity(diagnostic)
		counts[key] = counts.get(key, 0) + 1
	return counts


func _diagnostic_identity(diagnostic: FlowDiagnostic) -> String:
	# Paths may shift when an earlier collection entry is removed; stable diagnostic
	# content and related identity distinguish an existing defect from a new one.
	return "%s\u001f%s\u001f%s" % [diagnostic.code, diagnostic.related_id, diagnostic.message]


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


func find_block_container(controller: PVController, internal_id: String) -> FlowBlockContainer:
	if not is_instance_valid(controller) or _undo_redo == null or internal_id.is_empty():
		return null
	var graph: FlowGraph = controller.flow_graph
	if graph == null or graph.schema_version != FlowGraph.SCHEMA_VERSION_3 or not graph.containers.is_empty():
		return null
	if graph.constructor != null and graph.constructor.get_internal_id() == internal_id:
		return graph.constructor
	for method: FlowMethodDefinition in graph.methods:
		if method != null and method.get_internal_id() == internal_id:
			return method
	return find_ready_process(controller, internal_id)


func add_timer(controller: PVController) -> String:
	if not is_instance_valid(controller) or controller.flow_graph == null \
			or controller.flow_graph.schema_version != FlowGraph.SCHEMA_VERSION_3:
		return ""
	var values: Array = controller.flow_graph.processes.duplicate()
	var timer: FlowTimerDefinition = FlowTimerDefinition.new()
	timer.display_name = _first_available_display_name(_semantic_values(values, SemanticCollection.TIMERS), true)
	values.append(timer)
	_commit_collection("Add Timer", controller, Collection.PROCESSES, values)
	return timer.get_internal_id()


func set_ready_property(controller: PVController, process_id: String, block_id: String, property: StringName, value: Variant) -> bool:
	var process: FlowBlockContainer = find_block_container(controller, process_id)
	if process == null:
		return false
	var target: Resource = process if block_id.is_empty() else _ready_block(process, block_id)
	if target == null or not _is_supported_ready_property(process, target, block_id, property, value):
		return false
	if target.get(property) == value:
		return false
	if target is FlowMethodDefinition and property == &"display_name" and not _valid_method_name(controller.flow_graph, target, value):
		return false
	var action_name: String = "Rename %s Block" % _entry_point_action_name(process) \
		if target is FlowBlock and property == &"display_name" \
		else "Edit %s %s" % [_entry_point_action_name(process), property.capitalize()]
	_commit_ready_property(action_name, controller, target, property, value)
	return true


## Applies continuously edited Flusso values without rebuilding its controls on every keystroke.
## Undo entries are merged per property while the model itself changes immediately.
func set_ready_property_live(
		controller: PVController,
		process_id: String,
	block_id: String,
	property: StringName,
	value: Variant
) -> bool:
	var process: FlowBlockContainer = find_block_container(controller, process_id)
	if process == null:
		return false
	var target: Resource = process if block_id.is_empty() else _ready_block(process, block_id)
	if target == null or not _is_supported_ready_property(process, target, block_id, property, value):
		return false
	if target.get(property) == value:
		return false
	if target is FlowMethodDefinition and property == &"display_name" and not _valid_method_name(controller.flow_graph, target, value):
		return false
	var action_name: String = "Edit Flusso %s" % property.capitalize()
	_undo_redo.create_action(
		action_name,
		UndoRedo.MERGE_ENDS,
		controller,
		false,
		true
	)
	_undo_redo.add_do_method(self, &"_assign_ready_property_live", controller, target, property, value)
	_undo_redo.add_undo_method(
		self,
		&"_assign_ready_property_live",
		controller,
		target,
		property,
		target.get(property)
	)
	_undo_redo.commit_action()
	return true


## Applies a D4 descriptor-backed live edit through the existing undo boundary.
## The descriptor is the accepted property contract; no arbitrary property name
## is allowed to reach the live assignment path.
func set_ready_property_descriptor_live(
		controller: PVController,
		process_id: String,
		block_id: String,
		descriptor: FlowBlockPropertyDescriptor,
		value: Variant
) -> bool:
	var process: FlowBlockContainer = find_block_container(controller, process_id)
	if process == null or descriptor == null or block_id.is_empty() \
			or not descriptor.editable or not descriptor.is_generic_candidate():
		return false
	var target: FlowBlock = _ready_block(process, block_id)
	if target == null or not _descriptor_matches_target(target, descriptor, value):
		return false
	if target.get(descriptor.property_name) == value:
		return false
	var action_name: String = "Edit Flusso %s" % descriptor.property_name
	_undo_redo.create_action(
		action_name,
		UndoRedo.MERGE_ENDS,
		controller,
		false,
		true
	)
	_undo_redo.add_do_method(
		self,
		&"_assign_ready_property_live",
		controller,
		target,
		descriptor.property_name,
		value
	)
	_undo_redo.add_undo_method(
		self,
		&"_assign_ready_property_live",
		controller,
		target,
		descriptor.property_name,
		target.get(descriptor.property_name)
	)
	_undo_redo.commit_action()
	return true


func _descriptor_matches_target(
		target: FlowBlock,
		descriptor: FlowBlockPropertyDescriptor,
		value: Variant
) -> bool:
	if descriptor.property_name.is_empty():
		return false
	var value_matches: bool = typeof(value) == descriptor.model_type
	if descriptor.is_structured_document_candidate():
		value_matches = value is FlowStructuredDocument
	if not value_matches:
		return false
	for raw_property: Variant in target.get_property_list():
		if not raw_property is Dictionary:
			continue
		var property: Dictionary = raw_property as Dictionary
		if StringName(String(property.get("name", ""))) != descriptor.property_name:
			continue
		if int(property.get("type", TYPE_NIL)) != descriptor.model_type:
			return false
		var usage: int = int(property.get("usage", 0))
		return bool(usage & PROPERTY_USAGE_SCRIPT_VARIABLE) \
			and bool(usage & PROPERTY_USAGE_STORAGE) \
			and bool(usage & PROPERTY_USAGE_EDITOR) \
			and not bool(usage & PROPERTY_USAGE_READ_ONLY)
	return false


## Restores the persistent block properties captured when a Flusso session was opened.
func restore_ready_block_snapshot(
	controller: PVController,
	process_id: String,
	block_id: String,
	snapshot: Dictionary
) -> bool:
	var process: FlowBlockContainer = find_block_container(controller, process_id)
	if process == null or snapshot.is_empty():
		return false
	var block: FlowBlock = _ready_block(process, block_id)
	if block == null:
		return false

	var current: Dictionary = {}
	var changed_any: bool = false
	for property_name: Variant in snapshot:
		var key: StringName = StringName(property_name)
		var current_value: Variant = block.get(key)
		current[key] = current_value
		if current_value != snapshot[property_name]:
			changed_any = true
	if not changed_any:
		return false

	_undo_redo.create_action(
		"Revert Flusso Block",
		UndoRedo.MERGE_DISABLE,
		controller,
		false,
		true
	)
	_undo_redo.add_do_method(self, &"_assign_ready_snapshot", controller, block, snapshot)
	_undo_redo.add_undo_method(self, &"_assign_ready_snapshot", controller, block, current)
	_undo_redo.commit_action()
	return true


func _is_supported_ready_property(
	process: FlowBlockContainer,
	target: Resource,
	block_id: String,
	property: StringName,
	value: Variant
) -> bool:
	var allowed: bool = (property == &"enabled" and value is bool) \
		or (block_id.is_empty() and property == &"display_name" and value is String) \
		or (target is FlowBlock and property == &"display_name" and value is String) \
		or (target is FlowTimerDefinition and property == &"repeat" and value is bool) \
		or (target is FlowTimerDefinition and property == &"interval_seconds" and value is float and is_finite(value) and value > 0.0) \
		or (target is FlowPrintBlock and property == &"text" and value is String)
	if target is FlowMethodCallBlock and process is FlowProcess and property == &"method_id" and value is String:
		allowed = true
	return allowed


## Adds a block through the legacy built-in type ID or a stable authoring ID.
## Existing StringName callers remain registry-backed. A String caller is an
## authoring ID, and the optional fourth argument supports an explicit
## authoring ID without requiring a legacy type ID.
func add_ready_block(
		controller: PVController,
		process_id: String,
		block_type_or_authoring_id: Variant,
		authoring_id: String = ""
) -> String:
	var legacy_type_id: StringName = &""
	var resolved_authoring_id: String = authoring_id
	if resolved_authoring_id.is_empty():
		if block_type_or_authoring_id is String:
			resolved_authoring_id = block_type_or_authoring_id as String
		elif block_type_or_authoring_id is StringName:
			var candidate: String = String(block_type_or_authoring_id)
			if candidate.contains(":"):
				resolved_authoring_id = candidate
			else:
				legacy_type_id = block_type_or_authoring_id as StringName
	else:
		legacy_type_id = block_type_or_authoring_id as StringName
	return _add_ready_block(controller, process_id, legacy_type_id, resolved_authoring_id)


## Future authoring controls can supply only the stable catalog identity.
func add_ready_block_by_authoring_id(
		controller: PVController,
		process_id: String,
		authoring_id: String
) -> String:
	return _add_ready_block(controller, process_id, &"", authoring_id)


func _add_ready_block(
		controller: PVController,
		process_id: String,
		legacy_type_id: StringName,
		authoring_id: String
) -> String:
	var process: FlowBlockContainer = find_block_container(controller, process_id)
	if process == null:
		return ""
	var block: FlowBlock = _create_ready_block(legacy_type_id, authoring_id)
	if block == null:
		return ""
	block.display_name = _first_available_block_display_name(process.blocks, block)
	var updated: Array[FlowBlock] = process.blocks.duplicate()
	updated.append(block)
	_commit_ready_property("Add %s %s Block" % [_entry_point_action_name(process), block.display_name], controller, process, &"blocks", updated)
	return block.get_internal_id()


func _create_ready_block(legacy_type_id: StringName, authoring_id: String) -> FlowBlock:
	if not authoring_id.is_empty():
		return _create_authoring_block(authoring_id)
	return FlowBlockRegistry.create(legacy_type_id)


func _create_authoring_block(authoring_id: String) -> FlowBlock:
	if _authoring_context == null:
		_authoring_context = FLOW_EDITOR_BLOCK_AUTHORING_CONTEXT_SCRIPT.new() as RefCounted
	var creation_result: Object = _authoring_context.call(&"create_block", authoring_id) as Object
	if creation_result == null:
		_last_diagnostics = [_authoring_diagnostic(
			AUTHORING_CONTEXT_RESULT_MISSING,
			"The authoring context did not return a creation result.",
			authoring_id
		)]
		return null
	_last_diagnostics = _creation_diagnostics(creation_result)
	if not bool(creation_result.call(&"is_successful")):
		return null
	var block: FlowBlock = creation_result.get(&"block") as FlowBlock
	if block == null:
		_last_diagnostics.append(_authoring_diagnostic(
			AUTHORING_CONTEXT_BLOCK_MISSING,
			"The authoring context returned no block.",
			authoring_id
		))
		return null
	return block


func _creation_diagnostics(creation_result: Object) -> Array[FlowDiagnostic]:
	var diagnostics: Array[FlowDiagnostic] = []
	var raw_diagnostics: Variant = creation_result.get(&"diagnostics")
	if raw_diagnostics is Array:
		for diagnostic: Variant in raw_diagnostics:
			if diagnostic is FlowDiagnostic:
				diagnostics.append(diagnostic as FlowDiagnostic)
	return diagnostics


func _authoring_diagnostic(code: StringName, message: String, authoring_id: String) -> FlowDiagnostic:
	return FlowDiagnostic.new(
		code,
		FlowDiagnostic.Severity.ERROR,
		message,
		"authoring_id",
		authoring_id
	)


func add_method_call(controller: PVController, process_id: String) -> String:
	var process: FlowProcess = find_ready_process(controller, process_id)
	if process == null:
		return ""
	var block: FlowMethodCallBlock = FlowMethodCallBlock.new()
	block.display_name = _first_available_block_display_name(process.blocks, block)
	var updated: Array[FlowBlock] = process.blocks.duplicate()
	updated.append(block)
	_commit_ready_property("Add %s Call Method Block" % _entry_point_action_name(process), controller, process, &"blocks", updated)
	return block.get_internal_id()


func move_ready_block(controller: PVController, process_id: String, block_id: String, direction: int) -> bool:
	var process: FlowBlockContainer = find_block_container(controller, process_id)
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
	var process: FlowBlockContainer = find_block_container(controller, process_id)
	if process == null:
		return false
	var block: FlowBlock = _ready_block(process, block_id)
	if block == null:
		return false
	var updated: Array[FlowBlock] = process.blocks.duplicate()
	updated.remove_at(updated.find(block))
	_commit_ready_property("Delete %s Block" % _entry_point_action_name(process), controller, process, &"blocks", updated)
	return true


func _ready_block(process: FlowBlockContainer, block_id: String) -> FlowBlock:
	for block: FlowBlock in process.blocks:
		if block != null and block.get_internal_id() == block_id:
			return block
	return null


func _commit_ready_property(action: String, controller: PVController, resource: Resource, property: StringName, value: Variant) -> void:
	_undo_redo.create_action(action, UndoRedo.MERGE_DISABLE, controller, false, true)
	_undo_redo.add_do_method(self, &"_assign_ready_property", controller, resource, property, value)
	_undo_redo.add_undo_method(self, &"_assign_ready_property", controller, resource, property, resource.get(property))
	_undo_redo.commit_action()


func _assign_ready_property_live(
	controller: PVController,
	resource: Resource,
	property: StringName,
	value: Variant
) -> void:
	resource.set(property, value)
	resource.emit_changed()
	_refresh_diagnostics(controller.flow_graph)


func _assign_ready_snapshot(controller: PVController, resource: Resource, values: Dictionary) -> void:
	for property_name: Variant in values:
		resource.set(StringName(property_name), values[property_name])
	resource.emit_changed()
	controller.notify_property_list_changed()
	_refresh_diagnostics(controller.flow_graph)
	changed.emit()


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
		Collection.METHODS:
			graph.methods.assign(values)
	if controller != null:
		controller.notify_property_list_changed()
	_refresh_diagnostics(graph)
	emit_signal(&"changed")


func _set_display_name(resource: Resource, display_name: String) -> void:
	_assign_display_name(resource, display_name)
	_refresh_diagnostics_for_resource(resource)
	emit_signal(&"changed")


func _assign_variable_type(
		controller: PVController,
		variable: FlowVariableDefinition,
		value_type: int,
		complex_source: FlowValueSource
) -> void:
	variable.value_type = value_type
	variable.complex_value_source = complex_source
	controller.notify_property_list_changed()
	_refresh_diagnostics(controller.flow_graph)
	emit_signal(&"changed")


func _assign_variable_complex_source(
		controller: PVController,
		variable: FlowVariableDefinition,
		source: FlowValueSource
) -> void:
	variable.complex_value_source = source
	controller.notify_property_list_changed()
	_refresh_diagnostics(controller.flow_graph)
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
	return (collection >= Collection.PROCESSES and collection <= Collection.STATE_MACHINES) \
		or (graph.schema_version == FlowGraph.SCHEMA_VERSION_3 and collection == Collection.METHODS)


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
			return value is int and FlowVariableDefinition.is_valid_variable_value_type(value as int)
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
		Collection.METHODS:
			return graph.methods.duplicate()
	return []


func _semantic_collection_for_collection(collection: Collection) -> int:
	match collection:
		Collection.PROCESSES:
			return SemanticCollection.PROCESSES
		Collection.VARIABLES:
			return SemanticCollection.VARIABLES
		Collection.STATE_MACHINES:
			return SemanticCollection.STATE_MACHINES
		Collection.METHODS:
			return SemanticCollection.METHODS
	return -1


func _semantic_collection_for_resource(resource: Resource) -> int:
	# FlowTimerDefinition is a FlowProcess subtype, so its membership must be
	# resolved first instead of relying on the polymorphic storage collection.
	if resource is FlowTimerDefinition:
		return SemanticCollection.TIMERS
	if resource is FlowProcess:
		return SemanticCollection.PROCESSES
	if resource is FlowVariableDefinition:
		return SemanticCollection.VARIABLES
	if resource is FlowStateMachineDefinition:
		return SemanticCollection.STATE_MACHINES
	if resource is FlowMethodDefinition:
		return SemanticCollection.METHODS
	return -1


func _semantic_values(values: Array, semantic_collection: int) -> Array:
	var members: Array = []
	for value: Variant in values:
		var resource: Resource = value as Resource
		if resource != null and _semantic_collection_for_resource(resource) == semantic_collection:
			members.append(resource)
	return members


func _new_resource(collection: Collection, existing_values: Array, schema_3: bool) -> Resource:
	var resource: Resource = null
	match collection:
		Collection.PROCESSES:
			resource = FlowProcess.new()
		Collection.VARIABLES:
			resource = FlowVariableDefinition.new()
		Collection.STATE_MACHINES:
			resource = FlowStateMachineDefinition.new()
		Collection.METHODS:
			resource = FlowMethodDefinition.new()
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
	return FlowBlockRegistry.default_display_name(block)


func _block_display_name(block: FlowBlock) -> String:
	return block.display_name if not block.display_name.strip_edges().is_empty() else _default_block_display_name(block)


func _resource_action_name(collection: Collection, resource: Resource) -> String:
	if collection == Collection.PROCESSES and resource is FlowTimerDefinition:
		return "Timer"
	return _collection_name(collection)


func _entry_point_action_name(process: FlowBlockContainer) -> String:
	if process is FlowConstructorDefinition:
		return "Constructor"
	if process is FlowMethodDefinition:
		return "Method"
	return "Timer" if process is FlowTimerDefinition else "Ready"


func _valid_method_name(graph: FlowGraph, method: FlowMethodDefinition, value: String) -> bool:
	if value.strip_edges().is_empty():
		return false
	for other: FlowMethodDefinition in graph.methods:
		if other != null and other != method and other.display_name == value:
			return false
	return true


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
		Collection.METHODS:
			candidate.methods.assign(values)
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
		Collection.METHODS:
			return "Method"
	return "Resource"


func _refresh_diagnostics(graph: FlowGraph) -> void:
	if graph == null:
		_last_diagnostics = []
		return
	_last_diagnostics = FlowGraphValidator.validate(graph).diagnostics.duplicate()


func _refresh_diagnostics_for_resource(_resource: Resource) -> void:
	# Resource renames do not affect validation, but the Inspector still refreshes.
	_last_diagnostics = _last_diagnostics.duplicate()
