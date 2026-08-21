extends Node

## Fixed-tick heartbeat. Movement runs in _physics_process at the project's
## physics FPS (100 Hz); this signal is for systems needing tick notifications.

signal tick(delta: float)

const TICK_RATE := 100


func _ready() -> void:
	var fps: int = ProjectSettings.get_setting("physics/common/physics_fps", TICK_RATE)
	if fps != TICK_RATE:
		push_warning("TickManager: physics_fps is %d, expected %d" % [fps, TICK_RATE])


func _physics_process(delta: float) -> void:
	tick.emit(delta)
