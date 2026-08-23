extends SceneTree

## Headless performance benchmark (Sprint 27). Tooling, not a pass/fail test:
##   godot --headless --path . --script res://tools/benchmark.gd
## Runs a scripted bhop+surf session at 100Hz and reports physics-step time
## percentiles plus a memory trend for docs/performance_profile.md.

const WARMUP_TICKS := 300        # 3s: let autoloads/particles settle
const SAMPLE_TICKS := 6000       # 60s of simulated play
const MEMORY_SAMPLES := 12       # spread across the sampled window

var _samples: Array[float] = []
var _memory_samples: Array[int] = []
var _script_samples: Array[float] = []
var _tick := 0


func _initialize() -> void:
	process_frame.connect(_run)


func _run() -> void:
	process_frame.disconnect(_run)

	# Optional isolation switches via OS environment: BENCH_NO_VFX=1 skips
	# particle/VFX work, BENCH_NO_MOVE=1 freezes the scripted inputs.
	var sm := root.get_node("/root/SaveManager")
	if OS.get_environment("BENCH_NO_VFX") != "":
		sm.set_setting("video/vfx_enabled", false)
	if OS.get_environment("BENCH_NO_INTERP") != "":
		ProjectSettings.set_setting("physics/common/physics_interpolation", false)
		print("[bench] physics interpolation disabled for this run")
	if OS.get_environment("BENCH_EMPTY") != "":
		# Environment floor: same sampling loop, no world, no player.
		for i in WARMUP_TICKS:
			await physics_frame
		var floor_samples: Array[float] = []
		for i in SAMPLE_TICKS:
			await physics_frame
			floor_samples.append(Performance.get_monitor(
				Performance.TIME_PHYSICS_PROCESS))
		floor_samples.sort()
		print("[bench] EMPTY-WORLD floor ms: p50=%.3f p95=%.3f" % [
			floor_samples[int(0.50 * float(floor_samples.size() - 1))] * 1000.0,
			floor_samples[int(0.95 * float(floor_samples.size() - 1))] * 1000.0])
		quit(0)
		return

	# --- World: flat floor + 55-degree ramp (surf + bhop mix) ---
	var world := Node3D.new()
	root.add_child(world)
	var floor_body := StaticBody3D.new()
	var fs := CollisionShape3D.new()
	var fb := BoxShape3D.new()
	fb.size = Vector3(8000.0, 100.0, 8000.0)
	fs.shape = fb
	fs.position.y = -50.0
	floor_body.add_child(fs)
	world.add_child(floor_body)

	var ramp := StaticBody3D.new()
	var rs := CollisionShape3D.new()
	var rb := BoxShape3D.new()
	rb.size = Vector3(1200.0, 40.0, 4000.0)
	rs.shape = rb
	ramp.add_child(rs)
	ramp.rotation.z = -deg_to_rad(55.0)
	ramp.position = Vector3(-1500.0, -60.0, 0.0)
	world.add_child(ramp)

	var player: Player = (load("res://scenes/player/Player.tscn") as PackedScene).instantiate()
	player.position = Vector3(0.0, 40.0, 0.0)
	world.add_child(player)

	# --- Scripted session: hold forward, auto-bhop via held jump, weave the
	# camera to simulate strafing, and drop onto the ramp mid-session ---
	var idle := OS.get_environment("BENCH_NO_MOVE") != ""
	if not idle:
		Input.action_press("move_forward")
		Input.action_press("jump")

	for i in WARMUP_TICKS:
		await physics_frame

	var memory_interval := SAMPLE_TICKS / MEMORY_SAMPLES
	var mem_min := 0
	var mem_max := 0

	while _tick < SAMPLE_TICKS:
		await physics_frame
		_tick += 1
		if not idle:
			# Strafe simulation: sweep yaw left/right on a ~4s period.
			player.rotation.y = sin(float(_tick) / 25.0) * 1.2
			if _tick == 2000:
				# Drop onto the ramp for a surf segment.
				player.position = Vector3(-1500.0, 250.0, 500.0)
				player.velocity = Vector3(200.0, -100.0, -100.0)
		if _tick % memory_interval == 0:
			var mem := int(Performance.get_monitor(Performance.MEMORY_STATIC))
			_memory_samples.append(mem)
			mem_min = mem if mem_min == 0 else mini(mem_min, mem)
			mem_max = maxi(mem_max, mem)
		else:
			_samples.append(
				Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
		_script_samples.append(float(player.movement_controller.last_script_step_us))

	if not idle:
		Input.action_release("move_forward")
		Input.action_release("jump")

	# --- Report ---
	_samples.sort()
	_script_samples.sort()
	var n := _samples.size()
	var sn := _script_samples.size()
	print("script-side controller us: p50=%.0f p95=%.0f max=%.0f" % [
		_script_samples[int(0.50 * (sn - 1))],
		_script_samples[int(0.95 * (sn - 1))],
		_script_samples[sn - 1]])
	print("--- benchmark results (headless, 100Hz, %d ticks) ---" % n)
	print("physics step ms: p50=%.3f p95=%.3f p99=%.3f max=%.3f" % [
		_percentile(0.50) * 1000.0, _percentile(0.95) * 1000.0,
		_percentile(0.99) * 1000.0, _samples[n - 1] * 1000.0])
	var first_mem: int = _memory_samples[0]
	var last_mem: int = _memory_samples[_memory_samples.size() - 1]
	print("memory static MB: start=%.1f end=%.1f min=%.1f max=%.1f growth=%.1f" % [
		first_mem / 1048576.0, last_mem / 1048576.0,
		mem_min / 1048576.0, mem_max / 1048576.0,
		(last_mem - first_mem) / 1048576.0])
	print("render fps (headless): %.0f" % Performance.get_monitor(
		Performance.TIME_FPS))
	world.queue_free()
	quit(0)


func _percentile(fraction: float) -> float:
	var index := clampi(int(fraction * float(_samples.size())), 0,
		_samples.size() - 1)
	return _samples[index]
