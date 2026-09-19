class_name FlowStoreResult
extends RefCounted

## Runtime operation result; never serialized into the shared definition.
var ok: bool = false
var code: StringName = &""
var class_id: String = ""
var related_id: String = ""
var path: String = ""
var value: Variant = null
var store: RefCounted = null
var diagnostics: Array[FlowDiagnostic] = []

static func make(status: StringName, owner_id: String = "", attribute_id: String = "") -> FlowStoreResult:
	var result: FlowStoreResult = FlowStoreResult.new()
	result.ok = status == &"ok"
	result.code = status
	result.class_id = owner_id
	result.related_id = attribute_id
	result.path = "attributes[\"%s\"]" % attribute_id if not attribute_id.is_empty() else "graph"
	return result
