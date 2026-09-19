extends SceneTree


var _failures: Array[String] = []
var _checks: int = 0
var _scene_root: Node
var _retained_class_store: FlowClassRuntimeStore
var _other_class_store: FlowClassRuntimeStore


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var graph: FlowGraph = _store_graph()
	if not _check(not FlowGraphValidator.validate(graph).has_errors(), "Schema 5 store fixture is structurally valid."):
		_finish()
		return

	_scene_root = Node.new()
	_scene_root.name = &"FirstRuntimeScene"
	var first: PVController = _controller(graph, &"FirstController")
	var second: PVController = _controller(graph, &"SecondController")
	_scene_root.add_child(first)
	_scene_root.add_child(second)
	get_root().add_child(_scene_root)
	await process_frame

	if not _check(_stores_ready(first) and _stores_ready(second), "Two schema 5 controllers initialize both runtime stores."):
		_finish()
		return
	_check(first.instance_runtime_store != second.instance_runtime_store, "INSTANCE stores are controller-owned and independent.")
	_check(first.class_runtime_store == second.class_runtime_store, "CLASS stores are shared for one SceneTree and class ID.")
	_check(first.class_runtime_store.get("_class_id") == graph.get_internal_id(), "CLASS storage is keyed by the stable graph class ID.")

	_test_instance_isolation_and_operations(graph, first, second)
	_test_class_sharing_and_definition_snapshot(graph, first, second)
	_test_runtime_data_has_no_scene_references(first.instance_runtime_store, first.class_runtime_store)

	var first_instance_handle: FlowInstanceRuntimeStore = first.instance_runtime_store
	_retained_class_store = first.class_runtime_store
	_scene_root.queue_free()
	await _frames(3)
	_check(first_instance_handle.read(_attribute_id(graph, "StringValue")).code == &"store_closed", "Controller exit closes an externally retained INSTANCE handle.")
	_check(_retained_class_store.read(_attribute_id(graph, "SharedCount")).value == 99, "CLASS state survives a scene change and a temporary absence of controllers.")

	_scene_root = Node.new()
	_scene_root.name = &"SecondRuntimeScene"
	var third: PVController = _controller(graph, &"ThirdController")
	_scene_root.add_child(third)
	get_root().add_child(_scene_root)
	await process_frame
	_check(_stores_ready(third), "A controller in the replacement scene initializes normally.")
	_check(third.class_runtime_store == _retained_class_store, "A replacement scene reacquires the same SceneTree/class ID store.")
	_check(third.class_runtime_store.read(_attribute_id(graph, "SharedCount")).value == 99, "Replacement-scene controller observes continuous CLASS state.")
	_check(third.instance_runtime_store.read(_attribute_id(graph, "StringValue")).value == "deep default", "Replacement-scene controller receives fresh INSTANCE defaults.")

	var other_graph: FlowGraph = graph.duplicate(true) as FlowGraph
	other_graph._internal_id = FlowId.create()
	var other: PVController = _controller(other_graph, &"OtherClassController")
	_scene_root.add_child(other)
	await process_frame
	_check(_stores_ready(other), "A second class initializes in the same SceneTree.")
	_other_class_store = other.class_runtime_store
	_check(_other_class_store != _retained_class_store, "Different class IDs never share CLASS stores in one SceneTree.")
	_check(_other_class_store.read(_attribute_id(other_graph, "SharedCount")).value == 7, "A different class ID starts from its own CLASS default.")

	var conflict_graph: FlowGraph = graph.duplicate(true) as FlowGraph
	var conflict_attribute: FlowAttributeDefinition = _attribute_by_name(conflict_graph, "SharedCount")
	conflict_attribute.int_value = 1234
	var conflict: FlowStoreResult = FlowClassRuntimeStore.acquire(self, conflict_graph)
	_check(not conflict.ok and conflict.code == &"store_definition_conflict", "The same live class ID rejects conflicting slot definitions without resetting state.")
	_check(_retained_class_store.read(_attribute_id(graph, "SharedCount")).value == 99, "Definition conflict leaves shared CLASS state unchanged.")

	_scene_root.queue_free()
	await _frames(3)
	get_root().tree_exiting.emit()
	_check(_retained_class_store.read(_attribute_id(graph, "SharedCount")).code == &"store_closed", "SceneTree exit closes retained CLASS handles.")
	_check(_other_class_store.read(_attribute_id(other_graph, "SharedCount")).code == &"store_closed", "SceneTree exit closes every class store owned by that tree.")

	_finish()


func _test_instance_isolation_and_operations(graph: FlowGraph, first: PVController, second: PVController) -> void:
	var first_store: FlowInstanceRuntimeStore = first.instance_runtime_store
	var second_store: FlowInstanceRuntimeStore = second.instance_runtime_store
	var string_id: String = _attribute_id(graph, "StringValue")
	_check(first_store.write(string_id, "first only").ok, "A mutable INSTANCE attribute accepts an exact-type write.")
	_check(first_store.read(string_id).value == "first only", "The writing controller observes its INSTANCE value.")
	_check(second_store.read(string_id).value == "deep default", "Another controller retains its independent INSTANCE default.")

	var defaults: Array[Variant] = [
		true,
		41,
		2.5,
		"deep default",
		Vector2(2.0, -4.0),
		Vector3(1.0, 3.0, 5.0),
		Color(0.2, 0.4, 0.6, 0.8),
	]
	var replacements: Array[Variant] = [
		false,
		-8,
		9.75,
		"replacement",
		Vector2(-3.0, 7.0),
		Vector3(-1.0, -2.0, -3.0),
		Color(0.9, 0.1, 0.3, 1.0),
	]
	var wrong_values: Array[Variant] = [
		1,
		1.0,
		1,
		StringName("not String"),
		Vector3.ZERO,
		Vector2.ZERO,
		Vector4.ZERO,
	]
	for value_type: int in FlowVariableDefinition.ValueType.values():
		var attribute_id: String = _attribute_id(graph, _type_attribute_name(value_type))
		var store: FlowInstanceRuntimeStore = second_store
		_check(store.read(attribute_id).value == defaults[value_type], "Canonical type %d reads its exact default." % value_type)
		_check(store.write(attribute_id, replacements[value_type]).value == replacements[value_type], "Canonical type %d accepts its exact Variant type." % value_type)
		var rejected: FlowStoreResult = store.write(attribute_id, wrong_values[value_type])
		_check(not rejected.ok and rejected.code == &"attribute_type_incompatible", "Canonical type %d rejects a different Variant type." % value_type)
		_check(store.read(attribute_id).value == replacements[value_type], "Rejected type %d write preserves the previous runtime value." % value_type)
		_check(store.reset(attribute_id).value == defaults[value_type], "Reset restores the snapshotted default for type %d." % value_type)

	var string_definition: FlowAttributeDefinition = _attribute_by_name(graph, "StringValue")
	string_definition.string_value = "definition changed later"
	first_store.write(string_id, "runtime value")
	_check(first_store.reset(string_id).value == "deep default", "Reset uses the detached initialization snapshot, not a later Resource mutation.")
	string_definition.string_value = "deep default"

	var nullable_id: String = _attribute_id(graph, "NullableString")
	_check(first_store.read(nullable_id).ok and first_store.read(nullable_id).value == null, "Nullable attributes may initialize and read null.")
	_check(first_store.write(nullable_id, "present").value == "present", "Nullable attributes accept their exact non-null type.")
	_check(first_store.write(nullable_id, null).ok and first_store.read(nullable_id).value == null, "Nullable attributes accept null writes.")
	_check(first_store.reset(nullable_id).ok and first_store.read(nullable_id).value == null, "Nullable reset restores a null default.")
	var null_rejected: FlowStoreResult = first_store.write(string_id, null)
	_check(not null_rejected.ok and null_rejected.code == &"attribute_null_not_allowed", "Non-nullable attributes reject null.")

	var readonly_id: String = _attribute_id(graph, "ReadonlyValue")
	var const_id: String = _attribute_id(graph, "ConstValue")
	_check(first_store.read(readonly_id).value == 12, "READONLY initialization remains readable.")
	_check(first_store.write(readonly_id, 13).code == &"attribute_readonly", "READONLY rejects direct writes.")
	_check(first_store.reset(readonly_id).code == &"attribute_readonly", "READONLY rejects direct reset.")
	_check(first_store.read(readonly_id).value == 12, "Rejected READONLY operations preserve the value.")
	_check(first_store.read(const_id).value == 21, "CONST initializes exactly once from its default.")
	_check(first_store.write(const_id, 22).code == &"attribute_const", "CONST rejects writes after initialization.")
	_check(first_store.reset(const_id).code == &"attribute_const", "CONST rejects reset after initialization.")
	_check(first_store.read(const_id).value == 21, "Rejected CONST operations preserve the value.")

	var missing_id: String = FlowId.create()
	_check(first_store.read(missing_id).code == &"attribute_missing", "Read reports an unknown attribute deterministically.")
	_check(first_store.write(missing_id, 1).code == &"attribute_missing", "Write reports an unknown attribute deterministically.")
	_check(first_store.reset(missing_id).code == &"attribute_missing", "Reset reports an unknown attribute deterministically.")
	_check(first_store.read(_attribute_id(graph, "DisabledValue")).code == &"attribute_missing", "Disabled definitions do not create runtime slots.")

	var unopened: FlowInstanceRuntimeStore = FlowInstanceRuntimeStore.new()
	_check(unopened.read(string_id).code == &"store_not_initialized", "An uninitialized store rejects operations deterministically.")
	unopened.close()
	_check(unopened.read(string_id).code == &"store_closed", "A closed store rejects operations before slot lookup.")


func _test_class_sharing_and_definition_snapshot(graph: FlowGraph, first: PVController, second: PVController) -> void:
	var class_id: String = _attribute_id(graph, "SharedCount")
	var first_store: FlowClassRuntimeStore = first.class_runtime_store
	var second_store: FlowClassRuntimeStore = second.class_runtime_store
	_check(first_store.read(class_id).value == 7, "CLASS state initializes once from its definition default.")
	_check(first_store.write(class_id, 44).ok, "CLASS mutable state accepts an exact-type write.")
	_check(second_store.read(class_id).value == 44, "Controllers of one class observe the same CLASS value.")
	var definition: FlowAttributeDefinition = _attribute_by_name(graph, "SharedCount")
	definition.int_value = 888
	_check(first_store.reset(class_id).value == 7, "CLASS reset uses its original detached default snapshot.")
	definition.int_value = 7
	_check(second_store.write(class_id, 99).value == 99, "Shared CLASS state remains writable after reset.")


func _test_runtime_data_has_no_scene_references(instance_store: FlowInstanceRuntimeStore, class_store: FlowClassRuntimeStore) -> void:
	_check(not _contains_scene_reference(instance_store.get("_slots")), "INSTANCE slot metadata retains no Node, Resource or Callable.")
	_check(not _contains_scene_reference(instance_store.get("_values")), "INSTANCE values retain no Node, Resource or Callable.")
	_check(not _contains_scene_reference(class_store.get("_slots")), "CLASS slot metadata retains no Node, Resource or Callable.")
	_check(not _contains_scene_reference(class_store.get("_values")), "CLASS values retain no Node, Resource or Callable.")
	_check(get_meta(FlowClassRuntimeStore.TREE_REGISTRY, null) is Dictionary, "CLASS registry belongs to the active SceneTree metadata.")


func _contains_scene_reference(value: Variant) -> bool:
	if value is Node or value is Resource or value is Callable:
		return true
	if value is Array:
		for item: Variant in value:
			if _contains_scene_reference(item):
				return true
	if value is Dictionary:
		for key: Variant in value:
			if _contains_scene_reference(key) or _contains_scene_reference(value[key]):
				return true
	return false


func _stores_ready(controller: PVController) -> bool:
	return controller != null and controller.runtime_store_result != null \
		and controller.runtime_store_result.ok \
		and controller.instance_runtime_store != null \
		and controller.class_runtime_store != null


func _controller(graph: FlowGraph, controller_name: StringName) -> PVController:
	var controller: PVController = PVController.new()
	controller.name = controller_name
	controller.flow_graph = graph
	return controller


func _store_graph() -> FlowGraph:
	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_5
	graph.constructor = FlowConstructorDefinition.new()
	var defaults: Array[Variant] = [
		true,
		41,
		2.5,
		"deep default",
		Vector2(2.0, -4.0),
		Vector3(1.0, 3.0, 5.0),
		Color(0.2, 0.4, 0.6, 0.8),
	]
	for value_type: int in FlowVariableDefinition.ValueType.values():
		var attribute: FlowAttributeDefinition = _attribute(
			_type_attribute_name(value_type),
			FlowAttributeDefinition.Storage.INSTANCE,
			value_type,
			defaults[value_type]
		)
		graph.constructor.attributes.append(attribute)
	graph.constructor.attributes.append(_attribute("NullableString", FlowAttributeDefinition.Storage.INSTANCE, FlowVariableDefinition.ValueType.STRING, null, FlowAttributeDefinition.Mutability.MUTABLE, true))
	graph.constructor.attributes.append(_attribute("ReadonlyValue", FlowAttributeDefinition.Storage.INSTANCE, FlowVariableDefinition.ValueType.INT, 12, FlowAttributeDefinition.Mutability.READONLY))
	graph.constructor.attributes.append(_attribute("ConstValue", FlowAttributeDefinition.Storage.INSTANCE, FlowVariableDefinition.ValueType.INT, 21, FlowAttributeDefinition.Mutability.CONST))
	var disabled: FlowAttributeDefinition = _attribute("DisabledValue", FlowAttributeDefinition.Storage.INSTANCE, FlowVariableDefinition.ValueType.INT, 31)
	disabled.enabled = false
	graph.constructor.attributes.append(disabled)
	graph.class_attributes = [
		_attribute("SharedCount", FlowAttributeDefinition.Storage.CLASS, FlowVariableDefinition.ValueType.INT, 7),
	]
	return graph


func _attribute(
	name_value: String,
	storage: FlowAttributeDefinition.Storage,
	value_type: FlowVariableDefinition.ValueType,
	default_value: Variant,
	mutability: FlowAttributeDefinition.Mutability = FlowAttributeDefinition.Mutability.MUTABLE,
	nullable: bool = false
) -> FlowAttributeDefinition:
	var attribute: FlowAttributeDefinition = FlowAttributeDefinition.new()
	attribute.display_name = name_value
	attribute.storage = storage
	attribute.value_type = value_type
	attribute.mutability = mutability
	attribute.nullable = nullable
	attribute.default_is_null = default_value == null
	if default_value != null:
		match value_type:
			FlowVariableDefinition.ValueType.BOOL: attribute.bool_value = default_value
			FlowVariableDefinition.ValueType.INT: attribute.int_value = default_value
			FlowVariableDefinition.ValueType.FLOAT: attribute.float_value = default_value
			FlowVariableDefinition.ValueType.STRING: attribute.string_value = default_value
			FlowVariableDefinition.ValueType.VECTOR2: attribute.vector2_value = default_value
			FlowVariableDefinition.ValueType.VECTOR3: attribute.vector3_value = default_value
			FlowVariableDefinition.ValueType.COLOR: attribute.color_value = default_value
	return attribute


func _type_attribute_name(value_type: int) -> String:
	match value_type:
		FlowVariableDefinition.ValueType.BOOL: return "BoolValue"
		FlowVariableDefinition.ValueType.INT: return "IntValue"
		FlowVariableDefinition.ValueType.FLOAT: return "FloatValue"
		FlowVariableDefinition.ValueType.STRING: return "StringValue"
		FlowVariableDefinition.ValueType.VECTOR2: return "Vector2Value"
		FlowVariableDefinition.ValueType.VECTOR3: return "Vector3Value"
		FlowVariableDefinition.ValueType.COLOR: return "ColorValue"
	return "UnknownValue"


func _attribute_by_name(graph: FlowGraph, attribute_name: String) -> FlowAttributeDefinition:
	for attribute: FlowAttributeDefinition in graph.constructor.attributes + graph.class_attributes:
		if attribute != null and attribute.display_name == attribute_name:
			return attribute
	return null


func _attribute_id(graph: FlowGraph, attribute_name: String) -> String:
	var attribute: FlowAttributeDefinition = _attribute_by_name(graph, attribute_name)
	return attribute.get_internal_id() if attribute != null else ""


func _frames(count: int) -> void:
	for _index: int in count:
		await process_frame


func _check(condition: bool, message: String) -> bool:
	_checks += 1
	if not condition:
		_failures.append(message)
		push_error("[Flujo][AttributeStores] " + message)
	return condition


func _finish() -> void:
	if is_instance_valid(_scene_root):
		_scene_root.queue_free()
	await _frames(3)
	if _failures.is_empty():
		print("[Flujo] Schema 5 runtime attribute store focal passed (%d checks)" % _checks)
	quit(0 if _failures.is_empty() else 1)
