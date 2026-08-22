class_name MovementModule
extends Resource

## Base class for all movement modules (architecture §9.4). The controller
## calls init() once at setup and process() every tick when
## enabled_in_state() matches the current movement state.

var _controller: MovementController


func init(controller: MovementController) -> void:
	_controller = controller


func enabled_in_state(state: int) -> bool:
	return true


func process(input: InputState, delta: float) -> void:
	pass


## Optional post-move callback: the player just left the ground.
func on_takeoff(velocity: Vector3) -> void:
	pass


## Optional post-move callback: the player just touched down.
func on_land(velocity: Vector3, fall_speed: float) -> void:
	pass
