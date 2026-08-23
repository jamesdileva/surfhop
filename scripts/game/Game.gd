class_name Game
extends Node3D

## Boot / session scene (Phase 6 P1): the project's main_scene. Shows the main
## menu on launch; when a map is selected it wires the in-game systems
## (HUD, timer, ghost recording/playback), loads the map and spawns the
## player — the same assembly DevMain performs for dev bootstrap scenes.

const PLAYER_SCENE := preload("res://scenes/player/Player.tscn")
const HUD_SCENE := preload("res://scenes/ui/HUD.tscn")

var _player: Player = null


func _ready() -> void:
	var ui_manager: Node = get_node("/root/UIManager")
	ui_manager.register_game(self)
	ui_manager.show_menu("main")


func _exit_tree() -> void:
	var ui_manager := get_node_or_null("/root/UIManager")
	if ui_manager != null and ui_manager.get_game() == self:
		ui_manager.session_active = false
		ui_manager.register_game(null)


## Starts a map from the menu flow. Safe to call repeatedly: systems are
## created once, and an already-spawned player is reused for the next map.
func start_map(map_path: String) -> void:
	var ui_manager: Node = get_node("/root/UIManager")
	ui_manager.session_active = true
	_ensure_systems()
	var loader: Node = get_node("/root/LevelLoader")
	if not loader.map_loaded.is_connected(_on_map_loaded):
		loader.map_loaded.connect(_on_map_loaded)
	loader.load_map(map_path)


## Tears the session down and returns to the main menu.
func return_to_menu() -> void:
	var ui_manager: Node = get_node("/root/UIManager")
	ui_manager.session_active = false
	get_node("/root/GameManager").restart()
	get_node("/root/LevelLoader").unload_current()
	for child in get_children():
		child.queue_free()
	_player = null
	ui_manager.dismiss_menus()
	ui_manager.show_menu("main")


func _ensure_systems() -> void:
	if get_node_or_null("HUD") == null:
		var hud := HUD_SCENE.instantiate()
		hud.name = "HUD"
		add_child(hud)
	for system_name: String in ["TimerSystem", "GhostRecorder", "GhostPlayer"]:
		if get_node_or_null(system_name) == null:
			add_child(_new_system(system_name))


func _new_system(system_name: String) -> Node:
	match system_name:
		"TimerSystem":
			return TimerSystem.new()
		"GhostRecorder":
			return GhostRecorder.new()
		"GhostPlayer":
			return GhostPlayer.new()
	return null


func _on_map_loaded(map_node: Node) -> void:
	if not is_inside_tree():
		return
	var spawn := map_node.get_node_or_null("RespawnPoint")
	var pos := Vector3(0.0, 60.0, 0.0)
	if spawn != null:
		pos = spawn.global_position + Vector3(0.0, 20.0, 0.0)
	if _player == null or not is_instance_valid(_player):
		_player = PLAYER_SCENE.instantiate()
		add_child(_player)
	_player.global_position = pos
	_player.velocity = Vector3.ZERO

	var ghost: GhostPlayer = get_node_or_null("GhostPlayer")
	var game_manager := get_node("/root/GameManager")
	if ghost != null:
		ghost.load_replay(game_manager.map_name)
