extends SceneTree

## Slice 2 diagnostic: channel ride scrub analysis.
## Spawns a rider at the beginner V-channel right wall, carves, prints
## entry/exit speeds + where it ran out, at three entry speeds.

var _p: CharacterBody3D
var _mc: Node
var _frames := 0

func _initialize() -> void:
	p_print_header()
	process_frame.connect(_tick)
	_mc = null
	var level := load("res://scenes/maps/beginner.tscn") as PackedScene
	var map := level.instantiate()
	root.add_child(map)
	_p = (load("res://scenes/player/Player.tscn") as PackedScene).instantiate()
	map.add_child(_p)
	_mc = _p.get_node("MovementController")

	for entry_speed in [240.0, 450.0, 700.0]:
		await _run_once(entry_speed)
	print("---")
	print("DIAG DONE")
	quit(0)


func p_print_header() -> void:
	print("BEGINNER CHANNEL DIAG (wall-side, steer into wall)")


func _run_once(speed: float) -> void:
	print("--- entry %s ---" % speed)
	_p.position = Vector3(140.0, -100.0, -2860.0)
	_p.rotation = Vector3.ZERO
	_p.velocity = Vector3(0.0, -80.0, -speed)
	_frames = 0
	var saw_surf := false
	var entry_v := -1.0
	var exit_v := -1.0
	var states := ""
	for i in 300:
		await physics_frame
		_frames += 1
		var st: int = _mc.state
		if i < 400: pass
		if st == 2:  # SURF
			if not saw_surf:
				saw_surf = true
				entry_v = Vector2(_p.velocity.x, _p.velocity.z).length()
			states += "S"
		elif saw_surf and st != 2:
			exit_v = Vector2(_p.velocity.x, _p.velocity.z).length()
			states += "X"
			if _p.is_on_floor():
				break
		else:
			states += "."
		if saw_surf and _p.position.z < -3200.0:
			exit_v = Vector2(_p.velocity.x, _p.velocity.z).length()
			break
	print("saw_surf=%s entry=%.0f exit=%.0f finalpos=%.0f,%.0f,%.0f states=...%s" % [
		saw_surf, entry_v, exit_v, _p.position.x, _p.position.y, _p.position.z,
		states.right(80)])
	_p.position = Vector3(6000.0, -10000.0, 6000.0)
	_p.velocity = Vector3.ZERO
	for i in 6:
		await physics_frame


func _tick() -> void:
	pass
