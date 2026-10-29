@tool
## Uniform result for one editor-only block authoring request.
extends RefCounted


var authoring_id: String = ""
var block: FlowBlock
var diagnostics: Array[FlowDiagnostic] = []


## A creation with errors or without an instance is never publishable to the model.
func is_successful() -> bool:
	if block == null:
		return false
	for diagnostic: FlowDiagnostic in diagnostics:
		if diagnostic.severity == FlowDiagnostic.Severity.ERROR:
			return false
	return true
