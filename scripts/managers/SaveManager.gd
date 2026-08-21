extends Node

## Settings persistence, PB storage, ghost files. Full implementation in Sprint 17.
## load_settings() returns defaults on first run (no save file present).

const SETTINGS_PATH := "user://save/settings.cfg"
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
var _personal_bests: Dictionary = {}


func _ready() -> void:
	_settings = load_settings()


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


func get_pb(map_name: String) -> float:
	return _personal_bests.get(map_name, INF)


func save_pb(map_name: String, time: float) -> void:
	if time < get_pb(map_name):
		_personal_bests[map_name] = time
