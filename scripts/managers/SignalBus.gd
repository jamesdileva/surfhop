extends Node

## Global event dispatch. Routes signals between systems; owns no domain logic.

signal race_started(data: Dictionary)
signal race_finished(data: Dictionary)
signal checkpoint_reached(data: Dictionary)
signal player_landed(data: Dictionary)
signal player_jumped(data: Dictionary)
signal settings_changed(key: String, value: Variant)
signal velocity_updated(speed: float)  # horizontal speed, emitted each physics tick
signal footstep(speed: float)          # grounded stride, emitted by MovementController
signal surf_entered(data: Dictionary)  # player landed on / started a ramp wall
signal surf_exited()                   # player left ramp contact
