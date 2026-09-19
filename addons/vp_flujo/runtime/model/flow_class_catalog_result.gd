@tool
class_name FlowClassCatalogResult
extends FlowValidationResult

## Per-validation snapshot only, not persistent state or a global cache.
var graphs: Dictionary[String, FlowGraph] = {}
