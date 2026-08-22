class_name Collision
extends MovementModule

## Ground detection wrapper around the CharacterBody3D (architecture §9.2).
## The controller polls this module to determine the movement state; modules
## query it instead of touching the body directly.

func process(input: InputState, delta: float) -> void:
	pass # State is derived by the controller polling the queries below.


func on_floor() -> bool:
	return _controller.get_body().is_on_floor()


func floor_normal() -> Vector3:
	return _controller.get_body().get_floor_normal()


## Slope angle in degrees between the floor normal and straight up.
func slope_angle() -> float:
	return rad_to_deg(floor_normal().angle_to(Vector3.UP))
