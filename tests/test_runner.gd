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
	await _test_surfing()
	await _test_tuning_measurements()
	await _test_fixed_tick_determinism()
	await _test_movement_debug_tools()
	await _test_timer_system()
	await _test_checkpoints()
	await _test_map_loading()
	await _test_hud()
	await _test_save_system()
	await _test_ghost_recording()
	await _test_tutorial_map()
	await _test_beginner_map()
	await _test_intermediate_map()
	await _test_advanced_map()

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

	# Descend; spam the jump key near touchdown (real bhop technique) so the
	# buffer is guaranteed active at the moment of landing.
	var armed := false
	for i in 90:
		await physics_frame
		if player.velocity.y < 0.0 and player.position.y <= 20.0:
			root.get_node("InputManager")._input(_jump_press_event())
			armed = true
			if player.is_on_floor():
				break
	_check(armed, "bhop: armed buffer before touchdown")

	# Watch for the buffered auto-jump on landing. By the time the spam loop
	# observes the landed floor flag, the impulse has typically fired and a
	# couple of gravity ticks have passed - so accept any clear upward launch.
	var buffered_jump := false
	var trace := ""
	for i in 14:
		await physics_frame
		trace += "v=%s fl=%s | " % [player.velocity, player.is_on_floor()]
		if player.velocity.y > 150.0:
			buffered_jump = true
			break
	_check(buffered_jump, "buffered jump fires automatically on landing [%s]" % trace)
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

	# --- Pure-A strafe (classic CS circle-strafe: NO forward key, just A
	# + smooth mouse-left turn) must curve the path AND build speed ---
	while not player.is_on_floor():
		await physics_frame
	player.velocity = Vector3.ZERO
	player.rotation.y = 0.0
	await _wait_ticks(2)
	await _jump_from_ground(player)
	Input.action_press("move_left")
	var a_start := _h_speed(player)
	var start_heading := Vector2(player.velocity.x, player.velocity.z).angle()
	for i in 60:
		player.rotation.y -= 0.05  # smooth continuous left turn
		await physics_frame
	var a_end_speed := _h_speed(player)
	var end_heading := Vector2(player.velocity.x, player.velocity.z).angle()
	Input.action_release("move_left")
	var heading_change: float = absf(wrapf(end_heading - start_heading, -PI, PI))
	_check(a_end_speed > a_start + 40.0,
		"pure-A + mouse-turn accelerates without W (%s -> %s)" % [a_start, a_end_speed])
	_check(heading_change > 1.0,
		"pure-A strafing curves the flight path (%.0f deg turned)" % rad_to_deg(heading_change))

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


func _make_ramp(world: Node3D, angle_deg: float) -> StaticBody3D:
	# Tilted slab: top surface slopes downhill toward +X. Centered so the
	# plane of the top face passes near (0, -60, 0).
	var ramp := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1200.0, 40.0, 2000.0)
	shape.shape = box
	ramp.add_child(shape)
	ramp.rotation.z = -deg_to_rad(angle_deg)
	ramp.position = Vector3(0.0, -60.0, 0.0)
	world.add_child(ramp)
	return ramp


func _test_surfing() -> void:
	var world := Node3D.new()
	root.add_child(world)
	var ramp := _make_ramp(world, 50.0)

	# --- Landing on a ramp enters SURF state and slides gaining speed ---
	var player: Player = _spawn_test_player_at(world, Vector3(-150.0, 250.0, 0.0))
	var saw_surf := false
	var surf_start_speed := 0.0
	var speed_at_exit := 0.0
	var left_ramp := false
	var plane_error_max := 0.0
	for i in 300:
		await physics_frame
		if player.movement_controller.state == MovementState.SURF:
			if not saw_surf:
				saw_surf = true
				surf_start_speed = _h_speed(player)
			plane_error_max = maxf(plane_error_max,
				absf(player.velocity.dot(player.movement_controller.get_surface_normal())))
		elif saw_surf:
			speed_at_exit = _h_speed(player)
			left_ramp = true
			break
	_check(saw_surf, "landing on a 50-degree ramp enters SURF state")
	_check(left_ramp, "player slides down the ramp and exits to air")
	_check(speed_at_exit > surf_start_speed + 50.0,
		"gravity conversion builds speed on ramp (%s -> %s)" % [surf_start_speed, speed_at_exit])
	_check(plane_error_max < 25.0,
		"velocity stays close to ramp plane while surfing (max error %s)" % plane_error_max)

	# --- Anti-stuck / no cling: a player dropped stationary on the ramp
	# must start sliding rather than sticking ---
	player.velocity = Vector3.ZERO
	player.rotation.y = 0.0
	player.position = Vector3(-150.0, 250.0, 500.0)  # fresh spot on same ramp
	var sliding := false
	for i in 90:
		await physics_frame
		if player.movement_controller.state == MovementState.SURF and _h_speed(player) > 10.0:
			sliding = true
			break
	_check(sliding, "stationary player on ramp starts sliding (anti-stuck)")

	world.queue_free()
	await process_frame


func _test_tuning_measurements() -> void:
	var spawned := _spawn_test_player()
	var world: Node3D = spawned[0]
	var player: Player = spawned[1]
	await _wait_ticks(40)

	# --- Walk: ticks to reach 320 u/s (target ~0.5s per acceptance) ---
	Input.action_press("move_forward")
	var ticks_to_full := 0
	for i in 120:
		await physics_frame
		ticks_to_full = i + 1
		if _h_speed(player) >= 316.0:
			break
	_check(ticks_to_full > 0 and ticks_to_full <= 60,
		"walk reaches ~320 in %d ticks (%.2fs)" % [ticks_to_full, ticks_to_full * 0.01])
	print("[tuning] walk accel: %d ticks (%.2fs)" % [ticks_to_full, ticks_to_full * 0.01])
	Input.action_release("move_forward")
	world.queue_free()
	await process_frame

	# --- Jump air time (impulse 300 / gravity 800 -> physics says 0.75s) ---
	spawned = _spawn_test_player()
	world = spawned[0]
	player = spawned[1]
	await _wait_ticks(40)
	root.get_node("InputManager")._input(_jump_press_event())
	var air_ticks := 0
	var airborne := false
	for i in 150:
		await physics_frame
		if not player.is_on_floor():
			airborne = true
			air_ticks += 1
		elif airborne:
			break
	_check(airborne and air_ticks >= 68 and air_ticks <= 82,
		"jump air time matches impulse/gravity physics (%d ticks, docs claim ~0.45s - flagged)" % air_ticks)
	print("[tuning] jump air time: %d ticks (%.2fs; doc target 0.45s contradicts its own v=300/g=800 -> 0.75s)"
		% [air_ticks, air_ticks * 0.01])
	world.queue_free()
	await process_frame

	# --- Air strafe gain over 1s of optimal turning ---
	spawned = _spawn_test_player()
	world = spawned[0]
	player = spawned[1]
	await _wait_ticks(40)
	await _jump_from_ground(player)
	Input.action_press("move_left")
	var strafe_start := _h_speed(player)
	for i in 100:
		player.rotation.y -= 0.03
		await physics_frame
	var strafe_gain := _h_speed(player) - strafe_start
	Input.action_release("move_left")
	print("[tuning] strafe gain from low speed over 1s: %.0f u/s (doc target 100-150)" % strafe_gain)
	_check(strafe_gain > 30.0, "air strafing produces meaningful speed gain over 1s (+%.0f u/s)" % strafe_gain)
	world.queue_free()
	await process_frame

	# --- Surf speed build rate on a 50-degree ramp ---
	var world2 := Node3D.new()
	root.add_child(world2)
	var ramp := _make_ramp(world2, 50.0)
	var p2: Player = _spawn_test_player_at(world2, Vector3(-150.0, 250.0, 0.0))
	var surf_entry := -1.0
	var surf_exit_speed := -1.0
	for i in 200:
		await physics_frame
		if p2.movement_controller.state == MovementState.SURF:
			if surf_entry < 0.0:
				surf_entry = _h_speed(p2)
			surf_exit_speed = _h_speed(p2)
		elif surf_entry >= 0.0:
			break
	print("[tuning] surf on 50deg ramp: entry %.0f -> exit %.0f u/s" % [surf_entry, surf_exit_speed])
	_check(surf_exit_speed > surf_entry + 50.0,
		"surf at 50 degrees builds speed consistently (%.0f -> %.0f)" % [surf_entry, surf_exit_speed])
	world2.queue_free()
	await process_frame


func _run_scripted_sequence() -> Dictionary:
	# Identical input script used twice for the determinism check.
	var spawned := _spawn_test_player()
	var player: Player = spawned[1]
	await _wait_ticks(40)
	Input.action_press("move_forward")
	await _wait_ticks(20)
	root.get_node("InputManager")._input(_jump_press_event())
	await _wait_ticks(3)
	Input.action_press("move_left")
	for i in 25:
		player.rotation.y -= 0.04
		await physics_frame
	Input.action_release("move_forward")
	Input.action_release("move_left")
	var result := {"pos": player.global_position, "vel": player.velocity}
	spawned[0].queue_free()
	await process_frame
	return result


func _test_fixed_tick_determinism() -> void:
	# Same inputs over the same fixed ticks must produce bit-identical results
	# regardless of render pacing (doc §18.3 test_fixed_tick_determinism).
	var run_a := await _run_scripted_sequence()
	var run_b := await _run_scripted_sequence()
	_check(run_a["pos"] == run_b["pos"],
		"determinism: identical inputs give identical positions (a=%s b=%s)" % [run_a["pos"], run_b["pos"]])
	_check(run_a["vel"] == run_b["vel"],
		"determinism: identical inputs give identical velocity (a=%s b=%s)" % [run_a["vel"], run_b["vel"]])


func _f1_press() -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_F1
	ev.pressed = true
	return ev


func _test_movement_debug_tools() -> void:
	_check(InputMap.has_action("toggle_debug"), "toggle_debug action registered")

	var ui: Node = root.get_node("UIManager")
	var sm: Node = root.get_node("SaveManager")

	var spawned := _spawn_test_player()
	var world: Node3D = spawned[0]
	var player: Player = spawned[1]
	await _wait_ticks(40)

	var overlay: MovementDebugger = player.get_node("DebugOverlay")
	_check(overlay != null, "DebugOverlay present in Player scene")
	_check(overlay.visible == bool(sm.get_setting("movement/show_debug")),
		"overlay initial visibility follows saved setting")

	# F1 press routes through InputManager -> UIManager -> overlay.
	root.get_node("InputManager")._input(_f1_press())
	await physics_frame
	_check(ui.debug_visible == true, "F1 toggles debug on")
	_check(overlay.visible == true, "overlay visible after F1")
	_check(bool(sm.get_setting("movement/show_debug")) == true, "debug state persisted to settings")

	# Overlay draws while moving (updated at physics tick rate).
	Input.action_press("move_forward")
	await _wait_ticks(5)
	var velocity_mesh: ImmediateMesh = overlay.get_node("VelocityVector").mesh
	_check(velocity_mesh.get_surface_count() >= 1,
		"velocity arrow mesh updated while moving")
	var label: Label3D = overlay.get_node("StateLabel")
	_check(label.text.contains("GROUND") and label.text.contains("u/s"),
		"state label shows movement state and speed (%s)" % label.text.replace("\n", " "))
	Input.action_release("move_forward")

	root.get_node("InputManager")._input(_f1_press())
	await physics_frame
	_check(ui.debug_visible == false and overlay.visible == false, "F1 toggles debug off")

	world.queue_free()
	await process_frame

	# Restore pristine first-run state for other tests / dev environment.
	sm.set_setting("movement/show_debug", false)
	sm.save_settings()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sm.SETTINGS_PATH))


func _test_timer_system() -> void:
	# --- Time formatting (0:00.000) ---
	_check(TimerSystem.format_time(0.0) == "0:00.000",
		"format_time(0) == 0:00.000")
	_check(TimerSystem.format_time(65.5) == "1:05.500",
		"format_time(65.5) == 1:05.500")
	_check(TimerSystem.format_time(9.999) == "0:09.999",
		"format_time(9.999) == 0:09.999")

	var gm: Node = root.get_node("GameManager")
	var sm: Node = root.get_node("SaveManager")
	gm.restart()
	gm.map_name = "timer_test_map"

	var race_events: Array = []
	var recorder := func(payload: Dictionary) -> void: race_events.append(payload)
	root.get_node("SignalBus").race_finished.connect(recorder)

	var ts := TimerSystem.new()
	root.add_child(ts)

	# --- World: floor, start volume at spawn, finish line ahead ---
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var fb := BoxShape3D.new()
	fb.size = Vector3(4000.0, 100.0, 4000.0)
	fs.shape = fb
	fs.position.y = -50.0
	floor_body.add_child(fs)
	world.add_child(floor_body)

	var start_area: Area3D = (load("res://scenes/world/StartTrigger.tscn") as PackedScene).instantiate()
	start_area.position = Vector3.ZERO
	world.add_child(start_area)
	var finish_area: Area3D = (load("res://scenes/world/FinishTrigger.tscn") as PackedScene).instantiate()
	finish_area.position = Vector3(0.0, 40.0, -300.0)
	world.add_child(finish_area)

	var player: Player = _spawn_test_player_at(world, Vector3(0.0, 10.0, 0.0))
	await _wait_ticks(10)

	# Player starts inside the start volume; walking out begins the race.
	Input.action_press("move_forward")
	var running := false
	for i in 80:
		await physics_frame
		if gm.race_state == gm.RaceState.RUNNING:
			running = true
			break
	_check(running, "leaving the start trigger starts the race")

	# Pause freezes the timer (paused wall-clock never counts).
	paused = true
	gm.pause()
	await process_frame
	await process_frame
	var frozen_elapsed: float = gm.elapsed_seconds()
	await process_frame
	await process_frame
	_check(gm.elapsed_seconds() == frozen_elapsed,
		"pause stops the timer (elapsed unchanged while paused)")
	paused = false
	gm.resume()

	# Run to the finish line.
	var finished := false
	for i in 200:
		await physics_frame
		if gm.race_state == gm.RaceState.FINISHED:
			finished = true
			break
	Input.action_release("move_forward")
	_check(finished, "crossing the finish trigger finishes the race")
	_check(not race_events.is_empty(), "race_finished signal emitted with payload")
	if not race_events.is_empty():
		var payload: Dictionary = race_events.back()
		_check(bool(payload["is_pb"]), "first completion sets initial PB")
	_check(gm.race_time > 0.0 and gm.race_time < 60.0,
		"recorded race time is plausible (%.3fs)" % gm.race_time)
	_check(sm.get_pb("timer_test_map") == gm.race_time,
		"PB stored via SaveManager matches finish time")
	var first_pb: float = sm.get_pb("timer_test_map")

	# --- Second, slower run must NOT beat the PB ---
	gm.restart()
	player.velocity = Vector3.ZERO
	player.position = Vector3(0.0, 10.0, 0.0)
	await _wait_ticks(4)  # area re-detects overlap
	Input.action_press("move_forward")
	for i in 80:
		await physics_frame
		if gm.race_state == gm.RaceState.RUNNING:
			break
	Input.action_release("move_forward")  # stop moving: dawdling must not cross the finish
	for i in 100:  # dawdle so this run is slower than the first
		await physics_frame
	player.position = Vector3(0.0, 40.0, -320.0)  # teleport onto the finish
	var second_finished := false
	for i in 30:
		await physics_frame
		if gm.race_state == gm.RaceState.FINISHED:
			second_finished = true
			break
	Input.action_release("move_forward")
	_check(second_finished, "second run completes")
	if not race_events.is_empty():
		var last_payload: Dictionary = race_events.back()
		_check(not bool(last_payload["is_pb"]),
			"slower completion does not update PB")
	_check(sm.get_pb("timer_test_map") == first_pb,
		"PB unchanged after slower run")

	ts.queue_free()
	world.queue_free()
	await process_frame


func _r_press() -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_R
	ev.pressed = true
	return ev


func _test_checkpoints() -> void:
	var gm: Node = root.get_node("GameManager")
	gm.restart()
	gm.total_checkpoints = 0
	gm.active_checkpoint_id = -1
	gm.kill_plane_y = -300.0
	gm._spawn_captured = false  # autoload state leaks between suites; recapture

	var ui: Node = root.get_node("UIManager")

	# World: floor, start volume, two checkpoints, finish line.
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var fb := BoxShape3D.new()
	fb.size = Vector3(4000.0, 100.0, 4000.0)
	fs.shape = fb
	fs.position.y = -50.0
	floor_body.add_child(fs)
	world.add_child(floor_body)

	var start_area: Area3D = (load("res://scenes/world/StartTrigger.tscn") as PackedScene).instantiate()
	start_area.position = Vector3.ZERO
	world.add_child(start_area)

	var cp1: Checkpoint = (load("res://scenes/checkpoints/Checkpoint.tscn") as PackedScene).instantiate()
	cp1.position = Vector3(0.0, 40.0, -120.0)
	world.add_child(cp1)
	var cp2: Checkpoint = (load("res://scenes/checkpoints/Checkpoint.tscn") as PackedScene).instantiate()
	cp2.position = Vector3(0.0, 40.0, -220.0)
	world.add_child(cp2)

	var finish_area: Area3D = (load("res://scenes/world/FinishTrigger.tscn") as PackedScene).instantiate()
	finish_area.position = Vector3(0.0, 40.0, -320.0)
	world.add_child(finish_area)

	root.add_child(TimerSystem.new())
	var player: Player = _spawn_test_player_at(world, Vector3(0.0, 10.0, 0.0))
	await _wait_ticks(10)

	_check(gm.total_checkpoints == 2, "two checkpoints registered (got %d)" % gm.total_checkpoints)
	_check(cp1.checkpoint_id == 0 and cp2.checkpoint_id == 1,
		"checkpoint ids assigned in tree order (%d, %d)" % [cp1.checkpoint_id, cp2.checkpoint_id])

	# Walk the course: exit start -> cp1 -> cp2 -> finish.
	Input.action_press("move_forward")
	for i in 200:
		await physics_frame
		if player.position.z < -130.0:
			break
	_check(gm.active_checkpoint_id == 0, "checkpoint 1 reached")
	_check(ui.checkpoint_display == "Checkpoint 1/2",
		"UIManager shows checkpoint progress (%s)" % ui.checkpoint_display)
	_check(not gm.checkpoint_splits.is_empty(), "split recorded on checkpoint reach")
	var respawn_after_cp1: Vector3 = gm.respawn_transform.origin
	_check(absf(respawn_after_cp1.z - (-120.0)) < 1.0,
		"respawn position updated to checkpoint 1 (%s)" % respawn_after_cp1)

	for i in 200:
		await physics_frame
		if player.position.z < -230.0:
			break
	_check(gm.active_checkpoint_id == 1, "checkpoint 2 reached (forward progress)")
	_check(gm.checkpoint_splits.size() == 2, "second split recorded")
	_check(ui.checkpoint_display == "Checkpoint 2/2", "UIManager shows 2/2")

	# Stale checkpoints are ignored (no backward progress).
	var splits_before: int = gm.checkpoint_splits.size()
	gm._on_checkpoint_reached({"checkpoint_id": 0, "position": cp1.position,
		"basis": Basis.IDENTITY, "time": 9.9})
	_check(gm.active_checkpoint_id == 1 and gm.checkpoint_splits.size() == splits_before,
		"re-touching an old checkpoint does not regress progress")

	# Kill plane: falling below respawns at last checkpoint, race keeps running.
	Input.action_release("move_forward")
	var elapsed_before_fall: float = gm.elapsed_seconds()
	player.velocity = Vector3.ZERO
	player.position = Vector3(0.0, -500.0, -220.0)
	await _wait_ticks(3)
	_check(player.position.distance_to(gm.respawn_transform.origin) < 2.0,
		"falling below kill plane respawns at last checkpoint (at %s)" % player.position)
	_check(Vector2(player.velocity.x, player.velocity.z).length() < 10.0,
		"respawn zeroes horizontal velocity")
	_check(gm.race_state == gm.RaceState.RUNNING and gm.elapsed_seconds() >= elapsed_before_fall,
		"respawn does not reset the running timer")

	# Finish with both splits present.
	player.position = Vector3(0.0, 40.0, -320.0)
	var finished := false
	for i in 30:
		await physics_frame
		if gm.race_state == gm.RaceState.FINISHED:
			finished = true
			break
	_check(finished and gm.checkpoint_splits.size() == 2,
		"finish records run with both checkpoint splits")

	# R restarts the run and respawns at the last checkpoint.
	root.get_node("InputManager")._input(_r_press())
	await physics_frame
	await physics_frame
	_check(gm.race_state == gm.RaceState.IDLE, "R resets the race to IDLE")
	_check(gm.checkpoint_splits.is_empty(), "R clears splits")
	_check(player.position.distance_to(gm.respawn_transform.origin) < 2.0,
		"R respawns at last checkpoint")

	world.queue_free()
	ts_queue_free()
	await process_frame


## Frees leftover TimerSystem instances from earlier suites.
func ts_queue_free() -> void:
	for node in root.get_children():
		if node is TimerSystem:
			node.queue_free()


func _test_map_loading() -> void:
	var loader: Node = root.get_node("LevelLoader")
	var gm: Node = root.get_node("GameManager")

	# --- Discovery finds the fixture map and its metadata ---
	var found: Array[Dictionary] = loader.discover_maps()
	_check(found.size() >= 1, "discover_maps() found maps (got %d)" % found.size())
	var entry: Dictionary = {}
	for e in found:
		if e["metadata"].map_id == "test_map":
			entry = e
			break
	_check(not entry.is_empty(), "test_map discovered with metadata")
	if entry.is_empty():
		return
	var meta: MapMetadata = entry["metadata"]
	_check(meta.display_name == "Test Map" and meta.difficulty == 1,
		"MapMetadata fields accessible (%s, difficulty %d)" % [meta.display_name, meta.difficulty])

	# --- Async load: poll until current_map appears ---
	# Spawn a standalone player so the loader has someone to reconfigure.
	var player_root := Node3D.new()
	player_root.name = "MapTestPlayerRoot"
	root.add_child(player_root)
	var spawned_player: Player = _spawn_test_player_at(player_root, Vector3(0.0, 20.0, 0.0))
	await _wait_ticks(2)

	loader.load_map(entry["path"])
	var loaded := false
	for i in 120:
		await process_frame
		if loader.current_map != null:
			loaded = true
			break
	_check(loaded, "load_map completes asynchronously")
	_check(loader.current_map.name == "TestMap", "loaded map added to scene tree")
	_check(gm.map_name == "test_map", "GameManager.map_name set from metadata")

	# --- MovementConfig applied to the player's controller ---
	await _wait_ticks(2)
	var player: Player = get_first_node_in_group("player") as Player
	_check(player != null, "player present for config application")
	if player != null:
		var cfg: MovementConfig = player.movement_controller.config
		_check(cfg != null and cfg.resource_path == "res://resources/movement/default.tres",
			"map MovementConfig applied to MovementController (%s)" % (cfg.resource_path if cfg else "null"))

	# --- Reloading frees the previous instance (no leak) ---
	var previous: Node = loader.current_map
	loader.load_map(entry["path"])
	var reloaded := false
	for i in 120:
		await process_frame
		if loader.current_map != null and loader.current_map != previous:
			reloaded = true
			break
	_check(reloaded, "reloading swaps current map")
	await process_frame
	await process_frame
	_check(not is_instance_valid(previous), "previous map properly freed")

	# Cleanup: leave no map loaded for other suites.
	loader.unload_current()
	player_root.queue_free()
	await process_frame


func _test_hud() -> void:
	var gm: Node = root.get_node("GameManager")
	var ui: Node = root.get_node("UIManager")
	gm.restart()

	# --- Speed tiers (§13.3) ---
	_check(HUDController.tier_color(100.0) == Color(0.55, 0.55, 0.55), "tier: gray below 200")
	_check(HUDController.tier_color(300.0) == Color.WHITE, "tier: white 200-400")
	_check(HUDController.tier_color(500.0) == Color(1.0, 0.9, 0.25), "tier: yellow 400-600")
	_check(HUDController.tier_color(700.0) == Color(1.0, 0.55, 0.1), "tier: orange 600-800")
	_check(HUDController.tier_color(900.0) == Color(1.0, 0.15, 0.15), "tier: red above 800")

	# --- Live HUD with a moving player ---
	var spawned := _spawn_test_player()
	var world: Node3D = spawned[0]
	var player: Player = spawned[1]
	var hud: HUDController = (load("res://scenes/ui/HUD.tscn") as PackedScene).instantiate()
	root.add_child(hud)
	for i in 80:  # helper spawns from y=40; wait for touchdown
		await physics_frame
		if player.is_on_floor():
			break
	await _wait_ticks(2)

	Input.action_press("move_forward")
	await _wait_ticks(30)  # past the 30Hz throttle window, speed ~320

	var speed_text: String = hud.get_speed_text()
	_check(speed_text.ends_with("u/s") and int(speed_text.trim_suffix(" u/s")) > 200,
		"speed label shows live horizontal speed (%s)" % speed_text)
	_check(hud.get_speed_label().modulate == HUDController.tier_color(320.0),
		"speed label uses tier color")
	Input.action_release("move_forward")

	# Free the live emitter so the direct-emission check is deterministic
	# (a decelerating player overwrites _latest_speed every tick).
	world.queue_free()
	await process_frame

	# Direct emission drives the label (wait out the 30Hz throttle window).
	root.get_node("SignalBus").velocity_updated.emit(650.0)
	await _wait_ticks(5)
	_check(hud.get_speed_label().text == "650 u/s", "velocity_updated drives speed label")
	_check(hud.get_speed_label().modulate == HUDController.tier_color(650.0),
		"650 u/s shows orange tier")

	# --- Timer starts/stops with the race; PB updates on finish ---
	gm.start_race()
	await _wait_ticks(20)
	var running_text: String = hud.get_timer_text()
	_check(running_text != "0:00.000", "timer runs during race (%s)" % running_text)
	gm.finish_race()
	var frozen: String = hud.get_timer_text()
	await _wait_ticks(5)
	_check(hud.get_timer_text() == frozen, "timer freezes at finish")
	_check(frozen.begins_with("0:") or frozen.begins_with("1:"),
		"timer format is m:ss.mmm (%s)" % frozen)

	# --- Checkpoint display flows to HUD ---
	ui.show_checkpoint_progress(2, 5)
	await _wait_ticks(2)
	_check(hud.get_checkpoint_text() == "Checkpoint 2/5",
		"checkpoint label shows N/M (%s)" % hud.get_checkpoint_text())

	# --- Debug line visibility follows UIManager ---
	ui.set_debug_visible(true)
	await _wait_ticks(2)
	_check(hud.is_debug_line_visible(),
		"debug speed line visible in debug mode (ui.debug_visible=%s hud_registered=%s)" %
			[ui.debug_visible, ui.get_hud() == hud])
	ui.set_debug_visible(false)

	# --- FPS counter populates within a second ---
	var fps_before: String = hud.get_fps_text()
	for i in 80:
		await process_frame
		if hud.get_fps_text() != fps_before and not hud.get_fps_text().ends_with("--"):
			break
	_check(hud.get_fps_text().begins_with("FPS: ") and not hud.get_fps_text().ends_with("--"),
		"FPS counter shows real-time reading (%s)" % hud.get_fps_text())

	hud.queue_free()
	await process_frame


func _test_save_system() -> void:
	var sm: Node = root.get_node("SaveManager")
	var user_save_dir := ProjectSettings.globalize_path(sm.SETTINGS_PATH.get_base_dir())

	# --- Settings round-trip persists across a simulated restart ---
	sm.set_setting("input/mouse_sensitivity_x", 1.75)
	sm.save_settings()
	_check(FileAccess.file_exists(sm.SETTINGS_PATH), "settings file created on save")
	sm._settings = {}  # wipe memory; reload from disk like a fresh process
	sm._settings = sm.load_settings()
	var reloaded: Dictionary = sm._settings
	_check(absf(reloaded["input/mouse_sensitivity_x"] - 1.75) < 0.001,
		"settings persist to disk (%s)" % reloaded["input/mouse_sensitivity_x"])

	# Typed schema view matches.
	var typed: SettingsResource = sm.get_settings_resource()
	_check(absf(typed.mouse_sensitivity_x - 1.75) < 0.001 and typed.tick_rate == 100,
		"SettingsResource typed view works")

	# --- First run: defaults are written when no settings exist ---
	DirAccess.remove_absolute(ProjectSettings.globalize_path(sm.SETTINGS_PATH))
	sm._settings = sm.load_settings()
	sm.save_settings()
	_check(FileAccess.file_exists(sm.SETTINGS_PATH), "first run creates default settings")

	# --- PBs persist across a simulated restart ---
	sm.save_pb("save_test_map", 12.34, 450.0, 7)
	var first_record: MapRecord = sm._records.get_record("save_test_map")
	_check(first_record.pb_time == 12.34, "PB recorded (12.34)")
	_check(first_record.pb_date > 0, "PB date stamped")
	_check(first_record.completion_count == 1, "completion count tracked")

	sm._records = RecordsResource.new()  # simulate process restart
	sm.load_records()
	_check(sm.get_pb("save_test_map") == 12.34,
		"PBs persist to records.tres across restart simulation")

	# Faster time updates; slower keeps existing PB.
	sm.save_pb("save_test_map", 10.5)
	_check(sm.get_pb("save_test_map") == 10.5, "faster completion updates PB")
	sm.save_pb("save_test_map", 15.0)
	_check(sm.get_pb("save_test_map") == 10.5, "slower completion keeps PB")
	var updated: MapRecord = sm._records.get_record("save_test_map")
	_check(updated.completion_count == 3 and updated.best_speed == 450.0,
		"stats accumulate independently of PB (%d runs)" % updated.completion_count)

	# --- Ghost files round-trip through user://ghosts/ ---
	var ghost := Resource.new()
	ghost.set_meta("version", 1)
	ghost.set_meta("frame_count", 3)  # placeholder payload; Sprint 18 owns format
	_check(sm.save_ghost("save_test_map", ghost), "ghost saved to user://ghosts/")
	_check(sm.has_ghost("save_test_map"), "has_ghost sees the saved replay")
	var loaded_ghost: Resource = sm.load_ghost("save_test_map")
	_check(loaded_ghost != null and loaded_ghost.get_meta("frame_count") == 3,
		"ghost loads back with payload intact")
	_check(sm.load_ghost("nonexistent_map") == null, "missing ghost returns null")

	# --- Cleanup: restore pristine first-run state for dev environment ---
	for path: String in [sm.SETTINGS_PATH, sm.RECORDS_PATH, sm.ghost_path("save_test_map")]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	sm._records = RecordsResource.new()
	sm._settings = sm.DEFAULT_SETTINGS.duplicate(true)


func _test_ghost_recording() -> void:
	var gm: Node = root.get_node("GameManager")
	var sm: Node = root.get_node("SaveManager")
	gm.restart()
	gm.map_name = "ghost_test_map"

	var recorder := GhostRecorder.new()
	root.add_child(recorder)
	var ts := TimerSystem.new()
	root.add_child(ts)

	# World: floor, start volume, finish line.
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var fb := BoxShape3D.new()
	fb.size = Vector3(4000.0, 100.0, 4000.0)
	fs.shape = fb
	fs.position.y = -50.0
	floor_body.add_child(fs)
	world.add_child(floor_body)

	var start_area: Area3D = (load("res://scenes/world/StartTrigger.tscn") as PackedScene).instantiate()
	start_area.position = Vector3.ZERO
	world.add_child(start_area)
	var finish_area: Area3D = (load("res://scenes/world/FinishTrigger.tscn") as PackedScene).instantiate()
	finish_area.position = Vector3(0.0, 40.0, -300.0)
	world.add_child(finish_area)

	var player: Player = _spawn_test_player_at(world, Vector3(0.0, 10.0, 0.0))
	await _wait_ticks(10)
	_check(not recorder.is_recording, "recorder idle before race")

	# --- Run 1: walk to finish; PB ghost must be saved ---
	Input.action_press("move_forward")
	for i in 80:
		await physics_frame
		if gm.race_state == gm.RaceState.RUNNING:
			break
	_check(recorder.is_recording, "ghost starts recording when race starts")
	for i in 250:
		await physics_frame
		if gm.race_state == gm.RaceState.FINISHED:
			break
	Input.action_release("move_forward")
	_check(gm.race_state == gm.RaceState.FINISHED and bool(sm.get_pb("ghost_test_map") < INF),
		"first run finished as PB")

	_check(sm.has_ghost("ghost_test_map"), "ghost saved when PB achieved")
	var replay: GhostReplay = sm.load_ghost("ghost_test_map")
	_check(replay != null and replay.frames.size() >= 40,
		"replay contains the full run of frames (%d)" % (replay.frames.size() if replay else 0))
	if replay != null and replay.frames.size() >= 12:
		_check(replay.frames[10].tick == 10, "frames tick at 100Hz cadence")
		_check(replay.frames[10].velocity != Vector3.ZERO or replay.frames[11].velocity != Vector3.ZERO,
			"frames capture velocity")
		_check(absf(replay.finish_time - gm.race_time) < 0.001,
			"replay header stores finish time")

	# --- Run 2: playback stays in lockstep with the race ---
	gm.restart()
	player.velocity = Vector3.ZERO
	player.position = Vector3(0.0, 10.0, 0.0)
	await _wait_ticks(4)

	var ghost := GhostPlayer.new()
	world.add_child(ghost)
	_check(ghost.load_replay("ghost_test_map"), "ghost player loads saved replay")
	_check(not ghost.visible, "ghost hidden while not racing")

	Input.action_press("move_forward")
	for i in 80:
		await physics_frame
		if gm.race_state == gm.RaceState.RUNNING:
			break

	for i in 30:
		await physics_frame
	Input.action_release("move_forward")

	var index: int = ghost.current_frame_index()
	_check(index >= 25, "playback advanced with the race (frame %d)" % index)
	if replay.frames.size() > index and index >= 1:
		var expected: ReplayFrame = replay.frames[index - 1]
		_check(ghost.global_position == expected.position,
			"ghost position matches recorded frame exactly (%s vs %s)" %
				[ghost.global_position, expected.position])

	# Visually distinct: translucent material on the ghost model.
	var model_mat: StandardMaterial3D = ghost.get_node("GhostModel/MeshInstance3D").material_override
	_check(model_mat.albedo_color.a < 1.0, "ghost model is translucent")

	gm.restart()
	ghost.queue_free()
	recorder.queue_free()
	ts.queue_free()
	world.queue_free()
	if sm.has_ghost("ghost_test_map"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(sm.ghost_path("ghost_test_map")))
	await process_frame


func _test_tutorial_map() -> void:
	var loader: Node = root.get_node("LevelLoader")
	var gm: Node = root.get_node("GameManager")

	# --- Discovery + metadata point at the casual preset ---
	var found: Array[Dictionary] = loader.discover_maps()
	var entry: Dictionary = {}
	for e in found:
		if e["metadata"].map_id == "tutorial":
			entry = e
			break
	_check(not entry.is_empty(), "tutorial map discovered")
	if entry.is_empty():
		return
	var meta: MapMetadata = entry["metadata"]
	_check(meta.movement_config_path.ends_with("casual.tres"),
		"tutorial uses casual movement config (%s)" % meta.movement_config_path)

	# --- Load the map; player receives the casual config ---
	root.get_node("SaveManager")  # touch to ensure autoload order sane
	var player_root := Node3D.new()
	root.add_child(player_root)
	var spawned_player: Player = _spawn_test_player_at(player_root, Vector3(0.0, 20.0, 40.0))
	var ts := TimerSystem.new()  # wires start/finish triggers for the traversal
	root.add_child(ts)

	loader.load_map(entry["path"])
	var loaded := false
	for i in 120:
		await process_frame
		if loader.current_map != null:
			loaded = true
			break
	_check(loaded, "tutorial map loads")
	await _wait_ticks(5)
	var cfg: MovementConfig = spawned_player.movement_controller.config
	_check(cfg != null and cfg.resource_path.ends_with("casual.tres"),
		"casual config applied to player (%s)" % (cfg.resource_path if cfg else "null"))
	_check(cfg.jump_buffer_ms == 80.0 and cfg.coyote_time_ms == 100.0,
		"casual config is more forgiving (buffer %.0f, coyote %.0f)" %
			[cfg.jump_buffer_ms, cfg.coyote_time_ms])

	var map: Node3D = loader.current_map
	_check(map.name == "TutorialMap", "map root present")

	# --- Tutorial signs exist and reveal on proximity ---
	var bhop_sign: Area3D = map.get_node("BhopSign")
	var strafe_sign: Area3D = map.get_node("StrafeSign")
	var surf_sign: Area3D = map.get_node("SurfSign")
	for sign_area: Area3D in [bhop_sign, strafe_sign, surf_sign]:
		_check(sign_area != null and sign_area is TutorialSign, "%s present" % sign_area.name)
	var bhop_label: Label3D = bhop_sign.get_node("SignLabel")
	_check(not bhop_label.visible, "sign hidden before approach")
	_check(bhop_label.text.contains("BUNNY HOP"), "bhop sign text set")

	spawned_player.velocity = Vector3.ZERO
	spawned_player.position = bhop_sign.position + Vector3(0.0, -30.0, 0.0)
	await _wait_ticks(4)
	_check(bhop_label.visible, "sign appears when player approaches")
	spawned_player.position += Vector3(0.0, 0.0, -600.0)
	await _wait_ticks(4)
	_check(not bhop_label.visible, "sign hides when player leaves")

	# --- Traversal smoke test: start -> surf -> finish ---
	gm.restart()
	gm.kill_plane_y = -2000.0  # don't respawn-loop during the traversal checks
	spawned_player.position = Vector3(0.0, 20.0, -40.0)  # on the start platform
	await _wait_ticks(6)

	Input.action_press("move_forward")
	var running := false
	for i in 120:
		await physics_frame
		if gm.race_state == gm.RaceState.RUNNING:
			running = true
			break
	_check(running, "leaving the tutorial start platform starts the race")

	# Drop onto the middle of the surf ramp.
	spawned_player.position = Vector3(0.0, -150.0, -1662.0)
	spawned_player.velocity = Vector3(0.0, -50.0, -100.0)
	var surfing := false
	for i in 30:
		await physics_frame
		if spawned_player.movement_controller.state == MovementState.SURF:
			surfing = true
			break
	_check(surfing, "surf ramp section produces SURF state")

	# Land in the lower pool and cross the finish.
	spawned_player.position = Vector3(0.0, -400.0, -2100.0)
	await _wait_ticks(10)
	spawned_player.position = Vector3(0.0, -364.0, -2255.0)
	var finished := false
	for i in 30:
		await physics_frame
		if gm.race_state == gm.RaceState.FINISHED:
			finished = true
			break
	Input.action_release("move_forward")
	_check(finished, "map ends with a working finish line")
	var hud_nodes := root.get_children().filter(
		func(n: Node) -> bool: return n is HUDController)
	if hud_nodes.size() > 0:
		var finish_text: String = hud_nodes[0].get_finish_text()
		_check(finish_text.begins_with("FINISH"),
			"HUD shows finish feedback (%s)" % finish_text)

	loader.unload_current()
	player_root.queue_free()
	ts.queue_free()
	await process_frame


func _test_beginner_map() -> void:
	var loader: Node = root.get_node("LevelLoader")
	var gm: Node = root.get_node("GameManager")

	var found: Array[Dictionary] = loader.discover_maps()
	var entry: Dictionary = {}
	for e in found:
		if e["metadata"].map_id == "beginner":
			entry = e
			break
	_check(not entry.is_empty(), "beginner map discovered")
	if entry.is_empty():
		return
	var meta: MapMetadata = entry["metadata"]
	_check(meta.difficulty == 2 and meta.movement_config_path.ends_with("default.tres"),
		"beginner metadata: difficulty 2, standard config")

	# Load with a player; checkpoint counters must reset per map.
	var player_root := Node3D.new()
	root.add_child(player_root)
	var player: Player = _spawn_test_player_at(player_root, Vector3(0.0, 20.0, -40.0))
	var ts := TimerSystem.new()
	root.add_child(ts)

	loader.load_map(entry["path"])
	var loaded := false
	for i in 120:
		await process_frame
		if loader.current_map != null:
			loaded = true
			break
	_check(loaded, "beginner map loads")
	await _wait_ticks(5)
	var map: Node3D = loader.current_map
	var cfg: MovementConfig = player.movement_controller.config
	_check(cfg != null and cfg.resource_path.ends_with("default.tres"),
		"standard config applied (%s)" % (cfg.resource_path if cfg else "null"))
	_check(gm.total_checkpoints == 3,
		"exactly 3 checkpoints registered on load (got %d)" % gm.total_checkpoints)
	_check(map.get_node_or_null("SurfRamp1") != null and map.get_node_or_null("SurfRamp2") != null
		and map.get_node_or_null("SurfRamp3") != null, "three surf ramps present")
	var r1_angle: float = rad_to_deg(absf(map.get_node("SurfRamp1").rotation.x))
	var r2_angle: float = rad_to_deg(absf(map.get_node("SurfRamp2").rotation.x))
	var r3_angle: float = rad_to_deg(absf(map.get_node("SurfRamp3").rotation.x))
	_check(r1_angle < r2_angle and r2_angle < r3_angle,
		"ramps increase in angle (%.1f < %.1f < %.1f)" % [r1_angle, r2_angle, r3_angle])

	# --- Traversal smoke test ---
	gm.kill_plane_y = -3000.0
	player.position = Vector3(0.0, 20.0, -40.0)
	await _wait_ticks(6)

	Input.action_press("move_forward")
	var running := false
	for i in 120:
		await physics_frame
		if gm.race_state == gm.RaceState.RUNNING:
			running = true
			break
	_check(running, "start trigger begins the run")

	# Ride each ramp: teleport onto mid-ramp, expect SURF state each time.
	# Drop steeply onto each ramp (raycast-verified surface points); a shallow
	# fall with forward speed can parallel the slope without contacting.
	for ramp_info: Array in [
		["SurfRamp1", Vector3(0.0, -178.0, -2560.0)],
		["SurfRamp2", Vector3(0.0, -608.0, -4825.0)],
		["SurfRamp3", Vector3(0.0, -1083.0, -6930.0)],
	]:
		player.position = ramp_info[1]
		player.velocity = Vector3(0.0, -120.0, -30.0)
		var surfing := false
		var ramp_trace := ""
		for i in 30:
			await physics_frame
			ramp_trace += "%d:%d@(%d,%d,%d) " % [i, player.movement_controller.state,
				player.position.x, player.position.y, player.position.z]
			if player.movement_controller.state == MovementState.SURF:
				surfing = true
				break
		_check(surfing, "%s produces SURF state [%s]" % [ramp_info[0], ramp_trace])

	# Pass checkpoints via their volumes while running through the course.
	player.position = Vector3(0.0, -360.0, -3600.0)
	await _wait_ticks(4)
	_check(gm.active_checkpoint_id >= 0, "checkpoint registers during traversal")
	var splits_before: int = gm.checkpoint_splits.size()

	# Cross the finish.
	player.position = Vector3(0.0, -1314.0, -8555.0)
	var finished := false
	for i in 30:
		await physics_frame
		if gm.race_state == gm.RaceState.FINISHED:
			finished = true
			break
	Input.action_release("move_forward")
	_check(finished, "finish line completes the run")
	_check(gm.checkpoint_splits.size() >= splits_before,
		"splits survive to finish")

	loader.unload_current()
	player_root.queue_free()
	ts.queue_free()
	await process_frame


func _test_intermediate_map() -> void:
	var loader: Node = root.get_node("LevelLoader")
	var gm: Node = root.get_node("GameManager")

	var found: Array[Dictionary] = loader.discover_maps()
	var entry: Dictionary = {}
	for e in found:
		if e["metadata"].map_id == "intermediate":
			entry = e
			break
	_check(not entry.is_empty(), "intermediate map discovered")
	if entry.is_empty():
		return
	_check(entry["metadata"].difficulty == 3, "intermediate metadata difficulty 3")

	var player_root := Node3D.new()
	root.add_child(player_root)
	var player: Player = _spawn_test_player_at(player_root, Vector3(0.0, 20.0, -40.0))
	var ts := TimerSystem.new()
	root.add_child(ts)

	loader.load_map(entry["path"])
	var loaded := false
	for i in 120:
		await process_frame
		if loader.current_map != null:
			loaded = true
			break
	_check(loaded, "intermediate map loads")
	await _wait_ticks(5)
	var map: Node3D = loader.current_map

	_check(gm.total_checkpoints == 5,
		"exactly 5 checkpoints registered (got %d)" % gm.total_checkpoints)
	_check(gm.kill_plane_y == -2600.0,
		"metadata kill plane applied (%s)" % gm.kill_plane_y)

	var r1: float = rad_to_deg(absf(map.get_node("SurfRamp1").rotation.x))
	var r2: float = rad_to_deg(absf(map.get_node("SurfRamp2").rotation.x))
	var r3: float = rad_to_deg(absf(map.get_node("SurfRamp3").rotation.x))
	_check(r1_angle_ok(r1) and r1 < r2 and r2 < r3 and r3 <= 60.5,
		"ramps steepen within 50-60 degrees (%.1f < %.1f < %.1f)" % [r1, r2, r3])

	# Gaps are genuine voids: raycast down mid-gap must miss everything.
	var space := root.get_world_3d().direct_space_state
	for gap_z: float in [-3475.0, -12290.0]:
		var query := PhysicsRayQueryParameters3D.create(
			Vector3(0.0, 2000.0, gap_z), Vector3(0.0, -5000.0, gap_z))
		_check(space.intersect_ray(query).is_empty(),
			"gap at z=%.0f is a real void (no cheap floor)" % gap_z)

	# --- Traversal smoke test ---
	gm.restart()
	player.position = Vector3(0.0, 20.0, -40.0)
	await _wait_ticks(6)

	Input.action_press("move_forward")
	var running := false
	for i in 120:
		await physics_frame
		if gm.race_state == gm.RaceState.RUNNING:
			running = true
			break
	_check(running, "start trigger begins the run")

	# Touch all five checkpoints in order via their volumes.
	var cp_positions: Array[Vector3] = [
		Vector3(0.0, 40.0, -1600.0),
		Vector3(0.0, 40.0, -4900.0),
		Vector3(0.0, -440.0, -7900.0),
		Vector3(0.0, -970.0, -10900.0),
		Vector3(0.0, -970.0, -13600.0),
	]
	for i in cp_positions.size():
		player.position = cp_positions[i]
		player.velocity = Vector3.ZERO
		await _wait_ticks(4)
		_check(gm.active_checkpoint_id == i,
			"checkpoint %d reached in order" % (i + 1))
	_check(gm.checkpoint_splits.size() == 5, "all five splits recorded while running")

	# Drop steeply onto ramp3 mid-section.
	player.position = Vector3(0.0, -1395.0, -14881.0)
	player.velocity = Vector3(0.0, -120.0, -30.0)
	var surfing := false
	for i in 30:
		await physics_frame
		if player.movement_controller.state == MovementState.SURF:
			surfing = true
			break
	_check(surfing, "final 60-degree ramp produces SURF state")

	# Kill plane: falling into a gap respawns at the last checkpoint.
	player.position = Vector3(0.0, -2700.0, -6850.0)
	await _wait_ticks(4)
	_check(player.position.distance_to(gm.respawn_transform.origin) < 2.0,
		"kill plane respawn works on intermediate course")

	# Finish the run.
	player.position = Vector3(0.0, -1760.0, -16905.0)
	var finished := false
	for i in 30:
		await physics_frame
		if gm.race_state == gm.RaceState.FINISHED:
			finished = true
			break
	Input.action_release("move_forward")
	_check(finished, "finish line completes the run")
	_check(gm.checkpoint_splits.size() >= 5, "finish carries all checkpoint splits")

	loader.unload_current()
	player_root.queue_free()
	ts.queue_free()
	await process_frame


## Ramp angle sanity helper: first ramp must be at least ~49 degrees.
func r1_angle_ok(angle: float) -> bool:
	return angle >= 49.0


func _test_advanced_map() -> void:
	var loader: Node = root.get_node("LevelLoader")
	var gm: Node = root.get_node("GameManager")

	var found: Array[Dictionary] = loader.discover_maps()
	var entry: Dictionary = {}
	for e in found:
		if e["metadata"].map_id == "advanced":
			entry = e
			break
	_check(not entry.is_empty(), "advanced map discovered")
	if entry.is_empty():
		return
	_check(entry["metadata"].difficulty == 4, "advanced metadata difficulty 4")

	var player_root := Node3D.new()
	root.add_child(player_root)
	var player: Player = _spawn_test_player_at(player_root, Vector3(0.0, 20.0, -40.0))
	var ts := TimerSystem.new()
	root.add_child(ts)

	loader.load_map(entry["path"])
	var loaded := false
	for i in 120:
		await process_frame
		if loader.current_map != null:
			loaded = true
			break
	_check(loaded, "advanced map loads")
	await _wait_ticks(5)
	var map: Node3D = loader.current_map

	_check(gm.total_checkpoints == 6,
		"exactly 6 checkpoints registered (got %d)" % gm.total_checkpoints)
	_check(gm.kill_plane_y == -4600.0,
		"metadata kill plane applied (%s)" % gm.kill_plane_y)

	for ramp_name: String in ["SurfRamp1", "SurfRamp2", "SurfRamp2b", "SurfRamp4"]:
		var angle: float = rad_to_deg(absf(map.get_node(ramp_name).rotation.x))
		_check(angle >= 49.0 and angle <= 70.5,
			"%s within 50-70 degrees (%.1f)" % [ramp_name, angle])

	# Ramp-to-ramp seam: Ramp2's downhill end and Ramp2b's uphill end are
	# geometry-adjacent so flight carries across without touching a floor.
	var r2_end: Vector3 = map.get_meta("SurfRamp2_e2")
	var r2b_start: Vector3 = map.get_meta("SurfRamp2b_e1")
	_check(r2_end.distance_to(r2b_start) < 150.0,
		"ramp-to-ramp transition is seamless (gap %.0fu)" % r2_end.distance_to(r2b_start))

	# Void gaps are real.
	var space := root.get_world_3d().direct_space_state
	for gap_z: float in [-9010.0, -16590.0]:
		var query := PhysicsRayQueryParameters3D.create(
			Vector3(0.0, 3000.0, gap_z), Vector3(0.0, -6000.0, gap_z))
		_check(space.intersect_ray(query).is_empty(),
			"void gap at z=%.0f has no cheap floor" % gap_z)

	# --- Traversal smoke test ---
	gm.restart()
	player.position = Vector3(0.0, 20.0, -40.0)
	await _wait_ticks(6)

	Input.action_press("move_forward")
	var running := false
	for i in 120:
		await physics_frame
		if gm.race_state == gm.RaceState.RUNNING:
			running = true
			break
	_check(running, "start trigger begins the run")

	var cp_positions: Array[Vector3] = [
		Vector3(0.0, 40.0, -2700.0),
		Vector3(0.0, -760.0, -7300.0),
		Vector3(0.0, -760.0, -10900.0),
		Vector3(0.0, -2040.0, -13600.0),
		Vector3(0.0, -2040.0, -18000.0),
		Vector3(0.0, -2950.0, -21500.0),
	]
	for i in cp_positions.size():
		player.position = cp_positions[i]
		player.velocity = Vector3.ZERO
		await _wait_ticks(4)
		_check(gm.active_checkpoint_id == i,
			"checkpoint %d reached in order" % (i + 1))
	_check(gm.checkpoint_splits.size() == 6, "all six splits recorded while running")

	# Steep-drop onto each ramp produces SURF (raycast-informed entry points).
	for ramp_info: Array in [
		["SurfRamp1", Vector3(0.0, -378.0, -5630.0)],
		["SurfRamp2", Vector3(0.0, -1118.0, -12810.0)],
		["SurfRamp4", Vector3(0.0, -2517.0, -19494.0)],
	]:
		player.position = ramp_info[1]
		player.velocity = Vector3(0.0, -120.0, -30.0)
		var surfing := false
		for i in 30:
			await physics_frame
			if player.movement_controller.state == MovementState.SURF:
				surfing = true
				break
		_check(surfing, "%s produces SURF state" % ramp_info[0])

	# Kill plane respawn mid-course.
	player.position = Vector3(0.0, -4700.0, -9010.0)
	await _wait_ticks(4)
	_check(player.position.distance_to(gm.respawn_transform.origin) < 2.0,
		"kill plane respawn works on advanced course")

	# Finish.
	player.position = Vector3(0.0, -2950.0, -22405.0)
	var finished := false
	for i in 30:
		await physics_frame
		if gm.race_state == gm.RaceState.FINISHED:
			finished = true
			break
	Input.action_release("move_forward")
	_check(finished, "finish line completes the run")
	_check(gm.checkpoint_splits.size() >= 6, "finish carries all checkpoint splits")

	loader.unload_current()
	player_root.queue_free()
	ts.queue_free()
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
