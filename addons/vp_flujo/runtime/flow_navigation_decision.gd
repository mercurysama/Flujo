class_name FlowNavigationDecision
extends RefCounted

## Ephemeral runtime control returned by a FlowBlock.
enum Kind {
	CONTINUE,
	JUMP,
	STOP,
}

var kind: Kind = Kind.CONTINUE
var target_block_id: String = ""


static func continue_execution() -> FlowNavigationDecision:
	var decision: FlowNavigationDecision = FlowNavigationDecision.new()
	decision.kind = Kind.CONTINUE
	return decision


static func jump_to(block_id: String) -> FlowNavigationDecision:
	var decision: FlowNavigationDecision = FlowNavigationDecision.new()
	decision.kind = Kind.JUMP
	decision.target_block_id = block_id
	return decision


static func stop_execution() -> FlowNavigationDecision:
	var decision: FlowNavigationDecision = FlowNavigationDecision.new()
	decision.kind = Kind.STOP
	return decision


func is_well_formed() -> bool:
	match kind:
		Kind.CONTINUE, Kind.STOP:
			return target_block_id.is_empty()
		Kind.JUMP:
			return not target_block_id.is_empty()
	return false
