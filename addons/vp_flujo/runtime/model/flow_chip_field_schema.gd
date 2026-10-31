@tool
## Reusable runtime contract for one complete text-plus-chip field.
class_name FlowChipFieldSchema
extends Resource


enum Mode {
	FIXED,
	FLEXIBLE,
	HYBRID,
}

enum TextMode {
	DOCUMENTATION,
	RUNTIME_CONTENT,
	DISABLED,
}

## Public vocabulary alias for callers that name this axis a policy.
enum TextPolicy {
	DOCUMENTATION,
	RUNTIME_CONTENT,
	DISABLED,
}

const MODE_FIXED: int = Mode.FIXED
const MODE_FLEXIBLE: int = Mode.FLEXIBLE
const MODE_HYBRID: int = Mode.HYBRID
const TEXT_MODE_DOCUMENTATION: int = TextMode.DOCUMENTATION
const TEXT_MODE_RUNTIME_CONTENT: int = TextMode.RUNTIME_CONTENT
const TEXT_MODE_DISABLED: int = TextMode.DISABLED
const UNLIMITED_COUNT: int = FlowChipSlotDefinition.UNLIMITED_COUNT

@export_storage var _schema_id: String = FlowId.create()
@export var mode: int = Mode.FIXED
@export var text_mode: int = TextMode.RUNTIME_CONTENT
@export var slots: Array[FlowChipSlotDefinition] = []
## Ordered schema-only parts. The factory materializes text parts as real
## FlowTextSegment resources and slot parts as generated chip instances.
@export var template_parts: Array[FlowChipFieldTemplatePart] = []
## Field-level restrictions apply to flexible content. Fixed/hybrid named
## slots may declare narrower restrictions on their own definitions.
@export var accepted_value_types: Array[Variant.Type] = []
@export var accepted_source_kinds: Array[StringName] = []
@export var flexible_min_count: int = 0
@export var flexible_max_count: int = UNLIMITED_COUNT
@export var variadic_slot_definition: FlowChipSlotDefinition = null
## Field-level defaults for flexible fields or schemas without a named slot.
## Slot-level policy remains more specific when a slot is present.
@export var editable: bool = true
@export var allow_content_change: bool = true
@export var allow_reference_change: bool = true
@export var allow_type_change: bool = true
@export var allow_source_kind_change: bool = true

var schema_id: String:
	get:
		return _schema_id
	set(value):
		_schema_id = value


var text_policy: int:
	get:
		return text_mode
	set(value):
		text_mode = value


var slot_definitions: Array[FlowChipSlotDefinition]:
	get:
		return slots
	set(value):
		slots = value


var initial_template_parts: Array[FlowChipFieldTemplatePart]:
	get:
		return template_parts
	set(value):
		template_parts = value


var text_template_parts: Array[FlowChipFieldTemplatePart]:
	get:
		return template_parts
	set(value):
		template_parts = value


var initial_parts: Array[FlowChipFieldTemplatePart]:
	get:
		return template_parts
	set(value):
		template_parts = value


var text_segments: Array[FlowChipFieldTemplatePart]:
	get:
		return template_parts
	set(value):
		template_parts = value


var allowed_value_types: Array[Variant.Type]:
	get:
		return accepted_value_types
	set(value):
		accepted_value_types = value


var allowed_source_kinds: Array[StringName]:
	get:
		return accepted_source_kinds
	set(value):
		accepted_source_kinds = value


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


## Compatibility aliases for callers that spell the flexible bounds as slots.
var min_flexible_count: int:
	get:
		return flexible_min_count
	set(value):
		flexible_min_count = value


var max_flexible_count: int:
	get:
		return flexible_max_count
	set(value):
		flexible_max_count = value


var min_flexible_slots: int:
	get:
		return flexible_min_count
	set(value):
		flexible_min_count = value


var max_flexible_slots: int:
	get:
		return flexible_max_count
	set(value):
		flexible_max_count = value


var variadic_slot: FlowChipSlotDefinition:
	get:
		return variadic_slot_definition
	set(value):
		variadic_slot_definition = value


static func is_valid_mode(candidate_mode: int) -> bool:
	return candidate_mode == Mode.FIXED or candidate_mode == Mode.FLEXIBLE \
		or candidate_mode == Mode.HYBRID


static func is_valid_text_mode(candidate_text_mode: int) -> bool:
	return candidate_text_mode == TextMode.DOCUMENTATION \
		or candidate_text_mode == TextMode.RUNTIME_CONTENT \
		or candidate_text_mode == TextMode.DISABLED


func get_schema_id() -> String:
	return _schema_id


func get_slot_definition(candidate_slot_id: String) -> FlowChipSlotDefinition:
	for definition: FlowChipSlotDefinition in slots:
		if definition != null and definition.slot_id == candidate_slot_id:
			return definition
	if variadic_slot_definition != null \
			and variadic_slot_definition.slot_id == candidate_slot_id:
		return variadic_slot_definition
	return null


func get_variadic_slot_definition() -> FlowChipSlotDefinition:
	return variadic_slot_definition


func accepts_text() -> bool:
	return text_mode != TextMode.DISABLED


func accepts_value_type(candidate_type: Variant.Type) -> bool:
	return accepted_value_types.is_empty() or accepted_value_types.has(candidate_type)


func accepts_source_kind(candidate_kind: StringName) -> bool:
	return accepted_source_kinds.is_empty() or accepted_source_kinds.has(candidate_kind)


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


func is_value_type_locked() -> bool:
	return not can_change_type() or accepted_value_types.size() == 1


func is_source_kind_locked() -> bool:
	return not can_change_source_kind() or accepted_source_kinds.size() == 1


func add_text_part(text: String) -> FlowChipFieldTemplatePart:
	var part: FlowChipFieldTemplatePart = FlowChipFieldTemplatePart.text_part(text)
	template_parts.append(part)
	return part


func add_slot_part(candidate_slot_id: String) -> FlowChipFieldTemplatePart:
	var part: FlowChipFieldTemplatePart = FlowChipFieldTemplatePart.slot_part(candidate_slot_id)
	template_parts.append(part)
	return part


func get_flexible_min_count() -> int:
	return flexible_min_count


func get_flexible_max_count() -> int:
	return flexible_max_count


func get_min_flexible_slots() -> int:
	return flexible_min_count


func get_max_flexible_slots() -> int:
	return flexible_max_count


func validate(
		document: FlowStructuredDocument,
		variable_graph: FlowGraph = null
) -> FlowValidationResult:
	return FlowChipFieldValidator.validate(self, document, variable_graph)


func validate_structure() -> FlowValidationResult:
	return FlowChipFieldValidator.validate_schema(self)


## Duplicates the schema while preserving semantic slot IDs and ordering.
func duplicate_with_new_ids() -> FlowChipFieldSchema:
	var copy: FlowChipFieldSchema = duplicate(false) as FlowChipFieldSchema
	copy._schema_id = FlowId.create()
	copy.accepted_value_types = accepted_value_types.duplicate()
	copy.accepted_source_kinds = accepted_source_kinds.duplicate()
	copy.slots = []
	for definition: FlowChipSlotDefinition in slots:
		if definition == null:
			copy.slots.append(null)
		else:
			copy.slots.append(definition.duplicate_with_new_ids())
	copy.template_parts = []
	for part: FlowChipFieldTemplatePart in template_parts:
		if part == null:
			copy.template_parts.append(null)
		else:
			copy.template_parts.append(part.duplicate_with_new_id())
	if variadic_slot_definition != null:
		copy.variadic_slot_definition = variadic_slot_definition.duplicate_with_new_ids()
	return copy
