class_name Friction
extends MovementModule

## Ground friction with stop_speed behavior (Gameplay Systems §1.3, Quake
## PM_Friction). The override parameter is used by the BunnyHop module
## (Sprint 8) to reduce friction on buffered landing jumps.

func enabled_in_state(state: int) -> bool:
	return state == MovementState.GROUND


func process(input: InputState, delta: float) -> void:
	apply_friction(delta)


func apply_friction(delta: float, override: float = 1.0) -> void:
	var velocity := _controller.get_velocity()
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.001:
		velocity.x = 0.0
		velocity.z = 0.0
		_controller.set_velocity(velocity)
		return

	var friction: float = _controller.config.ground_friction * _controller.friction_override * override
	var control: float = maxf(speed, _controller.config.stop_speed)
	var drop: float = minf(control * friction * delta, speed)

	var new_speed := maxf(0.0, speed - drop)
	velocity.x *= new_speed / speed
	velocity.z *= new_speed / speed
	_controller.set_velocity(velocity)
