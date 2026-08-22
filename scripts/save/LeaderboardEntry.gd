class_name LeaderboardEntry
extends Resource

## Single leaderboard row (Gameplay Systems §9.1). Local MVP stores entries
## via SaveManager; Steam submission arrives in Sprint 28.

@export var player_name: String = ""
@export var time: float = 0.0
@export var date: int = 0            # unix time of the run
@export var replay_path: String = "" # ghost replay associated with this time
@export var rank: int = 0
