@tool
class_name FlowEditorBlockCatalogEntry
extends RefCounted

enum Origin {
	INTEGRATED,
	EXTERNAL,
}

var authoring_id: String = ""
var display_name: String = ""
var origin: Origin = Origin.INTEGRATED
var integrated_type_id: StringName = &""
var external_descriptor: FlowExternalBlockDescriptor


static func integrated(type_id: StringName, visible_name: String) -> FlowEditorBlockCatalogEntry:
	var entry: FlowEditorBlockCatalogEntry = FlowEditorBlockCatalogEntry.new()
	entry.authoring_id = String(type_id)
	entry.display_name = visible_name
	entry.origin = Origin.INTEGRATED
	entry.integrated_type_id = type_id
	return entry


static func external(descriptor: FlowExternalBlockDescriptor) -> FlowEditorBlockCatalogEntry:
	var entry: FlowEditorBlockCatalogEntry = FlowEditorBlockCatalogEntry.new()
	entry.authoring_id = descriptor.global_type_id()
	entry.display_name = descriptor.display_name
	entry.origin = Origin.EXTERNAL
	entry.external_descriptor = descriptor
	return entry


func is_integrated() -> bool:
	return origin == Origin.INTEGRATED


func is_external() -> bool:
	return origin == Origin.EXTERNAL
