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
@export var kill_plane_y: float = -1000.0  # falling below this respawns at last checkpoint
## Optional surface tint override (architecture §16 aesthetic). When left
## WHITE, WorldMaterials falls back to the per-difficulty palette.
@export var vertex_color_tint: Color = Color.WHITE
