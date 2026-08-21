extends Node

## Global event dispatch. Routes signals between systems; owns no domain logic.

signal race_started(data: Dictionary)
signal race_finished(data: Dictionary)
signal checkpoint_reached(data: Dictionary)
signal player_landed(data: Dictionary)
signal player_jumped(data: Dictionary)
signal settings_changed(key: String, value: Variant)
