@tool
extends SceneTree

## Potok 7E-1C: nested Bool Condition Tok with typed event fields persists, packets do not.
const TEMP_DIR: String = "res://.godot/flujo_tests"
const SCENE_PATH: String = TEMP_DIR + "/potok_7e1c_condition_tok_roundtrip.tscn"
const PACKET_SENTINEL: String = "POTOK_PRIVATE_PACKET_NEVER_PERSIST_7E1C"

var failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	for _i: int in 5:
		await process_frame
	while EditorInterface.get_resource_filesystem().is_scanning():
		await process_frame

	var manager: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if not _check(manager != null, "EditorUndoRedoManager available"):
		quit(1)
		return

	var root := Node.new()
	root.name = "Potok7E1CScene"
	get_root().add_child(root)
	var controller := PVController.new()
	controller.name = "ControllerNode"
	root.add_child(controller)
	controller.owner = root

	var graph := FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_3
	graph.constructor = FlowConstructorDefinition.new()
	var idle := FlowStateDefinition.new()
	idle.display_name = "Idle"
	var active := FlowStateDefinition.new()
	active.display_name = "Active"
	var edge := FlowStateTransitionDefinition.new()
	edge.display_name = "Impact condition"
	edge.trigger = FlowStateTransitionDefinition.Trigger.EVENT
	edge.event_name = &"impact"
	edge.target_state_id = active.get_internal_id()
	idle.transitions = [edge]
	var machine := FlowStateMachineDefinition.new()
	machine.display_name = "Typed Condition"
	machine.states = [idle, active]
	machine.initial_state_id = idle.get_internal_id()
	graph.state_machines = [machine]
	controller.flow_graph = graph

	var gid: String = graph.get_internal_id()
	var mid: String = machine.get_internal_id()
	var aid: String = idle.get_internal_id()
	var bid: String = active.get_internal_id()
	var eid: String = edge.get_internal_id()

	var kinds: Array[int] = [
		int(Variant.Type.TYPE_INT), int(Variant.Type.TYPE_BOOL),
		int(Variant.Type.TYPE_FLOAT), int(Variant.Type.TYPE_STRING)
	]
	var fields: Array[String] = ["hp", "active", "ratio", "status"]
	var values: Array = [5, true, 0.5, "ready"]
	var operators: Array[StringName] = [
		FlowConditionOperatorCatalog.OPERATOR_GREATER_THAN,
		FlowConditionOperatorCatalog.OPERATOR_EQUAL,
		FlowConditionOperatorCatalog.OPERATOR_GREATER_OR_EQUAL,
		FlowConditionOperatorCatalog.OPERATOR_EQUAL
	]
	var event_sources: Array[FlowEventPayloadValueSource] = [
		FlowEventPayloadValueSource.new(&"impact", "hp", Variant.Type.TYPE_INT),
		FlowEventPayloadValueSource.new(&"impact", "active", Variant.Type.TYPE_BOOL),
		FlowEventPayloadValueSource.new(&"impact", "ratio", Variant.Type.TYPE_FLOAT),
		FlowEventPayloadValueSource.new(&"impact", "status", Variant.Type.TYPE_STRING)
	]
	var literal_sources: Array[FlowLiteralValueSource] = [
		FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 5),
		FlowLiteralValueSource.new(Variant.Type.TYPE_BOOL, true),
		FlowLiteralValueSource.new(Variant.Type.TYPE_FLOAT, 0.5),
		FlowLiteralValueSource.new(Variant.Type.TYPE_STRING, "ready")
	]
	var comparisons: Array[FlowConditionComparison] = []
	var comparison_ids: Array[String] = []
	var event_ids: Array[String] = []
	var literal_ids: Array[String] = []
	for i: int in 4:
		var comparison := FlowConditionComparison.new(
			operators[i], event_sources[i], literal_sources[i]
		)
		comparisons.append(comparison)
		comparison_ids.append(comparison.comparison_id)
		event_ids.append(event_sources[i].get_source_id())
		literal_ids.append(literal_sources[i].get_source_id())
	var connectors: Array[StringName] = [
		FlowConditionOperatorCatalog.CONNECTOR_AND,
		FlowConditionOperatorCatalog.CONNECTOR_AND,
		FlowConditionOperatorCatalog.CONNECTOR_AND
	]
	var authored := FlowConditionValueSource.new(comparisons, connectors, true)
	var condition_id: String = authored.get_source_id()
	_check(not FlowGraphValidator.validate(graph).has_errors(),
		"Original authored EVENT edge graph validates")
	_check(authored.is_valid(graph), "Composite typed Bool source is valid before authoring")

	var commands := FlowGraphEditorCommands.new(manager)
	var history: UndoRedo = manager.get_history_undo_redo(manager.get_object_history_id(controller))
	_check(commands.set_fsm_transition_property(
		controller, mid, aid, eid, &"condition", authored
	), "Condition Tok is committed through validated Flusso command")
	_check(commands.set_fsm_transition_property(
		controller, mid, aid, eid, &"trigger", FlowStateTransitionDefinition.Trigger.CONDITION
	), "Existing transition switches to CONDITION with atomic action")
	_check(edge.condition == authored and edge.trigger == FlowStateTransitionDefinition.Trigger.CONDITION,
		"Authored condition is live without replacing edge identity")
	_check(_check_semantics(authored, condition_id, comparison_ids, event_ids,
		literal_ids, operators, kinds, fields, values),
		"All four typed operands, comparison IDs, AND connectors and NOT are authored")
	_check(not FlowGraphValidator.validate(graph).has_errors(),
		"Condition transition validates on original graph")

	history.undo()
	history.undo()
	_check(edge.trigger == FlowStateTransitionDefinition.Trigger.EVENT and edge.condition == null,
		"Two Undo actions restore original EVENT source with no condition")
	history.redo()
	history.redo()
	_check(edge.condition == authored and edge.trigger == FlowStateTransitionDefinition.Trigger.CONDITION
		and edge.get_internal_id() == eid and authored.get_source_id() == condition_id,
		"Two Redo actions restore exact same source and transition identities")

	# Only event metadata belongs to authored sources. Values are per-machine-tick data.
	var context := FlowValueResolutionContext.new(graph)
	_check(not authored.resolve(context).success,
		"Without event scope typed operands never read an ambient packet")
	context.begin_event_packet_scope(mid)
	var payload: Dictionary = _packet(false)
	payload["private_note"] = PACKET_SENTINEL
	context.record_event_packet(mid, &"impact", payload)
	var active_result: FlowValueResult = authored.resolve(context)
	_check(active_result.success and active_result.value_type == Variant.Type.TYPE_BOOL
		and active_result.value == true,
		"NOT(typed AND comparisons) resolves true with false active field")

	var dir_result: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(TEMP_DIR)
	)
	_check(dir_result == OK, "Owned persistence test directory available")
	var scene := PackedScene.new()
	var pack_result: Error = scene.pack(root)
	_check(pack_result == OK, "Scene with authored Condition Tok packs")
	var save_result: Error = FAILED
	if dir_result == OK and pack_result == OK:
		save_result = ResourceSaver.save(scene, ProjectSettings.globalize_path(SCENE_PATH))
	_check(save_result == OK, "Typed Condition Tok scene saves to actual .tscn")
	if save_result == OK:
		var source_text: String = FileAccess.get_file_as_string(
			ProjectSettings.globalize_path(SCENE_PATH)
		)
		_check(not source_text.is_empty() and not source_text.contains(PACKET_SENTINEL),
			"Private runtime packet sentinel is absent from serialized scene")
	context.end_event_packet_scope()
	_check(not authored.resolve(context).success,
		"Ending scope invalidates packet resolution in original graph")
	root.free()
	await process_frame

	if save_result == OK:
		var loaded: PackedScene = ResourceLoader.load(
			SCENE_PATH, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE
		) as PackedScene
		if _check(loaded != null, "Scene reloads without resource cache"):
			var instance: Node = loaded.instantiate()
			if _check(instance != null, "Reopened condition scene instantiates"):
				var persisted: PVController = instance.get_node_or_null(
					"ControllerNode"
				) as PVController
				if _check(persisted != null and persisted.flow_graph != null,
						"Reopened PVController owns a persistent graph"):
					var saved_graph: FlowGraph = persisted.flow_graph
					_check(saved_graph.get_internal_id() == gid and
						saved_graph.schema_version == FlowGraph.SCHEMA_VERSION_3,
						"Reopened graph ID and schema remain unchanged")
					if _check(saved_graph.state_machines.size() == 1,
							"Exactly one authored machine reopens"):
						var saved_machine: FlowStateMachineDefinition = saved_graph.state_machines[0]
						_check(saved_machine.get_internal_id() == mid and
							saved_machine.initial_state_id == aid and saved_machine.states.size() == 2,
							"Machine, initial ID and ordered states survive")
						if saved_machine.states.size() == 2:
							var saved_idle: FlowStateDefinition = saved_machine.states[0]
							_check(saved_idle.get_internal_id() == aid and
								saved_machine.states[1].get_internal_id() == bid,
								"State IDs and order survive")
							if _check(saved_idle.transitions.size() == 1,
									"One Condition transition reopens"):
								var saved_edge: FlowStateTransitionDefinition = saved_idle.transitions[0]
								_check(saved_edge.get_internal_id() == eid and
									saved_edge.target_state_id == bid and
									saved_edge.trigger == FlowStateTransitionDefinition.Trigger.CONDITION,
									"Transition stable ID, trigger and target persist")
								var saved_tok: FlowConditionValueSource = saved_edge.condition as FlowConditionValueSource
								if _check(saved_tok != null, "Stored Bool Condition Tok restores type"):
									_check(_check_semantics(saved_tok, condition_id,
										comparison_ids, event_ids, literal_ids, operators,
										kinds, fields, values),
										"Reopened full Bool expression and all typed source IDs match")
									_check(saved_tok.is_valid(saved_graph),
										"Reopened semantic source validates against graph")
									var fresh := FlowValueResolutionContext.new(saved_graph)
									_check(not saved_tok.resolve(fresh).success,
										"No transient event packet is restored on scene load")
									fresh.begin_event_packet_scope(mid)
									fresh.record_event_packet(mid, &"impact", _packet(false))
									var true_result: FlowValueResult = saved_tok.resolve(fresh)
									_check(true_result.success and true_result.value == true,
										"Fresh matching packet reproduces authored Bool result")
									fresh.record_event_packet(mid, &"impact", _packet(true))
									var false_result: FlowValueResult = saved_tok.resolve(fresh)
									_check(false_result.success and false_result.value == false,
										"Changing Bool field reproduces NOT(AND) semantics")
									fresh.record_event_packet(mid, &"impact",
										{"hp": "12", "active": true, "ratio": 0.75, "status": "ready"})
									var mismatch: FlowValueResult = saved_tok.resolve(fresh)
									_check(not mismatch.success and mismatch.diagnostic != null
										and mismatch.diagnostic.code == &"event_payload_type_mismatch",
										"Reopened typed source still rejects incorrect packet types")
									fresh.end_event_packet_scope()
									_check(not saved_tok.resolve(fresh).success,
										"Fresh event scope is erased after use")
					_check(not FlowGraphValidator.validate(saved_graph).has_errors(),
						"Reopened authored graph validates without event values")
				instance.free()

	_cleanup()
	if failures.is_empty():
		print("[Flujo] Potok 7E-1C typed Condition Tok persistence passed")
	else:
		for failure: String in failures:
			push_error("[Flujo] Potok 7E-1C: " + failure)
	quit(0 if failures.is_empty() else 1)


func _packet(active: bool) -> Dictionary:
	return {"hp": 12, "active": active, "ratio": 0.75, "status": "ready"}


func _check_semantics(
		condition: FlowConditionValueSource, condition_id: String,
		comparison_ids: Array[String], event_ids: Array[String],
		literal_ids: Array[String], operators: Array[StringName],
		types: Array[int], fields: Array[String], values: Array
) -> bool:
	if condition == null or condition.get_source_id() != condition_id \
			or condition.comparisons.size() != 4 or condition.connectors.size() != 3 \
			or not condition.negated:
		return false
	for connector: StringName in condition.connectors:
		if connector != FlowConditionOperatorCatalog.CONNECTOR_AND:
			return false
	for i: int in 4:
		var row: FlowConditionComparison = condition.comparisons[i]
		if row == null or row.comparison_id != comparison_ids[i] \
				or row.operator_id != operators[i]:
			return false
		var event: FlowEventPayloadValueSource = row.left_source as FlowEventPayloadValueSource
		var literal: FlowLiteralValueSource = row.right_source as FlowLiteralValueSource
		if event == null or literal == null:
			return false
		if event.get_source_id() != event_ids[i] or event.event_name != &"impact" \
				or event.field_name != fields[i] or int(event.value_type) != types[i] \
				or literal.get_source_id() != literal_ids[i] \
				or int(literal.value_type) != types[i] \
				or literal.value != values[i]:
			return false
	return true


func _check(ok: bool, message: String) -> bool:
	if not ok:
		failures.append(message)
	return ok


func _cleanup() -> void:
	var path: String = ProjectSettings.globalize_path(SCENE_PATH)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
	var directory_path: String = ProjectSettings.globalize_path(TEMP_DIR)
	if DirAccess.dir_exists_absolute(directory_path):
		var directory: DirAccess = DirAccess.open(directory_path)
		if directory != null and directory.get_files().is_empty() \
				and directory.get_directories().is_empty():
			DirAccess.remove_absolute(directory_path)
