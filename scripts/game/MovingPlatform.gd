class_name MovingPlatform
extends AnimatableBody3D

## Oscillating platform/wall for challenge maps. Moves along move_axis with
## sinusoidal motion; sync_to_physics keeps collisions stable while moving.

@export var move_axis := Vector3.RIGHT
@export var amplitude := 200.0
@export var period_seconds := 4.0

var _origin: Vector3
var _time := 0.0


func _ready() -> void:
	_origin = position
	sync_to_physics = true


func _physics_process(delta: float) -> void:
	_time += delta
	var offset := sin(_time * TAU / period_seconds) * amplitude
	position = _origin + move_axis.normalized() * offset
