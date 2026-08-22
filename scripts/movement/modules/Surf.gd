class_name Surf
extends MovementModule

## Surfing: ramp detection, velocity projection onto the ramp plane,
## anti-stuck measures and ramp-exit handling (Gameplay Systems §4, §5).
## Surf ramps are WALL contacts (steeper than floor_max_angle); gravity
## pressing into the wall each tick maintains contact while this module
## projects velocity onto the ramp plane and applies low surf friction.

var _last_ramp_normal: Vector3 = Vector3.ZERO


func enabled_in_state(state: int) -> bool:
	return state == MovementState.SURF


## A surface is a surf ramp when its angle from horizontal exceeds the
## configured minimum (§4.2): normal.dot(UP) < cos(surf_angle_min_deg).
func is_surf_normal(normal: Vector3) -> bool:
	return normal.dot(Vector3.UP) < cos(deg_to_rad(_controller.config.surf_angle_min_deg))


func process(input: InputState, delta: float) -> void:
	var normal := _controller.get_surface_normal()
	if normal == Vector3.ZERO:
		return
	var velocity := process_surf(_controller.get_velocity(), normal, delta)
	velocity = anti_stuck(velocity, normal, delta)
	_controller.set_velocity(velocity)
	_last_ramp_normal = normal


## Projects velocity onto the ramp plane and applies low surf friction (§4.3).
func process_surf(velocity_in: Vector3, normal: Vector3, delta: float) -> Vector3:
	var proj_speed := velocity_in.dot(normal)
	var velocity_out := velocity_in - normal * proj_speed

	var h_speed := Vector2(velocity_out.x, velocity_out.z).length()
	if h_speed > 0.001:
		var drop := minf(h_speed * _controller.config.surf_friction * delta, h_speed)
		velocity_out.x *= 1.0 - drop / h_speed
		velocity_out.z *= 1.0 - drop / h_speed

	return velocity_out


## Pushes the player off the ramp if horizontal speed falls too low (§4.6).
## Applied as an acceleration (scaled by delta) so that on moderate ramps
## gravity's inward pull wins and contact is maintained, while on very steep
## ramps (>~65 deg) a slow player still peels off instead of clinging.
func anti_stuck(velocity: Vector3, normal: Vector3, delta: float) -> Vector3:
	var h_speed := Vector2(velocity.x, velocity.z).length()
	if h_speed < _controller.config.surf_min_speed:
		velocity += normal * _controller.config.surf_push * delta
	return velocity


## Edge handling on leaving a ramp (§5.3): a small push in the ramp's
## "down-fling" direction keeps exits clean.
func on_takeoff(velocity: Vector3) -> void:
	if _last_ramp_normal == Vector3.ZERO:
		return
	var ramp_down := Vector3.DOWN - _last_ramp_normal
	_controller.set_velocity(velocity + ramp_down * _controller.config.surf_exit_boost)
	_last_ramp_normal = Vector3.ZERO
