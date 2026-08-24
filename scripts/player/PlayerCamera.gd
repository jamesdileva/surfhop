class_name PlayerCamera
extends Camera3D

## First-person mouse-look camera. Yaw rotates the parent body (the Player),
## pitch rotates the camera itself, clamped to +/- MAX_PITCH_DEG.
## Sensitivity and invert settings are read from SaveManager; runtime changes
## are applied by calling apply_settings().

const MOUSE_LOOK_SCALE: float = 0.1  # degrees per mouse count at sensitivity 1.0
const MAX_PITCH_DEG: float = 89.0
const BASE_FOV: float = 90.0

var mouse_captured: bool = false

var _yaw_deg: float = 0.0
var _pitch_deg: float = 0.0
var _sensitivity_x: float = 1.0
var _sensitivity_y: float = 1.0
var _invert_y: bool = false


func _ready() -> void:
	fov = BASE_FOV
	apply_settings()
	set_mouse_captured(true)


## Re-reads camera-related settings from SaveManager (e.g. after the player
## changes sensitivity in a settings menu).
func apply_settings() -> void:
	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager == null:
		return
	_sensitivity_x = save_manager.get_setting("input/mouse_sensitivity_x")
	_sensitivity_y = save_manager.get_setting("input/mouse_sensitivity_y")
	_invert_y = save_manager.get_setting("input/invert_mouse_y")


func set_mouse_captured(captured: bool) -> void:
	mouse_captured = captured
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured else Input.MOUSE_MODE_VISIBLE


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and mouse_captured:
		_yaw_deg = wrapf(_yaw_deg - event.relative.x * MOUSE_LOOK_SCALE * _sensitivity_x,
			-180.0, 180.0)
		var pitch_sign := 1.0 if _invert_y else -1.0
		_pitch_deg += pitch_sign * event.relative.y * MOUSE_LOOK_SCALE * _sensitivity_y
		_pitch_deg = clampf(_pitch_deg, -MAX_PITCH_DEG, MAX_PITCH_DEG)
		var parent_body := get_parent()
		if parent_body is Node3D:
			parent_body.rotation.y = deg_to_rad(_yaw_deg)
		rotation.x = deg_to_rad(_pitch_deg)
	elif event.is_action_pressed("ui_cancel"):
		# Esc opens the pause menu (tree pauses; settings reachable from it).
		# Works regardless of mouse capture (alt-tab releases the mouse, and
		# Esc must still pause). Marking the event handled stops it from ALSO
		# reaching UIManager's ui_cancel close handler, which would instantly
		# re-close the menu we just opened (the invisible-pause-menu bug).
		get_viewport().set_input_as_handled()
		var ui_manager := get_node_or_null("/root/UIManager")
		if ui_manager != null:
			ui_manager.toggle_pause()
		else:
			set_mouse_captured(false)
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT and not mouse_captured:
		# Click to re-capture after Esc (playtest QoL until pause menu exists).
		var ui := get_node_or_null("/root/UIManager")
		if ui == null or ui.current_menu == "":
			set_mouse_captured(true)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and mouse_captured:
		set_mouse_captured(false)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN and not mouse_captured:
		# Alt-tab back into an active run: re-capture automatically instead
		# of requiring a blind click first.
		var ui := get_node_or_null("/root/UIManager")
		if ui != null and ui.session_active and ui.current_menu == "":
			set_mouse_captured(true)
