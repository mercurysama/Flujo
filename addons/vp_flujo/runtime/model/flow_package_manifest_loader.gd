@tool
class_name FlowPackageManifestLoader
extends RefCounted

## Discovers only manifest metadata. It never loads or instantiates scripts.

const ROOT_PATH: String = "res://flow_packages"
const MANIFEST_FILE_NAME: String = "manifest.json"
const MANIFEST_VERSION: int = 1


func discover(root_path: String = ROOT_PATH) -> FlowPackageManifestDiscoveryResult:
	var result: FlowPackageManifestDiscoveryResult = FlowPackageManifestDiscoveryResult.new()
	var root: DirAccess = DirAccess.open(root_path)
	if root == null:
		_issue(result, &"package_root_missing", root_path, "", "Package root does not exist.")
		return result
	var package_ids: Array[String] = []
	root.list_dir_begin()
	var entry_name: String = root.get_next()
	while not entry_name.is_empty():
		if root.current_is_dir() and entry_name != "." and entry_name != "..":
			package_ids.append(entry_name)
		entry_name = root.get_next()
	root.list_dir_end()
	package_ids.sort()

	var global_type_ids: Dictionary = {}
	for package_id: String in package_ids:
		var manifest: FlowPackageManifest = _read_package(root_path, package_id, result)
		if manifest == null:
			continue
		for descriptor: FlowExternalBlockDescriptor in manifest.blocks:
			var global_type_id: String = descriptor.global_type_id()
			if global_type_ids.has(global_type_id):
				_issue(result, &"duplicate_global_type_id", _manifest_path(root_path, package_id) + ".blocks", global_type_id,
					"Global package/type ID is already declared.")
				manifest = null
				break
			global_type_ids[global_type_id] = true
		if manifest != null:
			result.manifests.append(manifest)
	return result


func _read_package(root_path: String, directory_name: String,
		result: FlowPackageManifestDiscoveryResult) -> FlowPackageManifest:
	var manifest_path: String = _manifest_path(root_path, directory_name)
	if not FileAccess.file_exists(manifest_path):
		_issue(result, &"package_manifest_missing", manifest_path, directory_name, "Package manifest is missing.")
		return null
	var file: FileAccess = FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		_issue(result, &"package_manifest_read_failed", manifest_path, directory_name, "Package manifest cannot be read.")
		return null
	var parser: JSON = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		_issue(result, &"package_manifest_json_invalid", manifest_path, directory_name, "Package manifest is not valid JSON.")
		return null
	var raw: Variant = parser.data
	if not raw is Dictionary:
		_issue(result, &"package_manifest_root_invalid", manifest_path, directory_name, "Package manifest root must be an object.")
		return null
	var data: Dictionary = raw as Dictionary
	var valid: bool = true
	var version: int = 0
	if not data.has("manifest_version") \
			or (typeof(data["manifest_version"]) != TYPE_INT and typeof(data["manifest_version"]) != TYPE_FLOAT):
		_issue(result, &"package_manifest_version_invalid", manifest_path + ".manifest_version", directory_name,
			"manifest_version must be integer 1.")
		valid = false
	else:
		version = int(data["manifest_version"])
		if version != MANIFEST_VERSION:
			_issue(result, &"package_manifest_version_invalid", manifest_path + ".manifest_version", directory_name,
				"manifest_version must be integer 1.")
			valid = false

	var manifest_package_id: String = ""
	if not data.has("package_id") or typeof(data["package_id"]) != TYPE_STRING or String(data["package_id"]).strip_edges().is_empty():
		_issue(result, &"package_manifest_package_id_invalid", manifest_path + ".package_id", directory_name,
			"package_id must be a non-empty string.")
		valid = false
	else:
		manifest_package_id = String(data["package_id"]).strip_edges()
		if manifest_package_id != directory_name:
			_issue(result, &"package_manifest_package_id_mismatch", manifest_path + ".package_id", directory_name,
				"package_id must match the package directory.")
			valid = false

	if not data.has("blocks") or not data["blocks"] is Array:
		_issue(result, &"package_manifest_blocks_invalid", manifest_path + ".blocks", directory_name,
			"blocks must be an array.")
		return null

	var manifest: FlowPackageManifest = FlowPackageManifest.new(manifest_package_id, version)
	var seen_type_ids: Dictionary = {}
	var raw_blocks: Array = data["blocks"] as Array
	for index: int in raw_blocks.size():
		var block_path: String = manifest_path + ".blocks[%d]" % index
		var raw_block: Variant = raw_blocks[index]
		if not raw_block is Dictionary:
			_issue(result, &"package_manifest_block_invalid", block_path, directory_name, "Block descriptor must be an object.")
			valid = false
			continue
		var block: Dictionary = raw_block as Dictionary
		var type_id: String = _required_string(block, "type_id", block_path, directory_name, result)
		var script_path: String = _required_string(block, "script", block_path, directory_name, result)
		var display_name: String = _required_string(block, "display_name", block_path, directory_name, result)
		if type_id.is_empty() or script_path.is_empty() or display_name.is_empty():
			valid = false
		if not script_path.is_empty() and not _is_relative_script_path(script_path):
			_issue(result, &"package_manifest_script_path_invalid", block_path + ".script", directory_name,
				"script must remain a relative path inside the package.")
			valid = false
		if not type_id.is_empty():
			if seen_type_ids.has(type_id):
				_issue(result, &"package_manifest_type_id_duplicate", block_path + ".type_id", directory_name + ":" + type_id,
					"type_id is duplicated within the package.")
				valid = false
			else:
				seen_type_ids[type_id] = true
		if not type_id.is_empty() and not script_path.is_empty() and not display_name.is_empty() \
				and _is_relative_script_path(script_path):
			manifest.add_block(FlowExternalBlockDescriptor.new(directory_name, type_id, script_path, display_name))
	if not valid:
		return null
	return manifest


func _required_string(data: Dictionary, key: String, block_path: String, related_id: String,
		result: FlowPackageManifestDiscoveryResult) -> String:
	if not data.has(key) or typeof(data[key]) != TYPE_STRING or String(data[key]).strip_edges().is_empty():
		_issue(result, &"package_manifest_block_field_empty", block_path + "." + key, related_id,
			key + " must be a non-empty string.")
		return ""
	return String(data[key]).strip_edges()


func _is_relative_script_path(path: String) -> bool:
	if path.is_empty() or path.begins_with("/") or path.begins_with("\\") or path.contains(":"):
		return false
	var depth: int = 0
	for segment: String in path.replace("\\", "/").split("/"):
		if segment.is_empty() or segment == ".":
			continue
		if segment == "..":
			depth -= 1
			if depth < 0:
				return false
		else:
			depth += 1
	return true


func _manifest_path(root_path: String, package_id: String) -> String:
	return root_path.path_join(package_id).path_join(MANIFEST_FILE_NAME)


static func _issue(result: FlowPackageManifestDiscoveryResult, code: StringName, path: String,
		related_id: String, message: String) -> void:
	result.add_diagnostic(FlowDiagnostic.new(code, FlowDiagnostic.Severity.ERROR, message, path, related_id))
