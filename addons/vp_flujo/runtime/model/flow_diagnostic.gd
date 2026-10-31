@tool
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
const CODE_MISSING_CONSTRUCTOR: StringName = &"missing_constructor"
const CODE_EMPTY_DISPLAY_NAME: StringName = &"empty_display_name"
const CODE_DUPLICATE_DISPLAY_NAME: StringName = &"duplicate_display_name"
const CODE_EMPTY_REQUIRED_CLASS_NAME: StringName = &"empty_required_class_name"
const CODE_METHOD_CALL_INCOMPATIBLE_SCHEMA: StringName = &"method_call_incompatible_schema"
const CODE_EMPTY_METHOD_REFERENCE: StringName = &"empty_method_reference"
const CODE_MISSING_METHOD_REFERENCE: StringName = &"missing_method_reference"
const CODE_INVALID_METHOD_REFERENCE: StringName = &"invalid_method_reference"
const CODE_MISSING_GLOBAL_VARIABLE_REFERENCE: StringName = &"missing_global_variable_reference"
const CODE_INVALID_GLOBAL_VARIABLE_REFERENCE: StringName = &"invalid_global_variable_reference"
const CODE_INVALID_VARIABLE_SCOPE: StringName = &"invalid_variable_scope"
const CODE_INVALID_VARIABLE_BINDING: StringName = &"invalid_variable_binding"
const CODE_INVALID_VALUE_TYPE: StringName = &"invalid_value_type"
const CODE_MISSING_INITIAL_STATE_REFERENCE: StringName = &"missing_initial_state_reference"
const CODE_INVALID_INITIAL_STATE_REFERENCE: StringName = &"invalid_initial_state_reference"
const CODE_MIGRATION_SOURCE_SCHEMA: StringName = &"migration_source_schema"
const CODE_MULTIPLE_INITIAL_STATES: StringName = &"multiple_initial_states"
const CODE_REQUIREMENTS_INCOMPATIBLE_SCHEMA: StringName = &"requirements_incompatible_schema"
const CODE_REQUIRED_NODE_CLASS_MISSING: StringName = &"required_node_class_missing"
const CODE_REQUIRED_NODE_CLASS_NOT_NODE: StringName = &"required_node_class_not_node"
const CODE_REQUIRED_NODE_CLASS_NOT_INSTANTIABLE: StringName = &"required_node_class_not_instantiable"
const CODE_REQUIRED_NODE_NAME_EMPTY: StringName = &"required_node_name_empty"
const CODE_REQUIRED_NODE_NAME_INVALID: StringName = &"required_node_name_invalid"
const CODE_REQUIRED_PROPERTIES_UNSUPPORTED: StringName = &"required_properties_unsupported"
const CODE_REQUIRED_NODE_BINDING_INVALID: StringName = &"required_node_binding_invalid"
const CODE_BINDINGS_INCOMPATIBLE_SCHEMA: StringName = &"bindings_incompatible_schema"
const CODE_MIGRATION_CONFIRMATION_REQUIRED: StringName = &"migration_confirmation_required"
const CODE_NULL_STRUCTURED_DOCUMENT: StringName = &"null_structured_document"
const CODE_UNSUPPORTED_STRUCTURED_DOCUMENT_VERSION: StringName = &"unsupported_structured_document_version"
const CODE_NULL_SEGMENT: StringName = &"null_segment"
const CODE_EMPTY_SEGMENT_ID: StringName = &"empty_segment_id"
const CODE_INVALID_SEGMENT_ID: StringName = &"invalid_segment_id"
const CODE_DUPLICATE_SEGMENT_ID: StringName = &"duplicate_segment_id"
const CODE_UNKNOWN_SEGMENT_TYPE: StringName = &"unknown_segment_type"
const CODE_UNKNOWN_CHIP_TYPE: StringName = &"unknown_chip_type"
const CODE_INVALID_LITERAL_VALUE_TYPE: StringName = &"invalid_literal_value_type"
const CODE_LITERAL_VALUE_TYPE_MISMATCH: StringName = &"literal_value_type_mismatch"
const CODE_LITERAL_TYPE_NIL: StringName = &"literal_type_nil"
const CODE_LITERAL_FLOAT_NOT_FINITE: StringName = &"literal_float_not_finite"
const CODE_NULL_CHIP_FIELD_SCHEMA: StringName = &"null_chip_field_schema"
const CODE_NULL_CHIP_FIELD_DOCUMENT: StringName = &"null_chip_field_document"
const CODE_EMPTY_CHIP_FIELD_SCHEMA_ID: StringName = &"empty_chip_field_schema_id"
const CODE_INVALID_CHIP_FIELD_SCHEMA_ID: StringName = &"invalid_chip_field_schema_id"
const CODE_INVALID_CHIP_FIELD_SCHEMA_MODE: StringName = &"invalid_chip_field_schema_mode"
const CODE_INVALID_CHIP_FIELD_TEXT_MODE: StringName = &"invalid_chip_field_text_mode"
const CODE_INVALID_CHIP_FIELD_COUNT_RANGE: StringName = &"invalid_chip_field_count_range"
const CODE_INVALID_CHIP_FIELD_CONFIGURATION: StringName = &"invalid_chip_field_configuration"
const CODE_INVALID_CHIP_FIELD_VARIADIC_CONFIGURATION: StringName = &"invalid_chip_field_variadic_configuration"
const CODE_INVALID_CHIP_FIELD_TEMPLATE_PART: StringName = &"invalid_chip_field_template_part"
const CODE_UNKNOWN_CHIP_FIELD_TEMPLATE_SLOT: StringName = &"unknown_chip_field_template_slot"
const CODE_NULL_CHIP_FIELD_TEMPLATE_PART: StringName = &"null_chip_field_template_part"
const CODE_INVALID_CHIP_FIELD_VALUE_TYPE: StringName = &"invalid_chip_field_value_type"
const CODE_INVALID_CHIP_FIELD_SOURCE_KIND: StringName = &"invalid_chip_field_source_kind"
const CODE_MISSING_CHIP_FIELD_INITIAL_SOURCE: StringName = &"missing_chip_field_initial_source"
const CODE_NULL_CHIP_SLOT_DEFINITION: StringName = &"null_chip_slot_definition"
const CODE_EMPTY_CHIP_SLOT_ID: StringName = &"empty_chip_slot_id"
const CODE_DUPLICATE_CHIP_SLOT_ID: StringName = &"duplicate_chip_slot_id"
const CODE_EMPTY_CHIP_SLOT_DISPLAY_NAME: StringName = &"empty_chip_slot_display_name"
const CODE_INVALID_CHIP_SLOT_COUNT_RANGE: StringName = &"invalid_chip_slot_count_range"
const CODE_MISSING_REQUIRED_CHIP_SLOT: StringName = &"missing_required_chip_slot"
const CODE_UNKNOWN_CHIP_SLOT: StringName = &"unknown_chip_slot"
const CODE_DUPLICATE_CHIP_SLOT: StringName = &"duplicate_chip_slot"
const CODE_CHIP_VALUE_TYPE_INCOMPATIBLE: StringName = &"chip_value_type_incompatible"
const CODE_CHIP_SOURCE_KIND_INCOMPATIBLE: StringName = &"chip_source_kind_incompatible"
const CODE_TOO_MANY_CHIPS: StringName = &"too_many_chips"
const CODE_TOO_FEW_CHIPS: StringName = &"too_few_chips"
const CODE_CHIP_REORDER_NOT_ALLOWED: StringName = &"chip_reorder_not_allowed"
const CODE_CHIP_FIELD_TEXT_NOT_ALLOWED: StringName = &"chip_field_text_not_allowed"
const CODE_EMPTY_VALUE_SOURCE_ID: StringName = &"empty_value_source_id"
const CODE_INVALID_VALUE_SOURCE_ID: StringName = &"invalid_value_source_id"
const CODE_INVALID_VALUE_SOURCE_KIND: StringName = &"invalid_value_source_kind"
const CODE_NULL_VALUE_SOURCE: StringName = &"null_value_source"
const CODE_INVALID_VALUE_SOURCE: StringName = &"invalid_value_source"
const CODE_EMPTY_VARIABLE_REFERENCE_ID: StringName = &"empty_variable_reference_id"
const CODE_INVALID_VARIABLE_REFERENCE_ID: StringName = &"invalid_variable_reference_id"
const CODE_INVALID_VARIABLE_REFERENCE_TYPE: StringName = &"invalid_variable_reference_type"
const CODE_VARIABLE_REFERENCE_MISSING: StringName = &"variable_reference_missing"
const CODE_VARIABLE_REFERENCE_TYPE_MISMATCH: StringName = &"variable_reference_type_mismatch"
const CODE_INVALID_CHIP_SLOT_KIND: StringName = &"invalid_chip_slot_kind"
const CODE_VARIADIC_CHIP_SLOT_KIND_REQUIRED: StringName = &"variadic_chip_slot_kind_required"
const CODE_EXPRESSION_OPERATOR_EMPTY: StringName = &"expression_operator_empty"
const CODE_EXPRESSION_OPERATOR_UNKNOWN: StringName = &"expression_operator_unknown"
const CODE_EXPRESSION_ARITY_INVALID: StringName = &"expression_arity_invalid"
const CODE_EXPRESSION_OPERAND_NULL: StringName = &"expression_operand_null"
const CODE_EXPRESSION_OPERAND_KIND_INVALID: StringName = &"expression_operand_kind_invalid"
const CODE_EXPRESSION_SIGNATURE_INCOMPATIBLE: StringName = &"expression_signature_incompatible"
const CODE_EXPRESSION_RESULT_TYPE_INCOMPATIBLE: StringName = &"expression_result_type_incompatible"
const CODE_VALUE_RESOLUTION_DEFERRED: StringName = &"value_resolution_deferred"
const CODE_CONDITION_COMPARISON_REQUIRED: StringName = &"condition_comparison_required"
const CODE_CONDITION_COMPARISON_ID_EMPTY: StringName = &"condition_comparison_id_empty"
const CODE_CONDITION_COMPARISON_ID_INVALID: StringName = &"condition_comparison_id_invalid"
const CODE_CONDITION_COMPARISON_ID_DUPLICATE: StringName = &"condition_comparison_id_duplicate"
const CODE_CONDITION_OPERATOR_EMPTY: StringName = &"condition_operator_empty"
const CODE_CONDITION_OPERATOR_UNKNOWN: StringName = &"condition_operator_unknown"
const CODE_CONDITION_SOURCE_NULL: StringName = &"condition_source_null"
const CODE_CONDITION_SOURCE_KIND_INVALID: StringName = &"condition_source_kind_invalid"
const CODE_CONDITION_CONNECTOR_COUNT_INVALID: StringName = &"condition_connector_count_invalid"
const CODE_CONDITION_CONNECTOR_UNKNOWN: StringName = &"condition_connector_unknown"
const CODE_CONDITION_SIGNATURE_INCOMPATIBLE: StringName = &"condition_signature_incompatible"
const CODE_CONDITION_INVALID: StringName = &"condition_invalid"

# Short aliases keep the diagnostic vocabulary usable by generic callers that
# do not repeat the full ChipField prefix.
const CODE_INVALID_SCHEMA_MODE: StringName = CODE_INVALID_CHIP_FIELD_SCHEMA_MODE
const CODE_EMPTY_SLOT_ID: StringName = CODE_EMPTY_CHIP_SLOT_ID
const CODE_DUPLICATE_SLOT_ID: StringName = CODE_DUPLICATE_CHIP_SLOT_ID
const CODE_NULL_SLOT_DEFINITION: StringName = CODE_NULL_CHIP_SLOT_DEFINITION
const CODE_MISSING_REQUIRED_SLOT: StringName = CODE_MISSING_REQUIRED_CHIP_SLOT
const CODE_UNKNOWN_SLOT: StringName = CODE_UNKNOWN_CHIP_SLOT
const CODE_DUPLICATE_SLOT: StringName = CODE_DUPLICATE_CHIP_SLOT
const CODE_VALUE_TYPE_INCOMPATIBLE: StringName = CODE_CHIP_VALUE_TYPE_INCOMPATIBLE
const CODE_SOURCE_KIND_INCOMPATIBLE: StringName = CODE_CHIP_SOURCE_KIND_INCOMPATIBLE

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
