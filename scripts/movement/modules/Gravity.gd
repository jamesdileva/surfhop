class_name Gravity
extends MovementModule

## Constant downward acceleration clamped to terminal velocity
## (Gameplay Systems §1.5).

func process(input: InputState, delta: float) -> void:
	apply_gravity(delta)


func apply_gravity(delta: float) -> void:
	var velocity := _controller.get_velocity()
	velocity.y -= _controller.config.gravity * delta
	velocity.y = maxf(velocity.y, -_controller.config.max_fall_speed)
	_controller.set_velocity(velocity)
