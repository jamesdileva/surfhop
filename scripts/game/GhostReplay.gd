class_name GhostReplay
extends Resource

## Persisted ghost replay container (Gameplay Systems §7, §12). Saved via
## SaveManager to user://ghosts/{map}_pb.tres when a PB is achieved.

const FORMAT_VERSION := 1

@export var version: int = FORMAT_VERSION
@export var map_id: String = ""
@export var finish_time: float = 0.0
@export var frames: Array[ReplayFrame] = []
