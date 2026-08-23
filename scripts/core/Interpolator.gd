class_name Interpolator
extends Node

## Render-smoothing owner for the Player (architecture §8, Sprint 27). Smooth
## visuals between 100Hz physics ticks come from Godot's built-in 3D physics
## interpolation (project setting physics/common/physics_interpolation=true),
## which the engine applies to every Node3D moved during _physics_process.
##
## This node owns the one thing built-in interpolation cannot know: position
## writes that are NOT motion. Checkpoint respawns and test teleports jump
## hundreds of units in a single tick; without intervention the engine would
## smoothly glide the view across the map. Any jump beyond TELEPORT_DISTANCE
## resets interpolation so the body snaps instantly.

const TELEPORT_DISTANCE := 100.0  # u/tick; legit motion peaks ~10u at terminal velocity

var _body: Node3D
var _last_position := Vector3.INF


func _ready() -> void:
	_body = get_parent() as Node3D


func _physics_process(_delta: float) -> void:
	if _body == null:
		return
	var pos := _body.global_position
	if _last_position != Vector3.INF \
			and pos.distance_to(_last_position) > TELEPORT_DISTANCE:
		_body.reset_physics_interpolation()
	_last_position = pos


## Manual reset hook for code that teleports the player deliberately.
func notify_teleported() -> void:
	if _body != null:
		_body.reset_physics_interpolation()
	_last_position = _body.global_position if _body != null else Vector3.INF
