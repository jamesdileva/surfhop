extends Node

## Steam integration facade (architecture §20.7, Sprint 28). The game ships
## with achievements, cloud-save and leaderboard seams that run in LOCAL
## (degraded) mode until release: real activation needs the GodotSteam
## GDExtension plus a paid AppID, so _try_connect_steam() returns false and
## every unlock is tracked/persisted locally instead. Flipping to live Steam
## later means filling in the three marked seams — no call-site changes.

signal achievement_unlocked(achievement_id: String, display_name: String)

const ACHIEVEMENTS_PATH := "user://save/achievements.cfg"
const BHOP_WINDOW_MS := 120  # jump fired this soon after a landing counts as a bhop
const SPEED_TIERS := {"speed_300": 300.0, "speed_600": 600.0}

const ACHIEVEMENTS := {
	"first_jump": "First Jump",
	"first_bhop": "First BHop",
	"first_surf": "First Surf",
	"first_pb": "First PB",
	"speed_300": "Beat 300 u/s",
	"speed_600": "Beat 600 u/s",
}

## True only when GodotSteam + the Steam client are connected. Always false
## until the release-time seams are filled in.
var available: bool = false

## Test/telemetry hook.
var unlock_count := 0

var _unlocked := {}  # id -> true
var _last_landing_ms := -1000000


func _ready() -> void:
	available = _try_connect_steam()
	_load_unlocked()
	var bus := get_node_or_null("/root/SignalBus")
	if bus == null:
		return
	bus.player_jumped.connect(_on_player_jumped)
	bus.player_landed.connect(func(_data: Dictionary) -> void:
		_last_landing_ms = Time.get_ticks_msec())
	bus.surf_entered.connect(func(_data: Dictionary) -> void:
		unlock("first_surf"))
	bus.race_finished.connect(func(payload: Dictionary) -> void:
		if bool(payload.get("is_pb", false)):
			unlock("first_pb")
		if available:
			submit_time(str(get_node("/root/GameManager").map_name),
				float(payload.get("time", 0.0))))
	bus.velocity_updated.connect(func(speed: float) -> void:
		for id: String in SPEED_TIERS:
			if speed >= SPEED_TIERS[id]:
				unlock(id))


# -------------------------------------------------------------- unlocks --

func unlock(achievement_id: String) -> void:
	if not ACHIEVEMENTS.has(achievement_id) or _unlocked.has(achievement_id):
		return
	_unlocked[achievement_id] = true
	unlock_count += 1
	_save_unlocked()
	if available:
		_activate_on_steam(achievement_id)
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null:
		audio_manager.play_sfx("achievement")
	achievement_unlocked.emit(achievement_id, ACHIEVEMENTS[achievement_id])


func is_unlocked(achievement_id: String) -> bool:
	return _unlocked.has(achievement_id)


func _on_player_jumped(_data: Dictionary) -> void:
	unlock("first_jump")
	# Bhop heuristic without touching the movement layer: a jump fired within
	# BHOP_WINDOW_MS of the last landing was buffered through it.
	if Time.get_ticks_msec() - _last_landing_ms <= BHOP_WINDOW_MS:
		unlock("first_bhop")


# ------------------------------------------------------- release-time seams --
# Fill these in once the GodotSteam GDExtension is installed and the game has
# a live AppID; everything else already routes through them.

func _try_connect_steam() -> bool:
	# Intended: detect GodotSteam singleton, Steam.init(), request current
	# stats/achievements, verify steam_appid.txt matches the store AppID.
	return false


func _activate_on_steam(_achievement_id: String) -> void:
	# Intended: Steam.activateAchievement(id) + storeStats().
	pass


## Submits a completed run to the map's leaderboard. Local mode keeps PBs in
## records.tres only (SaveManager already persists those).
func submit_time(_map_name: String, _time: float) -> bool:
	return false


# ---------------------------------------------------------------- storage --

func _load_unlocked() -> void:
	if not FileAccess.file_exists(ACHIEVEMENTS_PATH):
		return
	var cfg := ConfigFile.new()
	if cfg.load(ACHIEVEMENTS_PATH) != OK:
		push_warning("SteamManager: failed to read %s" % ACHIEVEMENTS_PATH)
		return
	for id: String in ACHIEVEMENTS:
		if bool(cfg.get_value("achievements", id, false)):
			_unlocked[id] = true


func _save_unlocked() -> void:
	var cfg := ConfigFile.new()
	for id: String in _unlocked:
		cfg.set_value("achievements", id, true)
	DirAccess.make_dir_recursive_absolute(
		ACHIEVEMENTS_PATH.get_base_dir())
	cfg.save(ACHIEVEMENTS_PATH)


## Test/dev helper: wipes local achievement state (and its file).
func reset_local_state() -> void:
	_unlocked.clear()
	unlock_count = 0
	if FileAccess.file_exists(ACHIEVEMENTS_PATH):
		DirAccess.remove_absolute(
			ProjectSettings.globalize_path(ACHIEVEMENTS_PATH))
