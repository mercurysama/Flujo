@tool
extends SceneTree

## Execute: godot --headless --path . --script res://tests/editor/pixnido_export_writer_smoke.gd

const WRITER := preload("res://addons/pixnido_panel_lab/sprite_export_writer.gd")
const TEST_DIR: String = "res://.godot/pixnido_writer_test/"


func _initialize() -> void:
	var failures: Array[String] = []
	if not WRITER.valid_directory("res://assets/sprites/"):
		failures.append("default destination rejected")
	if WRITER.valid_directory("res://../other"):
		failures.append("directory traversal was accepted")
	if WRITER.valid_directory("/tmp"):
		failures.append("external filesystem path was accepted")
	if "/" in WRITER.file_stem("../unsafe name:"):
		failures.append("unsafe filename not sanitized")

	var image: Image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.RED)
	var png: PackedByteArray = image.save_png_to_buffer()
	if png.is_empty():
		failures.append("could not construct test PNG")
	else:
		var encoded: String = Marshalls.raw_to_base64(png)
		var bad_directory: Dictionary = WRITER.write_base64(encoded, "image/png", "../sprite", "res://../other")
		if bool(bad_directory.get("ok", false)):
			failures.append("wrote to invalid directory")
		var bad_mime: Dictionary = WRITER.write_base64(encoded, "text/html", "sprite", TEST_DIR)
		if bool(bad_mime.get("ok", false)):
			failures.append("accepted unsupported MIME")
		var bad_data: Dictionary = WRITER.write_base64("AAAA", "image/png", "sprite", TEST_DIR)
		if bool(bad_data.get("ok", false)):
			failures.append("accepted invalid PNG")
		var first: Dictionary = WRITER.write_base64(encoded, "image/png", "../my sprite", TEST_DIR)
		var second: Dictionary = WRITER.write_base64(encoded, "image/png", "../my sprite", TEST_DIR)
		if not bool(first.get("ok", false)) or not bool(second.get("ok", false)):
			failures.append("failed PNG file write")
		else:
			var a: String = String(first.get("path", ""))
			var b: String = String(second.get("path", ""))
			if a == b:
				failures.append("second export overwrote the first")
			if FileAccess.get_file_as_bytes(a) != png:
				failures.append("first export bytes differ")
			if FileAccess.get_file_as_bytes(b) != png:
				failures.append("second export bytes differ")
			DirAccess.remove_absolute(ProjectSettings.globalize_path(a))
			DirAccess.remove_absolute(ProjectSettings.globalize_path(b))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_DIR))

	if failures.is_empty():
		print("[PixNido] Sprite export writer smoke test passed")
		quit(0)
	else:
		for failure in failures:
			printerr("[PixNido] " + failure)
		quit(1)
