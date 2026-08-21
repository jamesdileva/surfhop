extends Node

## Translates raw input events into logical actions. Full implementation in Sprint 3.

const MOVEMENT_ACTIONS := ["move_left", "move_right", "move_forward", "move_back"]


func get_movement_input() -> Vector2:
	if not _movement_actions_registered():
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


func is_action_pressed(action: String) -> bool:
	return InputMap.has_action(action) and Input.is_action_pressed(action)


func _movement_actions_registered() -> bool:
	for action: String in MOVEMENT_ACTIONS:
		if not InputMap.has_action(action):
			return false
	return true
