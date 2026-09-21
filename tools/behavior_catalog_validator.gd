@tool
extends RefCounted

const DEFAULT_PATH: String = "res://docs/behavior_catalog.json"
const REQUIRED_STRING_FIELDS: Array[String] = [
	"id", "area", "precondition", "public_action", "expected_result", "coverage", "baseline_status",
]
const COVERAGE_TYPES: Array[String] = ["automatic", "manual", "missing"]
const BASELINE_STATUSES: Array[String] = [
	"passing", "failing", "not_run", "manual_approved", "manual_pending", "not_covered",
]

static func validate_file(path: String = DEFAULT_PATH) -> PackedStringArray:
	var failures: PackedStringArray = []
	if not FileAccess.file_exists(path):
		failures.append("Catalog file does not exist: %s" % path)
		return failures
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		failures.append("Catalog file cannot be read: %s" % path)
		return failures
	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(file.get_as_text())
	if parse_error != OK:
		failures.append("Catalog JSON is invalid at line %d: %s" % [parser.get_error_line(), parser.get_error_message()])
		return failures
	return validate_catalog(parser.data)

static func validate_catalog(value: Variant) -> PackedStringArray:
	var failures: PackedStringArray = []
	if not value is Dictionary:
		failures.append("Catalog root must be a Dictionary.")
		return failures
	var catalog: Dictionary = value
	if catalog.get("schema", "") != "flujo.behavior-catalog/v1":
		failures.append("Catalog schema must be flujo.behavior-catalog/v1.")
	var version: Variant = catalog.get("catalog_version", null)
	if not (version is int or version is float) or float(version) < 1.0 or float(version) != floorf(float(version)):
		failures.append("catalog_version must be a positive integer.")
	if not catalog.get("behaviors", null) is Array:
		failures.append("behaviors must be an Array.")
		return failures
	var behaviors: Array = catalog.behaviors
	var seen_ids: Dictionary[String, int] = {}
	for index: int in behaviors.size():
		var prefix: String = "behaviors[%d]" % index
		if not behaviors[index] is Dictionary:
			failures.append("%s must be a Dictionary." % prefix)
			continue
		var behavior: Dictionary = behaviors[index]
		for field: String in REQUIRED_STRING_FIELDS:
			if not behavior.has(field) or not behavior[field] is String or String(behavior[field]).strip_edges().is_empty():
				failures.append("%s.%s is required and must be a non-empty String." % [prefix, field])
		var behavior_id: String = String(behavior.get("id", ""))
		if not behavior_id.begins_with("FLUJO-BHV-") or behavior_id != behavior_id.to_upper():
			failures.append("%s.id must be a stable uppercase FLUJO-BHV-* identifier." % prefix)
		elif seen_ids.has(behavior_id):
			failures.append("Duplicate behavior ID %s at %s and behaviors[%d]." % [behavior_id, prefix, seen_ids[behavior_id]])
		else:
			seen_ids[behavior_id] = index
		_validate_string_array(behavior, "invariants", prefix, failures, true)
		_validate_string_array(behavior, "test_paths", prefix, failures, false)
		var coverage: String = String(behavior.get("coverage", ""))
		if not COVERAGE_TYPES.has(coverage):
			failures.append("%s.coverage must be automatic, manual, or missing." % prefix)
		var baseline_status: String = String(behavior.get("baseline_status", ""))
		if not BASELINE_STATUSES.has(baseline_status):
			failures.append("%s.baseline_status is not recognized." % prefix)
		var paths: Array = behavior.get("test_paths", []) if behavior.get("test_paths", []) is Array else []
		if coverage in ["automatic", "manual"] and paths.is_empty():
			failures.append("%s requires at least one evidence path for %s coverage." % [prefix, coverage])
		if coverage == "missing" and not paths.is_empty():
			failures.append("%s with missing coverage must not claim evidence paths." % prefix)
		for path_value: Variant in paths:
			if not path_value is String or String(path_value).strip_edges().is_empty():
				continue
			var relative_path: String = String(path_value)
			if relative_path.begins_with("/") or relative_path.contains("..") or relative_path.begins_with("res://"):
				failures.append("%s.test_paths contains a non-relative repository path: %s" % [prefix, relative_path])
			elif not FileAccess.file_exists("res://" + relative_path):
				failures.append("%s.test_paths does not exist: %s" % [prefix, relative_path])
	return failures

static func _validate_string_array(behavior: Dictionary, field: String, prefix: String,
		failures: PackedStringArray, require_nonempty: bool) -> void:
	if not behavior.has(field) or not behavior[field] is Array:
		failures.append("%s.%s is required and must be an Array." % [prefix, field])
		return
	var values: Array = behavior[field]
	if require_nonempty and values.is_empty():
		failures.append("%s.%s must not be empty." % [prefix, field])
	for index: int in values.size():
		if not values[index] is String or String(values[index]).strip_edges().is_empty():
			failures.append("%s.%s[%d] must be a non-empty String." % [prefix, field, index])
