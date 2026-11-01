@tool
class_name FlowBlock
extends Resource


@export_storage var _internal_id: String = FlowId.create()

@export var display_name: String = "Block"
@export var enabled: bool = true
@export_multiline var user_note: String = ""


func get_internal_id() -> String:
	return _internal_id


## Extension hook for block-local structural validation.
func validate_structure(_context: Dictionary) -> void:
	pass


## Generic remap hook for graph-owned references embedded in block Akis.
## Concrete blocks may extend this contract for additional reference families.
func remap_internal_references(id_map: Dictionary[String, String]) -> void:
	if id_map.is_empty():
		return
	for raw_property: Variant in get_property_list():
		if not raw_property is Dictionary:
			continue
		var property: Dictionary = raw_property as Dictionary
		var property_name: StringName = StringName(String(property.get("name", "")))
		if property_name.is_empty():
			continue
		var property_value: Variant = get(property_name)
		if not property_value is FlowStructuredDocument:
			continue
		var document: FlowStructuredDocument = property_value as FlowStructuredDocument
		for segment: FlowDocumentSegment in document.segments:
			var chip: FlowChipSegment = segment as FlowChipSegment
			if chip == null:
				continue
			FlowValueSourceReferenceRemapper.remap_graph_ids(
				chip.get_value_source(),
				id_map
			)


func get_navigation_decision(_context: FlowNavigationContext) -> FlowNavigationDecision:
	return FlowNavigationDecision.continue_execution()


## Generic runtime bridge for any block-owned Akis property.
func resolve_structured_property_text(
		property_name: StringName,
		context: FlowValueResolutionContext
) -> FlowStructuredRenderResult:
	var value: Variant = get(property_name)
	if not value is FlowStructuredDocument:
		var result: FlowStructuredRenderResult = FlowStructuredRenderResult.new()
		result.add_diagnostic(FlowDiagnostic.new(
			FlowDiagnostic.CODE_STRUCTURED_VALUE_SHAPE_INVALID,
			FlowDiagnostic.Severity.ERROR,
			"Block property is not a FlowStructuredDocument.",
			String(property_name),
			_internal_id
		))
		return result
	return FlowStructuredDocumentResolver.resolve_text(
		value as FlowStructuredDocument,
		context
	)


func resolve_structured_property_value(
		property_name: StringName,
		context: FlowValueResolutionContext
) -> FlowValueResult:
	var value: Variant = get(property_name)
	if not value is FlowStructuredDocument:
		return FlowValueResult.fail(
			Variant.Type.TYPE_NIL,
			FlowDiagnostic.new(
				FlowDiagnostic.CODE_STRUCTURED_VALUE_SHAPE_INVALID,
				FlowDiagnostic.Severity.ERROR,
				"Block property is not a FlowStructuredDocument.",
				String(property_name),
				_internal_id
			)
		)
	return FlowStructuredDocumentResolver.resolve_value(
		value as FlowStructuredDocument,
		context
	)


func duplicate_with_new_id() -> FlowBlock:
	var copy: FlowBlock = duplicate(true) as FlowBlock
	copy._internal_id = FlowId.create()
	var id_map: Dictionary[String, String] = {}
	id_map[_internal_id] = copy.get_internal_id()
	copy.remap_internal_references(id_map)
	return copy
