class_name MapMetadata
extends Resource

## Per-map descriptor (Gameplay Systems §10.1). Attached to a map's root node
## as node metadata under the key "map_metadata".

@export var map_id: String = ""
@export var display_name: String = ""
@export var author: String = ""
@export var difficulty: int = 1  # 1-5 stars
@export var tags: PackedStringArray = []
@export var movement_config_path: String = "res://resources/movement/default.tres"
@export var thumbnail_path: String = ""
