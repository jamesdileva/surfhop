class_name MapRecord
extends Resource

## Per-map record entry (architecture §14.3), stored inside RecordsResource.

@export var map_name: String = ""
@export var pb_time: float = INF   # INF = no completion yet
@export var pb_date: int = 0       # unix time the PB was set
@export var best_speed: float = 0.0
@export var jumps: int = 0         # lifetime jump count for stats
@export var completion_count: int = 0
