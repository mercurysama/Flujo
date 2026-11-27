---
name: godot-control-layout
description: Builds Godot 4 Control UIs that resize instead of clipping or overlapping - containers versus anchors, anchor presets from code, size flags, custom_minimum_size, MarginContainer margins, Label wrapping, mouse_filter, CanvasLayer HUDs, Godot 4 theme override names (add_theme_color_override and friends) and the display/window/stretch settings for multiple resolutions. Use when creating or fixing menus, HUDs, dialogs and inventory screens, when UI elements are cut off, zero-sized, overlapping, ignoring position or size, or blocking clicks, or when the game must scale to other window sizes.
license: MIT
compatibility: Godot 4.3 or later (snippets tested on 4.7.2)
---

# Control layout in Godot 4

Most broken Godot UIs come from three mistakes: positioning children of a container by hand, anchoring a control without resetting its offsets, and leaving the stretch settings at their defaults. Lay out with containers, anchor only the root of each UI, and let minimum sizes drive everything else.

## Containers own their children

A child of any `Container` (`VBoxContainer`, `HBoxContainer`, `GridContainer`, `MarginContainer`, `PanelContainer`, `CenterContainer`, `ScrollContainer`, `FlowContainer`) cannot keep its own `position`, `size` or anchors: the container overwrites them on the next sort. Control a child's share of space with:

- `size_flags_horizontal` / `size_flags_vertical`: `Control.SIZE_FILL` (default), `SIZE_EXPAND_FILL` to take spare space, `SIZE_SHRINK_CENTER` / `SIZE_SHRINK_END` to stay small and aligned.
- `size_flags_stretch_ratio`: share of spare space between expanding siblings.
- `custom_minimum_size`: the smallest size the child accepts. Containers never shrink a child below its combined minimum size, which is how text and buttons avoid being cut off.

Pick the container by layout: rows or columns (`VBoxContainer`, `HBoxContainer`), a grid (`GridContainer` with `columns`), padding (`MarginContainer`, padding set by theme constants `margin_left`, `margin_top`, `margin_right`, `margin_bottom`), a background (`PanelContainer`, style box `panel`), long content (`ScrollContainer` with one child that has `SIZE_EXPAND_FILL`), wrapping items (`HFlowContainer`).

## Anchors for the root only

Anchors place a control relative to its parent's rectangle and are what you use for the outermost UI node. From code, use `set_anchors_and_offsets_preset()`. `set_anchors_preset()` only moves the anchors and keeps the old offsets, so a control created in code stays at size `(0, 0)`.

Presets: `PRESET_FULL_RECT`, `PRESET_TOP_LEFT`, `PRESET_TOP_RIGHT`, `PRESET_BOTTOM_LEFT`, `PRESET_BOTTOM_RIGHT`, `PRESET_CENTER`, `PRESET_TOP_WIDE`, `PRESET_BOTTOM_WIDE`, `PRESET_LEFT_WIDE`, `PRESET_RIGHT_WIDE`, `PRESET_HCENTER_WIDE`, `PRESET_VCENTER_WIDE`, and the centre-edge presets such as `PRESET_CENTER_TOP`.

## HUD on a CanvasLayer

A `Control` under a `Node2D` is drawn in world space and moves with the `Camera2D`. Put the HUD under a `CanvasLayer` so it stays on screen; `layer` orders several canvas layers (higher draws on top).

```gdscript
extends CanvasLayer

var score_label: Label


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 16)
	add_child(margin)

	var column := VBoxContainer.new()
	margin.add_child(column)

	var top_bar := HBoxContainer.new()
	column.add_child(top_bar)

	score_label = Label.new()
	score_label.text = "Score: 0"
	score_label.add_theme_font_size_override("font_size", 24)
	score_label.add_theme_color_override("font_color", Color.GOLD)
	top_bar.add_child(score_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_bar.add_child(spacer)

	var pause_button := Button.new()
	pause_button.text = "Pause"
	pause_button.custom_minimum_size = Vector2(96, 40)
	top_bar.add_child(pause_button)


func set_score(value: int) -> void:
	score_label.text = "Score: %d" % value
```

Built in the editor, the same tree is: CanvasLayer > MarginContainer (Layout: Full Rect) > VBoxContainer > HBoxContainer > Label, Control (Expand), Button.

## Text that does not clip

- A `Label` with `autowrap_mode` set needs a width from somewhere. Inside an `HBoxContainer` with default flags it collapses to 1 pixel wide and becomes very tall. Give it `SIZE_EXPAND_FILL` or a `custom_minimum_size.x`.
- For one-line text in a fixed space, set `text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS` (or `clip_text = true`).
- Prefer `add_theme_font_size_override("font_size", n)` over scaling a control: `scale` does not change the size containers reserve.

```gdscript
extends VBoxContainer


func add_message(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(label)


func add_title(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.custom_minimum_size = Vector2(0, 32)
	add_child(label)
```

## Clicks that do not reach the game

`mouse_filter` decides whether a control eats mouse input. Defaults differ: plain `Control`, `ColorRect` and `Panel` use `MOUSE_FILTER_STOP`, containers use `MOUSE_FILTER_PASS`, `Label` uses `MOUSE_FILTER_IGNORE`. A full-screen `Control` or `ColorRect` with `STOP` swallows every click, so `_unhandled_input()` in the game never sees it. Set `mouse_filter = Control.MOUSE_FILTER_IGNORE` on overlays, spacers and decorative rects.

## Theme overrides (Godot 4 names)

| Godot 3 | Godot 4 |
| --- | --- |
| `add_color_override("font_color", c)` | `add_theme_color_override("font_color", c)` |
| `add_font_override("font", f)` | `add_theme_font_override("font", f)` |
| (font size lived in DynamicFont) | `add_theme_font_size_override("font_size", 24)` |
| `add_stylebox_override("normal", sb)` | `add_theme_stylebox_override("normal", sb)` |
| `add_constant_override("separation", 8)` | `add_theme_constant_override("separation", 8)` |
| `add_icon_override("icon", tex)` | `add_theme_icon_override("icon", tex)` |
| `custom_colors/font_color` in `.tscn` | `theme_override_colors/font_color` |

Remove an override with the matching `remove_theme_*_override(name)`. For a consistent look, assign one `Theme` resource to the root control instead of overriding each node; children inherit it.

## Resolution and stretch

Set these in Project Settings > Display > Window (they are stored in `project.godot`):

- `display/window/size/viewport_width` and `viewport_height`: the base resolution you design for (default 1152 x 648).
- `display/window/stretch/mode`: `canvas_items` for most games (UI and 2D scale smoothly), `viewport` for pixel art, `disabled` for tools. Godot 3's `2d` mode is `canvas_items` in Godot 4. The setting's default is `disabled`; projects created in Godot 4.7 or later start with `canvas_items`.
- `display/window/stretch/aspect`: `expand` lets anchored UI use extra space on wider or taller screens; `keep` adds black bars. The default is `keep`; projects created in Godot 4.7 or later start with `expand`.
- `display/window/stretch/scale_mode`: `integer` for crisp pixel art.

At runtime the same settings are on the window: `get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS` and `get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND`.

## Checklist when UI is cut off or misplaced

1. Is the control a container child with a hand-set `position` or `size`? Use size flags and `custom_minimum_size`.
2. Was the root anchored with `set_anchors_preset()` only? Use `set_anchors_and_offsets_preset()`.
3. Does a wrapping `Label` have a width?
4. Is the HUD under a `CanvasLayer` rather than a `Node2D`?
5. Is `display/window/stretch/mode` still `disabled` while the window size changes?
6. Does an invisible full-screen control with `MOUSE_FILTER_STOP` sit on top?
