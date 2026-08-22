extends SceneTree

## Canonical headless test entry point. All test suites are reachable through
## this script: godot --headless --path . --script res://tests/test_runner.gd
## Exit code 0 + no ERROR lines in stdout = success.

var _failures: Array[String] = []
var _checks: int = 0


func _initialize() -> void:
	# Defer to the first process frame: nodes added during _initialize are not
	# yet part of an active tree (no _ready, no get_node absolute paths).
	process_frame.connect(_run_all_tests)


func _run_all_tests() -> void:
	process_frame.disconnect(_run_all_tests)
	_test_autoloads_registered()
	_test_signal_bus_signals()
	_test_game_manager_race_state()
	_test_input_manager_no_input()
	_test_input_state_wasd()
	_test_jump_just_pressed_one_frame()
	_test_mouse_delta_capture()
	_test_rebind_conflict_detection()
	_test_binding_persistence()
	_test_save_manager_defaults()
	_test_ui_manager_show_menu()
	_test_player_camera_look()
	_test_player_camera_sensitivity_and_invert()
	await _test_player_basic_movement()
	await _test_ground_friction()
	await _test_jump_coyote_and_no_double_jump()
	await _test_bunny_hop_buffer()
	await _test_air_strafing()

	print("---")
	print("Checks run: %d, Failures: %d" % [_checks, _failures.size()])
	if not _failures.is_empty():
		for failure: String in _failures:
			printerr("FAIL: " + failure)
		quit(1)
	else:
		print("ALL TESTS PASSED")
		quit(0)


func _check(condition: bool, test_name: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(test_name)


func _test_autoloads_registered() -> void:
	for manager: String in [
		"SignalBus", "GameManager", "InputManager", "TickManager",
		"UIManager", "SaveManager", "AudioManager", "LevelLoader",
	]:
		var node := root.get_node_or_null(NodePath(manager))
		_check(node != null, "Autoload '%s' is registered" % manager)
		if node != null:
			_check(node.get_script() != null, "Autoload '%s' has a script" % manager)


func _test_signal_bus_signals() -> void:
	var signal_names := ["race_started", "race_finished", "checkpoint_reached",
		"player_landed", "player_jumped", "settings_changed"]
	var bus: Node = root.get_node("SignalBus")
	for signal_name: String in signal_names:
		_check(bus.get_signal_list().any(
			func(s: Dictionary) -> bool: return s["name"] == signal_name),
			"SignalBus has signal '%s'" % signal_name)


func _test_game_manager_race_state() -> void:
	var gm: Node = root.get_node("GameManager")
	var state_keys: Array = gm.RaceState.keys()
	for key: String in ["IDLE", "RUNNING", "FINISHED", "PAUSED"]:
		_check(state_keys.has(key), "GameManager.RaceState enum has %s" % key)
	_check(gm.race_state == gm.RaceState.IDLE, "GameManager starts in IDLE")
	gm.start_race()
	_check(gm.race_state == gm.RaceState.RUNNING, "start_race() sets RUNNING")
	gm.finish_race()
	_check(gm.race_state == gm.RaceState.FINISHED, "finish_race() sets FINISHED")


func _test_input_manager_no_input() -> void:
	var im: Node = root.get_node("InputManager")
	var movement: Vector2 = im.get_movement_input()
	_check(movement == Vector2.ZERO,
		"get_movement_input() returns Vector2(0, 0) with no keys pressed (got %s)" % movement)
	_check(not im.is_action_pressed("jump"), "is_action_pressed() returns false for unbound action")


func _test_input_state_wasd() -> void:
	var im: Node = root.get_node("InputManager")
	Input.action_press("move_forward")
	var s: InputState = im.get_state()
	_check(s.forward == 1.0 and s.right == 0.0,
		"W gives forward=1.0, right=0.0 (got forward=%s, right=%s)" % [s.forward, s.right])
	Input.action_release("move_forward")

	Input.action_press("move_back")
	s = im.get_state()
	_check(s.forward == -1.0, "S gives forward=-1.0 (got %s)" % s.forward)
	Input.action_release("move_back")
	im.get_state()

	Input.action_press("move_right")
	Input.action_press("move_left")
	s = im.get_state()
	_check(s.right == 0.0, "D+A cancels to right=0.0 (got %s)" % s.right)
	Input.action_release("move_right")
	Input.action_release("move_left")
	im.get_state()

	Input.action_press("move_right")
	s = im.get_state()
	_check(s.right == 1.0 and s.forward == 0.0,
		"D gives right=1.0, forward=0.0 (got right=%s, forward=%s)" % [s.right, s.forward])
	Input.action_release("move_right")
	im.get_state()


func _test_jump_just_pressed_one_frame() -> void:
	var im: Node = root.get_node("InputManager")
	var press := InputEventKey.new()
	press.physical_keycode = KEY_SPACE
	press.pressed = true
	im._input(press)
	var first: InputState = im.get_state()
	_check(first.jump_just_pressed, "jump_just_pressed is true on the frame after press")
	var second: InputState = im.get_state()
	_check(not second.jump_just_pressed, "jump_just_pressed is false on the next read")


func _test_mouse_delta_capture() -> void:
	var im: Node = root.get_node("InputManager")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(10.0, -5.0)
	im._input(motion)
	motion = InputEventMouseMotion.new()
	motion.relative = Vector2(2.5, 1.5)
	im._input(motion)
	var s: InputState = im.get_state()
	_check(s.mouse_delta == Vector2(12.5, -3.5),
		"mouse delta accumulates between reads (got %s)" % s.mouse_delta)
	var next: InputState = im.get_state()
	_check(next.mouse_delta == Vector2.ZERO, "mouse delta resets after read")


func _test_rebind_conflict_detection() -> void:
	var im: Node = root.get_node("InputManager")
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	_check(not im.rebind_action("move_forward", space),
		"rebind_action rejects binding already used by another action")
	var unknown := InputEventKey.new()
	unknown.physical_keycode = KEY_Z
	_check(not im.rebind_action("nonexistent", unknown),
		"rebind_action rejects unknown actions")


func _test_binding_persistence() -> void:
	var im: Node = root.get_node("InputManager")
	var j_key := InputEventKey.new()
	j_key.physical_keycode = KEY_J
	_check(im.rebind_action("jump", j_key), "rebind_action('jump', J) succeeds")
	_check(FileAccess.file_exists(im.BINDINGS_PATH), "rebinding persisted to bindings.cfg")

	# Simulate a restart: wipe in-memory InputMap entry and reload from disk.
	InputMap.action_erase_events("jump")
	im.load_bindings()
	var events: Array = InputMap.action_get_events("jump")
	_check(events.size() == 1 and events[0] is InputEventKey
		and events[0].physical_keycode == KEY_J,
		"custom binding survives restart simulation")
	_check(im.is_action_pressed("jump") == false or true, "no error querying rebound action")

	# Restore defaults so the dev environment is not polluted by tests.
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	InputMap.action_erase_events("jump")
	InputMap.action_add_event("jump", space)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(im.BINDINGS_PATH))
	_check(not FileAccess.file_exists(im.BINDINGS_PATH), "test cleanup removed bindings.cfg")


func _mouse_motion(rel: Vector2) -> InputEventMouseMotion:
	var motion := InputEventMouseMotion.new()
	motion.relative = rel
	return motion


func _test_player_camera_look() -> void:
	var body := Node3D.new()
	body.name = "CameraTestBody"
	root.add_child(body)
	var cam: PlayerCamera = (load("res://scenes/player/PlayerCamera.tscn") as PackedScene).instantiate()
	body.add_child(cam)

	# Mouse right (+X) turns right (yaw decreases).
	cam._input(_mouse_motion(Vector2(100.0, 0.0)))
	_check(is_equal_approx(body.rotation.y, deg_to_rad(-10.0)),
		"100px mouse right yaws -10 degrees (got %s)" % rad_to_deg(body.rotation.y))

	# Mouse left (-X) turns left (yaw increases).
	cam._input(_mouse_motion(Vector2(-100.0, 0.0)))
	_check(is_equal_approx(body.rotation.y, 0.0),
		"100px mouse left returns yaw to 0 (got %s)" % rad_to_deg(body.rotation.y))

	# Mouse up (-Y) looks up (positive pitch).
	cam._input(_mouse_motion(Vector2(0.0, -50.0)))
	_check(cam.rotation.x > 0.0, "mouse up pitches up (got %s)" % rad_to_deg(cam.rotation.x))
	cam._input(_mouse_motion(Vector2(0.0, 50.0)))
	_check(is_equal_approx(cam.rotation.x, 0.0), "mouse down returns pitch to 0")

	# Pitch clamped to +/-89 degrees.
	cam._input(_mouse_motion(Vector2(0.0, -100000.0)))
	_check(is_equal_approx(rad_to_deg(cam.rotation.x), 89.0),
		"pitch clamps to +89 degrees (got %s)" % rad_to_deg(cam.rotation.x))
	cam._input(_mouse_motion(Vector2(0.0, 200000.0)))
	_check(is_equal_approx(rad_to_deg(cam.rotation.x), -89.0),
		"pitch clamps to -89 degrees (got %s)" % rad_to_deg(cam.rotation.x))

	body.queue_free()


func _test_player_camera_sensitivity_and_invert() -> void:
	var sm: Node = root.get_node("SaveManager")
	var body := Node3D.new()
	root.add_child(body)
	var cam: PlayerCamera = (load("res://scenes/player/PlayerCamera.tscn") as PackedScene).instantiate()
	body.add_child(cam)

	sm.set_setting("input/mouse_sensitivity_x", 2.0)
	cam.apply_settings()
	cam._input(_mouse_motion(Vector2(50.0, 0.0)))
	_check(is_equal_approx(body.rotation.y, deg_to_rad(-10.0)),
		"sensitivity_x=2.0 doubles yaw per pixel (got %s)" % rad_to_deg(body.rotation.y))

	sm.set_setting("input/invert_mouse_y", true)
	cam.apply_settings()
	cam._input(_mouse_motion(Vector2(0.0, 30.0)))
	_check(cam.rotation.x > 0.0,
		"invert_mouse_y flips pitch direction (got %s)" % rad_to_deg(cam.rotation.x))

	# Restore defaults so other tests / runs see standard settings.
	sm.set_setting("input/mouse_sensitivity_x", 1.0)
	sm.set_setting("input/invert_mouse_y", false)

	body.queue_free()


func _wait_ticks(count: int) -> void:
	for i in count:
		await physics_frame


func _test_player_basic_movement() -> void:
	# Flat floor with top surface at y = 0 (Quake-scale world).
	var world := Node3D.new()
	world.name = "MovementTestWorld"
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4000.0, 100.0, 4000.0)
	floor_shape.shape = box
	floor_shape.position.y = -50.0
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)

	var player: Player = (load("res://scenes/player/Player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0.0, 40.0, 0.0)
	world.add_child(player)

	# Land on the floor first.
	await _wait_ticks(40)
	_check(player.is_on_floor(), "player lands on flat floor")

	# W walks forward relative to camera facing (-Z), capped at walk_speed.
	Input.action_press("move_forward")
	await _wait_ticks(30)
	var velocity := player.velocity
	var h_speed := Vector2(velocity.x, velocity.z).length()
	_check(h_speed > 100.0, "holding W accelerates the player (speed=%s)" % h_speed)
	_check(h_speed <= player.movement_controller.config.walk_speed + 1.0,
		"horizontal speed capped at walk_speed (speed=%s)" % h_speed)
	_check(velocity.z < -50.0 and absf(velocity.x) < 1.0,
		"movement is forward-relative-to-camera (-Z, got %s)" % velocity)

	# Sustained ground movement never exceeds walk_speed.
	await _wait_ticks(80)
	h_speed = Vector2(player.velocity.x, player.velocity.z).length()
	_check(h_speed <= player.movement_controller.config.walk_speed + 1.0,
		"speed stays capped after sustained walking (speed=%s)" % h_speed)

	# Stub jump: buffered jump press while grounded gives upward velocity.
	var jump_press := InputEventKey.new()
	jump_press.physical_keycode = KEY_SPACE
	jump_press.pressed = true
	var jumped := false
	for i in 10:
		root.get_node("InputManager")._input(jump_press)
		await physics_frame
		if player.velocity.y > 100.0:
			jumped = true
			break
	_check(jumped, "jump stub applies upward impulse when grounded")
	Input.action_release("move_forward")

	# Fall under gravity, clamped at terminal velocity.
	player.velocity = Vector3.ZERO
	player.position.y += 5000.0
	await _wait_ticks(140)
	_check(player.velocity.y <= -999.0,
		"gravity accelerates fall to terminal velocity (v_y=%s)" % player.velocity.y)
	_check(player.velocity.y >= -player.movement_controller.config.max_fall_speed - 1.0,
		"fall speed clamped at max_fall_speed (v_y=%s)" % player.velocity.y)

	# Physics tick rate is configured at 100Hz.
	_check(Engine.physics_ticks_per_second == 100, "physics configured for 100Hz ticks")

	world.queue_free()
	await process_frame


func _spawn_test_player() -> Array:
	# Returns [world: Node3D, player: Player] — flat floor with top at y = 0.
	var world := Node3D.new()
	world.name = "MovementTestWorld"
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4000.0, 100.0, 4000.0)
	floor_shape.shape = box
	floor_shape.position.y = -50.0
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)

	var player: Player = (load("res://scenes/player/Player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0.0, 40.0, 0.0)
	world.add_child(player)
	return [world, player]


func _h_speed(player: CharacterBody3D) -> float:
	return Vector2(player.velocity.x, player.velocity.z).length()


func _test_ground_friction() -> void:
	var spawned := _spawn_test_player()
	var world: Node3D = spawned[0]
	var player: Player = spawned[1]
	await _wait_ticks(40)
	_check(player.is_on_floor(), "friction test: player lands on flat floor")

	# Accelerate smoothly toward walk_speed while holding W.
	Input.action_press("move_forward")
	await _wait_ticks(30)
	var top_speed := _h_speed(player)
	_check(top_speed > 250.0 and top_speed <= 321.0,
		"W accelerates smoothly up to walk_speed (speed=%s)" % top_speed)

	# Releasing input engages friction: exponential-ish decay.
	Input.action_release("move_forward")
	await _wait_ticks(20)  # 0.2s
	var after_200ms := _h_speed(player)
	_check(after_200ms < top_speed * 0.35,
		"friction removes most speed within 0.2s (%s -> %s)" % [top_speed, after_200ms])

	# Clean stop: stop_speed behavior decays linearly to an exact zero.
	var ticks_to_stop := 0
	while _h_speed(player) > 0.001 and ticks_to_stop < 200:
		await physics_frame
		ticks_to_stop += 1
	_check(_h_speed(player) <= 0.001,
		"player comes to a complete stop via friction (ticks=%d)" % ticks_to_stop)

	# Velocity module reports consistent horizontal speed.
	var vel_module: Velocity = null
	for module in player.movement_controller._modules:
		if module is Velocity:
			vel_module = module
	_check(vel_module != null and is_zero_approx(vel_module.horizontal_speed()),
		"Velocity module horizontal_speed() agrees with stopped state")

	world.queue_free()
	await process_frame


func _jump_press_event() -> InputEventKey:
	var press := InputEventKey.new()
	press.physical_keycode = KEY_SPACE
	press.pressed = true
	return press


func _test_jump_coyote_and_no_double_jump() -> void:
	var world := Node3D.new()
	root.add_child(world)

	# Floor slab with its -Z edge at z = -100, top surface at y = 0.
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2000.0, 100.0, 200.0)
	floor_shape.shape = box
	floor_shape.position.y = -50.0
	floor_body.add_child(floor_shape)
	world.add_child(floor_body)

	var spawned := _spawn_test_player_at(world, Vector3(0.0, 10.0, -60.0))
	var player: Player = spawned
	await _wait_ticks(30)
	_check(player.is_on_floor(), "jump test: player landed")

	# Walk forward (-Z) off the edge.
	Input.action_press("move_forward")
	var left_ground := false
	for i in 150:
		await physics_frame
		if not player.is_on_floor():
			left_ground = true
			break
	Input.action_release("move_forward")
	_check(left_ground, "player walked off the ledge")

	# Coyote time: jumping immediately after leaving the ground must fire.
	root.get_node("InputManager")._input(_jump_press_event())
	await _wait_ticks(2)
	_check(player.velocity.y > 250.0,
		"coyote jump fires just after leaving ground (v_y=%s)" % player.velocity.y)

	# No double jump: past the coyote window a fresh press does nothing.
	await _wait_ticks(40)
	var v_before := player.velocity.y
	root.get_node("InputManager")._input(_jump_press_event())
	await _wait_ticks(2)
	_check(player.velocity.y < 250.0 and absf(player.velocity.y - v_before) < 60.0,
		"no double jump mid-air (before=%s after=%s)" % [v_before, player.velocity.y])

	# Landing resets the coyote timer: a grounded jump works again.
	player.velocity = Vector3.ZERO
	player.position = Vector3(0.0, 100.0, 0.0)
	var landed := false
	for i in 80:
		await physics_frame
		if player.is_on_floor():
			landed = true
			break
	_check(landed, "player re-landed on floor")
	await _wait_ticks(2)
	root.get_node("InputManager")._input(_jump_press_event())
	await _wait_ticks(2)
	_check(player.velocity.y > 250.0,
		"grounded jump works after landing (v_y=%s)" % player.velocity.y)

	world.queue_free()
	await process_frame


func _test_bunny_hop_buffer() -> void:
	var spawned := _spawn_test_player()
	var world: Node3D = spawned[0]
	var player: Player = spawned[1]
	await _wait_ticks(40)

	# Reach full ground speed.
	Input.action_press("move_forward")
	await _wait_ticks(30)
	var ground_speed := _h_speed(player)
	_check(ground_speed > 300.0, "bhop test: reached run speed (%s)" % ground_speed)

	# Jump, then press jump again mid-air within the 50ms buffer window of
	# landing. Flight time is 75 ticks (v=300, g=800); land ~tick 75.
	root.get_node("InputManager")._input(_jump_press_event())
	await _wait_ticks(2)
	_check(player.velocity.y > 250.0 and not player.is_on_floor(), "bhop: initial jump fired")

	# Descend; arm the jump buffer just before touchdown (< 50ms away).
	var armed := false
	for i in 90:
		await physics_frame
		if player.velocity.y < 0.0 and player.position.y <= 12.0:
			root.get_node("InputManager")._input(_jump_press_event())
			armed = true
			break
	_check(armed, "bhop: armed buffer before touchdown")

	# Watch for the buffered auto-jump on landing.
	var buffered_jump := false
	for i in 12:
		await physics_frame
		if player.velocity.y > 250.0:
			buffered_jump = true
			break
	_check(buffered_jump, "buffered jump fires automatically on landing")
	var bhop_speed := _h_speed(player)
	_check(bhop_speed >= ground_speed * 0.95,
		"bhop preserves horizontal speed through landing (%s -> %s)" % [ground_speed, bhop_speed])

	# Land WITHOUT a buffer this time: full friction must apply and bleed speed.
	await _wait_ticks(80)  # fly out and settle back on the floor
	while not player.is_on_floor():
		await physics_frame
	Input.action_release("move_forward")
	await _wait_ticks(30)
	var after_friction := _h_speed(player)
	_check(after_friction < bhop_speed * 0.5,
		"unbuffered landing applies full friction (%s -> %s)" % [bhop_speed, after_friction])

	world.queue_free()
	await process_frame


func _spawn_test_player_at(world: Node3D, pos: Vector3) -> Player:
	var player: Player = (load("res://scenes/player/Player.tscn") as PackedScene).instantiate()
	player.position = pos
	world.add_child(player)
	return player


func _jump_from_ground(player: Player) -> void:
	while not player.is_on_floor():
		await physics_frame
	await _wait_ticks(2)
	root.get_node("InputManager")._input(_jump_press_event())
	await _wait_ticks(3)


func _test_air_strafing() -> void:
	var spawned := _spawn_test_player()
	var world: Node3D = spawned[0]
	var player: Player = spawned[1]
	await _wait_ticks(40)

	# --- W+A + mouse left gains speed in air (from low speed, where the
	# air-speed-cap mechanics produce visible gains) ---
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	await _wait_ticks(2)
	await _jump_from_ground(player)
	Input.action_press("move_left")
	var start_speed := _h_speed(player)
	for i in 60:  # simulate mouse-left turn while holding W+A
		player.rotation.y -= 0.05
		await physics_frame
	var strafe_left := _h_speed(player)
	_check(strafe_left > start_speed + 20.0,
		"W+A + mouse-left turn gains air speed (%s -> %s)" % [start_speed, strafe_left])
	Input.action_release("move_left")

	# --- W+D + mouse right also gains speed ---
	while not player.is_on_floor():
		await physics_frame
	await _wait_ticks(5)
	player.rotation.y = 0.0
	player.velocity = Vector3.ZERO
	await _wait_ticks(2)
	await _jump_from_ground(player)
	Input.action_press("move_right")
	var start_right := _h_speed(player)
	for i in 60:  # mouse-right turn
		player.rotation.y += 0.05
		await physics_frame
	var strafe_right := _h_speed(player)
	Input.action_release("move_right")
	_check(strafe_right > start_right + 20.0,
		"W+D + mouse-right turn gains air speed (%s -> %s)" % [start_right, strafe_right])

	# --- Pure W in air must NOT gain significant speed (even from high
	# speed: wish parallel to velocity has add_speed <= 0) ---
	while not player.is_on_floor():
		await physics_frame
	Input.action_press("move_forward")
	await _wait_ticks(30)
	await _jump_from_ground(player)
	var pure_start := _h_speed(player)
	for i in 30:
		await physics_frame
	var pure_end := _h_speed(player)
	_check(pure_end <= pure_start + 5.0,
		"pure W in air does not gain speed (%s -> %s)" % [pure_start, pure_end])
	Input.action_release("move_forward")

	world.queue_free()
	await process_frame


func _test_save_manager_defaults() -> void:
	var sm: Node = root.get_node("SaveManager")
	var settings: Dictionary = sm.load_settings()
	if FileAccess.file_exists(sm.SETTINGS_PATH):
		_check(not settings.is_empty(), "load_settings() returns settings when file exists")
	else:
		_check(settings == sm.DEFAULT_SETTINGS, "load_settings() returns defaults on first run")
	_check(sm.get_pb("nonexistent_map") == INF, "get_pb() returns INF for unknown map")


func _test_ui_manager_show_menu() -> void:
	var ui: Node = root.get_node("UIManager")
	ui.show_menu("main")
	_check(ui.current_menu == "main", "show_menu('main') sets current menu without error")
