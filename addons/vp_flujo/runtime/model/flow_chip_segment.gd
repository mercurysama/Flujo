@tool
## Runtime-safe polymorphic boundary for typed semantic chip segments.
class_name FlowChipSegment
extends FlowDocumentSegment


const SEGMENT_TYPE: StringName = &"chip"
const SLOT_KIND_NAMED: StringName = &"named"
const SLOT_KIND_VARIADIC: StringName = &"variadic"

@export_storage var _slot_id: String = ""
## A variadic zone is identified separately from a named fixed slot. Its
## slot_id names the semantic zone, not an array position or one occurrence.
@export_storage var _slot_kind: StringName = SLOT_KIND_NAMED
## Generic chips persist a source reference here. LiteralValueSegment overrides
## the accessors below to preserve its older value_type/value storage.
@export_storage var _value_source: FlowValueSource = null


var value_source: FlowValueSource:
	get:
		return get_value_source()
	set(value):
		set_value_source(value)


var slot_id: String:
	get:
		return _slot_id
	set(value):
		_slot_id = value


func get_segment_type() -> StringName:
	return SEGMENT_TYPE


func get_slot_id() -> String:
	return _slot_id


func set_slot_id(value: String) -> void:
	_slot_id = value


var slot_kind: StringName:
	get:
		return _slot_kind
	set(value):
		_slot_kind = value


func get_slot_kind() -> StringName:
	return _slot_kind


func set_slot_kind(value: StringName) -> void:
	_slot_kind = value


func get_value_source() -> FlowValueSource:
	return _value_source


func set_value_source(source: FlowValueSource) -> void:
	_value_source = source


func get_value_type() -> Variant.Type:
	var source: FlowValueSource = get_value_source()
	return source.get_value_type() if source != null else Variant.Type.TYPE_NIL


func get_value() -> Variant:
	var source: FlowValueSource = get_value_source()
	return source.get_value() if source != null else null


## Future chip subtypes override this with their stable semantic type.
func get_chip_type() -> StringName:
	return &""


## Runtime-safe semantic metadata for a future generic chip consumer.
## A subtype that has not implemented the contract returns null safely.
func get_chip_type_descriptor() -> FlowChipTypeDescriptor:
	return null


## Deterministic label projection for the future generic chip consumer.
func get_chip_label() -> String:
	return ""


## Structured tooltip projection for the future generic chip consumer.
func get_chip_tooltip_data() -> FlowChipTooltipData:
	return null


## Generic editor contract for chips that expose one typed editable value.
## The editor never needs to identify the concrete segment subtype.
func get_editable_value_type() -> Variant.Type:
	return Variant.Type.TYPE_NIL


func get_editable_value() -> Variant:
	return null


func get_default_editable_value(candidate_type: Variant.Type) -> Variant:
	var descriptor: FlowChipTypeDescriptor = get_chip_type_descriptor()
	return descriptor.get_default_value(candidate_type) if descriptor != null else null


func can_set_editable_value(_candidate_type: Variant.Type, _candidate_value: Variant) -> bool:
	return false


func set_editable_value(_candidate_type: Variant.Type, _candidate_value: Variant) -> bool:
	return false


## Validates the common source boundary. Concrete subtypes may append further
## diagnostics without changing the generic field validator.
func validate_structure(result: FlowValidationResult, element_path: String) -> void:
	var source: FlowValueSource = get_value_source()
	if source == null or result == null:
		return
	source.validate_structure(result, element_path + ".value_source")
	if not source.is_valid():
		result.add_diagnostic(FlowDiagnostic.new(
			FlowDiagnostic.CODE_INVALID_VALUE_SOURCE,
			FlowDiagnostic.Severity.ERROR,
			"ValueSource is structurally invalid.",
			element_path + ".value_source",
			source.get_source_id()
		))


## Editor hosts may use this to mark unresolved references without repairing
## their authored source. Runtime-safe chips are valid by default.
func is_chip_valid() -> bool:
	return true


## Future chip subtypes may provide a deterministic runtime text projection.
func get_runtime_text() -> String:
	return ""


## Duplicates the chip instance and its independent source identity while
## preserving the semantic slot association.
func duplicate_with_new_id() -> FlowDocumentSegment:
	var copy: FlowChipSegment = duplicate(false) as FlowChipSegment
	copy._segment_id = FlowId.create()
	copy._value_source = null
	var source: FlowValueSource = get_value_source()
	if source != null:
		copy.set_value_source(source.duplicate_with_new_id())
	return copy
