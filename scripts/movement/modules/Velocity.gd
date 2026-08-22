class_name Velocity
extends MovementModule

## Owns convenience access to the canonical player velocity and applies the
## final per-axis max-velocity clamp each tick (architecture §9.2 step 7,
## §9.6). Runs last.

func process(input: InputState, delta: float) -> void:
	apply_max_velocity_clamp()


## Horizontal-only speed (ignoring the vertical component).
func horizontal_speed() -> float:
	var v := _controller.get_velocity()
	return Vector2(v.x, v.z).length()


func set_velocity(new_velocity: Vector3, preserve_vertical: bool = false) -> void:
	if preserve_vertical:
		new_velocity.y = _controller.get_velocity().y
	_controller.set_velocity(new_velocity)


func apply_max_velocity_clamp() -> void:
	var v := _controller.get_velocity()
	var max_v: Vector3 = _controller.config.max_velocity
	var clamped := Vector3(
		clampf(v.x, -max_v.x, max_v.x),
		clampf(v.y, -max_v.y, max_v.y),
		clampf(v.z, -max_v.z, max_v.z))
	if clamped != v:
		set_velocity(clamped)
