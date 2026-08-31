## Collects the candidate graph and diagnostics from one FlowGraph migration attempt.
class_name FlowGraphMigrationResult
extends RefCounted


var migrated_graph: FlowGraph
var diagnostics: Array[FlowDiagnostic] = []


## Returns whether the migration collected any error diagnostic.
func has_errors() -> bool:
	for diagnostic: FlowDiagnostic in diagnostics:
		if diagnostic.severity == FlowDiagnostic.Severity.ERROR:
			return true

	return false


## Returns whether a validated migrated graph is available.
func is_successful() -> bool:
	return migrated_graph != null and not has_errors()


## Appends one diagnostic while preserving migration traversal order.
func add_diagnostic(diagnostic: FlowDiagnostic) -> void:
	diagnostics.append(diagnostic)


## Appends diagnostics from a validation pass in their original order.
func add_validation_result(validation_result: FlowValidationResult) -> void:
	for diagnostic: FlowDiagnostic in validation_result.diagnostics:
		diagnostics.append(diagnostic)
