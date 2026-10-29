@tool
class_name FlowBlockPropertyPresentationDocument
extends RefCounted

## Valid top-level projection of one optional presentation sidecar.

const FORMAT_VERSION: int = 1

var source_path: String = ""
var block_type_id: String = ""
var declarations: Array[FlowBlockPropertyPresentationDeclaration] = []
var _declarations_by_property: Dictionary = {}


func _init(new_source_path: String = "", new_block_type_id: String = "") -> void:
	source_path = new_source_path
	block_type_id = new_block_type_id


func add_declaration(declaration: FlowBlockPropertyPresentationDeclaration) -> void:
	if declaration == null or declaration.property_name.is_empty():
		return
	declarations.append(declaration)
	_declarations_by_property[declaration.property_name] = declaration


func declaration_for(property_name: StringName) -> FlowBlockPropertyPresentationDeclaration:
	return _declarations_by_property.get(property_name) as FlowBlockPropertyPresentationDeclaration
