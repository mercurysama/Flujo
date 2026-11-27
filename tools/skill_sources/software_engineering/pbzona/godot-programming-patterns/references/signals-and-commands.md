# Signals and Commands

## Signals Represent Facts

Use a signal when an object announces something that has happened without requiring a particular listener. Good names read as facts:

- `health_changed(current, maximum)`
- `item_collected(item_id)`
- `request_completed(result)`
- `animation_finished` (built in)

Avoid imperative names such as `update_hud_now` unless the signal truly represents a request and zero listeners is acceptable.

The node that owns the state declares and emits the signal. The listener decides how to react.

## Connect at an Ownership Boundary

An owning scene can wire a child producer to a child consumer:

```gdscript
extends Node

@onready var charge: ChargeMeter = %Charge
@onready var readout: Label = %Readout

func _ready() -> void:
	_readout_charge(charge.current())
	charge.changed.connect(_readout_charge)

func _readout_charge(value: int) -> void:
	readout.text = "%d%%" % value
```

This sequence deliberately reads current state before subscribing. A signal carries a transition, not a retained snapshot.

For runtime-created peers, the creator should usually connect them. For a long-lived emitter and short-lived listener, confirm the connection disappears when the listener is freed and avoid capturing another dead object in a bound callable.

Guard intentional repeated setup:

```gdscript
var callback := _readout_charge
if not charge.changed.is_connected(callback):
	charge.changed.connect(callback)
```

Do not add this guard blindly; repeated setup may itself be the bug.

## Keep Payloads Useful and Stable

- Type every payload supported by the project's Godot version.
- Pass the changed value when listeners would otherwise query it immediately.
- Pass stable domain data rather than a private child node.
- Avoid a large untyped dictionary when a typed object or several explicit parameters form a stable contract.
- Emit only after the authoritative state is valid.
- Avoid emitting every frame when consumers only need actual changes.

## Prefer Calls for Required Work

Use a direct method call when:

- Exactly one collaborator must perform the operation.
- The caller needs a return value or error.
- Ordering is part of correctness.
- Failure must be handled immediately.

A required save operation is a call. A `save_completed` notification may be a signal.

## Commands Represent Intent

A command turns an operation into a value with a lifecycle. It is justified when the operation needs history, delayed execution, a queue, replay, remapping, or audit.

A small base contract can use `RefCounted` because commands normally do not need a scene-tree lifecycle:

```gdscript
class_name EditCommand
extends RefCounted

func apply() -> bool:
	push_error("EditCommand.apply() must be overridden.")
	return false

func revert() -> bool:
	push_error("EditCommand.revert() must be overridden.")
	return false
```

A concrete command captures prior state rather than guessing an inverse later:

```gdscript
class_name MoveMarkerCommand
extends EditCommand

var _marker: Node2D
var _before: Vector2
var _after: Vector2

func _init(marker: Node2D, destination: Vector2) -> void:
	_marker = marker
	_before = marker.position
	_after = destination

func apply() -> bool:
	if not is_instance_valid(_marker):
		return false
	_marker.position = _after
	return true

func revert() -> bool:
	if not is_instance_valid(_marker):
		return false
	_marker.position = _before
	return true
```

The history owns ordering:

```gdscript
class_name CommandHistory
extends Node

var _done: Array[EditCommand] = []
var _undone: Array[EditCommand] = []

func run(command: EditCommand) -> bool:
	if not command.apply():
		return false
	_done.push_back(command)
	_undone.clear()
	return true

func undo() -> bool:
	while not _done.is_empty():
		var command: EditCommand = _done.pop_back()
		if command.revert():
			_undone.push_back(command)
			return true
	return false

func redo() -> bool:
	while not _undone.is_empty():
		var command: EditCommand = _undone.pop_back()
		if command.apply():
			_done.push_back(command)
			return true
	return false
```

## Define Command Policies

Before implementation, decide:

- **Target lifetime:** reject invalid targets, prune failed history entries, use stable IDs, or keep targets alive.
- **Failure:** only record successful commands, or store a failure result separately.
- **Transactions:** group several low-level changes into one user-visible command.
- **Merging:** collapse pointer-drag updates into one before/after command.
- **Capacity:** cap history and define which old entries are discarded.
- **Determinism:** capture random choices and required inputs if replay matters.
- **Side effects:** decide whether audio, particles, analytics, or network messages repeat on redo.
- **Serialization:** do not assume a command holding live nodes can be saved or sent over a network.

Commands should call domain APIs rather than mutate arbitrary fields. That keeps validation and invariants in the object that owns the state.

## Verification

### Signals

- Connect zero, one, and multiple listeners.
- Mutate to a new value and assert one emission with the expected payload.
- Set the same value and confirm the documented no-op behavior.
- Free and recreate a listener; confirm there is one reaction.
- Initialize a listener after prior mutations; confirm it reads current state correctly.

### Commands

- Capture state, apply, revert, and compare exact state.
- Apply, revert, then redo and compare again.
- Undo or redo an empty stack.
- Undo several command types in reverse order.
- Execute a new command after undo and confirm redo is cleared.
- Exercise the invalid-target policy.
- Confirm one continuous user gesture creates the intended number of history entries.
