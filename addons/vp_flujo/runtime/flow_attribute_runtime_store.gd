class_name FlowAttributeRuntimeStore
extends RefCounted

## Stable-ID storage with an explicit requester class context, not executable accessors.
## Definitions are snapshotted; no graph, controller or Node is retained.
var _class_id: String = ""
var _slots: Dictionary[String, Dictionary] = {}
var _values: Dictionary[String, Variant] = {}
var _parents: Dictionary[String, String] = {}
var _owners: Dictionary[String, FlowAttributeRuntimeStore] = {}
var _initialized: bool = false
var _closed: bool = false

func _initialize_slots(owner_id: String, slots: Dictionary[String, Dictionary],
		parents: Dictionary[String, String]) -> FlowStoreResult:
	if _initialized or _closed:
		return FlowStoreResult.make(&"store_already_initialized", _class_id)
	_slots.assign(slots.duplicate(true))
	_parents.assign(parents)
	for attribute_id: String in _slots:
		_values[attribute_id] = _copy_value(_slots[attribute_id].default)
	_class_id = owner_id
	_initialized = true
	return FlowStoreResult.make(&"ok", _class_id)

func read(attribute_id: String, requester_class_id: String = "") -> FlowStoreResult:
	var result: FlowStoreResult = _check_slot(attribute_id, false, requester_class_id)
	if result.ok:
		result.value = _copy_value(_value_store(attribute_id)._values[attribute_id])
	return result

func write(attribute_id: String, value: Variant, requester_class_id: String = "") -> FlowStoreResult:
	var result: FlowStoreResult = _check_slot(attribute_id, true, requester_class_id)
	if not result.ok:
		return result
	var slot: Dictionary = _slots[attribute_id]
	if value == null:
		if not slot.nullable:
			return FlowStoreResult.make(&"attribute_null_not_allowed", _class_id, attribute_id)
	elif not _matches_type(value, slot.type):
		return FlowStoreResult.make(&"attribute_type_incompatible", _class_id, attribute_id)
	_value_store(attribute_id)._values[attribute_id] = _copy_value(value)
	return read(attribute_id, requester_class_id)

func reset(attribute_id: String, requester_class_id: String = "") -> FlowStoreResult:
	var result: FlowStoreResult = _check_slot(attribute_id, true, requester_class_id)
	if not result.ok:
		return result
	_value_store(attribute_id)._values[attribute_id] = _copy_value(_slots[attribute_id].default)
	return read(attribute_id, requester_class_id)

## Closing invalidates even externally retained handles; it never resets CLASS on scene change.
func close() -> void:
	_values.clear()
	_slots.clear()
	_parents.clear()
	_owners.clear()
	_closed = true

func _check_slot(attribute_id: String, changing: bool, requester_class_id: String) -> FlowStoreResult:
	if _closed:
		return FlowStoreResult.make(&"store_closed", _class_id, attribute_id)
	if not _initialized:
		return FlowStoreResult.make(&"store_not_initialized", _class_id, attribute_id)
	if not _slots.has(attribute_id):
		return FlowStoreResult.make(&"attribute_missing", _class_id, attribute_id)
	if _value_store(attribute_id)._closed:
		return FlowStoreResult.make(&"store_closed", _class_id, attribute_id)
	# Omission means the receiving store's class, never the slot's declaring class.
	var requester: String = _class_id if requester_class_id.is_empty() else requester_class_id
	if not FlowId.is_valid(requester):
		return FlowStoreResult.make(&"attribute_requester_invalid", _class_id, attribute_id)
	var slot: Dictionary = _slots[attribute_id]
	var declaring_id: String = slot.declaring_class_id
	var accessible: bool = slot.visibility == FlowAttributeDefinition.Visibility.PUBLIC or requester == declaring_id
	if slot.visibility == FlowAttributeDefinition.Visibility.PROTECTED and not accessible:
		var visited: Dictionary[String, bool] = {}
		var current: String = requester
		while _parents.has(current) and not visited.has(current):
			visited[current] = true
			current = _parents[current]
			if current == declaring_id:
				accessible = true
				break
	if not accessible:
		return FlowStoreResult.make(&"attribute_inaccessible", _class_id, attribute_id)
	if changing:
		match _slots[attribute_id].mutability:
			FlowAttributeDefinition.Mutability.CONST:
				return FlowStoreResult.make(&"attribute_const", _class_id, attribute_id)
			FlowAttributeDefinition.Mutability.READONLY:
				return FlowStoreResult.make(&"attribute_readonly", _class_id, attribute_id)
	return FlowStoreResult.make(&"ok", declaring_id, attribute_id)

func _value_store(attribute_id: String) -> FlowAttributeRuntimeStore:
	return _owners.get(attribute_id, self)

static func snapshot_slot(attribute: FlowAttributeDefinition, declaring_id: String) -> Dictionary:
	var initial: Variant = null if attribute.default_is_null else _default_value(attribute)
	return {
		"declaring_class_id": declaring_id, "type": attribute.value_type,
		"nullable": attribute.nullable, "mutability": attribute.mutability,
		"visibility": attribute.visibility, "default": _copy_value(initial),
	}

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
