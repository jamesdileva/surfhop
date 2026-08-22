extends Node

## Fixed-tick heartbeat. Movement runs in _physics_process at the project's
## physics FPS (100 Hz); this signal is for systems needing tick notifications.

signal tick(delta: float)

const TICK_RATE := 100


func _ready() -> void:
	# NOTE: docs say "physics/common/physics_fps", but the real Godot 4 setting
	# is physics/common/physics_ticks_per_second.
	var fps: int = ProjectSettings.get_setting("physics/common/physics_ticks_per_second", TICK_RATE)
	if fps != TICK_RATE:
		push_warning("TickManager: physics tick rate is %d, expected %d" % [fps, TICK_RATE])


func _physics_process(delta: float) -> void:
	tick.emit(delta)
