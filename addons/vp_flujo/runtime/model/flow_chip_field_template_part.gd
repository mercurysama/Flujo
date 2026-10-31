@tool
## Runtime-safe schema template part used to place literal text or a semantic slot.
class_name FlowChipFieldTemplatePart
extends Resource


enum Kind {
	TEXT,
	SLOT,
}


@export_storage var _part_id: String = FlowId.create()
@export var kind: int = Kind.TEXT
@export_multiline var text: String = ""
@export var slot_id: String = ""


static func text_part(value: String) -> FlowChipFieldTemplatePart:
	var part: FlowChipFieldTemplatePart = FlowChipFieldTemplatePart.new()
	part.kind = Kind.TEXT
	part.text = value
	part.slot_id = ""
	return part


static func slot_part(value: String) -> FlowChipFieldTemplatePart:
	var part: FlowChipFieldTemplatePart = FlowChipFieldTemplatePart.new()
	part.kind = Kind.SLOT
	part.text = ""
	part.slot_id = value
	return part


static func new_text(value: String) -> FlowChipFieldTemplatePart:
	return text_part(value)


static func new_slot(value: String) -> FlowChipFieldTemplatePart:
	return slot_part(value)


var part_id: String:
	get:
		return _part_id
	set(value):
		_part_id = value


func is_text_part() -> bool:
	return kind == Kind.TEXT


func is_slot_part() -> bool:
	return kind == Kind.SLOT


func duplicate_with_new_id() -> FlowChipFieldTemplatePart:
	var copy: FlowChipFieldTemplatePart = duplicate(false) as FlowChipFieldTemplatePart
	copy._part_id = FlowId.create()
	return copy
