class_name BunnyHop
extends MovementModule

## Jump buffering and friction skip on landing (Gameplay Systems §2.1-2.2).
## A jump pressed while airborne arms a buffer; if the player lands while the
## buffer is active, friction is reduced and the jump fires automatically,
## preserving horizontal momentum.

var jump_buffer_timer: float = 0.0
var total_jumps: int = 0
## Whether jump is currently held (sampled every tick). Lets the landing
## handler extend the friction skip to held-hop landings (audit M4).
var _jump_held := false


func enabled_in_state(state: int) -> bool:
	# The buffer must tick down in every state.
	return true


func process(input: InputState, delta: float) -> void:
	if input.jump_just_pressed:
		jump_buffer_timer = _controller.config.jump_buffer_ms / 1000.0
	jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)
	_jump_held = input.jump_held


## Called by the controller's generic post-move dispatch when a landing
## transition is detected (§2.5 flow). fall_speed is the vertical speed the
## player arrived with. Only REAL floor landings auto-fire: surf-wall
## touchdowns must keep sliding (CS2-style; jumping off a ramp is manual).
func on_land(velocity: Vector3, fall_speed: float) -> void:
	var bus := _controller.get_tree().root.get_node_or_null("SignalBus")

	if jump_buffer_timer > 0.0 and _controller.is_on_floor():
		_controller.friction_override = _controller.config.friction_override_factor
		_controller.apply_jump_impulse()
		jump_buffer_timer = 0.0
		total_jumps += 1
	elif _controller.config.auto_bhop and _jump_held and _controller.is_on_floor():
		# Hold path (audit M4, CS2 sv_autobunnyhopping parity): the hop
		# itself fires next tick from Jump (grounded + held), but Friction
		# runs first that tick — without this skip, holders pay one full
		# ground-friction tick (~19 u/s at 320) per landing that press
		# players never pay. Same skip, same momentum.
		_controller.friction_override = _controller.config.friction_override_factor

	if bus != null:
		bus.player_landed.emit({
			"velocity": velocity,
			"fall_speed": fall_speed,
			"position": _controller.get_body().global_position,
		})
