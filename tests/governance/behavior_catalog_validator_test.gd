extends SceneTree

const VALIDATOR := preload("res://tools/behavior_catalog_validator.gd")
const CATALOG_PATH: String = "res://docs/behavior_catalog.json"

var _failures: Array[String] = []

func _init() -> void:
	_run.call_deferred()

func _run() -> void:
	var actual_failures: PackedStringArray = VALIDATOR.validate_file(CATALOG_PATH)
	_check(actual_failures.is_empty(), "The versioned behavior catalog is valid: %s" % "; ".join(actual_failures))
	var catalog: Dictionary = _load_catalog()
	if catalog.is_empty():
		_finish()
		return

	var duplicate: Dictionary = catalog.duplicate(true)
	duplicate.behaviors.append(duplicate.behaviors[0].duplicate(true))
	_check(_contains(VALIDATOR.validate_catalog(duplicate), "Duplicate behavior ID"), "Duplicate stable IDs are rejected.")

	var missing_field: Dictionary = catalog.duplicate(true)
	missing_field.behaviors[0].erase("precondition")
	_check(_contains(VALIDATOR.validate_catalog(missing_field), ".precondition is required"), "Missing mandatory fields are rejected.")

	var missing_path: Dictionary = catalog.duplicate(true)
	missing_path.behaviors[0].test_paths = ["tests/does_not_exist.gd"]
	_check(_contains(VALIDATOR.validate_catalog(missing_path), "test_paths does not exist"), "Nonexistent evidence paths are rejected.")

	if _failures.is_empty():
		print("[Flujo] Behavior catalog validator passed")
	_finish()

func _load_catalog() -> Dictionary:
	var file: FileAccess = FileAccess.open(CATALOG_PATH, FileAccess.READ)
	if not _check(file != null, "Open the behavior catalog fixture."):
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not _check(parsed is Dictionary, "Parse the behavior catalog fixture."):
		return {}
	return parsed as Dictionary

func _contains(failures: PackedStringArray, fragment: String) -> bool:
	for failure: String in failures:
		if failure.contains(fragment):
			return true
	return false

func _check(condition: bool, message: String) -> bool:
	if not condition:
		_failures.append(message)
		push_error("[Flujo][BehaviorCatalog] " + message)
	return condition

func _finish() -> void:
	quit(0 if _failures.is_empty() else 1)
