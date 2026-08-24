extends Node

## Music playback, SFX management and volume control (architecture §13).
## Placeholder sounds are synthesized by tools/generate_sfx.gd; swap the files
## under assets/audio/ to replace them. Music stations are selectable via the
## audio/music_track setting (drop .wav/.ogg/.mp3 files into assets/audio/music/).

const SFX := {
	"jump": "res://assets/audio/sfx/jump.wav",
	"land": "res://assets/audio/sfx/land.wav",
	"footstep_a": "res://assets/audio/sfx/footstep_a.wav",
	"footstep_b": "res://assets/audio/sfx/footstep_b.wav",
	"finish": "res://assets/audio/sfx/finish.wav",
	"achievement": "res://assets/audio/sfx/achievement.wav",
	"ui_click": "res://assets/audio/sfx/ui_click.wav",
}
const SURF_LOOP := "res://assets/audio/sfx/surf_loop.wav"
const MUSIC_DIR := "res://assets/audio/music/"
const MUSIC_FALLBACK := "res://assets/audio/music/menu_placeholder.wav"
const POOL_SIZE := 10
const MUSIC_RESUME_DELAY := 2.5

## Test/telemetry hook: name -> times played.
var play_counts := {}

var _sfx_pool: Array[AudioStreamPlayer] = []
var _music_player: AudioStreamPlayer
var _surf_player: AudioStreamPlayer
var _streams := {}
var _surfing := false
var _latest_speed := 0.0
var _music_resume_timer := -1.0


func _ready() -> void:
	_ensure_buses()
	_load_streams()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	add_child(_music_player)
	_surf_player = AudioStreamPlayer.new()
	_surf_player.name = "SurfLoopPlayer"
	_surf_player.stream = _streams.get("surf_loop")
	_surf_player.bus = "SFX"
	_surf_player.volume_db = -8.0  # placeholder loop is noise; keep it subtle
	add_child(_surf_player)

	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager != null:
		set_volume("Master", save_manager.get_setting("audio/master_volume"))
		set_volume("Music", save_manager.get_setting("audio/music_volume"))
		set_volume("SFX", save_manager.get_setting("audio/sfx_volume"))

	var bus := get_node_or_null("/root/SignalBus")
	if bus != null:
		bus.player_jumped.connect(func(_data: Dictionary) -> void: play_sfx("jump"))
		bus.player_landed.connect(_on_player_landed)
		bus.footstep.connect(func(speed: float) -> void:
			play_sfx("footstep_a" if randi() % 2 == 0 else "footstep_b",
				-8.0, clampf(0.9 + speed / 800.0, 0.85, 1.3)))
		bus.velocity_updated.connect(func(speed: float) -> void: _latest_speed = speed)
		bus.surf_entered.connect(func(_data: Dictionary) -> void:
			_surfing = true
			if not _surf_player.playing:
				_surf_player.play())
		bus.surf_exited.connect(func() -> void:
			_surfing = false
			_surf_player.stop())
		# Music keeps playing during runs (playtest P2 decision): background
		# enjoyment beats the old silence-during-race design. The finish blip
		# still plays; play_music() below no-ops while music is running.
		bus.race_finished.connect(func(_payload: Dictionary) -> void:
			play_sfx("finish")
			_music_resume_timer = MUSIC_RESUME_DELAY)

	play_music(str(get_node("/root/SaveManager").get_setting("audio/music_track")))


func _process(delta: float) -> void:
	if _surfing and _surf_player.playing:
		_surf_player.pitch_scale = clampf(0.7 + _latest_speed / 500.0, 0.7, 1.8)
	if _music_resume_timer >= 0.0:
		_music_resume_timer -= delta
		if _music_resume_timer < 0.0:
			play_music()


# ------------------------------------------------------------------ volume --

func set_volume(bus_name: String, linear_value: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	var v := clampf(linear_value, 0.0, 1.0)
	AudioServer.set_bus_mute(idx, v <= 0.001)
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(v, 0.001)))


func get_volume(bus_name: String) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return 0.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))


func _ensure_buses() -> void:
	for bus_name: String in ["Music", "SFX", "UI"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, "Master")


# --------------------------------------------------------------------- sfx --

func _load_streams() -> void:
	for sfx_name: String in SFX:
		_streams[sfx_name] = load(SFX[sfx_name])
	_streams["surf_loop"] = load(SURF_LOOP)


## Plays a named sound effect on the SFX bus.
func play_sfx(sfx_name: String, volume_offset_db := 0.0, pitch := 1.0) -> void:
	play_counts[sfx_name] = int(play_counts.get(sfx_name, 0)) + 1
	var stream: AudioStream = _streams.get(sfx_name)
	if stream == null:
		return
	for p in _sfx_pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_offset_db
			p.pitch_scale = pitch
			p.play()
			return
	# Pool exhausted: steal the first voice.
	_sfx_pool[0].stream = stream
	_sfx_pool[0].volume_db = volume_offset_db
	_sfx_pool[0].pitch_scale = pitch
	_sfx_pool[0].play()


func _on_player_landed(payload: Dictionary) -> void:
	var fall_speed: float = absf(payload.get("fall_speed", 0.0))
	var impact_db := clampf((fall_speed - 300.0) / 100.0 * 2.0, -6.0, 3.0)
	play_sfx("land", impact_db)


# ------------------------------------------------------------------- music --

## Starts a music station (audio/music_track setting or explicit track name).
## Falls back to the placeholder loop when a track file is missing.
func play_music(track := "") -> void:
	if track == "":
		var save_manager := get_node_or_null("/root/SaveManager")
		if save_manager != null:
			track = str(save_manager.get_setting("audio/music_track"))
	if track == "" or track == "<null>":
		track = "placeholder"
	var stream: AudioStream = null
	for ext: String in [".ogg", ".wav", ".mp3", ".tres"]:
		var candidate := MUSIC_DIR + track + ext
		if ResourceLoader.exists(candidate):
			stream = ResourceLoader.load(candidate)
			if stream != null:
				break
	if stream == null:
		stream = load(MUSIC_FALLBACK)
	if _music_player.stream == stream and _music_player.playing:
		return
	_music_player.stream = stream
	_music_player.play()
	play_counts["music"] = int(play_counts.get("music", 0)) + 1


func stop_music() -> void:
	_music_player.stop()
