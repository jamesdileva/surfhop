class_name Jump
extends MovementModule

## Jump impulse with coyote time (Gameplay Systems §2.3, §2.4). Landing on
## any floor refreshes the coyote window; leaving the ground starts a countdown
## during which jumping still works. No double jump.

var coyote_timer: float = 0.0


func enabled_in_state(state: int) -> bool:
	# Runs in every state: the coyote timer must tick down while airborne.
	return true


func process(input: InputState, delta: float) -> void:
	# Jumping requires REAL ground only (CS2-style: ramps are ridden, never
	# jumped from — the ramp exit launches you). Surf/wall contact must not
	# refresh coyote: doing so lets held-jump re-fire every tick against any
	# steep surface, turning walls into ladders and hopping riders straight
	# off ramps instead of gliding.
	var grounded := _controller.is_on_floor()
	if grounded:
		coyote_timer = _controller.config.coyote_time_ms / 1000.0
	else:
		coyote_timer = maxf(0.0, coyote_timer - delta)

	# Auto-bhop: holding jump re-hops on every landing (config-driven).
	var wants_jump := input.jump_just_pressed \
		or (_controller.config.auto_bhop and input.jump_held)
	if wants_jump and coyote_timer > 0.0:
		apply_jump_impulse()
		coyote_timer = 0.0


func apply_jump_impulse() -> void:
	# Horizontal momentum is fully preserved; only the vertical component is
	# replaced by the jump impulse (ground jumps only — see process()).
	var velocity := _controller.get_velocity()
	velocity.y = _controller.config.jump_impulse
	_controller.set_velocity(velocity)
	var bus := _controller.get_tree().root.get_node_or_null("SignalBus")
	if bus != null:
		bus.player_jumped.emit({"velocity": velocity, "position": _controller.get_body().global_position})
