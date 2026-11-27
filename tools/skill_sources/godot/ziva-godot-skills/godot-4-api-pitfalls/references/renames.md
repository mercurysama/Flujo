# Less common Godot 3 to Godot 4 renames

Sources: the official "Upgrading from Godot 3 to Godot 4" guide and the engine's `editor/project_upgrade/renames_map_3_to_4.cpp`. Every Godot 4 class, method, property, signal and constant below exists in the Godot 4.7.2 class reference. Shader names come from the Godot 4.7 shading language reference.

## Classes

Most 3D nodes gained a `3D` suffix (`Area` is `Area3D`, `RigidBody` is `RigidBody3D`, `Camera` is `Camera3D`, `MeshInstance` is `MeshInstance3D`, `CollisionShape` is `CollisionShape3D`). Other renames:

| Godot 3 | Godot 4 |
| --- | --- |
| `BoxShape`, `CapsuleShape`, `PlaneShape`, `RayShape` | `BoxShape3D`, `CapsuleShape3D`, `WorldBoundaryShape3D`, `SeparationRayShape3D` |
| `LineShape2D`, `RayShape2D` | `WorldBoundaryShape2D`, `SeparationRayShape2D` |
| `CubeMesh` | `BoxMesh` |
| `Position3D` | `Marker3D` |
| `SpatialMaterial`, `ParticlesMaterial` | `StandardMaterial3D`, `ParticleProcessMaterial` |
| `Particles` | `GPUParticles3D` |
| `Light2D` (the node) | `PointLight2D` (`Light2D` is now the abstract base) |
| `Listener` | `AudioListener3D` |
| `GIProbe`, `BakedLightmap` | `VoxelGI`, `LightmapGI` |
| `ProceduralSky`, `PanoramaSky` | `Sky` with a `ProceduralSkyMaterial` or `PanoramaSkyMaterial` |
| `StreamTexture` | `CompressedTexture2D` |
| `VisualServer`, `Physics2DServer` | `RenderingServer`, `PhysicsServer2D` |
| `Physics2DDirectSpaceState` | `PhysicsDirectSpaceState2D` |
| `NavigationPolygonInstance`, `NavigationMeshInstance` | `NavigationRegion2D`, `NavigationRegion3D` |
| `Navigation2D`, `Navigation` | Removed. Use `NavigationAgent2D` / `NavigationAgent3D` with navigation regions |
| `VisibilityNotifier2D`, `VisibilityEnabler2D` | `VisibleOnScreenNotifier2D`, `VisibleOnScreenEnabler2D` |
| `VisibilityNotifier`, `VisibilityEnabler` | `VisibleOnScreenNotifier3D`, `VisibleOnScreenEnabler3D` |
| `Viewport` (the node), `ViewportContainer` | `SubViewport`, `SubViewportContainer` |
| `VideoPlayer` | `VideoStreamPlayer` |
| `ShortCut` | `Shortcut` |
| `ToolButton` | `Button` with `flat = true` |
| `YSort` | `Node2D` with `y_sort_enabled = true` |
| `DynamicFont`, `DynamicFontData`, `BitmapFont` | `FontFile` (or `SystemFont`) |
| `OpenSimplexNoise` | `FastNoiseLite` |
| `ARVROrigin`, `ARVRCamera`, `ARVRController`, `ARVRServer` | `XROrigin3D`, `XRCamera3D`, `XRController3D`, `XRServer` |
| `EditorSpatialGizmoPlugin` | `EditorNode3DGizmoPlugin` |

## Methods

| Godot 3 | Godot 4 |
| --- | --- |
| `funcref(obj, "method")` | `Callable(obj, "method")`, or `obj.method` |
| `transform.xform(v)`, `transform.xform_inv(v)` | `transform * v`, `v * transform` |
| `vector.linear_interpolate(b, t)` | `vector.lerp(b, t)` |
| `vector.clamped(length)` | `vector.limit_length(length)` |
| `Node.raise()` | `move_to_front()` on a `CanvasItem`, `get_parent().move_child(self, -1)` on other nodes |
| `Control.get_stylebox()` | `get_theme_stylebox()` |
| `Control.set_tooltip()` | `tooltip_text` property |
| `Node3D.get_world()` | `get_world_3d()` |
| `GridMap.world_to_map()`, `map_to_world()` | `local_to_map()`, `map_to_local()` |
| `ImageTexture.new()` then `create_from_image(img, flags)` | `ImageTexture.create_from_image(img)` (static) |
| `thread.start(self, "_work", data)` | `thread.start(_work.bind(data))` |
| `Thread.is_active()` | `is_started()` (true until `wait_to_finish()`); `is_alive()` only tells whether it is still running |
| `AnimationPlayer.add_animation()` | `add_animation_library()` with an `AnimationLibrary` |
| `PacketPeerUDP.listen()`, `is_listening()` | `bind()`, `is_bound()` |
| `get_network_unique_id()`, `get_network_connected_peers()` | `multiplayer.get_unique_id()`, `multiplayer.get_peers()` |
| `set_network_master(id)` | `set_multiplayer_authority(id)` |
| `AABB.has_no_surface()`, `Rect2.has_no_area()` | `has_surface()`, `has_area()` (inverted meaning) |

## Properties

| Godot 3 | Godot 4 |
| --- | --- |
| `Camera.set_zfar()`, `set_znear()` | `Camera3D.far`, `Camera3D.near` properties |
| `Camera2D.current = true` | `make_current()` (needs `enabled`, which defaults to `true`); read it with `is_current()` |
| `Camera2D.rotating` | `ignore_rotation` (inverted meaning) |
| `BaseButton.pressed` (state) | `button_pressed` |
| `BaseButton.group` | `button_group` |
| `PathFollow2D.offset`, `PathFollow3D.offset` | `progress` |
| `PathFollow2D.rotate` | `rotates` |
| `Label.percent_visible` | `visible_ratio` |
| `ProgressBar.percent_visible` | `show_percentage` |
| `WindowDialog.window_title` | `Window.title` |
| `InputEventMouseButton.doubleclick` | `double_click` |
| `AudioServer.device` | `output_device` |
| `AnimatedTexture.fps` | `speed_scale` |
| `BoxShape.extents`, `GIProbe.extents`, `ReflectionProbe.extents` | `size` (full size, so double the old value) |
| `CSGBox` `width`, `height`, `depth` | `CSGBox3D.size` (a `Vector3`, same values) |

## Signals and constants

| Godot 3 | Godot 4 |
| --- | --- |
| `CanvasItem` signal `hide` | `hidden` |
| `Tween` signal `tween_all_completed` | `finished` on the `Tween` returned by `create_tween()` (`loop_finished` is not emitted after the last loop) |
| `MainLoop.NOTIFICATION_WM_QUIT_REQUEST` | `NOTIFICATION_WM_CLOSE_REQUEST` |
| `KEY_CONTROL` | `KEY_CTRL` |
| `JOY_BUTTON_0`, `JOY_XBOX_A`, `JOY_SONY_X` | `JOY_BUTTON_A` |
| `JOY_ANALOG_LX` | `JOY_AXIS_LEFT_X` |

## Shaders

| Godot 3 | Godot 4 |
| --- | --- |
| `.shader` files | `.gdshader` |
| `hint_albedo`, `hint_color` | `source_color` |
| `WORLD_MATRIX`, `CAMERA_MATRIX`, `INV_CAMERA_MATRIX` | `MODEL_MATRIX`, `INV_VIEW_MATRIX`, `VIEW_MATRIX` |
| Particle shader `vertex()` | `start()` and `process()` |
