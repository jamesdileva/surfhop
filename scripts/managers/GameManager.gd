extends Node

## Game state machine and time-trial timer integration (Gameplay Systems §8).
## Owns the race state machine and wall-clock timing; TimerSystem wires the
## start/finish trigger scenes to this manager.

enum RaceState { IDLE, RUNNING, FINISHED, PAUSED }

var race_state: RaceState = RaceState.IDLE
var race_time: float = 0.0          # duration of the last completed run
var map_name: String = "default"    # set by LevelLoader when a map loads
var checkpoint_splits: Array[float] = []

var _start_time_usec: int = 0
var _finish_time_usec: int = 0
var _paused_at_usec: int = 0


func _bus() -> Node:
	return get_node_or_null("/root/SignalBus")


## Seconds elapsed in the current (or last) race.
func elapsed_seconds() -> float:
	if race_state == RaceState.RUNNING:
		return float(Time.get_ticks_usec() - _start_time_usec) / 1000000.0
	if _finish_time_usec > _start_time_usec:
		return float(_finish_time_usec - _start_time_usec) / 1000000.0
	return 0.0


func start_race() -> void:
	race_state = RaceState.RUNNING
	_start_time_usec = Time.get_ticks_usec()
	_finish_time_usec = 0
	race_time = 0.0
	var bus := _bus()
	if bus != null:
		bus.race_started.emit({"time": 0.0})


func finish_race() -> void:
	if race_state != RaceState.RUNNING:
		return
	_finish_time_usec = Time.get_ticks_usec()
	race_state = RaceState.FINISHED
	race_time = elapsed_seconds()
	var is_pb := check_pb(race_time)
	var bus := _bus()
	if bus != null:
		bus.race_finished.emit({
			"time": race_time,
			"is_pb": is_pb,
			"splits": checkpoint_splits,
		})


## First completion always sets the PB; later completions only if faster (§8.2).
func check_pb(time: float) -> bool:
	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager == null:
		return false
	var pb: float = save_manager.get_pb(map_name)
	if pb == INF or pb == 0.0 or time < pb:
		save_manager.save_pb(map_name, time)
		return true
	return false


func pause() -> void:
	if race_state == RaceState.RUNNING:
		race_state = RaceState.PAUSED
		_paused_at_usec = Time.get_ticks_usec()


## Resuming shifts the start stamp forward so paused time never counts (§13).
func resume() -> void:
	if race_state == RaceState.PAUSED:
		_start_time_usec += Time.get_ticks_usec() - _paused_at_usec
		race_state = RaceState.RUNNING


func restart() -> void:
	race_state = RaceState.IDLE
	_start_time_usec = 0
	_finish_time_usec = 0
	race_time = 0.0
	checkpoint_splits.clear()
