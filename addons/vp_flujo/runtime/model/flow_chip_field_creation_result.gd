@tool
class_name FlowChipFieldCreationResult
extends FlowValidationResult


## Result of building one initial structured document from a field schema.
var document: FlowStructuredDocument = null


func is_successful() -> bool:
	return document != null and not has_errors()
