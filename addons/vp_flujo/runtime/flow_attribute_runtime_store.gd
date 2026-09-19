class_name FlowAttributeRuntimeStore
extends RefCounted

## Declaring-class storage primitive, not a public cross-class access resolver.
## Definitions are snapshotted; no graph, controller or Node is retained.
var _class_id: String = ""
var _slots: Dictionary[String, Dictionary] = {}
var _values: Dictionary[String, Variant] = {}
var _initialized: bool = false
var _closed: bool = false

func _initialize(graph: FlowGraph, storage: FlowAttributeDefinition.Storage) -> FlowStoreResult:
	if _initialized or _closed:
		return FlowStoreResult.make(&"store_already_initialized", _class_id)
	if graph == null or graph.schema_version != FlowGraph.SCHEMA_VERSION_5:
		return FlowStoreResult.make(&"store_schema_unsupported")
	var validation: FlowValidationResult = FlowGraphValidator.validate(graph)
	if validation.has_errors():
		var invalid: FlowStoreResult = FlowStoreResult.make(&"store_definition_invalid", graph.get_internal_id())
		invalid.diagnostics.assign(validation.diagnostics)
		return invalid
	# No catalog/runtime inheritance resolver is introduced by this foundation.
	if not graph.base_class_id.is_empty():
		return FlowStoreResult.make(&"store_inheritance_unresolved", graph.get_internal_id())
	var attributes: Array[FlowAttributeDefinition] = graph.class_attributes
	if storage == FlowAttributeDefinition.Storage.INSTANCE:
		attributes = graph.constructor.attributes
	for attribute: FlowAttributeDefinition in attributes:
		if attribute == null or not attribute.enabled:
			continue
		var initial: Variant = null if attribute.default_is_null else _default_value(attribute)
		var slot: Dictionary = {
			"type": attribute.value_type, "nullable": attribute.nullable,
			"mutability": attribute.mutability, "visibility": attribute.visibility,
			"default": _copy_value(initial),
		}
		_slots[attribute.get_internal_id()] = slot.duplicate(true)
		_values[attribute.get_internal_id()] = _copy_value(initial)
	_class_id = graph.get_internal_id()
	_initialized = true
	return FlowStoreResult.make(&"ok", _class_id)

func read(attribute_id: String) -> FlowStoreResult:
	var result: FlowStoreResult = _check_slot(attribute_id, false)
	if result.ok:
		result.value = _copy_value(_values[attribute_id])
	return result

func write(attribute_id: String, value: Variant) -> FlowStoreResult:
	var result: FlowStoreResult = _check_slot(attribute_id, true)
	if not result.ok:
		return result
	var slot: Dictionary = _slots[attribute_id]
	if value == null:
		if not slot.nullable:
			return FlowStoreResult.make(&"attribute_null_not_allowed", _class_id, attribute_id)
	elif not _matches_type(value, slot.type):
		return FlowStoreResult.make(&"attribute_type_incompatible", _class_id, attribute_id)
	_values[attribute_id] = _copy_value(value)
	return read(attribute_id)

func reset(attribute_id: String) -> FlowStoreResult:
	var result: FlowStoreResult = _check_slot(attribute_id, true)
	if not result.ok:
		return result
	_values[attribute_id] = _copy_value(_slots[attribute_id].default)
	return read(attribute_id)

## Closing invalidates even externally retained handles; it never resets CLASS on scene change.
func close() -> void:
	_values.clear()
	_slots.clear()
	_closed = true

func _check_slot(attribute_id: String, changing: bool) -> FlowStoreResult:
	if _closed:
		return FlowStoreResult.make(&"store_closed", _class_id, attribute_id)
	if not _initialized:
		return FlowStoreResult.make(&"store_not_initialized", _class_id, attribute_id)
	if not _slots.has(attribute_id):
		return FlowStoreResult.make(&"attribute_missing", _class_id, attribute_id)
	if changing:
		match _slots[attribute_id].mutability:
			FlowAttributeDefinition.Mutability.CONST:
				return FlowStoreResult.make(&"attribute_const", _class_id, attribute_id)
			FlowAttributeDefinition.Mutability.READONLY:
				return FlowStoreResult.make(&"attribute_readonly", _class_id, attribute_id)
	return FlowStoreResult.make(&"ok", _class_id, attribute_id)

static func _copy_value(value: Variant) -> Variant:
	if value is Array or value is Dictionary:
		return value.duplicate(true)
	return value

static func _default_value(attribute: FlowAttributeDefinition) -> Variant:
	match attribute.value_type:
		FlowVariableDefinition.ValueType.BOOL: return attribute.bool_value
		FlowVariableDefinition.ValueType.INT: return attribute.int_value
		FlowVariableDefinition.ValueType.FLOAT: return attribute.float_value
		FlowVariableDefinition.ValueType.STRING: return attribute.string_value
		FlowVariableDefinition.ValueType.VECTOR2: return attribute.vector2_value
		FlowVariableDefinition.ValueType.VECTOR3: return attribute.vector3_value
		FlowVariableDefinition.ValueType.COLOR: return attribute.color_value
	return null

static func _matches_type(value: Variant, kind: FlowVariableDefinition.ValueType) -> bool:
	match kind:
		FlowVariableDefinition.ValueType.BOOL: return typeof(value) == TYPE_BOOL
		FlowVariableDefinition.ValueType.INT: return typeof(value) == TYPE_INT
		FlowVariableDefinition.ValueType.FLOAT: return typeof(value) == TYPE_FLOAT
		FlowVariableDefinition.ValueType.STRING: return typeof(value) == TYPE_STRING
		FlowVariableDefinition.ValueType.VECTOR2: return typeof(value) == TYPE_VECTOR2
		FlowVariableDefinition.ValueType.VECTOR3: return typeof(value) == TYPE_VECTOR3
		FlowVariableDefinition.ValueType.COLOR: return typeof(value) == TYPE_COLOR
	return false
