class_name Surf
extends MovementModule

## Surfing: ramp detection, velocity projection onto the ramp plane,
## anti-stuck measures and ramp-exit handling (Gameplay Systems §4, §5).
## Surf ramps are WALL contacts (steeper than floor_max_angle); gravity
## pressing into the wall each tick maintains contact while this module
## projects velocity onto the ramp plane and applies low surf friction.

var _last_ramp_normal: Vector3 = Vector3.ZERO
var _surf_active := false

# Hot-path cache (Sprint 27): cos(floor_max_angle_deg) recomputed only when
# the config instance changes; output is bit-identical to per-call evaluation.
# Single-source threshold (surf-feel fix): floor_max_angle_deg is authoritative
# (matches Collision.steep_normal and the body's move_and_slide limit).
var _cached_config: MovementConfig = null
var _surf_cos_min := 0.0


func enabled_in_state(state: int) -> bool:
	return state == MovementState.SURF


## A surface is a surf ramp when its angle from horizontal exceeds the
## configured walkable limit (§4.2): normal.dot(UP) < cos(floor_max_angle_deg).
## floor_max_angle_deg is the single source of truth (engine agreement); the
## legacy surf_angle_min_deg must be kept equal to it (see MovementConfig).
func is_surf_normal(normal: Vector3) -> bool:
	if _cached_config != _controller.config:
		_cached_config = _controller.config
		_surf_cos_min = cos(deg_to_rad(_controller.config.floor_max_angle_deg))
	return normal.dot(Vector3.UP) < _surf_cos_min


func process(input: InputState, delta: float) -> void:
	var normal := _controller.get_surface_normal()
	if normal == Vector3.ZERO:
		return
	var entering := not _surf_active
	if entering:
		_surf_active = true
		var bus := _controller.get_node_or_null("/root/SignalBus")
		if bus != null:
			bus.surf_entered.emit({
				"normal": normal,
				"position": _controller.get_body().global_position,
			})
	# Gravity has already run this tick (module order), so velocity is never
	# zero on a ramp - the projection below converts it into downhill slide.
	var velocity_in := _controller.get_velocity()
	var velocity := process_surf(velocity_in, normal, delta)
	if entering:
		# Landing-tick preservation (Gameplay Systems §5.2): the engine's
		# move_and_slide wall-slide plus this projection can each clip energy
		# on the entry tick. Floor the horizontal speed at
		# surf_preservation of the pre-projection value so a surf entry
		# keeps momentum CS-style. Gravity conversion that GAINS speed is
		# never clamped (only the loss floor applies).
		velocity = _preserve_entry_speed(velocity_in, velocity)
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


## Entry-tick loss floor: rescale horizontal velocity so surf entries keep at
## least surf_preservation of the pre-projection horizontal speed.
func _preserve_entry_speed(velocity_in: Vector3, velocity_out: Vector3) -> Vector3:
	var h_in := Vector2(velocity_in.x, velocity_in.z).length()
	if h_in < 0.001:
		return velocity_out
	var h_out := Vector2(velocity_out.x, velocity_out.z).length()
	if h_out < 0.001:
		return velocity_out
	var floor_speed := h_in * _controller.config.surf_preservation
	if h_out < floor_speed:
		var scale := floor_speed / h_out
		velocity_out.x *= scale
		velocity_out.z *= scale
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
	if _surf_active:
		_surf_active = false
		var bus := _controller.get_node_or_null("/root/SignalBus")
		if bus != null:
			bus.surf_exited.emit()
	if _last_ramp_normal == Vector3.ZERO:
		return
	var ramp_down := Vector3.DOWN - _last_ramp_normal
	_controller.set_velocity(velocity + ramp_down * _controller.config.surf_exit_boost)
	_last_ramp_normal = Vector3.ZERO
