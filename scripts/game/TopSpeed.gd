class_name TopSpeed
extends Node

## Endless-mode score tracker (Phase 7 E1): on maps whose metadata is tagged
## "endless", tracks the current-session peak speed and persists the all-time
## top per map (MapRecord.best_speed via SaveManager). Dormant everywhere else.

const ANNOUNCE_MARGIN := 25.0  # u/s above the all-time top before re-announcing

var endless_active := false
var session_top := 0.0
var all_time_top := 0.0

var _last_announced := 0.0


func _ready() -> void:
	var bus := get_node_or_null("/root/SignalBus")
	if bus == null:
		return
	bus.velocity_updated.connect(_on_velocity_updated)
	var loader := get_node_or_null("/root/LevelLoader")
	if loader != null:
		loader.map_loaded.connect(_on_map_loaded)


func _on_map_loaded(_map_node: Node) -> void:
	session_top = 0.0
	_last_announced = 0.0
	endless_active = false
	all_time_top = 0.0
	var loader := get_node_or_null("/root/LevelLoader")
	var game_manager := get_node_or_null("/root/GameManager")
	if loader == null or game_manager == null:
		return
	var metadata: MapMetadata = loader.current_metadata
	endless_active = metadata != null and metadata.tags.has("endless")
	if endless_active:
		all_time_top = float(
			get_node("/root/SaveManager").get_top_speed(game_manager.map_name))


func _on_velocity_updated(speed: float) -> void:
	if not endless_active:
		return
	if speed > session_top:
		session_top = speed
	if speed > all_time_top:
		var save_manager := get_node("/root/SaveManager")
		save_manager.record_top_speed(
			get_node("/root/GameManager").map_name, speed)
		all_time_top = speed
		if speed - _last_announced >= ANNOUNCE_MARGIN or _last_announced == 0.0:
			_last_announced = speed
			get_node("/root/SignalBus").top_speed_beaten.emit(speed)
