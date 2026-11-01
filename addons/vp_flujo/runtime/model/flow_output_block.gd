@tool
class_name FlowOutputBlock
extends FlowBlock

## Shared runtime contract for blocks that emit one text message.


func get_output_message() -> String:
	return ""


## Context-aware output contract. Legacy blocks remain valid through the scalar
## fallback while Akis-aware blocks may resolve references at runtime.
func resolve_output_message(
		_context: FlowValueResolutionContext
) -> FlowValueResult:
	return FlowValueResult.ok(get_output_message(), Variant.Type.TYPE_STRING)
