@tool
## Ephemeral result boundary for future FlowValueSource runtime resolution.
class_name FlowValueResult
extends RefCounted


var success: bool = false
var value: Variant = null
var value_type: Variant.Type = Variant.Type.TYPE_NIL
var diagnostic: FlowDiagnostic = null


static func ok(result_value: Variant, result_type: Variant.Type) -> FlowValueResult:
	var result: FlowValueResult = FlowValueResult.new()
	result.success = true
	result.value = result_value
	result.value_type = result_type
	return result


static func fail(result_type: Variant.Type, result_diagnostic: FlowDiagnostic) -> FlowValueResult:
	var result: FlowValueResult = FlowValueResult.new()
	result.success = false
	result.value = null
	result.value_type = result_type
	result.diagnostic = result_diagnostic
	return result
