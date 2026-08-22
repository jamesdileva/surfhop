class_name BunnyHop
extends MovementModule

## Jump buffering and friction skip on landing (Gameplay Systems §2.1-2.2).
## A jump pressed while airborne arms a buffer; if the player lands while the
## buffer is active, friction is reduced and the jump fires automatically,
## preserving horizontal momentum.

var jump_buffer_timer: float = 0.0
var total_jumps: int = 0


func enabled_in_state(state: int) -> bool:
	# The buffer must tick down in every state.
	return true


func process(input: InputState, delta: float) -> void:
	if input.jump_just_pressed:
		jump_buffer_timer = _controller.config.jump_buffer_ms / 1000.0
	jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)


## Called by the controller when a landing transition is detected post-move
## (§2.5 flow). fall_speed is the vertical speed the player arrived with.
func on_landing(fall_speed: float) -> void:
	var velocity := _controller.get_velocity()
	var bus := _controller.get_tree().root.get_node_or_null("SignalBus")

	if jump_buffer_timer > 0.0:
		_controller.friction_override = _controller.config.friction_override_factor
		_controller.apply_jump_impulse()
		jump_buffer_timer = 0.0
		total_jumps += 1

	if bus != null:
		bus.player_landed.emit({"velocity": velocity, "fall_speed": fall_speed})
