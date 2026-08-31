## Describes one model validation finding with a stable code and source location.
class_name FlowDiagnostic
extends RefCounted


enum Severity {
	INFO,
	WARNING,
	ERROR,
}

const CODE_NULL_GRAPH: StringName = &"null_graph"
const CODE_UNSUPPORTED_SCHEMA_VERSION: StringName = &"unsupported_schema_version"
const CODE_EMPTY_INTERNAL_ID: StringName = &"empty_internal_id"
const CODE_INVALID_INTERNAL_ID_LENGTH: StringName = &"invalid_internal_id_length"
const CODE_NON_HEXADECIMAL_INTERNAL_ID: StringName = &"non_hexadecimal_internal_id"
const CODE_DUPLICATE_INTERNAL_ID: StringName = &"duplicate_internal_id"
const CODE_REPEATED_RESOURCE_INSTANCE: StringName = &"repeated_resource_instance"
const CODE_UNMIGRATABLE_CONTAINER_TYPE: StringName = &"unmigratable_container_type"
const CODE_MIXED_SCHEMA_SOURCES: StringName = &"mixed_schema_sources"
const CODE_MISSING_OWNER_CONTAINER_REFERENCE: StringName = &"missing_owner_container_reference"
const CODE_INVALID_OWNER_CONTAINER_REFERENCE: StringName = &"invalid_owner_container_reference"
const CODE_MISSING_GLOBAL_VARIABLE_REFERENCE: StringName = &"missing_global_variable_reference"
const CODE_INVALID_GLOBAL_VARIABLE_REFERENCE: StringName = &"invalid_global_variable_reference"
const CODE_MIGRATION_SOURCE_SCHEMA: StringName = &"migration_source_schema"
const CODE_MULTIPLE_INITIAL_STATES: StringName = &"multiple_initial_states"

var code: StringName
var severity: Severity
var message: String
var element_path: String
var related_id: String


## Creates a diagnostic with all structured context needed by validation consumers.
func _init(
		new_code: StringName,
		new_severity: Severity,
		new_message: String,
		new_element_path: String,
		new_related_id: String = ""
) -> void:
	code = new_code
	severity = new_severity
	message = new_message
	element_path = new_element_path
	related_id = new_related_id
