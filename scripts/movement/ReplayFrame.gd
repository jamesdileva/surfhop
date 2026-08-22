class_name ReplayFrame
extends Resource

## One recorded physics tick of a ghost run (Gameplay Systems §7.2).
## Input capture is intentionally omitted in MVP (needed only for
## input-broadcast replay/netcode); playback is state-driven.

@export var tick: int = 0
@export var position: Vector3 = Vector3.ZERO
@export var velocity: Vector3 = Vector3.ZERO
@export var rotation: Vector3 = Vector3.ZERO  # body yaw only (pitch lives on the camera)
@export var movement_state: int = 0
