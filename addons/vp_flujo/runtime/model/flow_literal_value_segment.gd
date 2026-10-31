@tool
## Typed literal chip segment with exact Variant.Type preservation.
class_name FlowLiteralValueSegment
extends FlowChipSegment


const CHIP_TYPE: StringName = &"literal_value"
const TYPE_BOOL: Variant.Type = FlowLiteralValueSource.TYPE_BOOL
const TYPE_INT: Variant.Type = FlowLiteralValueSource.TYPE_INT
const TYPE_FLOAT: Variant.Type = FlowLiteralValueSource.TYPE_FLOAT
const TYPE_STRING: Variant.Type = FlowLiteralValueSource.TYPE_STRING
const TYPE_STRING_NAME: Variant.Type = FlowLiteralValueSource.TYPE_STRING_NAME
const DISPLAY_NAME: String = "Literal"
const CATEGORY: StringName = FlowChipTypeDescriptor.CATEGORY_LITERAL
const LABEL_STRATEGY: StringName = FlowChipTypeDescriptor.LABEL_STRATEGY_VALUE
const STYLE_ROLE: StringName = FlowChipTypeDescriptor.STYLE_ROLE_LITERAL

@export_storage var value_type: Variant.Type = Variant.Type.TYPE_NIL
@export_storage var value: Variant

## K1/K2 persist value_type/value directly. This adapter is deliberately
## ephemeral: the legacy fields remain the sole persisted source of truth until
## a separately approved storage migration.
var _legacy_value_source: FlowLiteralValueSource = null


func _init(new_value_type: Variant.Type = Variant.Type.TYPE_NIL, new_value: Variant = null) -> void:
	value_type = new_value_type
	value = new_value
	_legacy_value_source = null


func get_chip_type() -> StringName:
	return CHIP_TYPE


func get_chip_type_descriptor() -> FlowChipTypeDescriptor:
	var descriptor: FlowChipTypeDescriptor = FlowChipTypeDescriptor.new()
	descriptor.type_id = CHIP_TYPE
	descriptor.display_name = DISPLAY_NAME
	descriptor.category = CATEGORY
	descriptor.label_strategy = LABEL_STRATEGY
	descriptor.semantic_style_role = STYLE_ROLE
	descriptor.editable = true
	descriptor.supported_variant_types = [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME]
	return descriptor


func get_chip_label() -> String:
	if not is_valid_literal():
		return ""
	return get_runtime_text()


func get_chip_tooltip_data() -> FlowChipTooltipData:
	var data: FlowChipTooltipData = FlowChipTooltipData.new(DISPLAY_NAME)
	data.add_field("Type", DISPLAY_NAME)
	data.add_field("Value", get_chip_label())
	data.add_field("Variant", _variant_type_display_name(value_type))
	return data


func get_value_type() -> Variant.Type:
	return value_type


func get_value() -> Variant:
	return value


## Exposes the legacy literal through the common chip → source boundary.
## Every read re-syncs the adapter from the persisted legacy fields, so the two
## representations cannot silently drift.
func get_value_source() -> FlowValueSource:
	if _legacy_value_source == null:
		_legacy_value_source = FlowLiteralValueSource.new()
	_legacy_value_source.value_type = value_type
	_legacy_value_source.value = value
	return _legacy_value_source


## Assigning a source to a legacy literal copies only its exact authored data;
## the source resource itself is not shared with the segment.
func set_value_source(source: FlowValueSource) -> void:
	if source == null:
		value_type = Variant.Type.TYPE_NIL
		value = null
		_legacy_value_source = null
		return
	if not source is FlowLiteralValueSource:
		return
	var literal_source: FlowLiteralValueSource = source as FlowLiteralValueSource
	value_type = literal_source.get_value_type()
	value = literal_source.get_value()
	_legacy_value_source = null


func get_editable_value_type() -> Variant.Type:
	return value_type


func get_editable_value() -> Variant:
	return value


func can_set_editable_value(candidate_type: Variant.Type, candidate_value: Variant) -> bool:
	return FlowLiteralValueSource.is_valid_literal(candidate_type, candidate_value)


func set_editable_value(candidate_type: Variant.Type, candidate_value: Variant) -> bool:
	if not can_set_editable_value(candidate_type, candidate_value):
		return false
	value_type = candidate_type
	value = candidate_value
	return true


static func is_allowed_type(candidate: Variant.Type) -> bool:
	return FlowLiteralValueSource.is_allowed_type(candidate)


func value_matches_declared_type() -> bool:
	return FlowLiteralValueSource.value_matches_declared_type(value_type, value)


func has_finite_float() -> bool:
	return FlowLiteralValueSource.has_finite_float(value_type, value)


func is_valid_literal() -> bool:
	return FlowLiteralValueSource.is_valid_literal(value_type, value)


func get_runtime_text() -> String:
	return FlowLiteralValueSource.format_runtime_text(value_type, value) \
		if is_valid_literal() else ""


func duplicate_with_new_id() -> FlowDocumentSegment:
	var copy: FlowLiteralValueSegment = duplicate(false) as FlowLiteralValueSegment
	copy._segment_id = FlowId.create()
	copy._value_source = null
	copy._legacy_value_source = null
	return copy


static func _variant_type_display_name(candidate: Variant.Type) -> String:
	return FlowChipTypeDescriptor.variant_type_display_name(candidate)
