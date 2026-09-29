@tool
class_name FlowPackageManifestScriptValidationResult
extends FlowValidationResult

## Valid descriptors from one script-validation pass, kept in manifest order.
var valid_descriptors: Array[FlowExternalBlockDescriptor] = []
