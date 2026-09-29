extends Node

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_descriptor()
	_test_manifest()
	_test_scope()
	if _failures.is_empty():
		print("[Flujo] External manifest descriptor test passed")
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	get_tree().quit(1)


func _test_descriptor() -> void:
	var descriptor: FlowExternalBlockDescriptor = FlowExternalBlockDescriptor.new(
		"demo",
		"sample",
		"res://flow_packages/demo/sample.gd",
		"Sample"
	)
	_check(descriptor.is_valid(), "A complete descriptor is valid.")
	_check(descriptor.global_type_id() == "demo:sample", "The global type ID uses package_id:type_id.")
	_check(descriptor.validation_errors().is_empty(), "A valid descriptor has no validation errors.")
	var repeated: FlowExternalBlockDescriptor = FlowExternalBlockDescriptor.new(
		"demo",
		"sample",
		"res://flow_packages/demo/sample.gd",
		"Sample"
	)
	_check(
		repeated.global_type_id() == descriptor.global_type_id() and repeated.validation_errors() == descriptor.validation_errors(),
		"Descriptor validation and global IDs are deterministic."
	)
	var empty: FlowExternalBlockDescriptor = FlowExternalBlockDescriptor.new("", "", "", "")
	_check(
		not empty.is_valid() and empty.validation_errors() == ["empty_package_id", "empty_type_id", "empty_script_path", "empty_display_name"],
		"Empty required descriptor fields are rejected in stable order."
	)


func _test_manifest() -> void:
	var manifest: FlowPackageManifest = FlowPackageManifest.new("demo")
	var first: FlowExternalBlockDescriptor = FlowExternalBlockDescriptor.new(
		"demo", "first", "res://flow_packages/demo/first.gd", "First"
	)
	var second: FlowExternalBlockDescriptor = FlowExternalBlockDescriptor.new(
		"demo", "second", "res://flow_packages/demo/second.gd", "Second"
	)
	_check(manifest.add_block(first), "A non-null descriptor can be added.")
	_check(manifest.add_block(second), "Manifest preserves the second descriptor.")
	_check(manifest.is_valid(), "A version 1 manifest with valid ordered descriptors is valid.")
	_check(manifest.blocks[0] == first and manifest.blocks[1] == second, "Manifest preserves descriptor order.")
	var duplicate: FlowPackageManifest = FlowPackageManifest.new("demo")
	duplicate.blocks = [first, FlowExternalBlockDescriptor.new(
		"demo", "first", "res://flow_packages/demo/other.gd", "Other"
	)]
	_check(
		not duplicate.is_valid() and duplicate.validation_errors() == ["duplicate_block_type_id:demo:first"],
		"Duplicate package/type IDs are rejected deterministically."
	)
	var mismatch: FlowPackageManifest = FlowPackageManifest.new("demo")
	mismatch.blocks = [FlowExternalBlockDescriptor.new(
		"other", "first", "res://flow_packages/other/first.gd", "First"
	)]
	_check(
		not mismatch.is_valid() and mismatch.validation_errors() == ["block_package_id_mismatch:0"],
		"A descriptor from another package is rejected without repair."
	)
	var future: FlowPackageManifest = FlowPackageManifest.new("demo", 2)
	_check(
		not future.is_valid() and future.validation_errors() == ["unsupported_manifest_version"],
		"An unsupported manifest version is rejected deterministically."
	)
	var null_entry: FlowPackageManifest = FlowPackageManifest.new("demo")
	null_entry.blocks = [null]
	_check(
		not null_entry.is_valid() and null_entry.validation_errors() == ["null_block_descriptor:0"],
		"A null descriptor is rejected without changing the ordered collection."
	)


func _test_scope() -> void:
	var descriptor_source: String = FileAccess.get_file_as_string(
		"res://addons/vp_flujo/runtime/model/flow_external_block_descriptor.gd"
	)
	var manifest_source: String = FileAccess.get_file_as_string(
		"res://addons/vp_flujo/runtime/model/flow_package_manifest.gd"
	)
	var combined: String = descriptor_source + manifest_source
	_check(not combined.contains("FlowReadyExecutor"), "Manifest data does not depend on the runtime executor.")
	_check(not combined.contains("FlowBlockRegistry"), "Manifest data does not depend on the built-in registry.")
	_check(not combined.contains("FlowIfBlock"), "Manifest data does not depend on a future IF block.")
	_check(not combined.contains("ResourceLoader"), "Manifest data does not load scripts or resources.")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
