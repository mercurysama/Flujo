@tool
extends RefCounted

## Project-only sprite writer. The webpage cannot supply an output path.

const DEFAULT_DIRECTORY: String = "res://assets/sprites/"
const MAX_BYTES: int = 32 * 1024 * 1024


static func valid_directory(path: String) -> bool:
	if not path.begins_with("res://") or "\\" in path:
		return false
	var relative: String = path.trim_prefix("res://").trim_suffix("/")
	for component in relative.split("/"):
		if component == "." or component == ".." or ":" in component:
			return false
	var project_root: String = ProjectSettings.globalize_path("res://").simplify_path().trim_suffix("/")
	var absolute: String = ProjectSettings.globalize_path(path).simplify_path()
	return absolute == project_root or absolute.begins_with(project_root + "/")


static func file_stem(name: String) -> String:
	var clean: String = ""
	for i in range(mini(name.length(), 120)):
		var c: String = name.substr(i, 1)
		var point: int = c.unicode_at(0)
		if (point >= 48 and point <= 57) or (point >= 65 and point <= 90) or (point >= 97 and point <= 122) or c == "-" or c == "_":
			clean += c
		elif not clean.ends_with("_"):
			clean += "_"
	clean = clean.trim_prefix("_").trim_suffix("_")
	return "sprite" if clean.is_empty() else clean.substr(0, 64)


static func signature_valid(data: PackedByteArray, mime: String) -> bool:
	if mime == "image/png":
		return data.size() >= 33 and data[0] == 137 and data[1] == 80 and data[2] == 78 and data[3] == 71 and data[4] == 13 and data[5] == 10 and data[6] == 26 and data[7] == 10 and data[12] == 73 and data[13] == 72 and data[14] == 68 and data[15] == 82
	if mime == "image/webp":
		return data.size() >= 20 and data[0] == 82 and data[1] == 73 and data[2] == 70 and data[3] == 70 and data[8] == 87 and data[9] == 69 and data[10] == 66 and data[11] == 80
	return false


static func write_base64(encoded: String, mime: String, name: String, folder: String) -> Dictionary:
	if not valid_directory(folder):
		return {"ok": false, "message": "Destination must be inside the Godot project."}
	if mime != "image/png" and mime != "image/webp":
		return {"ok": false, "message": "Unsupported sprite image type."}
	if encoded.is_empty() or encoded.length() > 44739248 or encoded.length() % 4 != 0:
		return {"ok": false, "message": "Encoded sprite is invalid or too large."}
	var bytes: PackedByteArray = Marshalls.base64_to_raw(encoded)
	if bytes.is_empty() or bytes.size() > MAX_BYTES or not signature_valid(bytes, mime):
		return {"ok": false, "message": "Image header invalid or sprite exceeds 32 MiB."}

	var root: String = ProjectSettings.globalize_path(folder).simplify_path()
	var err: Error = DirAccess.make_dir_recursive_absolute(root)
	if err != OK:
		return {"ok": false, "message": "Cannot create destination folder: %d" % err}
	var ext: String = ".png" if mime == "image/png" else ".webp"
	var stamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var base: String = file_stem(name) + "-" + stamp
	var chosen: String = ""
	for i in range(10000):
		var candidate: String = base + ("" if i == 0 else "-%03d" % i) + ext
		if not FileAccess.file_exists(root.path_join(candidate)):
			chosen = candidate
			break
	if chosen.is_empty():
		return {"ok": false, "message": "No unused filename available."}
	var path: String = folder.trim_suffix("/").path_join(chosen)
	if folder == "res://":
		path = folder + chosen
	var output: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if output == null:
		return {"ok": false, "message": "Cannot open output file."}
	output.store_buffer(bytes)
	output.flush()
	var write_error: Error = output.get_error()
	output.close()
	if write_error != OK:
		DirAccess.remove_absolute(root.path_join(chosen))
		return {"ok": false, "message": "File write failed: %d" % write_error}
	return {"ok": true, "path": path, "size": bytes.size()}
