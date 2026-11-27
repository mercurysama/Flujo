# Object Pooling

## Require Evidence

Pooling trades allocation churn for retained memory and reset complexity. Measure a representative workload first.

Look for:

- Repeated `PackedScene.instantiate()` and `queue_free()` in a hot path.
- Frame-time spikes correlated with bursts of short-lived objects.
- A large count of structurally identical projectiles, decals, enemies, or effects.
- A stable upper bound or a clear exhaustion policy.

Do not pool a rarely created menu, boss, level, or other object whose lifecycle is already simple. Do not pool only because an object is conceptually reusable.

## Define the Reusable Contract

The pooled object should have explicit activation and deactivation APIs. It should request recycling instead of freeing itself.

```gdscript
class_name PooledBolt
extends Area2D

signal recycle_ready(bolt: PooledBolt)

@export var speed: float = 520.0
@onready var lifetime: Timer = %Lifetime
var _active: bool = false
var _direction: Vector2 = Vector2.RIGHT

func _ready() -> void:
	visible = false
	monitoring = false
	monitorable = false
	set_physics_process(false)
	lifetime.stop()

func activate(at: Vector2, direction: Vector2) -> void:
	global_position = at
	_direction = direction.normalized()
	_active = true
	visible = true
	monitoring = true
	monitorable = true
	set_physics_process(true)
	lifetime.start()

func request_recycle() -> void:
	if not _active:
		return
	_active = false
	visible = false
	set_physics_process(false)
	lifetime.stop()
	call_deferred(&"_finish_recycle")

func _finish_recycle() -> void:
	monitoring = false
	monitorable = false
	recycle_ready.emit(self)

func _physics_process(delta: float) -> void:
	global_position += _direction * speed * delta

func _on_lifetime_timeout() -> void:
	request_recycle()
```

The pool owns instances and guarantees one return:

```gdscript
class_name BoltPool
extends Node2D

@export var bolt_scene: PackedScene
@export_range(0, 512, 1) var warm_count: int = 24
var _available: Array[PooledBolt] = []

func _ready() -> void:
	assert(bolt_scene != null, "Assign Bolt Scene before warming the pool.")
	for _index in range(warm_count):
		_available.push_back(_create_bolt())

func acquire(at: Vector2, direction: Vector2) -> PooledBolt:
	var bolt: PooledBolt
	if _available.is_empty():
		bolt = _create_bolt()
	else:
		bolt = _available.pop_back()
	bolt.activate(at, direction)
	return bolt

func _create_bolt() -> PooledBolt:
	var bolt := bolt_scene.instantiate() as PooledBolt
	assert(bolt != null, "BoltPool requires a PooledBolt root.")
	add_child(bolt)
	bolt.recycle_ready.connect(_release)
	return bolt

func _release(bolt: PooledBolt) -> void:
	if bolt in _available:
		return
	_available.push_back(bolt)
```

Collision and timeout handlers call `request_recycle()` rather than returning
the object directly. The deferred finish changes monitoring outside physics
query flushing and only makes the object available afterward, so a same-frame
acquire cannot be disabled by a stale deferred change. This is a structural
example, not a drop-in universal pool. Match the project's collision mode,
process callback, ownership, and reset needs.

## Choose an Exhaustion Policy

Pick one policy explicitly:

- **Grow:** instantiate another object. Smooth behavior, but the pool no longer has a hard memory cap.
- **Drop request:** return `null` or a failure result. Useful for cosmetic effects.
- **Recycle oldest:** acceptable only when interrupting the oldest active object is semantically safe.
- **Block/queue:** useful for non-frame-critical jobs, rarely for immediate gameplay effects.
- **Fixed failure:** assert in development when exceeding the designed bound.

If `acquire()` can fail, express that in callers and in the project's typing convention.

## Reset Every Mutable Subsystem

Audit each pooled scene, including child nodes:

- Local and global transform, scale, and rotation.
- Linear/angular velocity and accumulated forces.
- Health, damage, owner/team, target, and transient flags.
- Collision layers, masks, disabled shapes, monitoring, and monitorability.
- `_process`, `_physics_process`, input, and process mode.
- Timers, tweens, animations, animation callbacks, and await chains.
- Particles, trails, shaders, material parameters, and modulate values.
- Audio playback and bus overrides.
- Navigation target and avoidance state.
- Temporary signal connections and bound callables.
- Child nodes added during the prior use.
- Randomized values that must be regenerated.

Prefer one `activate(...)` and one `deactivate()` path over scattered reset calls in spawners, collision handlers, and timers.

## Keep Ownership Stable

- Put the pool under an owner whose lifetime covers every borrowed object.
- Do not reparent pooled nodes casually; local transforms and owner teardown become harder to reason about.
- Release or destroy the whole pool when its owning scene exits.
- Do not place a scene-local pool in an autoload solely to preserve allocations across unrelated levels.
- If a pooled object awaits a signal or timer, ensure deactivation cancels or invalidates the continuation.

## Avoid Linear Hot-Path Searches

Maintain an available stack or queue. Do not scan every pooled object each shot to find one whose `visible` flag is false. Track active and inactive membership explicitly if debugging or policy requires both.

## Instrument the Pool

Useful development counters include:

- Total objects created.
- Active objects now.
- High-water active count.
- Acquire requests dropped.
- Duplicate release attempts.
- Warm-up duration.

Keep instrumentation lightweight and gate noisy logs behind a development flag.

## Verification

1. Warm the pool and record total created.
2. Run below capacity for many cycles; total created should remain stable.
3. Reach exact capacity, then exceed it and observe the chosen policy.
4. Trigger two release causes in the same frame; the object must return once.
5. Reacquire every object and inspect all reset state.
6. Change scenes while objects are active; confirm the owner, instances, timers, and callbacks leave cleanly.
7. Compare profiler captures before and after under the same spawn pattern.
8. Remove the pool if evidence does not justify its retained memory and complexity.
