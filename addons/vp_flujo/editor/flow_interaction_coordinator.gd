@tool
class_name FlowInteractionCoordinator
extends RefCounted


## Coordinates editor-only Flujo interaction without retaining persistent model or runtime state.
enum State {
	GODOT,
	FLOW,
	GAME,
}

var _dock: VPFlujoDock
var _state: State = State.GODOT
var _selected_controller_reference: WeakRef
var _flow_controller_reference: WeakRef
var _focus_before_flow_reference: WeakRef
var _flow_controller_before_game_reference: WeakRef
var _resume_flow_after_game: bool = false
var _playing_scene: bool = false
var _transition_generation: int = 0


func _init(dock: VPFlujoDock) -> void:
	_dock = dock


## Creates the configurable editor shortcut with F4 as Flujo's default interaction key.
static func create_default_shortcut() -> Shortcut:
	var shortcut: Shortcut = Shortcut.new()
	var event: InputEventKey = InputEventKey.new()
	event.keycode = KEY_F4
	shortcut.events = [event]
	return shortcut


func get_state() -> State:
	return _state


func is_flow_active() -> bool:
	return _state == State.FLOW


## Applies only hierarchy selection changes; ordinary editor focus changes do not call this method.
func set_selected_controller(controller: PVController) -> void:
	var next_controller: PVController = controller if is_instance_valid(controller) else null
	var current_controller: PVController = _selected_controller()
	if current_controller == next_controller:
		return
	_selected_controller_reference = weakref(next_controller) if next_controller != null else null
	if _state == State.FLOW and _flow_controller() != next_controller:
		_leave_flow(false, null)


## Handles the registered editor shortcut only while Flujo owns editor interaction.
func handle_shortcut(event: InputEvent, shortcut: Shortcut, viewport: Viewport) -> bool:
	if _state == State.GAME or shortcut == null or not event is InputEventKey:
		return false
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo or not shortcut.matches_event(event):
		return false
	return toggle_flow_interaction(viewport)


## Shares the exact F4 transition path with the dock's accessible interaction button.
func toggle_flow_interaction(viewport: Viewport) -> bool:
	if _state == State.GAME:
		return false
	var controller: PVController = _selected_controller()
	if controller == null:
		return false
	if _state == State.GODOT:
		_enter_flow(controller, viewport)
		return true
	if _state == State.FLOW:
		_leave_flow(true, viewport)
		return true
	return false


## Polls actual editor execution state so F5, F6, and editor buttons share one transition path.
func update_playing_scene(is_playing_scene: bool, viewport: Viewport) -> void:
	if _playing_scene == is_playing_scene:
		return
	_playing_scene = is_playing_scene
	if is_playing_scene:
		_enter_game(viewport)
	else:
		_leave_game()


## Releases editor-local interaction state before the owning plugin removes its dock and shortcut.
func shutdown() -> void:
	_transition_generation += 1
	_resume_flow_after_game = false
	_focus_before_flow_reference = null
	_flow_controller_reference = null
	_selected_controller_reference = null
	_playing_scene = false
	_state = State.GODOT
	if is_instance_valid(_dock):
		_dock.close_flow_transient_interfaces()
		_dock.set_editing_visible(false)
		_dock.deactivate_flow_interaction()
	_dock = null


func _enter_flow(controller: PVController, viewport: Viewport) -> void:
	if not is_instance_valid(controller) or not is_instance_valid(_dock):
		return
	_transition_generation += 1
	_flow_controller_reference = weakref(controller)
	_focus_before_flow_reference = _weak_focus_owner(viewport)
	_state = State.FLOW
	_dock.set_editing_visible(true)
	_dock.activate_flow_interaction()
	var target: Control = _dock.get_preferred_interaction_focus_target()
	_schedule_flow_focus(target, controller, _transition_generation)


func _leave_flow(restore_focus: bool, viewport: Viewport) -> void:
	_transition_generation += 1
	var focus_before_flow: WeakRef = _focus_before_flow_reference
	_focus_before_flow_reference = null
	_flow_controller_reference = null
	_state = State.GODOT
	if is_instance_valid(_dock):
		_dock.close_flow_transient_interfaces()
		_dock.deactivate_flow_interaction()
	if restore_focus:
		_schedule_focus_restore(focus_before_flow, _transition_generation)


func _enter_game(viewport: Viewport) -> void:
	_transition_generation += 1
	_resume_flow_after_game = _state == State.FLOW
	_flow_controller_before_game_reference = _flow_controller_reference
	_focus_before_flow_reference = null
	_flow_controller_reference = null
	_state = State.GAME
	_release_focus(viewport)
	if is_instance_valid(_dock):
		_dock.close_flow_transient_interfaces()
		_dock.set_editing_visible(false)
		_dock.suspend_for_game()


func _leave_game() -> void:
	_transition_generation += 1
	var resume_controller: PVController = _controller_from_reference(_flow_controller_before_game_reference)
	var may_resume: bool = _resume_flow_after_game \
		and resume_controller != null \
		and resume_controller == _selected_controller()
	_resume_flow_after_game = false
	_flow_controller_before_game_reference = null
	if may_resume and is_instance_valid(_dock):
		_flow_controller_reference = weakref(resume_controller)
		_state = State.FLOW
		_dock.set_editing_visible(true)
		_dock.activate_flow_interaction()
		return
	_flow_controller_reference = null
	_state = State.GODOT
	if is_instance_valid(_dock):
		_dock.set_editing_visible(false)
		_dock.deactivate_flow_interaction()


func _schedule_flow_focus(target: Control, controller: PVController, generation: int) -> void:
	if target == null or controller == null:
		return
	call_deferred(
		&"_focus_flow_target",
		weakref(target),
		weakref(controller),
		generation
	)


func _focus_flow_target(target_reference: WeakRef, controller_reference: WeakRef, generation: int) -> void:
	if generation != _transition_generation or _state != State.FLOW:
		return
	if _controller_from_reference(controller_reference) != _flow_controller():
		return
	var target: Control = _control_from_reference(target_reference)
	if _can_focus(target):
		target.grab_focus()


func _schedule_focus_restore(target_reference: WeakRef, generation: int) -> void:
	if target_reference == null:
		return
	call_deferred(&"_restore_previous_focus", target_reference, generation)


func _restore_previous_focus(target_reference: WeakRef, generation: int) -> void:
	if generation != _transition_generation or _state != State.GODOT:
		return
	var target: Control = _control_from_reference(target_reference)
	if _can_focus(target):
		target.grab_focus()


func _release_focus(viewport: Viewport) -> void:
	if viewport == null:
		return
	var focus_owner: Control = viewport.gui_get_focus_owner() as Control
	if is_instance_valid(focus_owner):
		focus_owner.release_focus()


func _selected_controller() -> PVController:
	return _controller_from_reference(_selected_controller_reference)


func _flow_controller() -> PVController:
	return _controller_from_reference(_flow_controller_reference)


func _controller_from_reference(reference: WeakRef) -> PVController:
	if reference == null:
		return null
	var candidate: PVController = reference.get_ref() as PVController
	return candidate if is_instance_valid(candidate) else null


func _weak_focus_owner(viewport: Viewport) -> WeakRef:
	if viewport == null:
		return null
	var focus_owner: Control = viewport.gui_get_focus_owner() as Control
	return weakref(focus_owner) if is_instance_valid(focus_owner) else null


func _control_from_reference(reference: WeakRef) -> Control:
	if reference == null:
		return null
	var candidate: Control = reference.get_ref() as Control
	return candidate if is_instance_valid(candidate) else null


func _can_focus(control: Control) -> bool:
	return is_instance_valid(control) \
		and control.is_inside_tree() \
		and control.is_visible_in_tree() \
		and control.focus_mode != Control.FOCUS_NONE
