@tool
## Persistent ordered document composed of reusable runtime segments.
class_name FlowStructuredDocument
extends Resource


const CURRENT_VERSION: int = 1
const TOK_TYPE_TEXT: StringName = &"text"

@export_storage var version: int = CURRENT_VERSION
@export var segments: Array[FlowDocumentSegment] = []
## Author-defined Akis contract (block-level), not end-user editable UI state.
## Keys are tok type ids (e.g. "text"). Values are dictionaries like
## {"insertable": bool, "evaluable": bool}. Missing/empty uses V1 defaults.
@export var akis_type_config: Dictionary = {}
## Optional initial tok type sequence for this Akis contract (e.g. ["text"]).
## Empty means no forced preconfiguration beyond defaults/free insertion rules.
@export var akis_preconfiguration: Array[String] = []


## Compatibility alias for consumers that name the persisted revision explicitly.
var document_version: int:
	get:
		return version
	set(value):
		version = value


## Compatibility alias for model code that uses schema-style terminology.
var schema_version: int:
	get:
		return version
	set(value):
		version = value


func get_version() -> int:
	return version


## Returns effective type config for V1. Only "text" is implemented in this cycle.
func get_akis_type_config(type_id: StringName) -> Dictionary:
	var key: String = String(type_id)
	if akis_type_config.has(key) and akis_type_config[key] is Dictionary:
		var cfg: Dictionary = (akis_type_config[key] as Dictionary).duplicate(true)
		if not cfg.has("insertable"):
			cfg["insertable"] = _default_insertable(type_id)
		if not cfg.has("evaluable"):
			cfg["evaluable"] = _default_evaluable(type_id)
		return cfg
	if akis_type_config.has(type_id) and akis_type_config[type_id] is Dictionary:
		var cfg2: Dictionary = (akis_type_config[type_id] as Dictionary).duplicate(true)
		if not cfg2.has("insertable"):
			cfg2["insertable"] = _default_insertable(type_id)
		if not cfg2.has("evaluable"):
			cfg2["evaluable"] = _default_evaluable(type_id)
		return cfg2
	return {
		"insertable": _default_insertable(type_id),
		"evaluable": _default_evaluable(type_id),
	}


func is_tok_type_insertable(type_id: StringName) -> bool:
	return bool(get_akis_type_config(type_id).get("insertable", _default_insertable(type_id)))


func is_tok_type_evaluable_by_default(type_id: StringName) -> bool:
	return bool(get_akis_type_config(type_id).get("evaluable", _default_evaluable(type_id)))


func get_effective_preconfiguration() -> Array[String]:
	if not akis_preconfiguration.is_empty():
		return akis_preconfiguration.duplicate()
	# V1 default: Tok Texto allowed/evaluable, preconfiguration ["text"].
	return [String(TOK_TYPE_TEXT)]


func _default_insertable(type_id: StringName) -> bool:
	if type_id == TOK_TYPE_TEXT:
		return true
	return false


func _default_evaluable(type_id: StringName) -> bool:
	if type_id == TOK_TYPE_TEXT:
		return true
	return false


## Ensures a V1 Akis has at least the default/preconfigured initial Text Tok.
## Does not delete existing toks; preserves legacy content.
func ensure_default_text_tok_if_empty() -> bool:
	if not segments.is_empty():
		return false
	var pre: Array[String] = get_effective_preconfiguration()
	var initial_type: String = String(TOK_TYPE_TEXT)
	for entry: Variant in pre:
		if entry is String or entry is StringName:
			initial_type = String(entry)
			break
	if initial_type != String(TOK_TYPE_TEXT):
		return false
	if not is_tok_type_insertable(TOK_TYPE_TEXT) and pre.is_empty():
		return false
	var tok: FlowTextSegment = FlowTextSegment.new()
	tok.text = ""
	tok.evaluable = is_tok_type_evaluable_by_default(TOK_TYPE_TEXT)
	segments.append(tok)
	return true


## Duplicates the document, preserving order and null positions while assigning
## independent IDs to every copied segment.
func duplicate_with_new_ids() -> FlowStructuredDocument:
	var copy: FlowStructuredDocument = duplicate(false) as FlowStructuredDocument
	copy.segments = []
	for segment: FlowDocumentSegment in segments:
		if segment == null:
			copy.segments.append(null)
		else:
			copy.segments.append(segment.duplicate_with_new_id())
	return copy


## Deep copy used by editor session snapshots. Persistent segment IDs remain
## unchanged so Revertir can restore the exact document that was opened.
func duplicate_preserving_ids() -> FlowStructuredDocument:
	var copy: FlowStructuredDocument = duplicate(false) as FlowStructuredDocument
	copy.segments = []
	for segment: FlowDocumentSegment in segments:
		if segment == null:
			copy.segments.append(null)
		else:
			copy.segments.append(segment.duplicate(true) as FlowDocumentSegment)
	return copy
