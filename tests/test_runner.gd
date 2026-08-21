extends SceneTree

## Canonical headless test entry point. All test suites are reachable through
## this script: godot --headless --path . --script res://tests/test_runner.gd
## Exit code 0 + no ERROR lines in stdout = success.

var _failures: Array[String] = []
var _checks: int = 0


func _initialize() -> void:
	_test_autoloads_registered()
	_test_signal_bus_signals()
	_test_game_manager_race_state()
	_test_input_manager_no_input()
	_test_save_manager_defaults()
	_test_ui_manager_show_menu()

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
