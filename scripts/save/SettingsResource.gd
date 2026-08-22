class_name SettingsResource
extends Resource

## Typed settings schema with defaults (Master Architecture §14, Gameplay
## Systems §14.2). SaveManager persists these to user://save/settings.cfg as
## sectioned key/value pairs; this class is the canonical field list.

# [input]
@export var mouse_sensitivity_x: float = 1.0
@export var mouse_sensitivity_y: float = 1.0
@export var invert_mouse_y: bool = false

# [audio]
@export var master_volume: float = 0.8
@export var music_volume: float = 0.6
@export var sfx_volume: float = 0.9

# [graphics]
@export var fullscreen: bool = true
@export var vsync: bool = true
@export var fps_cap: int = 0

# [movement]
@export var tick_rate: int = 100
@export var show_debug: bool = false


## Builds a typed instance from SaveManager's "section/key" dictionary.
static func from_dict(data: Dictionary) -> SettingsResource:
	var s := SettingsResource.new()
	s.mouse_sensitivity_x = data.get("input/mouse_sensitivity_x", 1.0)
	s.mouse_sensitivity_y = data.get("input/mouse_sensitivity_y", 1.0)
	s.invert_mouse_y = data.get("input/invert_mouse_y", false)
	s.master_volume = data.get("audio/master_volume", 0.8)
	s.music_volume = data.get("audio/music_volume", 0.6)
	s.sfx_volume = data.get("audio/sfx_volume", 0.9)
	s.fullscreen = data.get("graphics/fullscreen", true)
	s.vsync = data.get("graphics/vsync", true)
	s.fps_cap = data.get("graphics/fps_cap", 0)
	s.tick_rate = data.get("movement/tick_rate", 100)
	s.show_debug = data.get("movement/show_debug", false)
	return s


## Converts back to SaveManager's "section/key" dictionary form.
func to_dict() -> Dictionary:
	return {
		"input/mouse_sensitivity_x": mouse_sensitivity_x,
		"input/mouse_sensitivity_y": mouse_sensitivity_y,
		"input/invert_mouse_y": invert_mouse_y,
		"audio/master_volume": master_volume,
		"audio/music_volume": music_volume,
		"audio/sfx_volume": sfx_volume,
		"graphics/fullscreen": fullscreen,
		"graphics/vsync": vsync,
		"graphics/fps_cap": fps_cap,
		"movement/tick_rate": tick_rate,
		"movement/show_debug": show_debug,
	}
