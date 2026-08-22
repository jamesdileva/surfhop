class_name AirMovement
extends MovementModule

## Air acceleration with strafe-based speed gain (Gameplay Systems §1.4,
## Half-Life/CS variant): the air_speed_cap limits the PROJECTION check, but
## the acceleration itself scales with the full move speed — this is what
## makes classic circle-strafing (A-only + smooth mouse turn) possible.
## NOTE: doc §1.4 shows the weaker Quake-1 variant; flagged as doc divergence.

func enabled_in_state(state: int) -> bool:
	return state == MovementState.AIR


func process(input: InputState, delta: float) -> void:
	var camera := _controller.get_camera()
	if camera == null:
		return
	# Air wish direction combines WASD with the camera's yaw basis (§1.6).
	var wish_dir := input.compute_wish_dir(camera)
	if wish_dir == Vector3.ZERO:
		return
	apply_air_acceleration(wish_dir, delta)


func apply_air_acceleration(wish_dir: Vector3, delta: float) -> void:
	var velocity := _controller.get_velocity()
	var projected_speed: float = _controller.config.air_speed_cap
	var current := velocity.dot(wish_dir)
	var add_speed := projected_speed - current
	if add_speed <= 0.0:
		return
	var accel_speed := minf(
		_controller.config.air_accel * delta * _controller.config.walk_speed,
		add_speed)
	velocity += wish_dir * accel_speed
	_controller.set_velocity(velocity)
