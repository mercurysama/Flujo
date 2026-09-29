@tool
class_name FlowPackageManifest
extends RefCounted

## In-memory projection of the approved v1 JSON manifest contract.
## Discovery, JSON parsing and script loading remain outside this class.

const MANIFEST_VERSION: int = 1

var manifest_version: int = MANIFEST_VERSION
var package_id: String = ""
var blocks: Array[FlowExternalBlockDescriptor] = []


func _init(new_package_id: String = "", new_manifest_version: int = MANIFEST_VERSION) -> void:
	package_id = new_package_id.strip_edges()
	manifest_version = new_manifest_version


func add_block(descriptor: FlowExternalBlockDescriptor) -> bool:
	if descriptor == null:
		return false
	blocks.append(descriptor)
	return true


func validation_errors() -> Array[String]:
	var errors: Array[String] = []
	if manifest_version != MANIFEST_VERSION:
		errors.append("unsupported_manifest_version")
	if package_id.is_empty():
		errors.append("empty_package_id")
	var seen_type_ids: Dictionary = {}
	for index: int in blocks.size():
		var descriptor: FlowExternalBlockDescriptor = blocks[index]
		if descriptor == null:
			errors.append("null_block_descriptor:%d" % index)
			continue
		for descriptor_error: String in descriptor.validation_errors():
			errors.append("block_%d:%s" % [index, descriptor_error])
		if descriptor.package_id != package_id:
			errors.append("block_package_id_mismatch:%d" % index)
		var global_id: String = descriptor.global_type_id()
		if seen_type_ids.has(global_id):
			errors.append("duplicate_block_type_id:%s" % global_id)
		else:
			seen_type_ids[global_id] = true
	return errors


func is_valid() -> bool:
	return validation_errors().is_empty()
