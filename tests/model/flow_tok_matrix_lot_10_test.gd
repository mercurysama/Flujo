extends Node


const TEMP_ROOT: String = "res://.godot/flujo_tests/tok_matrix_lot_10"
const RESOURCE_PATH: String = TEMP_ROOT + "/gradient.tres"

var _failures: Array[String] = []


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT))
	_test_all_tok_families_in_one_akis()
	_cleanup()
	_finish()


func _test_all_tok_families_in_one_akis() -> void:
	var gradient: Gradient = Gradient.new()
	gradient.add_point(0.5, Color(0.2, 0.4, 0.8))
	_check(ResourceSaver.save(gradient, RESOURCE_PATH) == OK, "Resource Tok fixture saves.")

	var graph: FlowGraph = FlowGraph.new()
	graph.schema_version = FlowGraph.SCHEMA_VERSION_4
	graph.constructor = FlowConstructorDefinition.new()

	var requirement: FlowRequiredNodeDefinition = FlowRequiredNodeDefinition.new()
	requirement.display_name = "Target"
	requirement.expected_node_name = &"Target"
	requirement.required_class_name = &"Node2D"
	graph.constructor.requirements = [requirement]

	var count: FlowVariableDefinition = FlowVariableDefinition.new()
	count.display_name = "Count"
	count.value_type = FlowVariableDefinition.ValueType.INT
	count.int_value = 7
	graph.variables = [count]

	var controller: PVController = PVController.new()
	controller.name = "Controller"
	controller.flow_graph = graph
	var target: Node2D = Node2D.new()
	target.name = "Target"
	target.z_index = 12
	controller.add_child(target)
	controller.requirement_bindings = {
		requirement.get_internal_id(): NodePath("Target"),
	}

	var operation: FlowOperationValueSource = FlowOperationValueSource.new(
		FlowOperationOperatorCatalog.OPERATOR_ADD,
		[
			FlowVariableRefValueSource.new(count.get_internal_id(), count.value_type),
			FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 5),
		]
	)
	var condition: FlowConditionValueSource = FlowConditionValueSource.new(
		[
			FlowConditionComparison.new(
				FlowConditionOperatorCatalog.OPERATOR_GREATER_THAN,
				FlowNodePropertyRefValueSource.new(
					requirement.get_internal_id(),
					NodePath("Target"),
					&"Target",
					&"z_index",
					Variant.Type.TYPE_INT
				),
				FlowLiteralValueSource.new(Variant.Type.TYPE_INT, 10)
			),
		],
		[]
	)
	var array: FlowArrayValueSource = FlowArrayValueSource.new([
		FlowVariableRefValueSource.new(count.get_internal_id(), count.value_type),
		operation.duplicate_with_new_id(),
	])
	var dictionary: FlowDictionaryValueSource = FlowDictionaryValueSource.new([
		FlowDictionaryEntry.new(
			"ok",
			condition.duplicate_with_new_id()
		),
	])
	var enum_source: FlowEnumValueSource = FlowEnumValueSource.new(
		&"Direction",
		[&"Left", &"Right"],
		[0, 10],
		10,
		true
	)
	var bitfield: FlowBitfieldValueSource = FlowBitfieldValueSource.new(
		&"Permissions",
		[&"Read", &"Write", &"Execute"],
		[1, 2, 4],
		5
	)

	var document: FlowStructuredDocument = FlowStructuredDocument.new()
	document.segments = [
		_text("literal="),
		FlowLiteralValueSegment.new(Variant.Type.TYPE_STRING, "hello"),
		_text("|var="),
		FlowVariableRefSegment.new(
			FlowVariableRefValueSource.new(count.get_internal_id(), count.value_type)
		),
		_text("|op="),
		FlowOperationSegment.new(operation),
		_text("|cond="),
		FlowConditionSegment.new(condition),
		_text("|node="),
		FlowNodeRefSegment.new(
			FlowNodeRefValueSource.new(
				requirement.get_internal_id(),
				NodePath("Target"),
				&"Target",
				&"Node2D"
			)
		),
		_text("|prop="),
		FlowNodePropertyRefSegment.new(
			FlowNodePropertyRefValueSource.new(
				requirement.get_internal_id(),
				NodePath("Target"),
				&"Target",
				&"z_index",
				Variant.Type.TYPE_INT
			)
		),
		_text("|array="),
		FlowArraySegment.new(array),
		_text("|dict="),
		FlowDictionarySegment.new(dictionary),
		_text("|resource="),
		FlowResourceRefSegment.new(
			FlowResourceRefValueSource.new(RESOURCE_PATH, &"Gradient")
		),
		_text("|enum="),
		FlowEnumSegment.new(enum_source),
		_text("|flags="),
		FlowBitfieldSegment.new(bitfield),
	]

	var validation: FlowValidationResult = FlowStructuredDocumentValidator.validate(
		document,
		graph
	)
	_check(
		not validation.has_errors(),
		"One Akis containing every implemented Tok family validates."
	)

	var context: FlowValueResolutionContext = FlowValueResolutionContext.new(
		graph,
		controller,
		controller
	)
	var rendered: FlowStructuredRenderResult = FlowStructuredDocumentResolver.resolve_text(
		document,
		context
	)
	_check(not rendered.has_errors(), "All Tok families resolve through one runtime context.")
	if not rendered.has_errors():
		_check(rendered.text.contains("literal=hello"), "Literal Tok reaches text runtime.")
		_check(rendered.text.contains("|var=7"), "Variable Tok reaches text runtime.")
		_check(rendered.text.contains("|op=12"), "Operation Tok reaches text runtime.")
		_check(rendered.text.contains("|cond=true"), "Condition Tok reaches text runtime.")
		_check(rendered.text.contains("|node=Target"), "Node Tok reaches text runtime.")
		_check(rendered.text.contains("|prop=12"), "Node Property Tok reaches text runtime.")
		_check(rendered.text.contains("|array=[7, 12]"), "Array Tok reaches text runtime.")
		_check(rendered.text.contains("|dict={"), "Dictionary Tok reaches text runtime.")
		_check(rendered.text.contains("ok"), "Dictionary Tok preserves its key.")
		_check(rendered.text.contains(RESOURCE_PATH), "Resource Tok reaches text runtime.")
		_check(rendered.text.contains("|enum=10"), "Enum Tok reaches text runtime as int.")
		_check(rendered.text.contains("|flags=5"), "Bitfield Tok reaches text runtime as int.")

	controller.free()


func _text(value: String) -> FlowTextSegment:
	var segment: FlowTextSegment = FlowTextSegment.new()
	segment.text = value
	return segment


func _cleanup() -> void:
	var absolute_resource: String = ProjectSettings.globalize_path(RESOURCE_PATH)
	if FileAccess.file_exists(absolute_resource):
		DirAccess.remove_absolute(absolute_resource)
	var absolute_root: String = ProjectSettings.globalize_path(TEMP_ROOT)
	if DirAccess.dir_exists_absolute(absolute_root):
		DirAccess.remove_absolute(absolute_root)


func _check(condition: bool, message: String) -> void:
	if condition:
		return
	_failures.append(message)
	push_error("[Flujo] Lot 10 Tok matrix failed: " + message)


func _finish() -> void:
	if _failures.is_empty():
		print("[Flujo] Lot 10 all-Tok Akis matrix test passed")
	else:
		push_error("[Flujo] Lot 10 Tok matrix failed: %d failures" % _failures.size())
	get_tree().quit(0 if _failures.is_empty() else 1)
