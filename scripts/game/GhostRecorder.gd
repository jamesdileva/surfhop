class_name GhostRecorder
extends Node

## Records the player's run frame-by-frame while a race is running and saves
## it as the PB ghost when a personal best is achieved (Gameplay Systems §7.3).
## Add one instance per map / main scene; driven entirely by SignalBus events.

var is_recording: bool = false
var frames: Array[ReplayFrame] = []

var _tick := 0


func _ready() -> void:
	var bus := get_node_or_null("/root/SignalBus")
	if bus != null:
		bus.race_started.connect(start_recording)
		bus.race_finished.connect(_on_race_finished)


func _exit_tree() -> void:
	var bus := get_node_or_null("/root/SignalBus")
	if bus != null and bus.race_started.is_connected(start_recording):
		bus.race_started.disconnect(start_recording)
	if bus != null and bus.race_finished.is_connected(_on_race_finished):
		bus.race_finished.disconnect(_on_race_finished)


func start_recording(_data: Dictionary = {}) -> void:
	frames.clear()
	_tick = 0
	is_recording = true


func stop_recording() -> void:
	is_recording = false


func record_frame(tick: int, player: Player) -> void:
	var frame := ReplayFrame.new()
	frame.tick = tick
	frame.position = player.global_position
	frame.velocity = player.velocity
	frame.rotation = player.rotation
	frame.movement_state = player.movement_controller.state if \
		player.movement_controller != null else MovementState.AIR
	frames.append(frame)


func build_replay(map_id: String, finish_time: float) -> GhostReplay:
	var replay := GhostReplay.new()
	replay.map_id = map_id
	replay.finish_time = finish_time
	replay.frames = frames.duplicate()
	return replay


func _physics_process(_delta: float) -> void:
	if not is_recording:
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null or player.movement_controller == null:
		return
	record_frame(_tick, player)
	_tick += 1


func _on_race_finished(payload: Dictionary) -> void:
	stop_recording()
	if not bool(payload.get("is_pb", false)) or frames.is_empty():
		return
	var game_manager := get_node_or_null("/root/GameManager")
	var save_manager := get_node_or_null("/root/SaveManager")
	if game_manager == null or save_manager == null:
		return
	save_manager.save_ghost(game_manager.map_name,
		build_replay(game_manager.map_name, payload["time"]))
