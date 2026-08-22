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


## Horizontal wish direction from WASD input relative to the camera's yaw
## (Gameplay Systems §1.6). Returns ZERO when no movement keys are held.
func compute_wish_dir(camera: Camera3D) -> Vector3:
	var cam_forward := -camera.basis.z
	var cam_right := camera.basis.x
	cam_forward.y = 0.0
	cam_right.y = 0.0
	cam_forward = cam_forward.normalized()
	cam_right = cam_right.normalized()
	var wish_dir := cam_forward * forward + cam_right * right
	if wish_dir.length() < 0.01:
		return Vector3.ZERO
	return wish_dir.normalized()
