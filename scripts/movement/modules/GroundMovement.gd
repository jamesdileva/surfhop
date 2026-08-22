class_name GroundMovement
extends MovementModule

## Ground acceleration toward the wish direction (Gameplay Systems §1.2,
## classic Quake PM_Accelerate).

func enabled_in_state(state: int) -> bool:
	return state == MovementState.GROUND


func process(input: InputState, delta: float) -> void:
	var camera := _controller.get_camera()
	if camera == null:
		return
	var wish_dir := input.compute_wish_dir(camera)
	if wish_dir == Vector3.ZERO:
		return
	apply_ground_acceleration(wish_dir, _controller.config.walk_speed, delta)


func apply_ground_acceleration(wish_dir: Vector3, wish_speed: float, delta: float) -> void:
	var velocity := _controller.get_velocity()
	var current_speed := velocity.dot(wish_dir)
	var add_speed := wish_speed - current_speed
	if add_speed <= 0.0:
		return
	var accel_speed := minf(_controller.config.ground_accel * delta * wish_speed, add_speed)
	_controller.set_velocity(velocity + wish_dir * accel_speed)
