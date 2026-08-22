extends Node

## Settings persistence, PB storage and ghost files (architecture §14).
## Settings live in user://save/settings.cfg, PBs in user://save/records.tres
## (RecordsResource), ghosts in user://ghosts/{map}_pb.tres. First run creates
## default settings.

const SETTINGS_PATH := "user://save/settings.cfg"
const RECORDS_PATH := "user://save/records.tres"
const GHOSTS_DIR := "user://ghosts"

const DEFAULT_SETTINGS := {
	"input/mouse_sensitivity_x": 1.0,
	"input/mouse_sensitivity_y": 1.0,
	"input/invert_mouse_y": false,
	"audio/master_volume": 0.8,
	"audio/music_volume": 0.6,
	"audio/sfx_volume": 0.9,
	"graphics/fullscreen": true,
	"graphics/vsync": true,
	"graphics/fps_cap": 0,
	"movement/tick_rate": 100,
	"movement/show_debug": false,
}

var _settings: Dictionary = {}
var _records: RecordsResource = RecordsResource.new()


func _ready() -> void:
	if not FileAccess.file_exists(SETTINGS_PATH):
		_settings = DEFAULT_SETTINGS.duplicate(true)
		save_settings()  # first run: create defaults on disk
	else:
		_settings = load_settings()
	load_records()


# ---------------------------------------------------------------- settings --

func load_settings() -> Dictionary:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return DEFAULT_SETTINGS.duplicate(true)
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		push_warning("SaveManager: failed to read %s, using defaults" % SETTINGS_PATH)
		return DEFAULT_SETTINGS.duplicate(true)
	var loaded: Dictionary = DEFAULT_SETTINGS.duplicate(true)
	for key: String in DEFAULT_SETTINGS:
		var section_and_key := key.split("/", false, 1)
		loaded[key] = cfg.get_value(section_and_key[0], section_and_key[1], DEFAULT_SETTINGS[key])
	return loaded


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key: String in _settings:
		var section_and_key := key.split("/", false, 1)
		cfg.set_value(section_and_key[0], section_and_key[1], _settings[key])
	DirAccess.make_dir_recursive_absolute(SETTINGS_PATH.get_base_dir())
	if cfg.save(SETTINGS_PATH) != OK:
		push_error("SaveManager: failed to write %s" % SETTINGS_PATH)


func get_setting(key: String) -> Variant:
	return _settings.get(key, DEFAULT_SETTINGS.get(key))


func set_setting(key: String, value: Variant) -> void:
	_settings[key] = value


## Typed view of the current settings (SettingsResource schema).
func get_settings_resource() -> SettingsResource:
	return SettingsResource.from_dict(_settings)


# ------------------------------------------------------------- records/PBs --

func load_records() -> void:
	if not FileAccess.file_exists(RECORDS_PATH):
		return
	var loaded := ResourceLoader.load(RECORDS_PATH) as RecordsResource
	if loaded == null:
		return
	# Defensive: drop entries saved by older/broken formats (not MapRecord).
	for key: String in loaded.records.keys():
		if not (loaded.records[key] is MapRecord):
			loaded.records.erase(key)
	_records = loaded


func persist_records() -> void:
	DirAccess.make_dir_recursive_absolute(RECORDS_PATH.get_base_dir())
	if ResourceSaver.save(_records, RECORDS_PATH) != OK:
		push_error("SaveManager: failed to write %s" % RECORDS_PATH)


func get_pb(map_name: String) -> float:
	var record: MapRecord = _records.records.get(map_name)
	return record.pb_time if record != null else INF


## Records a completion. Updates the PB only when faster (§8.2); other stats
## accumulate regardless. Pass -1 for unknown speed/jumps.
func save_pb(map_name: String, time: float, best_speed: float = -1.0,
		jumps: int = -1) -> void:
	var record: MapRecord = _records.records.get_or_add(
		map_name, MapRecord.new())
	record.map_name = map_name
	record.completion_count += 1
	if best_speed >= 0.0:
		record.best_speed = maxf(record.best_speed, best_speed)
	if jumps >= 0:
		record.jumps += jumps
	if time < record.pb_time:
		record.pb_time = time
		record.pb_date = int(Time.get_unix_time_from_system())
	persist_records()


# ------------------------------------------------------------------ ghosts --

func ghost_path(map_name: String) -> String:
	return "%s/%s_pb.tres" % [GHOSTS_DIR, map_name]


## Stores a replay payload (GhostRecorder's resource; format owned by §7/§12).
func save_ghost(map_name: String, replay: Resource) -> bool:
	DirAccess.make_dir_recursive_absolute(GHOSTS_DIR)
	if ResourceSaver.save(replay, ghost_path(map_name)) != OK:
		push_error("SaveManager: failed to save ghost for '%s'" % map_name)
		return false
	return true


func load_ghost(map_name: String) -> Resource:
	var path := ghost_path(map_name)
	if not FileAccess.file_exists(path):
		return null
	return ResourceLoader.load(path)


func has_ghost(map_name: String) -> bool:
	return FileAccess.file_exists(ghost_path(map_name))
