@tool
## Collects the ordered diagnostics produced by one model validation pass.
class_name FlowValidationResult
extends RefCounted


var diagnostics: Array[FlowDiagnostic] = []


## Returns whether at least one collected diagnostic has error severity.
func has_errors() -> bool:
	for diagnostic: FlowDiagnostic in diagnostics:
		if diagnostic.severity == FlowDiagnostic.Severity.ERROR:
			return true

	return false


## Appends a diagnostic while preserving validation traversal order.
func add_diagnostic(diagnostic: FlowDiagnostic) -> void:
	diagnostics.append(diagnostic)
