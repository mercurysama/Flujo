extends Node

var _failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	_test_descriptor()
	_test_manifest()
	_test_mixed_manifest_preservation()
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


func _test_mixed_manifest_preservation() -> void:
	var empty_descriptor: FlowExternalBlockDescriptor = FlowExternalBlockDescriptor.new("", "", "", "")
	var mismatch_descriptor: FlowExternalBlockDescriptor = FlowExternalBlockDescriptor.new(
		"other", "mismatch", "res://flow_packages/other/mismatch.gd", "Mismatch"
	)
	var duplicate_first: FlowExternalBlockDescriptor = FlowExternalBlockDescriptor.new(
		"demo", "duplicate", "res://flow_packages/demo/first.gd", "First duplicate"
	)
	var duplicate_second: FlowExternalBlockDescriptor = FlowExternalBlockDescriptor.new(
		"demo", "duplicate", "res://flow_packages/demo/second.gd", "Second duplicate"
	)
	var mixed: FlowPackageManifest = FlowPackageManifest.new("demo", 2)
	mixed.blocks = [empty_descriptor, null, mismatch_descriptor, duplicate_first, duplicate_second]
	var expected_errors: Array[String] = [
		"unsupported_manifest_version",
		"block_0:empty_package_id",
		"block_0:empty_type_id",
		"block_0:empty_script_path",
		"block_0:empty_display_name",
		"block_package_id_mismatch:0",
		"null_block_descriptor:1",
		"block_package_id_mismatch:2",
		"duplicate_block_type_id:demo:duplicate",
	]
	var first_errors: Array[String] = mixed.validation_errors()
	var second_errors: Array[String] = mixed.validation_errors()
	_check(first_errors == expected_errors, "Mixed manifest diagnostics are complete and ordered deterministically.")
	_check(second_errors == expected_errors, "Repeated mixed manifest validation keeps the exact diagnostic order.")
	_check(first_errors == second_errors, "Repeated mixed manifest validation returns the same diagnostics.")
	var first_is_valid: bool = mixed.is_valid()
	var second_is_valid: bool = mixed.is_valid()
	_check(not first_is_valid, "The mixed invalid manifest remains invalid on the first is_valid call.")
	_check(not second_is_valid, "The mixed invalid manifest remains invalid on the repeated is_valid call.")

	_check(mixed.manifest_version == 2, "Repeated validation preserves the authored manifest version.")
	_check(mixed.package_id == "demo", "Repeated validation preserves the authored manifest package ID.")
	_check(mixed.blocks.size() == 5, "Repeated validation preserves the authored descriptor array size.")
	_check(mixed.blocks[0] == empty_descriptor, "Repeated validation preserves the first descriptor reference.")
	_check(mixed.blocks[1] == null, "Repeated validation preserves the deliberate null position.")
	_check(mixed.blocks[2] == mismatch_descriptor, "Repeated validation preserves the mismatch descriptor reference.")
	_check(mixed.blocks[3] == duplicate_first, "Repeated validation preserves the first duplicate descriptor reference.")
	_check(mixed.blocks[4] == duplicate_second, "Repeated validation preserves the second duplicate descriptor reference.")

	_check(empty_descriptor.package_id == "", "Repeated validation preserves the empty descriptor package field.")
	_check(empty_descriptor.type_id == "", "Repeated validation preserves the empty descriptor type field.")
	_check(empty_descriptor.script_path == "", "Repeated validation preserves the empty descriptor script field.")
	_check(empty_descriptor.display_name == "", "Repeated validation preserves the empty descriptor display field.")
	_check(mismatch_descriptor.package_id == "other", "Repeated validation preserves the mismatch package field.")
	_check(mismatch_descriptor.type_id == "mismatch", "Repeated validation preserves the mismatch type field.")
	_check(
		mismatch_descriptor.script_path == "res://flow_packages/other/mismatch.gd",
		"Repeated validation preserves the mismatch script field."
	)
	_check(mismatch_descriptor.display_name == "Mismatch", "Repeated validation preserves the mismatch display field.")
	_check(duplicate_first.package_id == "demo", "Repeated validation preserves the first duplicate package field.")
	_check(duplicate_first.type_id == "duplicate", "Repeated validation preserves the first duplicate type field.")
	_check(
		duplicate_first.script_path == "res://flow_packages/demo/first.gd",
		"Repeated validation preserves the first duplicate script field."
	)
	_check(duplicate_first.display_name == "First duplicate", "Repeated validation preserves the first duplicate display field.")
	_check(duplicate_second.package_id == "demo", "Repeated validation preserves the second duplicate package field.")
	_check(duplicate_second.type_id == "duplicate", "Repeated validation preserves the second duplicate type field.")
	_check(
		duplicate_second.script_path == "res://flow_packages/demo/second.gd",
		"Repeated validation preserves the second duplicate script field."
	)
	_check(duplicate_second.display_name == "Second duplicate", "Repeated validation preserves the second duplicate display field.")


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
