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
	_test_mixed_invalid_manifest()


func _test_mixed_invalid_manifest() -> void:
	var mixed: FlowPackageManifest = FlowPackageManifest.new("demo", 2)
	var empty: FlowExternalBlockDescriptor = FlowExternalBlockDescriptor.new("", "", "", "")
	var mismatch: FlowExternalBlockDescriptor = FlowExternalBlockDescriptor.new(
		"other", "mismatch", "res://flow_packages/other/mismatch.gd", "Mismatch"
	)
	var duplicate_first: FlowExternalBlockDescriptor = FlowExternalBlockDescriptor.new(
		"demo", "shared", "res://flow_packages/demo/first.gd", "First shared"
	)
	var duplicate_second: FlowExternalBlockDescriptor = FlowExternalBlockDescriptor.new(
		"demo", "shared", "res://flow_packages/demo/second.gd", "Second shared"
	)
	mixed.blocks = [empty, null, mismatch, duplicate_first, duplicate_second]
	var expected_errors: Array[String] = [
		"unsupported_manifest_version",
		"block_0:empty_package_id",
		"block_0:empty_type_id",
		"block_0:empty_script_path",
		"block_0:empty_display_name",
		"block_package_id_mismatch:0",
		"null_block_descriptor:1",
		"block_package_id_mismatch:2",
		"duplicate_block_type_id:demo:shared",
	]
	var first_errors: Array[String] = mixed.validation_errors()
	var second_errors: Array[String] = mixed.validation_errors()
	_check(
		not mixed.is_valid() and first_errors == expected_errors and second_errors == expected_errors,
		"Mixed invalid manifest data accumulates deterministic diagnostics in authored order."
	)
	_check(
		mixed.package_id == "demo"
			and mixed.manifest_version == 2
			and mixed.blocks.size() == 5
			and mixed.blocks[0] == empty
			and mixed.blocks[1] == null
			and mixed.blocks[2] == mismatch
			and mixed.blocks[3] == duplicate_first
			and mixed.blocks[4] == duplicate_second
			and empty.package_id.is_empty()
			and empty.type_id.is_empty()
			and empty.script_path.is_empty()
			and empty.display_name.is_empty()
			and mismatch.package_id == "other"
			and mismatch.type_id == "mismatch"
			and mismatch.script_path == "res://flow_packages/other/mismatch.gd"
			and mismatch.display_name == "Mismatch"
			and duplicate_first.global_type_id() == "demo:shared"
			and duplicate_first.script_path == "res://flow_packages/demo/first.gd"
			and duplicate_first.display_name == "First shared"
			and duplicate_second.global_type_id() == "demo:shared"
			and duplicate_second.script_path == "res://flow_packages/demo/second.gd"
			and duplicate_second.display_name == "Second shared",
		"Validation preserves authored fields, descriptor identities, order, and the null slot."
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
