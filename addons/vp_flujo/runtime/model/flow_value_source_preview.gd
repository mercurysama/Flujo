@tool
## Shared display-only preview dispatcher for nested/composite ValueSources.
class_name FlowValueSourcePreview
extends RefCounted


static func preview(source: FlowValueSource, graph: FlowGraph = null) -> String:
	if source == null:
		return "<unset>"
	if source is FlowLiteralValueSource:
		var literal: FlowLiteralValueSource = source as FlowLiteralValueSource
		if not literal.is_valid():
			return "<invalid literal>"
		var text: String = literal.get_runtime_text()
		return ""%s"" % text 			if literal.get_value_type() == Variant.Type.TYPE_STRING 			or literal.get_value_type() == Variant.Type.TYPE_STRING_NAME 			else text
	if source is FlowVariableRefValueSource:
		var variable: FlowVariableRefValueSource = source as FlowVariableRefValueSource
		if graph != null:
			var definition: FlowVariableDefinition = variable.resolve_definition(graph)
			if definition != null:
				return definition.display_name
		return "<variable:%s>" % variable.variable_id
	if source is FlowNodeRefValueSource:
		return (source as FlowNodeRefValueSource).get_preview()
	if source is FlowNodePropertyRefValueSource:
		return (source as FlowNodePropertyRefValueSource).get_preview()
	if source is FlowOperationValueSource:
		return (source as FlowOperationValueSource).get_preview(graph)
	if source is FlowConditionValueSource:
		return (source as FlowConditionValueSource).get_preview(graph)
	if source is FlowArrayValueSource:
		return (source as FlowArrayValueSource).get_preview(graph)
	if source is FlowDictionaryValueSource:
		return (source as FlowDictionaryValueSource).get_preview(graph)
	if source is FlowResourceRefValueSource:
		return (source as FlowResourceRefValueSource).get_preview()
	if source is FlowEnumValueSource:
		return (source as FlowEnumValueSource).get_preview()
	if source is FlowBitfieldValueSource:
		return (source as FlowBitfieldValueSource).get_preview()
	return "<%s>" % String(source.get_source_kind())
