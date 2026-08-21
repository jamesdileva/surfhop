extends Node

## Game state machine: race lifecycle, pause, restart.

enum RaceState { IDLE, RUNNING, FINISHED, PAUSED }

var race_state: RaceState = RaceState.IDLE
var race_time: float = 0.0


func start_race() -> void:
	race_state = RaceState.RUNNING
	race_time = 0.0


func finish_race() -> void:
	if race_state == RaceState.RUNNING:
		race_state = RaceState.FINISHED


func restart() -> void:
	pass # Stub: implemented in Sprint 13 (Timer System).
