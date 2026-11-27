extends Node


const TEMP_ROOT: String = "res://.godot/flujo_tests/akis_text_v1"
const RESOURCE_PATH: String = TEMP_ROOT + "/akis_text_v1.tres"
const FPRINT_SCRIPT: Script = preload("res://flow_packages/mercury.fprint/block.gd")


var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_multiple_independent_text_toks_and_ids()
	_test_order_edit_delete_independence_and_empty_spaces()
	_test_evaluable_resolution_and_type_config()
	_test_serialization_and_legacy_compatibility()
	_test_fprint_akis_defaults_and_concat()
	_cleanup()
	_finish()


func _test_multiple_independent_text_toks_and_ids() -> void:
	# Continuous text is one Tok Texto; multiple independent text toks are still
	# valid when intentionally separate instances exist in Akis.
	var doc: FlowStructuredDocument = FlowStructuredDocument.new()
	var phrase: FlowTextSegment = FlowTextSegment.new()
	phrase.text = "Hola mundo"
	doc.segments = [phrase]
	_check(doc.segments.size() == 1 and doc.segments[0] is FlowTextSegment,
		"A continuous phrase is represented as a single Text Tok.")
	_check((doc.segments[0] as FlowTextSegment).text == "Hola mundo",
		"Continuous text is not fragmented by words/spaces.")

	var t1: FlowTextSegment = FlowTextSegment.new()
	var t2: FlowTextSegment = FlowTextSegment.new()
	t1.text = "A"
	t2.text = "B"
	var multi: FlowStructuredDocument = FlowStructuredDocument.new()
	multi.segments = [t1, t2]
	_check(multi.segments.size() == 2, "Akis can hold multiple independent Text Toks when intentionally present.")
	_check(FlowId.is_valid(t1.get_segment_id()) and FlowId.is_valid(t2.get_segment_id()),
		"Each Text Tok has a valid stable FlowId.")
	_check(t1.get_segment_id() != t2.get_segment_id(), "Text Tok IDs are unique.")
	_check(t1.get_segment_type() == &"text" and t2.get_segment_type() == &"text",
		"Text Toks preserve text type.")
	var ids_before: Array[String] = [t1.get_segment_id(), t2.get_segment_id()]
	_check(t1.get_segment_id() == ids_before[0] and t2.get_segment_id() == ids_before[1],
		"Text Tok IDs remain stable across reads.")


func _test_order_edit_delete_independence_and_empty_spaces() -> void:
	var doc: FlowStructuredDocument = FlowStructuredDocument.new()
	var t1: FlowTextSegment = FlowTextSegment.new()
	var t2: FlowTextSegment = FlowTextSegment.new()
	var t3: FlowTextSegment = FlowTextSegment.new()
	t1.text = "A"
	t2.text = "B"
	t3.text = "C"
	doc.segments = [t1, t2, t3]
	# Edit independent tok
	t2.text = "B2"
	_check(t1.text == "A" and t2.text == "B2" and t3.text == "C",
		"Editing one Text Tok does not modify others.")
	# Delete independent tok
	doc.segments.remove_at(1)
	_check(doc.segments.size() == 2 and doc.segments[0] == t1 and doc.segments[1] == t3,
		"Deleting one Text Tok preserves others and order of remaining.")
	_check((doc.segments[0] as FlowTextSegment).text == "A" and (doc.segments[1] as FlowTextSegment).text == "C",
		"Remaining Text Toks keep their content after deletion.")
	# Continuous text, empty text and spaces in a single tok
	var single: FlowStructuredDocument = FlowStructuredDocument.new()
	var phrase: FlowTextSegment = FlowTextSegment.new()
	phrase.text = "Hola mundo"
	single.segments = [phrase]
	var phrase_rendered: FlowStructuredRenderResult = FlowStructuredDocumentResolver.resolve_text(single)
	_check(phrase_rendered.text == "Hola mundo", "Continuous phrase resolves as a single Text Tok value.")
	var doc2: FlowStructuredDocument = FlowStructuredDocument.new()
	var empty_tok: FlowTextSegment = FlowTextSegment.new()
	empty_tok.text = ""
	doc2.segments = [empty_tok]
	var rendered_empty: FlowStructuredRenderResult = FlowStructuredDocumentResolver.resolve_text(doc2)
	_check(not rendered_empty.has_errors() and rendered_empty.text == "",
		"Empty Text Tok is allowed and resolves to empty string.")
	var doc3: FlowStructuredDocument = FlowStructuredDocument.new()
	var spaces: FlowTextSegment = FlowTextSegment.new()
	spaces.text = "  \n\t"
	doc3.segments = [spaces]
	var rendered_spaces: FlowStructuredRenderResult = FlowStructuredDocumentResolver.resolve_text(doc3)
	_check(rendered_spaces.text == "  \n\t", "Spaces and newlines are preserved within the Text Tok.")


func _test_evaluable_resolution_and_type_config() -> void:
	var doc: FlowStructuredDocument = FlowStructuredDocument.new()
	var t1: FlowTextSegment = FlowTextSegment.new()
	var t2: FlowTextSegment = FlowTextSegment.new()
	var t3: FlowTextSegment = FlowTextSegment.new()
	t1.text = "Hola "
	t2.text = "IGNORAR"
	t3.text = "mundo"
	t1.evaluable = true
	t2.evaluable = false
	t3.evaluable = true
	doc.segments = [t1, t2, t3]
	var rendered: FlowStructuredRenderResult = FlowStructuredDocumentResolver.resolve_text(doc)
	_check(not rendered.has_errors(), "Akis with mixed evaluable states resolves without errors.")
	_check(rendered.text == "Hola mundo", "evaluable=false excludes Tok value while preserving order of evaluable Toks.")
	_check(t2.text == "IGNORAR" and not t2.evaluable, "Non-evaluable Tok remains visible/editable state in data (content preserved).")

	# All evaluable in a single continuous Tok
	var doc_all: FlowStructuredDocument = FlowStructuredDocument.new()
	var a: FlowTextSegment = FlowTextSegment.new()
	a.text = "Hola mundo"
	doc_all.segments = [a]
	var r_all: FlowStructuredRenderResult = FlowStructuredDocumentResolver.resolve_text(doc_all)
	_check(r_all.text == "Hola mundo", "evaluable=true Text Tok is included.")

	# Type config (author contract) and insertable flag
	var cfg_doc: FlowStructuredDocument = FlowStructuredDocument.new()
	cfg_doc.akis_type_config = {"text": {"insertable": false, "evaluable": true}}
	cfg_doc.akis_preconfiguration = ["text"]
	_check(cfg_doc.is_tok_type_insertable(FlowStructuredDocument.TOK_TYPE_TEXT) == false,
		"Akis type config can mark Text insertable=false (prevents new insertions by contract).")
	_check(cfg_doc.is_tok_type_evaluable_by_default(FlowStructuredDocument.TOK_TYPE_TEXT) == true,
		"Akis type config preserves evaluable setting for Text type.")
	# Existing toks must not be removed when insertable becomes false
	var existing: FlowTextSegment = FlowTextSegment.new()
	existing.text = "persist"
	cfg_doc.segments = [existing]
	_check(cfg_doc.segments.size() == 1 and (cfg_doc.segments[0] as FlowTextSegment).text == "persist",
		"Existing Toks are preserved when insertable changes to false.")


func _test_serialization_and_legacy_compatibility() -> void:
	_check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT)) == OK,
		"Create scoped Akis Text V1 persistence directory.")
	var doc: FlowStructuredDocument = FlowStructuredDocument.new()
	doc.akis_type_config = {"text": {"insertable": true, "evaluable": true}}
	doc.akis_preconfiguration = ["text"]
	var t1: FlowTextSegment = FlowTextSegment.new()
	var t2: FlowTextSegment = FlowTextSegment.new()
	t1.text = "Hola "
	t2.text = "mundo"
	t2.evaluable = false
	doc.segments = [t1, t2]
	_check(ResourceSaver.save(doc, RESOURCE_PATH) == OK, "Akis document with Text Toks persists via ResourceSaver.")
	var loaded: FlowStructuredDocument = ResourceLoader.load(
		RESOURCE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP
	) as FlowStructuredDocument
	_check(loaded != null, "Akis document reloads successfully.")
	if loaded != null:
		_check(loaded.segments.size() == 2, "Reload preserves Text Tok count and order.")
		if loaded.segments.size() == 2 and loaded.segments[0] is FlowTextSegment and loaded.segments[1] is FlowTextSegment:
			var lt1: FlowTextSegment = loaded.segments[0] as FlowTextSegment
			var lt2: FlowTextSegment = loaded.segments[1] as FlowTextSegment
			_check(lt1.get_segment_id() == t1.get_segment_id() and lt2.get_segment_id() == t2.get_segment_id(),
				"Reload preserves stable Text Tok IDs.")
			_check(lt1.text == "Hola " and lt2.text == "mundo",
				"Reload preserves Text Tok contents and spaces.")
			_check(lt1.evaluable == true and lt2.evaluable == false,
				"Reload preserves per-Tok evaluable state.")
		var rendered: FlowStructuredRenderResult = FlowStructuredDocumentResolver.resolve_text(loaded)
		_check(rendered.text == "Hola ", "Reloaded Akis resolves evaluable Toks correctly.")

	# Legacy compatibility: document without Akis config fields/evaluable defaults still resolves.
	var legacy_doc: FlowStructuredDocument = FlowStructuredDocument.new()
	var legacy_text: FlowTextSegment = FlowTextSegment.new()
	legacy_text.text = "legacy"
	legacy_doc.segments = [legacy_text]
	var legacy_rendered: FlowStructuredRenderResult = FlowStructuredDocumentResolver.resolve_text(legacy_doc)
	_check(not legacy_rendered.has_errors() and legacy_rendered.text == "legacy",
		"Legacy structured documents remain compatible and render evaluable text by default.")


func _test_fprint_akis_defaults_and_concat() -> void:
	var block: FlowBlock = FPRINT_SCRIPT.new() as FlowBlock
	_check(block != null, "FPrint block can be instantiated.")
	if block == null:
		return
	var doc: FlowStructuredDocument = block.get(&"document") as FlowStructuredDocument
	_check(doc != null and doc.segments.size() == 1 and doc.segments[0] is FlowTextSegment,
		"FPrint Akis contains an initial Text Tok by default.")
	if doc != null and doc.segments.size() == 1 and doc.segments[0] is FlowTextSegment:
		_check((doc.segments[0] as FlowTextSegment).text.is_empty(),
			"Initial FPrint Text Tok is empty; placeholder is not part of document.")
	# Single continuous Text Tok
	var d2: FlowStructuredDocument = FlowStructuredDocument.new()
	var a: FlowTextSegment = FlowTextSegment.new()
	a.text = "Hola mundo"
	d2.segments = [a]
	block.set(&"document", d2)
	block.set(&"prefix", "")
	block.set(&"suffix", "")
	_check((block as FlowOutputBlock).get_output_message() == "Hola mundo",
		"FPrint outputs the single continuous evaluable Text Tok.")
	# Evaluable false exclusion
	a.evaluable = false
	_check((block as FlowOutputBlock).get_output_message() == "",
		"FPrint excludes non-evaluable Text Tok content.")
	a.evaluable = true
	a.text = "Hola "
	var b: FlowTextSegment = FlowTextSegment.new()
	b.text = "mundo"
	b.evaluable = false
	d2.segments = [a, b]
	_check((block as FlowOutputBlock).get_output_message() == "Hola ",
		"FPrint excludes non-evaluable Tok while preserving spaces/content of evaluable Toks.")
	# User Note does not participate
	block.set(&"user_note", "nota interna")
	_check((block as FlowOutputBlock).get_output_message() == "Hola ",
		"User Note does not participate in FPrint output.")


func _cleanup() -> void:
	var absolute_root: String = ProjectSettings.globalize_path(TEMP_ROOT)
	if not DirAccess.dir_exists_absolute(absolute_root):
		return
	var directory: DirAccess = DirAccess.open(absolute_root)
	if directory == null:
		return
	for file_name: String in directory.get_files():
		DirAccess.remove_absolute(absolute_root.path_join(file_name))
	DirAccess.remove_absolute(absolute_root)


func _check(condition: bool, message: String) -> bool:
	if not condition:
		_failures.append(message)
		push_error(message)
	return condition


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Akis Text V1 test passed")
	else:
		for failure: String in _failures:
			push_error(failure)
	get_tree().quit(0 if _failures.is_empty() else 1)
