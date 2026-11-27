# SOLID and Coupling in Godot

## Use Principles as Questions

SOLID is a set of review questions, not a requirement to produce five layers for every feature.

### Single responsibility

Ask: which independent product decisions can force this script to change?

A player script that reads controls, calculates locomotion, updates animation, stores inventory, plays audio, and formats HUD text has several change pressures. Split where state and lifecycle form a coherent boundary, for example:

```text
Player (CharacterBody2D)
|-- Locomotion
|-- Inventory
|-- Visuals
`-- Audio
```

Do not split a calculation from the state it protects merely to shorten a file.

### Open/closed

Ask: can a new variation be added by supplying a component, resource, callable, or subtype without editing a central type switch?

Prefer extension points only where variation is already expected. A `match kind:` statement with two stable cases can be clearer than an abstract hierarchy. Refactor when every new case repeatedly changes tested core code.

### Liskov substitution

Ask: can each subtype be used anywhere the base type is accepted without special checks?

Check these contract details:

- Accepted inputs are not unexpectedly narrower.
- Required setup is not secretly different.
- A promised signal still occurs under the same conditions.
- A method does not change from synchronous to deferred without callers knowing.
- The subtype preserves ownership and lifetime expectations.

If callers repeatedly ask `if actor is FlyingActor`, the shared base contract may be wrong or too broad.

### Interface segregation

GDScript does not need a large formal interface to express a capability. Give clients a focused typed dependency or child component with only the operations they use.

An object that can take damage does not automatically need movement, dialog, inventory, or targeting APIs.

### Dependency inversion

High-level behavior should receive a stable capability rather than locate a concrete scene shape. In Godot this often means:

- A typed exported property configured by the owning scene.
- A setup parameter supplied immediately after instantiation.
- A focused component class.
- A signal for outward notification after state changes.

It does not mean every call needs a service locator or global event bus.

## Component Example

The component owns durability state and publishes a fact after mutation:

```gdscript
class_name Durability
extends Node

signal changed(current: int, maximum: int)
signal depleted

@export_range(1, 10000, 1) var maximum: int = 20
var _current: int

func _ready() -> void:
	_current = maximum

func current() -> int:
	return _current

func apply_damage(amount: int) -> void:
	if amount <= 0 or _current == 0:
		return
	_current = maxi(0, _current - amount)
	changed.emit(_current, maximum)
	if _current == 0:
		depleted.emit()
```

A hazard depends only on that capability:

```gdscript
class_name DamageHazard
extends Area2D

@export_range(1, 1000, 1) var damage: int = 4

func affect(target: Durability) -> void:
	target.apply_damage(damage)
```

The owning actor decides which `Durability` instance is passed. The hazard does not search a target's children by a magic name and does not know how depletion is presented.

## Refactor by Seam

Use an incremental sequence:

1. Characterize current behavior with a test or repeatable manual flow.
2. Name the responsibility and its required inputs, outputs, and state.
3. Add the new typed API while retaining the old entry point.
4. Delegate old behavior through the new unit.
5. Migrate callers one at a time.
6. Move state only after there is one clear writer.
7. Remove the compatibility entry point when no concrete consumer needs it.

Avoid changing scene structure, public names, state ownership, and behavior in one unverified step.

## Coupling Smells

- A reusable child uses `../../..` to reach a manager.
- UI writes gameplay fields directly.
- A script knows private child names inside several sibling scenes.
- Every new variant adds another branch in several unrelated files.
- A global lookup appears inside `_process()` or `_physics_process()`.
- A base class exposes methods that most subclasses implement as `pass`.
- A component cannot run in a minimal test scene because it assumes the project main scene.
- Renaming one node breaks many distant scripts.

Choose the narrowest correction. An exported reference may solve a brittle path without requiring a new framework.

## Inheritance Versus Composition

Use inheritance when there is a durable is-a relationship and the base contract is meaningful on its own. Keep trees shallow.

Use composition when:

- A capability is optional.
- Several unrelated actors share it.
- It has an independent lifecycle or state.
- Designers need to assemble combinations in scenes.
- Subclasses would otherwise disable inherited behavior.

Inherited scenes are useful for shared structure, but inspect overrides carefully. A base-scene edit can affect every descendant, while a local override can hide the new default.

## Verification Questions

- Can the new unit run with a minimal owner?
- Can a test replace its dependency with a small stand-in?
- Is there one writer for each moved state value?
- Are errors reported at the boundary rather than becoming null dereferences later?
- Did the refactor reduce paths, lookups, and reasons to change?
- Does deleting or replacing a collaborator follow a defined lifecycle?
- Is the resulting design simpler for the next likely change, not every imaginable change?
