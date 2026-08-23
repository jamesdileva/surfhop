class_name HUDController
extends CanvasLayer

## Main racing HUD (architecture §12): speed with color tiers, race timer,
## PB, checkpoint progress, FPS, and a debug speed line. Speed updates are
## throttled to 30 Hz (Gameplay Systems §13.2); tiers per §13.3.

const SPEED_UPDATE_INTERVAL := 1.0 / 30.0

@onready var _speed_label: Label = $Root/SpeedLabel
@onready var _timer_label: Label = $Root/TimerLabel
@onready var _pr_label: Label = $Root/PRLabel
@onready var _checkpoint_label: Label = $Root/CheckpointLabel
@onready var _fps_label: Label = $Root/FPSLabel
@onready var _debug_label: Label = $Root/DebugSpeedLabel

var _finish_label := Label.new()
var _achievement_label := Label.new()

var _latest_speed: float = 0.0
var _speed_accum := 0.0
var _fps_accum := 0.0
var _finish_display_timer := 0.0
var _achievement_display_timer := 0.0


func _ready() -> void:
	_finish_label.text = ""
	_finish_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_finish_label.add_theme_font_size_override("font_size", 44)
	_finish_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_finish_label.position = Vector2(400, 140)
	_finish_label.size = Vector2(1120, 120)
	_finish_label.visible = false
	$Root.add_child(_finish_label)

	_achievement_label.text = ""
	_achievement_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_achievement_label.add_theme_font_size_override("font_size", 32)
	_achievement_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_achievement_label.position = Vector2(400, 70)
	_achievement_label.size = Vector2(1120, 60)
	_achievement_label.modulate = Color(0.4, 1.0, 0.6)
	_achievement_label.visible = false
	$Root.add_child(_achievement_label)

	var bus := get_node_or_null("/root/SignalBus")
	if bus != null:
		bus.velocity_updated.connect(_on_velocity_updated)
		bus.race_finished.connect(_on_race_finished)
	var steam_manager := get_node_or_null("/root/SteamManager")
	if steam_manager != null:
		steam_manager.achievement_unlocked.connect(_on_achievement_unlocked)
	var loader := get_node_or_null("/root/LevelLoader")
	if loader != null:
		loader.map_loaded.connect(_on_map_loaded)
	var ui_manager := get_node_or_null("/root/UIManager")
	if ui_manager != null and ui_manager.has_method("register_hud"):
		ui_manager.register_hud(self)
	_refresh_pb()
	_timer_label.text = "0:00.000"
	_checkpoint_label.text = ""


func _exit_tree() -> void:
	var ui_manager := get_node_or_null("/root/UIManager")
	if ui_manager != null and ui_manager.get_hud() == self:
		ui_manager.clear_hud()


func _process(delta: float) -> void:
	if _finish_display_timer > 0.0:
		_finish_display_timer -= delta
		if _finish_display_timer <= 0.0:
			_finish_label.visible = false
	if _achievement_display_timer > 0.0:
		_achievement_display_timer -= delta
		if _achievement_display_timer <= 0.0:
			_achievement_label.visible = false

	_speed_accum += delta
	if _speed_accum >= SPEED_UPDATE_INTERVAL:
		_speed_accum = 0.0
		_apply_speed(_latest_speed)

	_fps_accum += delta
	if _fps_accum >= 1.0:
		_fps_accum = 0.0
		_fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

	var game_manager := get_node_or_null("/root/GameManager")
	if game_manager != null:
		match game_manager.race_state:
			game_manager.RaceState.RUNNING:
				_timer_label.text = TimerSystem.format_time(game_manager.elapsed_seconds())
			game_manager.RaceState.FINISHED:
				_timer_label.text = TimerSystem.format_time(game_manager.race_time)
			_:
				pass
	var ui_manager := get_node_or_null("/root/UIManager")
	if ui_manager != null and ui_manager.checkpoint_display != "":
		_checkpoint_label.text = ui_manager.checkpoint_display


func _on_velocity_updated(speed: float) -> void:
	_latest_speed = speed


## Color tiers per Gameplay Systems §13.3.
static func tier_color(speed: float) -> Color:
	if speed < 200.0:
		return Color(0.55, 0.55, 0.55)
	if speed < 400.0:
		return Color.WHITE
	if speed < 600.0:
		return Color(1.0, 0.9, 0.25)
	if speed < 800.0:
		return Color(1.0, 0.55, 0.1)
	return Color(1.0, 0.15, 0.15)


static func tier_name(speed: float) -> String:
	if speed < 200.0:
		return "Slow"
	if speed < 400.0:
		return "Normal"
	if speed < 600.0:
		return "Fast"
	if speed < 800.0:
		return "Very fast"
	return "Maximum"


func _apply_speed(speed: float) -> void:
	_speed_label.text = "%d u/s" % int(round(speed))
	_speed_label.modulate = tier_color(speed)
	if _debug_label.visible:
		_debug_label.text = "%d u/s [%s]" % [int(round(speed)), tier_name(speed)]


func set_debug_visible(value: bool) -> void:
	_debug_label.visible = value


func get_speed_label() -> Label:
	return _speed_label


func get_speed_text() -> String:
	return _speed_label.text


func get_timer_text() -> String:
	return _timer_label.text


func get_checkpoint_text() -> String:
	return _checkpoint_label.text


func get_fps_text() -> String:
	return _fps_label.text


func is_debug_line_visible() -> bool:
	return _debug_label.visible


func get_finish_text() -> String:
	return _finish_label.text


func _refresh_pb() -> void:
	var save_manager := get_node_or_null("/root/SaveManager")
	var game_manager := get_node_or_null("/root/GameManager")
	if save_manager == null or game_manager == null:
		return
	var pb: float = save_manager.get_pb(game_manager.map_name)
	_pr_label.text = "PB --" if pb == INF else "PB " + TimerSystem.format_time(pb)


func _on_race_finished(payload: Dictionary) -> void:
	_timer_label.text = TimerSystem.format_time(payload["time"])
	var pb_text := "  —  NEW PERSONAL BEST!" if bool(payload["is_pb"]) else ""
	_finish_label.text = "FINISH  %s%s" % [TimerSystem.format_time(payload["time"]), pb_text]
	_finish_label.modulate = Color(1.0, 0.85, 0.2) if bool(payload["is_pb"]) else Color.WHITE
	_finish_label.visible = true
	_finish_display_timer = 5.0
	_refresh_pb()


func _on_achievement_unlocked(_id: String, display_name: String) -> void:
	_achievement_label.text = "ACHIEVEMENT UNLOCKED — %s" % display_name
	_achievement_label.visible = true
	_achievement_display_timer = 4.0


func get_achievement_text() -> String:
	return _achievement_label.text


## New map (re)loaded: PB belongs to the new map now.
func _on_map_loaded(_map_node: Node) -> void:
	_refresh_pb()
