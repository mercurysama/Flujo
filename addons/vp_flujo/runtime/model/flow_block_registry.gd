@tool
class_name FlowBlockRegistry
extends RefCounted

## The single built-in authoring registry. Persistent identity remains on FlowBlock.
const PRINT: StringName = &"print"
const EVERYTHING_FLOWS: StringName = &"everything_flows"
const CUSTOM_HELLO: StringName = &"custom_hello"

const _PRINT_SCRIPT: Script = preload("res://addons/vp_flujo/runtime/model/flow_print_block.gd")
const _EVERYTHING_FLOWS_SCRIPT: Script = preload("res://addons/vp_flujo/runtime/model/flow_everything_flows_block.gd")
const _CUSTOM_HELLO_SCRIPT: Script = preload("res://addons/vp_flujo/runtime/model/flow_custom_hello_block.gd")
const _ORDER: Array[StringName] = [PRINT, EVERYTHING_FLOWS, CUSTOM_HELLO]
const _SCRIPTS: Dictionary = {
	PRINT: _PRINT_SCRIPT,
	EVERYTHING_FLOWS: _EVERYTHING_FLOWS_SCRIPT,
	CUSTOM_HELLO: _CUSTOM_HELLO_SCRIPT,
}
const _DISPLAY_NAMES: Dictionary = {
	PRINT: "Print",
	EVERYTHING_FLOWS: "Everything Flows",
	CUSTOM_HELLO: "Custom Hello",
}


static func creatable_type_ids() -> Array[StringName]:
	return _ORDER.duplicate()


static func create(type_id: StringName) -> FlowBlock:
	var block_script: Script = _SCRIPTS.get(type_id) as Script
	return block_script.new() as FlowBlock if block_script != null else null


static func display_name_for_type(type_id: StringName) -> String:
	return _DISPLAY_NAMES.get(type_id, "") as String


static func type_id_for_block(block: FlowBlock) -> StringName:
	if block == null:
		return &""
	for type_id: StringName in _ORDER:
		if block.get_script() == _SCRIPTS[type_id]:
			return type_id
	return &""


static func default_display_name(block: FlowBlock) -> String:
	var type_id: StringName = type_id_for_block(block)
	return display_name_for_type(type_id) if not type_id.is_empty() else block.display_name
