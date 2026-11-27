@tool
## Declarative catalog of Akis/Tok types available to Flujo editors/runtime.
## Enabled/insertable/evaluable are determined by code and block context.
class_name FlowTokCatalog
extends RefCounted


const TOK_TEXT: StringName = &"text"
const TOK_VARIABLE: StringName = &"variable"
const TOK_OPERATION: StringName = &"operation"
const TOK_VARIABLE_UPDATE: StringName = &"variable_update"

const CATEGORY_TEXT: StringName = &"text"
const CATEGORY_DATA: StringName = &"data"
const CATEGORY_EXPRESSION: StringName = &"expression"
const CATEGORY_ACTION: StringName = &"action"

const CONTEXT_GENERIC_AKIS: StringName = &"generic_akis"
const CONTEXT_FPRINT: StringName = &"fprint"
const CONTEXT_FSET: StringName = &"fset"


static func get_all_definitions() -> Array[Dictionary]:
	return [
		_definition(
			TOK_TEXT,
			"Text",
			CATEGORY_TEXT,
			"Literal text content.",
			Color(0.75, 0.75, 0.78),
			"",
			true,
			true,
			true,
			{"kind": "text"},
			"inline",
			Variant.Type.TYPE_STRING,
			[]
		),
		_definition(
			TOK_VARIABLE,
			"Variable",
			CATEGORY_DATA,
			"Reference to an existing graph variable.",
			Color(0.35, 0.68, 1.0),
			"",
			true,
			true,
			true,
			{"kind": "variable_ref", "requires_variable": true},
			"variable_selector",
			Variant.Type.TYPE_NIL,
			["requires_existing_variable", "respects_scope_and_type"]
		),
		_definition(
			TOK_OPERATION,
			"Operation",
			CATEGORY_EXPRESSION,
			"Evaluates an expression and returns a value.",
			Color(0.95, 0.72, 0.30),
			"",
			true,
			true,
			true,
			{"kind": "operation", "operators": ["+", "-", "*", "/", "%", "**", "//"]},
			"operation_editor",
			Variant.Type.TYPE_NIL,
			["no_side_effects", "type_checked"]
		),
		_definition(
			TOK_VARIABLE_UPDATE,
			"Variable update",
			CATEGORY_ACTION,
			"Updates a variable with side effects.",
			Color(0.95, 0.45, 0.45),
			"",
			true,
			false,
			true,
			{"kind": "variable_update", "operators": ["++", "--", "+=", "-=", "*=", "/=", "%=", "**=", "//="]},
			"variable_update_editor",
			Variant.Type.TYPE_NIL,
			["side_effects", "single_evaluation_required", "writable_target"]
		),
	]


static func get_definition(type_id: StringName) -> Dictionary:
	for definition: Dictionary in get_all_definitions():
		if StringName(definition.get("id", &"")) == type_id:
			return definition.duplicate(true)
	return {}


static func get_insertable_definitions(context: StringName = CONTEXT_GENERIC_AKIS) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition: Dictionary in get_all_definitions():
		if not bool(definition.get("enabled", false)) or not bool(definition.get("insertable", false)):
			continue
		if _is_allowed_in_context(StringName(definition.get("id", &"")), context):
			result.append(definition.duplicate(true))
	return result


static func is_type_enabled(type_id: StringName) -> bool:
	return bool(get_definition(type_id).get("enabled", false))


static func is_type_insertable(type_id: StringName, context: StringName = CONTEXT_GENERIC_AKIS) -> bool:
	var definition: Dictionary = get_definition(type_id)
	if definition.is_empty():
		return false
	return bool(definition.get("enabled", false)) \
		and bool(definition.get("insertable", false)) \
		and _is_allowed_in_context(type_id, context)


static func is_type_evaluable(type_id: StringName) -> bool:
	return bool(get_definition(type_id).get("evaluable", false))


static func _is_allowed_in_context(type_id: StringName, context: StringName) -> bool:
	match context:
		CONTEXT_FPRINT:
			# Side-effect updates are not auto-enabled in FPrint evaluation contexts.
			return type_id != TOK_VARIABLE_UPDATE
		_:
			return true


static func _definition(
		id: StringName,
		name: String,
		category: StringName,
		description: String,
		color: Color,
		icon: String,
		enabled: bool,
		insertable: bool,
		evaluable: bool,
		config_schema: Dictionary,
		editor: String,
		result_type: Variant.Type,
		validation_rules: Array
) -> Dictionary:
	return {
		"id": id,
		"name": name,
		"category": category,
		"description": description,
		"color": color,
		"icon": icon,
		"enabled": enabled,
		"insertable": insertable,
		"evaluable": evaluable,
		"config_schema": config_schema.duplicate(true),
		"editor": editor,
		"result_type": result_type,
		"validation_rules": validation_rules.duplicate(),
	}
