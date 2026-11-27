---
name: godot-signals
description: Godot 4 signal patterns and their failure modes - declaring typed signals, emit(), connect() and disconnect() with Callables, bind() and unbind(), lambdas, CONNECT_ONE_SHOT and CONNECT_DEFERRED, await on signals and timers, editor-made connections stored in .tscn files, and the call down, signal up rule. Use when wiring UI buttons, timers, Area2D or body events and custom game events, when replacing Godot 3 connect("signal", self, "method") or yield code, or when debugging "already connected", "Method expected N argument(s)" or handlers that silently never run.
license: MIT
compatibility: Godot 4.3 or later (snippets tested on 4.7.2)
---

# Signals in Godot 4

In Godot 4 a signal is a first-class `Signal` value and a method reference is a `Callable`. Use the object syntax (`button.pressed.connect(_on_pressed)`) everywhere. The parser then rejects a misspelled handler, and a misspelled signal on `self`; a misspelled signal on another typed node is caught when `unsafe_property_access` is set to Error (see the godot-4-api-pitfalls skill). The string forms (`connect("pressed", ...)`, `emit_signal("died")`) are only checked at runtime.

## Declare, emit, connect

```gdscript
extends Node

signal health_changed(old_value: int, new_value: int)
signal died

var health := 100


func take_damage(amount: int) -> void:
	var old := health
	health = maxi(health - amount, 0)
	health_changed.emit(old, health)
	if health == 0:
		died.emit()
```

```gdscript
extends Control

@onready var start_button: Button = %StartButton
@onready var quit_button: Button = %QuitButton


func _ready() -> void:
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(get_tree().quit)
	start_button.mouse_entered.connect(func() -> void: start_button.grab_focus())


func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://level_1.tscn")
```

The handler must accept exactly the arguments the signal emits. A mismatch is not a parse error; at emit time Godot logs `Error calling from signal 'x' to callable: '...': Method expected 0 argument(s), but called with 1.` and skips the handler.

## bind() and unbind()

- `bind(a, b)` appends extra arguments after the signal's own arguments. A handler for `pressed` bound with one value takes one parameter; for `health_changed(old, new)` bound with one value it takes three, in the order `old, new, bound`.
- `unbind(n)` drops the last `n` signal arguments, so a no-argument function can handle a signal that sends some.

```gdscript
extends HBoxContainer

signal slot_chosen(index: int)

var slot_buttons: Array[Button] = []


func _ready() -> void:
	for i in 4:
		var button := Button.new()
		button.text = "Slot %d" % (i + 1)
		add_child(button)
		slot_buttons.append(button)
		button.pressed.connect(_on_slot_pressed.bind(i))
	var timer := Timer.new()
	add_child(timer)
	timer.timeout.connect(_refresh)
	slot_chosen.connect(_refresh.unbind(1))
	timer.start(1.0)


func _on_slot_pressed(index: int) -> void:
	slot_chosen.emit(index)


func _refresh() -> void:
	for button in slot_buttons:
		button.disabled = false
```

## Disconnect, duplicates and one-shot connections

- `disconnect()` needs a Callable equal to the connected one. `_handler.bind(1)` built again compares equal and works. A lambda does not: keep it in a variable and disconnect that variable.
- Connecting the same Callable twice logs `Signal 'x' is already connected to given callable ...` and keeps one connection. Guard with `is_connected()` when code can run twice, for example in `_ready()` of a node that is re-added to the tree.
- `connect(callable, CONNECT_ONE_SHOT)` disconnects after the first emission. `CONNECT_DEFERRED` runs the handler at idle time. Use it (or `set_deferred()`) when a physics callback such as `body_entered` changes physics state; doing it directly logs `Can't change this state while flushing queries.`
- Connections to an object are removed when that object is freed.

```gdscript
extends Area2D

@onready var shape: CollisionShape2D = $CollisionShape2D
var _on_first_touch := func(body: Node2D) -> void: print(body.name, " touched first")


func _ready() -> void:
	body_entered.connect(_on_first_touch, CONNECT_ONE_SHOT)
	body_entered.connect(_close_after_entry, CONNECT_DEFERRED)
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	print(body.name, " entered")


func _close_after_entry(_body: Node2D) -> void:
	shape.disabled = true


func stop_listening() -> void:
	body_entered.disconnect(_on_body_entered)
```

## await

`await signal` pauses the function until the signal fires and returns its arguments: `null` for no arguments, the value for one, an `Array` for two or more. A function that contains `await` is a coroutine; callers that need its result must `await` it too, otherwise they continue immediately.

```gdscript
extends Node2D

signal door_opened(door_name: String)


func _ready() -> void:
	await get_tree().create_timer(0.5).timeout
	var opened_by: String = await door_opened
	print("Door opened: ", opened_by)
	await play_intro()
	print("Intro finished")


func play_intro() -> void:
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 1.0).from(0.0)
	await tween.finished
```

`await` never times out. If the signal is never emitted (or its emitter is freed first) the function simply stops there, with no error. Use a `Timer` or a one-shot connection when a fallback path is needed.

## Editor connections

Connections made in the Node dock are saved in the scene file, not in the script:

```text
[connection signal="pressed" from="StartButton" to="." method="_on_start_button_pressed"]
```

If the method is renamed or deleted in the script, the connection stays in the `.tscn`. In Godot 4.7.2, emitting a signal whose connected method does not exist prints no error, so the button just stops working. After renaming a handler, search the scenes for `method="old_name"` and update them, or reconnect in the Node dock. Connect in code when the script should be self-contained; connect in the editor when designers wire scenes. Avoid doing both for the same signal and method: the second connect logs "already connected".

## Call down, signal up

A node calls methods on its children (it owns them and knows they exist) and emits signals for its parent or siblings to react to (it should not know who is listening). The parent, or whichever node composes the two, does the connecting:

```gdscript
extends Node2D

@onready var player: Node2D = $Player
@onready var health_bar: ProgressBar = $HUD/HealthBar


func _ready() -> void:
	player.connect(&"health_changed", _on_player_health_changed)


func _on_player_health_changed(_old_value: int, new_value: int) -> void:
	health_bar.value = new_value
```

This parent only knows `Player` as a `Node2D`, so it names the custom signal as a string. Give the player script a `class_name Player`, type the variable as `Player`, and write `player.health_changed.connect(_on_player_health_changed)` so the parser checks the name too.

For events that many unrelated scenes care about (player died, level finished), a common pattern is an autoload script that only declares signals, used as an event bus: `Events.player_died.emit()` and `Events.player_died.connect(_on_player_died)`.

## Godot 3 forms to replace

| Godot 3 | Godot 4 |
| --- | --- |
| `connect("pressed", self, "_on_pressed")` | `pressed.connect(_on_pressed)` |
| `connect("pressed", self, "_on_pressed", [id])` | `pressed.connect(_on_pressed.bind(id))` |
| `connect("timeout", self, "_on_timeout", [], CONNECT_ONESHOT)` | `timeout.connect(_on_timeout, CONNECT_ONE_SHOT)` |
| `disconnect("pressed", self, "_on_pressed")` | `pressed.disconnect(_on_pressed)` |
| `is_connected("pressed", self, "_on_pressed")` | `pressed.is_connected(_on_pressed)` |
| `emit_signal("died")` | `died.emit()` |
| `yield(obj, "signal_name")` | `await obj.signal_name` |
| `funcref(obj, "method")` | `Callable(obj, "method")` or `obj.method` |
