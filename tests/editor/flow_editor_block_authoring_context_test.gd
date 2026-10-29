@tool
extends SceneTree


const MANUAL_FIXTURE_ROOT: String = "res://tests/fixtures/manual_block_sdk"
const EXTERNAL_FIXTURE_ROOT: String = "res://tests/fixtures/external_manifests"
const AUTHORING_ID: String = "manual_output:output"
const MISSING_PACKAGE_ROOT: String = "res://.godot/flujo_tests/d3_missing_packages"
const AUTHORING_CONTEXT_SCRIPT: Script = preload(
	"res://addons/vp_flujo/editor/flow_editor_block_authoring_context.gd"
)


var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_integrated_snapshot_without_packages()
	_test_manual_external_snapshot_and_creation()
	_test_invalid_external_entries_and_diagnostics()
	_test_stale_entry_failure_is_deterministic()
	if _failures.is_empty():
		print("[Flujo] Editor block authoring context test passed")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	quit(1)


func _test_integrated_snapshot_without_packages() -> void:
	var context = AUTHORING_CONTEXT_SCRIPT.new()
	var entries: Array[FlowEditorBlockCatalogEntry] = context.get_entries()
	_check(entries.size() == 3, "The canonical package root still exposes built-ins when it is absent.")
	if entries.size() == 3:
		_check(entries[0].authoring_id == "print", "Print remains first in the editor snapshot.")
		_check(entries[1].authoring_id == "everything_flows", "Everything Flows remains second in the editor snapshot.")
		_check(entries[2].authoring_id == "custom_hello", "Custom Hello remains third in the editor snapshot.")
	var print_result = context.create_block("print")
	_check(print_result.is_successful() and print_result.block is FlowPrintBlock,
		"Integrated creation uses the registry through the common result.")
	_check(print_result.authoring_id == "print", "Integrated creation preserves its stable authoring ID.")


func _test_manual_external_snapshot_and_creation() -> void:
	var context = AUTHORING_CONTEXT_SCRIPT.new(MANUAL_FIXTURE_ROOT)
	var entries: Array[FlowEditorBlockCatalogEntry] = context.get_entries()
	_check(entries.size() == 4, "The injected manual fixture appends one external entry after built-ins.")
	if entries.size() == 4:
		_check(entries[3].authoring_id == AUTHORING_ID, "The external entry uses package_id:type_id identity.")
		_check(entries[3].display_name == "Manual Output", "The external display name comes from the manifest.")

	var first = context.create_block(AUTHORING_ID)
	var second = context.create_block(AUTHORING_ID)
	_check(first.is_successful() and first.block is FlowOutputBlock,
		"External creation uses the validated factory through the common result.")
	_check(first.block != null and first.block.get_script().resource_path.ends_with(
		"/tests/fixtures/manual_block_sdk/manual_output/block.gd"
	), "External creation retains the injected package script.")
	_check(second.is_successful() and second.block != null and first.block != second.block,
		"Two external creations return independent instances.")
	if first.block != null and second.block != null:
		_check(first.block.get_internal_id() != second.block.get_internal_id(),
			"Two external creations receive independent persistent IDs.")


func _test_invalid_external_entries_and_diagnostics() -> void:
	var context = AUTHORING_CONTEXT_SCRIPT.new(EXTERNAL_FIXTURE_ROOT)
	var catalog: FlowEditorBlockCatalog = context.get_catalog()
	_check(catalog != null and catalog.find("mixed_script:valid") != null,
		"A valid external descriptor remains in the catalog beside invalid siblings.")
	_check(catalog.find("mixed_script:missing") == null and catalog.find("mixed_script:broken") == null,
		"Invalid external scripts are excluded from the authoring snapshot.")
	_check(catalog.find("invalid_duplicate:same") == null,
		"A metadata-invalid package is excluded from the authoring snapshot.")
	_check(_has_diagnostic(context.get_diagnostics(), &"package_manifest_type_id_duplicate"),
		"Manifest diagnostics remain available from the editor context.")
	_check(_has_diagnostic(context.get_diagnostics(), &"external_script_missing"),
		"Script diagnostics remain available from the editor context.")


func _test_stale_entry_failure_is_deterministic() -> void:
	var context = AUTHORING_CONTEXT_SCRIPT.new(MANUAL_FIXTURE_ROOT)
	var result = context.create_block("missing:entry")
	_check(not result.is_successful() and result.block == null,
		"A stale authoring ID fails without producing a partial block.")
	_check(result.diagnostics.size() == 1 and result.diagnostics[0].code == &"editor_authoring_entry_missing",
		"A stale authoring ID publishes one deterministic diagnostic.")
	_check(not FileAccess.get_file_as_string(
		"res://addons/vp_flujo/editor/flow_editor_block_authoring_context.gd"
	).contains("manual_block_sdk"), "Production context contains no fixture path.")


func _has_diagnostic(diagnostics: Array[FlowDiagnostic], code: StringName) -> bool:
	for diagnostic: FlowDiagnostic in diagnostics:
		if diagnostic.code == code:
			return true
	return false


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
