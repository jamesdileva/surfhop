extends Node

## Translates raw Godot input events into a structured InputState for the
## movement framework. Handles rebinding with conflict detection and persists
## custom bindings across restarts. Defaults live in project.godot [input].

const ACTIONS := ["move_forward", "move_back", "move_left", "move_right", "jump", "duck", "sprint"]
const BINDINGS_PATH := "user://save/bindings.cfg"

var _mouse_delta: Vector2 = Vector2.ZERO
var _jump_just_pressed: bool = false


func _ready() -> void:
	load_bindings()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_delta += event.relative
	elif event.is_action_pressed("jump"):
		_jump_just_pressed = true


func _process(_delta: float) -> void:
	# Unread per-frame data never persists past one rendered frame.
	_mouse_delta = Vector2.ZERO
	_jump_just_pressed = false


func get_state() -> InputState:
	var state := InputState.new()
	var move := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	state.right = move.x
	state.forward = move.y
	state.jump_just_pressed = _jump_just_pressed
	state.jump_held = Input.is_action_pressed("jump")
	state.crouch_held = Input.is_action_pressed("duck")
	state.sprint_held = Input.is_action_pressed("sprint")
	state.mouse_delta = _mouse_delta
	_mouse_delta = Vector2.ZERO
	_jump_just_pressed = false
	return state


func is_action_pressed(action: String) -> bool:
	return InputMap.has_action(action) and Input.is_action_pressed(action)


func get_movement_input() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_back", "move_forward")


## Rebinds an action to a new event. Returns false (silently, for callers to
## surface as UI feedback) on unknown actions or conflicting bindings.
func rebind_action(action: String, event: InputEvent) -> bool:
	if not ACTIONS.has(action):
		return false
	if _has_conflict(action, event):
		return false
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)
	save_bindings()
	return true


func load_bindings() -> void:
	if not FileAccess.file_exists(BINDINGS_PATH):
		return
	var cfg := ConfigFile.new()
	if cfg.load(BINDINGS_PATH) != OK:
		push_warning("InputManager: failed to read %s, keeping defaults" % BINDINGS_PATH)
		return
	for action: String in ACTIONS:
		if cfg.has_section_key("bindings", action):
			var events: Array = cfg.get_value("bindings", action, [])
			InputMap.action_erase_events(action)
			for event: InputEvent in events:
				InputMap.action_add_event(action, event)


func save_bindings() -> void:
	var cfg := ConfigFile.new()
	for action: String in ACTIONS:
		cfg.set_value("bindings", action, InputMap.action_get_events(action))
	DirAccess.make_dir_recursive_absolute(BINDINGS_PATH.get_base_dir())
	if cfg.save(BINDINGS_PATH) != OK:
		push_error("InputManager: failed to write %s" % BINDINGS_PATH)


func _has_conflict(action: String, event: InputEvent) -> bool:
	for other: String in ACTIONS:
		if other == action:
			continue
		for existing: InputEvent in InputMap.action_get_events(other):
			if _same_binding(existing, event):
				return true
	return false


func _same_binding(a: InputEvent, b: InputEvent) -> bool:
	if a is InputEventKey and b is InputEventKey:
		if a.physical_keycode != KEY_NONE and a.physical_keycode == b.physical_keycode:
			return true
		return a.keycode != KEY_NONE and a.keycode == b.keycode
	if a is InputEventMouseButton and b is InputEventMouseButton:
		return a.button_index == b.button_index
	return false
