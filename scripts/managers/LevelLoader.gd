extends Node

## Async map loading, unloading and discovery (architecture §7.8, Gameplay
## Systems §10). Maps are .tscn scenes in res://scenes/maps/ whose root node
## carries a MapMetadata resource as node metadata ("map_metadata").

signal map_loaded(map_node: Node)

const MAPS_DIR := "res://scenes/maps"
const METADATA_KEY := "map_metadata"

var current_map: Node = null
var current_metadata: MapMetadata = null

var _pending_path: String = ""
var _container: Node3D


func _ready() -> void:
	_container = Node3D.new()
	_container.name = "CurrentMapContainer"


## Scans the maps directory; returns entries for every scene carrying
## MapMetadata. Each entry: {"path": String, "metadata": MapMetadata}.
func discover_maps() -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var dir := DirAccess.open(MAPS_DIR)
	if dir == null:
		return results
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if not dir.current_is_dir() and file.ends_with(".tscn"):
			var path := MAPS_DIR + "/" + file
			var metadata := get_map_metadata(path)
			if metadata != null:
				results.append({"path": path, "metadata": metadata})
		file = dir.get_next()
	dir.list_dir_end()
	return results


## Reads a map scene's MapMetadata without keeping the instance alive.
func get_map_metadata(path: String) -> MapMetadata:
	var packed := load(path) as PackedScene
	if packed == null:
		return null
	var instance := packed.instantiate()
	var metadata := instance.get_meta(METADATA_KEY) as MapMetadata \
		if instance.has_meta(METADATA_KEY) else null
	instance.free()
	return metadata


## Starts an async (threaded) load; completion is polled in _process so no
## single frame hitches. Frees any previously loaded map first.
func load_map(path: String) -> void:
	unload_current()
	ResourceLoader.load_threaded_request(path)
	_pending_path = path


func unload_current() -> void:
	if current_map != null and is_instance_valid(current_map):
		current_map.queue_free()
	current_map = null
	current_metadata = null


func _process(_delta: float) -> void:
	if _pending_path == "":
		return
	var status := ResourceLoader.load_threaded_get_status(_pending_path)
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			var packed: PackedScene = ResourceLoader.load_threaded_get(_pending_path)
			_finalize_load(packed.instantiate())
			_pending_path = ""
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("LevelLoader: failed to load map '%s'" % _pending_path)
			_pending_path = ""


func _finalize_load(map: Node) -> void:
	if _container.get_parent() == null:
		get_tree().root.add_child(_container)
	_container.add_child(map)
	current_map = map
	current_metadata = map.get_meta(METADATA_KEY) as MapMetadata \
		if map.has_meta(METADATA_KEY) else null
	_apply_movement_config()
	var game_manager := get_node_or_null("/root/GameManager")
	if game_manager != null and current_metadata != null:
		game_manager.map_name = current_metadata.map_id
	map_loaded.emit(map)


## Applies the loaded map's MovementConfig to the player (sprint acceptance).
func _apply_movement_config() -> void:
	if current_metadata == null or current_metadata.movement_config_path == "":
		return
	var player := get_tree().get_first_node_in_group("player")
	if player == null or player.movement_controller == null:
		return
	player.movement_controller.config = load(current_metadata.movement_config_path)
