---
name: godot-programming-patterns
description: "Godot 4.x SOLID design, typed signals, command objects, undo/redo, and object pooling. Use when refactoring tightly coupled GDScript, splitting monolithic scene behavior, replacing polling with signals, representing actions for queues or history, or reducing measured spawn/free churn."
license: MIT
metadata:
  author: godot-skills
  version: "1.0.0"
---

# Godot Programming Patterns

Apply a pattern only to a demonstrated design or performance pressure. A direct typed method call is often the best design.

## Scope

Use this skill for:

- Applying SOLID as a diagnostic tool to Godot scripts and scene composition.
- Separating behavior into focused components without needless inheritance.
- Designing, emitting, connecting, and testing typed signals.
- Encapsulating reversible, queued, replayable, or remappable actions as commands.
- Implementing object pools with explicit acquire, activate, release, and reset contracts.

Do not use this skill for introductory node, scene, resource, Input Map, or editor guidance; use the fundamentals skill. Do not use it to choose authoritative game state, autoload managers, scene transitions, or persistence formats; use the game-architecture skill. Local patterns may support those systems, but this skill does not decide their ownership.

## Inspect Before Refactoring

1. Find `project.godot` and read `config/features` to identify the exact Godot 4.x baseline.
2. Inspect neighboring scripts and scenes. Match static-typing, `class_name`, naming, folder, component, connection, and test conventions.
3. Reproduce the current behavior and record a baseline. For pooling, capture profiler or monitor evidence rather than assuming allocation is the bottleneck.
4. Map the current collaborators: callers, callees, signals, groups, node paths, exported references, and runtime-created nodes.
5. Mark lifetimes and ownership. A signal connection, command target, or pooled object must not outlive the object that owns it.
6. Search for an existing component, event, command base, history service, or pool before adding another abstraction.
7. Identify the exact pressure: multiple reasons to change, one-to-many notification, action history, or measured churn.

Preserve public behavior and editor wiring unless changing that contract is part of the request.

## Select the Smallest Pattern

- Use a **direct method call** for one known collaborator when the caller needs a result or controls sequencing.
- Use a **signal** for a fact that already happened and may interest zero or more local listeners.
- Use a **focused component** when behavior has its own state, lifecycle, or reuse boundary.
- Use a **command** when an action must be stored, reversed, queued, replayed, logged, or generated independently from execution.
- Use a **pool** only when repeated instantiation/destruction is measurably costly and objects can be reset reliably.
- Use inheritance only when every subtype honors the base contract. Prefer scene composition for optional capabilities.

Do not combine patterns by default. For example, a one-off button action does not need a command object, event bus, and pool.

## Implementation Workflow

1. Write the existing observable contract or add a focused regression test.
2. Introduce one seam: a typed method, component, signal, command, or pool boundary.
3. Migrate one producer and one consumer while keeping the project runnable.
4. Make ownership explicit through an exported reference, setup parameter, or owning scene.
5. Remove obsolete paths only after all callers are migrated.
6. Exercise lifecycle edges: scene exit, target deletion, repeated connection, undo after deletion, and pool exhaustion.
7. Compare behavior and performance with the baseline.

## Pattern Decisions

### SOLID in scene-based code

- Give a script one coherent reason to change, not an arbitrary line limit.
- Separate input intent, simulation, and presentation when they evolve independently.
- Extend through focused components or stable contracts rather than expanding type switches.
- Keep subtype preconditions no stricter and outcomes no weaker than the base contract.
- Depend on the smallest API a collaborator needs.
- Pass dependencies in; do not make reusable nodes search globally for concrete implementations.

Avoid extracting every three-line method into a new node. A split is useful only when it clarifies ownership, change pressure, testing, or reuse.

### Signals

Name signals as completed facts such as `value_changed` or `request_finished`, and type their payloads. The emitter owns signal meaning; listeners own their reactions.

```gdscript
class_name HeatGauge
extends Node

signal value_changed(value: float)

@export_range(0.1, 100.0, 0.1) var maximum: float = 10.0
var _value: float = 0.0

func value() -> float:
	return _value

func set_value(next_value: float) -> void:
	var clamped := clampf(next_value, 0.0, maximum)
	if is_equal_approx(clamped, _value):
		return
	_value = clamped
	value_changed.emit(_value)
```

Signals are not stored state. A late listener should read the current value during initialization and then subscribe for later changes.

### Commands

A command should contain everything needed to execute, plus the exact prior state needed to undo if undo is promised. Keep input collection outside the command. Do not store a live node reference in long-lived history without defining what happens when that node is freed.

Use commands for semantic actions, not every frame of continuous movement. Merge or checkpoint drag-like interactions so history remains useful.

### Object pools

Define the lifecycle before writing the container:

1. Acquire an inactive instance.
2. Activate it with all required spawn data.
3. Use it without allocating replacement state each cycle.
4. Request release when its job ends.
5. Reset every mutable subsystem.
6. Return it exactly once.

Visibility alone is not a sufficient inactive-state contract. Processing, monitoring, timers, animations, particles, audio, velocities, and temporary signal connections may continue while hidden.

## Verification

Run the project's established checks, then validate the selected pattern directly:

- **SOLID/component refactor:** old callers still work; the extracted unit can be exercised independently; no new global lookup was introduced.
- **Signal:** one mutation emits once; an unchanged value emits zero times; payloads are correct; a recreated listener does not create duplicate reactions.
- **Command:** execute then undo restores exact prior state; redo reapplies it; a new command clears redo; empty history is safe; invalid targets follow a defined policy.
- **Pool:** warm-up reaches the expected size; steady-state reuse stops allocations; exhaustion follows the chosen grow/drop/fail policy; release is idempotent; reused objects have no stale state.
- **Performance:** compare profiler captures under the same workload and report whether frame time, allocation, or node churn improved.
- **Lifecycle:** change or reload scenes repeatedly and check for orphaned nodes, stale callbacks, and retained references.

## Failure Modes

- **More classes, same coupling:** responsibilities were renamed but dependencies still cross every boundary. Redesign the contract, not only the files.
- **Signal used as a command:** the emitter expects exactly one listener to perform required work. Use an explicit dependency and method call.
- **Missed startup update:** a listener subscribed after the initial emission. Pull the initial snapshot before relying on future signals.
- **Duplicate callback:** initialization connected more than once or a long-lived emitter retained a listener unexpectedly. Inspect connection ownership and guard intentional reconnects.
- **Undo drifts:** the inverse operation was calculated instead of restoring captured prior state.
- **Command target vanished:** history retained a scene node beyond its lifetime. Reject, prune, or resolve a stable target according to an explicit policy.
- **Pool creates double returns:** both collision and timeout release the same object. Make active state explicit and release idempotent.
- **Hidden pooled object still acts:** collision, processing, timer, animation, or audio state was not disabled.
- **Pooling is slower:** the workload was not allocation-bound, the pool scans linearly, or reset work costs more than instantiation. Keep the measured simpler design.

## References

- [SOLID and coupling](references/solid-and-coupling.md)
- [Signals and commands](references/signals-and-commands.md)
- [Object pooling](references/object-pooling.md)
