extends Node3D

## Development bootstrap scene: wires timer/HUD/ghost systems, loads a map,
## and spawns the player at its RespawnPoint. Dev-only convenience until the
## real menu flow exists. Choose the map via the exported path or:
##   godot --path . -- --map=beginner
## where the value is a map id under res://scenes/maps/.

@export_file("*.tscn") var default_map := "res://scenes/maps/tutorial.tscn"

var _player: Player = null


func _ready() -> void:
	var hud_instance := (load("res://scenes/ui/HUD.tscn") as PackedScene).instantiate()
	add_child(hud_instance)
	# Dev scenes always show the debug line (state/speed/slope limit) so
	# playtest feedback can include it. Not persisted to settings.
	if hud_instance.has_method("set_debug_visible"):
		hud_instance.set_debug_visible(true)
	var ts := TimerSystem.new()
	ts.name = "TimerSystem"
	add_child(ts)
	var recorder := GhostRecorder.new()
	recorder.name = "GhostRecorder"
	add_child(recorder)
	var ghost := GhostPlayer.new()
	ghost.name = "GhostPlayer"
	add_child(ghost)

	var map_path := _resolve_map_path()
	get_node("/root/LevelLoader").map_loaded.connect(_on_map_loaded)
	get_node("/root/LevelLoader").load_map(map_path)


func _resolve_map_path() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--map="):
			return "res://scenes/maps/%s.tscn" % arg.substr(6)
	return default_map


func _on_map_loaded(map_node: Node) -> void:
	if _player != null or not is_inside_tree():
		return
	var spawn := map_node.get_node_or_null("RespawnPoint")
	var pos: Vector3 = Vector3(0.0, 60.0, 0.0)
	if spawn != null:
		pos = spawn.global_position + Vector3(0.0, 20.0, 0.0)
	_player = (load("res://scenes/player/Player.tscn") as PackedScene).instantiate()
	add_child(_player)  # parented here so freeing the dev scene frees everything
	_player.global_position = pos

	var ghost: GhostPlayer = get_node("GhostPlayer")
	var game_manager := get_node("/root/GameManager")
	if ghost != null and game_manager != null:
		ghost.load_replay(game_manager.map_name)
