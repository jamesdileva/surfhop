class_name Game
extends Node3D

## Boot / session scene (Phase 6 P1): the project's main_scene. Shows the main
## menu on launch; when a map is selected it wires the in-game systems
## (HUD, timer, ghost recording/playback), loads the map and spawns the
## player â€” the same assembly DevMain performs for dev bootstrap scenes.

const PLAYER_SCENE := preload("res://scenes/player/Player.tscn")
const HUD_SCENE := preload("res://scenes/ui/HUD.tscn")

const SMOKE_LOG_PATH_SUFFIX := "velocity_smoke.log"
const SMOKE_STAGE_TIMEOUT_MS := 60000

var _player: Player = null

# --- Sentinel smoke mode (Sprint INT1) ---
var _smoke_active := false
var _smoke_map_id := "beginner"
var _smoke_run_seconds := 8.0
var _smoke_hold_seconds := 0.0
var _smoke_stage_pause := 0.0
var _smoke_milestones: Array[String] = []


func _ready() -> void:
	var ui_manager: Node = get_node("/root/UIManager")
	ui_manager.register_game(self)
	_parse_smoke_args()
	ui_manager.show_menu("main")
	if _smoke_active:
		_run_smoke()


func _exit_tree() -> void:
	var ui_manager := get_node_or_null("/root/UIManager")
	if ui_manager != null and ui_manager.get_game() == self:
		ui_manager.session_active = false
		ui_manager.register_game(null)


## Self-driving smoke pass for external smoke testers (integration.md): boots
## through the real menu flow into a map, simulates gameplay input, and exits
## 0/1 so the harness's exit-code + crash-signature checks assert behavior.
## --smoke-hold=<seconds> keeps the window alive after RESULT so screenshot
## timing in smoke testers is not a race against self-exit.
## --smoke-stage-pause=<seconds> dwells on each milestone (menu, map load,
## gameplay) so external screenshot timing can catch the actual stage.
func _parse_smoke_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg == "--smoke":
			_smoke_active = true
		elif arg.begins_with("--smoke-map="):
			_smoke_map_id = arg.substr(12)
		elif arg.begins_with("--smoke-run-seconds="):
			_smoke_run_seconds = float(arg.substr(20))
		elif arg.begins_with("--smoke-hold="):
			_smoke_hold_seconds = float(arg.substr(13))
		elif arg.begins_with("--smoke-stage-pause="):
			_smoke_stage_pause = float(arg.substr(20))


func _smoke_beat() -> void:
	if _smoke_stage_pause > 0.0:
		await get_tree().create_timer(_smoke_stage_pause).timeout


## Framebuffer-accurate stage evidence for external testers: the game
## photographs itself at the exact right moment, immune to window-capture
## blanking and app-log tail lag. Files land in %TEMP% as
## velocity_smoke_<stage>.png; no-op in headless mode.
func _smoke_capture(stage: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var temp_dir := OS.get_environment("TEMP")
	if temp_dir != "" and img != null:
		img.save_png(temp_dir.path_join("velocity_smoke_%s.png" % stage))


func _run_smoke() -> void:
	await get_tree().process_frame
	var ui_manager: Node = get_node("/root/UIManager")

	# Stage 1: main menu actually shown.
	if not _smoke_stage("MENU_SHOWN",
			ui_manager.current_menu == "main"
			and ui_manager.get_node_or_null("MainMenu") != null
			and ui_manager.get_node_or_null("MainMenu").visible):
		return _smoke_finish(false, "main menu did not appear")
	await _smoke_beat()
	await _smoke_capture("menu")

	# Stage 1b: map select screen (the real Play flow).
	ui_manager.show_menu("map_select")
	if not _smoke_stage("MAP_SELECT_SHOWN",
			ui_manager.current_menu == "map_select"
			and ui_manager.get_node_or_null("MapSelect") != null
			and ui_manager.get_node_or_null("MapSelect").visible):
		return _smoke_finish(false, "map select did not appear")
	await _smoke_beat()
	await _smoke_capture("map_select")

	# Stage 1c: settings overlay (opened on top, as a real user would).
	ui_manager.show_menu("settings")
	if not _smoke_stage("SETTINGS_SHOWN",
			ui_manager.current_menu == "settings"
			and ui_manager.get_node_or_null("SettingsMenu") != null
			and ui_manager.get_node_or_null("SettingsMenu").visible):
		return _smoke_finish(false, "settings did not appear")
	await _smoke_beat()
	await _smoke_capture("settings")

	# Stage 2: resolve the requested map.
	var loader: Node = get_node("/root/LevelLoader")
	var map_path := ""
	for entry: Dictionary in loader.discover_maps():
		if entry["metadata"].map_id == _smoke_map_id:
			map_path = entry["path"]
			break
	if map_path == "":
		return _smoke_finish(false, "map id '%s' not found" % _smoke_map_id)

	# Stage 3: launch and wait for the async load + player spawn.
	ui_manager.launch_map(map_path)
	_smoke_record("MAP_LOAD_STARTED", true)
	await _smoke_beat()
	var deadline := Time.get_ticks_msec() + SMOKE_STAGE_TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		var player := get_tree().get_first_node_in_group("player") as Node3D
		if player != null and loader.current_map != null:
			break
	if not _smoke_stage("PLAYER_SPAWNED",
			get_tree().get_first_node_in_group("player") != null
			and loader.current_map != null):
		return _smoke_finish(false, "map/player never became ready")
	await _smoke_beat()

	# Stage 4: simulate gameplay; movement proves the simulation runs end to end.
	_smoke_record("RUN_STARTED", true)
	var player := get_tree().get_first_node_in_group("player") as CharacterBody3D
	var start_pos := player.global_position
	Input.action_press("move_forward")
	Input.action_press("jump")  # auto-bhop keeps a hopping pace
	var play_deadline := Time.get_ticks_msec() + int(_smoke_run_seconds * 1000.0)
	var run_started_ms := Time.get_ticks_msec()
	var gameplay_captured := false
	while Time.get_ticks_msec() < play_deadline:
		await get_tree().physics_frame
		if not gameplay_captured \
				and Time.get_ticks_msec() - run_started_ms >= 4000:
			gameplay_captured = true
			_smoke_capture("gameplay")
	Input.action_release("move_forward")
	Input.action_release("jump")
	var moved := player.global_position.distance_to(start_pos)
	if not _smoke_stage("GAMEPLAY_OK", moved > 50.0):
		return _smoke_finish(false, "player did not move (%.1fu)" % moved)
	_smoke_finish(true, "moved %.0fu in %.0fs" % [moved, _smoke_run_seconds])


func _smoke_record(stage: String, ok: bool) -> void:
	var line := "%s=%s" % [stage, "OK" if ok else "FAIL"]
	_smoke_milestones.append(line)
	# Live-print so external testers can gate screenshots on real moments
	# instead of discovering every marker only at finish.
	print("[smoke] " + line)


func _smoke_stage(stage: String, ok: bool) -> bool:
	_smoke_record(stage, ok)
	return ok


func _smoke_finish(success: bool, detail: String) -> void:
	print("[smoke] RESULT=%s %s" % ["OK" if success else "FAIL", detail])
	var temp_dir := OS.get_environment("TEMP")
	if temp_dir != "":
		var file := FileAccess.open(
			temp_dir.path_join(SMOKE_LOG_PATH_SUFFIX), FileAccess.WRITE)
		if file != null:
			for milestone: String in _smoke_milestones:
				file.store_line(milestone)
			file.store_line("RESULT=%s %s" % ["OK" if success else "FAIL", detail])
			file.close()
	if _smoke_hold_seconds > 0.0:
		await get_tree().create_timer(_smoke_hold_seconds).timeout
	get_tree().quit(0 if success else 1)


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
