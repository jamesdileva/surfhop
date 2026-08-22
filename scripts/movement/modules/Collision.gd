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


## Returns the first post-slide contact normal steeper than the walkable
## limit (a surf ramp / wall), or ZERO when no such contact exists.
## Ceilings (normals pointing downward) are ignored.
func steep_normal() -> Vector3:
	var body := _controller.get_body()
	var limit: float = cos(deg_to_rad(_controller.config.surf_angle_min_deg))
	for i in body.get_slide_collision_count():
		var n := body.get_slide_collision(i).get_normal()
		if n.dot(Vector3.UP) >= 0.0 and n.dot(Vector3.UP) < limit:
			return n
	return Vector3.ZERO
