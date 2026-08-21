class_name InputState
extends RefCounted

## Per-tick input snapshot consumed by the MovementController.
## Produced by InputManager.get_state(); one instance per read.

var forward: float = 0.0    # -1 to 1 (S to W)
var right: float = 0.0      # -1 to 1 (A to D)
var jump_just_pressed: bool = false
var jump_held: bool = false
var crouch_held: bool = false
var sprint_held: bool = false
var mouse_delta: Vector2 = Vector2.ZERO
