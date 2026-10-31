@tool
## Persistent semantic contract for one named chip slot or variadic zone.
class_name FlowChipSlotDefinition
extends Resource


const UNLIMITED_COUNT: int = -1

@export var slot_id: String = ""
@export var display_name: String = ""
@export var required: bool = false
@export var accepted_value_types: Array[Variant.Type] = []
@export var accepted_source_kinds: Array[StringName] = []
@export_storage var initial_value_source: FlowValueSource = null
@export var allow_delete: bool = true
@export var allow_reorder: bool = true
## Required describes presence, not mutability. A required slot remains editable
## unless its explicit edit policy says otherwise.
@export var editable: bool = true
@export var allow_content_change: bool = true
@export var allow_reference_change: bool = true
@export var allow_type_change: bool = true
@export var allow_source_kind_change: bool = true
@export var repeatable: bool = false
@export var min_count: int = 0
@export var max_count: int = 1


func _init(
		new_slot_id: String = "",
		new_display_name: String = "",
		new_required: bool = false
) -> void:
	slot_id = new_slot_id
	display_name = new_display_name
	required = new_required


## Compatibility vocabulary for callers that use slot_key.
var slot_key: String:
	get:
		return slot_id
	set(value):
		slot_id = value


## Compatibility vocabulary for callers that use label.
var label: String:
	get:
		return display_name
	set(value):
		display_name = value


## Compatibility vocabulary for callers that use accepted_types.
var accepted_types: Array[Variant.Type]:
	get:
		return accepted_value_types
	set(value):
		accepted_value_types = value


## Compatibility vocabulary retained for the earlier partial model.
var allow_multiple: bool:
	get:
		return repeatable
	set(value):
		repeatable = value


var source_kinds: Array[StringName]:
	get:
		return accepted_source_kinds
	set(value):
		accepted_source_kinds = value


## Compatibility aliases for callers that use the longer policy vocabulary.
var allow_edit: bool:
	get:
		return editable
	set(value):
		editable = value


var allow_value_edit: bool:
	get:
		return allow_content_change
	set(value):
		allow_content_change = value


var allow_source_change: bool:
	get:
		return allow_reference_change
	set(value):
		allow_reference_change = value


var allow_change_content: bool:
	get:
		return allow_content_change
	set(value):
		allow_content_change = value


var allow_change_reference: bool:
	get:
		return allow_reference_change
	set(value):
		allow_reference_change = value


var allow_change_type: bool:
	get:
		return allow_type_change
	set(value):
		allow_type_change = value


var allow_change_source_kind: bool:
	get:
		return allow_source_kind_change
	set(value):
		allow_source_kind_change = value


func get_slot_id() -> String:
	return slot_id


func get_display_name() -> String:
	return display_name


func is_repeatable() -> bool:
	return repeatable


## A required slot has an effective minimum of one even when min_count is zero.
func get_effective_min_count() -> int:
	return maxi(min_count, 1 if required else 0)


func get_effective_max_count() -> int:
	return max_count


func accepts_value_type(candidate_type: Variant.Type) -> bool:
	return accepted_value_types.is_empty() or accepted_value_types.has(candidate_type)


func accepts_source_kind(candidate_kind: StringName) -> bool:
	return accepted_source_kinds.is_empty() or accepted_source_kinds.has(candidate_kind)


func accepts_source(source: FlowValueSource) -> bool:
	return source != null and source.is_valid() \
		and accepts_value_type(source.get_value_type()) \
		and accepts_source_kind(source.get_source_kind())


## The reusable slot policy keeps required presence independent from editability.
func can_edit() -> bool:
	return editable


func can_change_content() -> bool:
	return editable and allow_content_change


func can_change_reference() -> bool:
	return editable and allow_reference_change


func can_change_type() -> bool:
	return editable and allow_content_change and allow_type_change


func can_change_source_kind() -> bool:
	return editable and allow_reference_change and allow_source_kind_change


## Required occurrences are never deletable, even if an older schema left
## allow_delete at its permissive default.
func can_delete() -> bool:
	return not required and allow_delete


## A single accepted type is a schema type lock, not an immutable-value flag.
func is_value_type_locked() -> bool:
	return not can_change_type() or accepted_value_types.size() == 1


## A single accepted source kind is a source-kind lock, not an immutable-value
## flag. A slot can therefore remain editable while retaining its source kind.
func is_source_kind_locked() -> bool:
	return not can_change_source_kind() or accepted_source_kinds.size() == 1


func has_initial_value_source() -> bool:
	return initial_value_source != null


## Creates an independent runtime-safe source from the schema's authored default.
## The source is a prototype/configuration resource, never an editor factory.
func create_initial_value_source() -> FlowValueSource:
	if initial_value_source == null:
		return null
	return initial_value_source.duplicate_with_new_id()


## Compatibility vocabulary for callers that call the default a source directly.
func create_default_source() -> FlowValueSource:
	return create_initial_value_source()


var default_value_source: FlowValueSource:
	get:
		return initial_value_source
	set(value):
		initial_value_source = value


## Duplicates the definition and gives its nested initial source a new ID.
## The semantic slot_id itself remains stable because it names block meaning.
func duplicate_with_new_ids() -> FlowChipSlotDefinition:
	var copy: FlowChipSlotDefinition = duplicate(false) as FlowChipSlotDefinition
	copy.accepted_value_types = accepted_value_types.duplicate()
	copy.accepted_source_kinds = accepted_source_kinds.duplicate()
	if initial_value_source != null:
		copy.initial_value_source = initial_value_source.duplicate_with_new_id()
	return copy
