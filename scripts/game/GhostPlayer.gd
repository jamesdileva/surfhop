class_name GhostPlayer
extends Node3D

## Plays back a saved PB ghost in sync with the live race: one recorded frame
## per physics tick, started by race_started (Gameplay Systems §7.4). The
## translucent GhostModel child makes it visually distinct from the player.

var replay: GhostReplay = null

var _model: Node3D
var _play_tick := -1  # -1 = not playing


func _ready() -> void:
	visible = false  # hidden until a race starts playback
	if _model == null:
		var scene := load("res://scenes/props/GhostModel.tscn") as PackedScene
		_model = scene.instantiate()
		add_child(_model)
	var bus := get_node_or_null("/root/SignalBus")
	if bus != null:
		bus.race_started.connect(_on_race_started)
		bus.race_finished.connect(_on_race_finished)


func _exit_tree() -> void:
	var bus := get_node_or_null("/root/SignalBus")
	if bus != null:
		if bus.race_started.is_connected(_on_race_started):
			bus.race_started.disconnect(_on_race_started)
		if bus.race_finished.is_connected(_on_race_finished):
			bus.race_finished.disconnect(_on_race_finished)


## Loads a replay from SaveManager's ghost path (or any explicit path).
func load_replay(map_name: String) -> bool:
	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager == null:
		return false
	replay = save_manager.load_ghost(map_name) as GhostReplay
	return replay != null and replay.frames.size() > 0


func play() -> void:
	if replay == null or replay.frames.is_empty():
		return
	visible = true
	_play_tick = 0


func stop() -> void:
	_playing_stop()


func _playing_stop() -> void:
	_play_tick = -1
	visible = false


func _on_race_started(_data: Dictionary = {}) -> void:
	play()


func _on_race_finished(_payload: Dictionary) -> void:
	stop()


func _physics_process(_delta: float) -> void:
	if _play_tick < 0 or replay == null:
		return
	if _play_tick >= replay.frames.size():
		_playing_stop()
		return
	var frame := replay.frames[_play_tick]
	global_position = frame.position
	rotation.y = frame.rotation.y
	_play_tick += 1


## Frame index currently being displayed (test/telemetry hook).
func current_frame_index() -> int:
	return _play_tick
