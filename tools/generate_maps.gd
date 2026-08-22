extends SceneTree

## Regenerates all game maps + movement presets + dev bootstrap scenes.
## Run headlessly:
##   godot --headless --path . --script res://tools/generate_maps.gd
## Every map gets a WorldEnvironment (procedural sky) + directional sun.

var map: Node3D


# ------------------------------------------------------------ shared parts --
func _floor_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.93, 0.96)  # white geometry per design docs
	mat.roughness = 0.9
	return mat



func _static_body(body_name: String, size: Vector3, pos: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	body.add_child(shape)
	var visual := MeshInstance3D.new()
	visual.name = "Visual"
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = _floor_material()
	body.add_child(visual)
	body.position = pos
	map.add_child(body)
	return body


func _ramp(ramp_name: String, e1: Vector3, e2: Vector3, width: float) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = ramp_name
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	var span := e2 - e1
	var slope_len := span.length() * 1.08
	box.size = Vector3(width, 40.0, slope_len)
	shape.shape = box
	body.add_child(shape)
	var ramp_visual := MeshInstance3D.new()
	ramp_visual.name = "Visual"
	var ramp_mesh := BoxMesh.new()
	ramp_mesh.size = Vector3(width, 40.0, slope_len)
	ramp_visual.mesh = ramp_mesh
	ramp_visual.material_override = _floor_material()
	body.add_child(ramp_visual)
	var angle := rad_to_deg(atan(abs(span.y) / abs(span.z)))
	body.rotation.x = -deg_to_rad(angle)
	body.position = (e1 + e2) / 2.0 - Vector3(0.0, 14.0 / cos(deg_to_rad(angle)), 0.0)
	if map != null:
		map.set_meta("%s_e1" % ramp_name, e1)
		map.set_meta("%s_e2" % ramp_name, e2)
	map.add_child(body)
	return body


func _trigger(trigger_name: String, scene_path: String, pos: Vector3) -> void:
	var area: Area3D = (load(scene_path) as PackedScene).instantiate()
	area.name = trigger_name
	area.position = pos
	map.add_child(area)


func _checkpoint(cp_name: String, pos: Vector3) -> void:
	var cp: Area3D = (load("res://scenes/checkpoints/Checkpoint.tscn") as PackedScene).instantiate()
	cp.name = cp_name
	cp.position = pos
	map.add_child(cp)


func _marker(pos: Vector3) -> void:
	var respawn := Marker3D.new()
	respawn.name = "RespawnPoint"
	respawn.position = pos
	map.add_child(respawn)


func _sign(sign_name: String, text: String, pos: Vector3) -> void:
	var sign_node := Area3D.new()
	sign_node.name = sign_name
	sign_node.set_script(load("res://scripts/game/TutorialSign.gd"))
	sign_node.sign_text = text
	sign_node.position = pos
	var sshape := CollisionShape3D.new()
	sshape.name = "CollisionShape3D"
	var sphere := SphereShape3D.new()
	sphere.radius = 220.0
	sshape.shape = sphere
	sign_node.add_child(sshape)
	var label := Label3D.new()
	label.name = "SignLabel"
	label.position = Vector3(0.0, 90.0, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.4
	label.font_size = 48
	label.modulate = Color(1.0, 0.95, 0.6)
	sign_node.add_child(label)
	map.add_child(sign_node)


## Lighting + environment for every map (missing lights rendered the world
## as a uniform gray in earlier builds).
func _lighting() -> void:
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.24, 0.44, 0.76)
	sky_material.sky_horizon_color = Color(0.68, 0.79, 0.9)
	sky_material.ground_bottom_color = Color(0.14, 0.16, 0.2)
	sky_material.ground_horizon_color = Color(0.6, 0.66, 0.72)
	var sky := Sky.new()
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	we.environment = env
	map.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	map.add_child(sun)


func _finish_map(map_name: String) -> void:
	for child in map.get_children():
		if child.owner == null:
			child.owner = map
		for sub in child.get_children():
			if sub.owner == null and not str(sub.get_script()).ends_with("StartTrigger"):
				sub.owner = map
	var packed := PackedScene.new()
	print("%s pack: %s" % [map_name, error_string(packed.pack(map))])
	print("%s save: %s" % [map_name, error_string(
		ResourceSaver.save(packed, "res://scenes/maps/%s.tscn" % map_name))])


# ----------------------------------------------------------------- tutorial --

func build_tutorial() -> void:
	map = Node3D.new()
	map.name = "TutorialMap"
	var meta := MapMetadata.new()
	meta.map_id = "tutorial"
	meta.display_name = "Tutorial"
	meta.author = "Velocity Engine"
	meta.difficulty = 1
	meta.tags = PackedStringArray(["bhop", "surf", "air-strafe", "tutorial"])
	meta.movement_config_path = "res://resources/movement/casual.tres"
	map.set_meta("map_metadata", meta)

	_static_body("CourseFloor", Vector3(800.0, 100.0, 1700.0), Vector3(0.0, -50.0, -800.0))
	_static_body("LowerFloor", Vector3(800.0, 100.0, 700.0), Vector3(0.0, -464.0, -2100.0))

	# Surf ramp: 48-degree slab (must exceed the 45-degree walkable limit
	# unambiguously; exact 45 sat on the classification boundary).
	_ramp("SurfRamp", Vector3(0.0, 31.0, -1429.0), Vector3(0.0, -405.0, -1822.0), 400.0)

	_trigger("StartTrigger", "res://scenes/world/StartTrigger.tscn", Vector3(0.0, 50.0, -80.0))
	_trigger("FinishTrigger", "res://scenes/world/FinishTrigger.tscn", Vector3(0.0, -364.0, -2250.0))
	_marker(Vector3(0.0, 30.0, -40.0))

	_sign("BhopSign", "BUNNY HOP\nJump again the instant you land\nto keep your speed!",
		Vector3(180.0, 40.0, -300.0))
	_sign("StrafeSign", "AIR STRAFE\nWhile airborne hold W + A\nand turn your mouse left.",
		Vector3(180.0, 40.0, -950.0))
	_sign("SurfSign", "SURF\nHold A or D against the ramp\nand steer with your mouse.",
		Vector3(180.0, 40.0, -1350.0))

	_lighting()
	_finish_map("tutorial")


# ---------------------------------------------------------------- beginner --

func build_beginner() -> void:
	map = Node3D.new()
	map.name = "BeginnerMap"
	var meta := MapMetadata.new()
	meta.map_id = "beginner"
	meta.display_name = "Beginner"
	meta.author = "Velocity Engine"
	meta.difficulty = 2
	meta.tags = PackedStringArray(["bhop", "surf"])
	meta.movement_config_path = "res://resources/movement/default.tres"
	map.set_meta("map_metadata", meta)

	_static_body("FloorA", Vector3(800.0, 100.0, 2600.0), Vector3(0.0, -50.0, -1250.0))
	_static_body("FloorB", Vector3(800.0, 100.0, 1900.0), Vector3(0.0, -450.0, -3750.0))
	_static_body("FloorC", Vector3(800.0, 100.0, 1900.0), Vector3(0.0, -900.0, -5850.0))
	_static_body("FloorD", Vector3(800.0, 100.0, 2100.0), Vector3(0.0, -1400.0, -7900.0))

	_ramp("SurfRamp1", Vector3(0.0, 10.0, -2380.0), Vector3(0.0, -390.0, -2760.0), 800.0)
	_ramp("SurfRamp2", Vector3(0.0, -390.0, -4620.0), Vector3(0.0, -840.0, -5030.0), 800.0)
	_ramp("SurfRamp3", Vector3(0.0, -840.0, -6720.0), Vector3(0.0, -1340.0, -7140.0), 800.0)

	_trigger("StartTrigger", "res://scenes/world/StartTrigger.tscn", Vector3(0.0, 50.0, -80.0))
	_trigger("FinishTrigger", "res://scenes/world/FinishTrigger.tscn", Vector3(0.0, -1314.0, -8550.0))
	_checkpoint("Checkpoint1", Vector3(0.0, 40.0, -1200.0))
	_checkpoint("Checkpoint2", Vector3(0.0, -360.0, -3600.0))
	_checkpoint("Checkpoint3", Vector3(0.0, -810.0, -5800.0))
	_marker(Vector3(0.0, 30.0, -40.0))

	_lighting()
	_finish_map("beginner")


# ------------------------------------------------------------- intermediate --

func build_intermediate() -> void:
	map = Node3D.new()
	map.name = "IntermediateMap"
	var meta := MapMetadata.new()
	meta.map_id = "intermediate"
	meta.display_name = "Intermediate"
	meta.author = "Velocity Engine"
	meta.difficulty = 3
	meta.tags = PackedStringArray(["bhop", "surf", "air-strafe"])
	meta.movement_config_path = "res://resources/movement/default.tres"
	meta.kill_plane_y = -2600.0
	map.set_meta("map_metadata", meta)

	_static_body("FloorA", Vector3(340.0, 100.0, 3350.0), Vector3(0.0, -50.0, -1625.0))
	_static_body("FloorB", Vector3(340.0, 100.0, 2550.0), Vector3(0.0, -50.0, -4925.0))
	_static_body("FloorC", Vector3(340.0, 100.0, 2560.0), Vector3(0.0, -530.0, -7920.0))
	_static_body("FloorD", Vector3(340.0, 100.0, 2600.0), Vector3(0.0, -1060.0, -10800.0))
	_static_body("FloorE", Vector3(340.0, 100.0, 2220.0), Vector3(0.0, -1060.0, -13590.0))
	_static_body("FloorF", Vector3(340.0, 100.0, 2140.0), Vector3(0.0, -1850.0, -16130.0))

	_ramp("SurfRamp1", Vector3(0.0, 10.0, -6180.0), Vector3(0.0, -490.0, -6600.0), 340.0)
	_ramp("SurfRamp2", Vector3(0.0, -470.0, -9150.0), Vector3(0.0, -1020.0, -9535.0), 340.0)
	_ramp("SurfRamp3", Vector3(0.0, -1000.0, -14650.0), Vector3(0.0, -1800.0, -15112.0), 340.0)

	_trigger("StartTrigger", "res://scenes/world/StartTrigger.tscn", Vector3(0.0, 50.0, -80.0))
	_trigger("FinishTrigger", "res://scenes/world/FinishTrigger.tscn", Vector3(0.0, -1760.0, -16900.0))
	_checkpoint("Checkpoint1", Vector3(0.0, 40.0, -1600.0))
	_checkpoint("Checkpoint2", Vector3(0.0, 40.0, -4900.0))
	_checkpoint("Checkpoint3", Vector3(0.0, -440.0, -7900.0))
	_checkpoint("Checkpoint4", Vector3(0.0, -970.0, -10900.0))
	_checkpoint("Checkpoint5", Vector3(0.0, -970.0, -13600.0))
	_marker(Vector3(0.0, 30.0, -40.0))

	_lighting()
	_finish_map("intermediate")


# ----------------------------------------------------------------- advanced --

func build_advanced() -> void:
	map = Node3D.new()
	map.name = "AdvancedMap"
	var meta := MapMetadata.new()
	meta.map_id = "advanced"
	meta.display_name = "Advanced"
	meta.author = "Velocity Engine"
	meta.difficulty = 4
	meta.tags = PackedStringArray(["bhop", "surf", "air-strafe", "high-speed"])
	meta.movement_config_path = "res://resources/movement/default.tres"
	meta.kill_plane_y = -4600.0
	map.set_meta("map_metadata", meta)

	_static_body("FloorA", Vector3(360.0, 100.0, 5500.0), Vector3(0.0, -50.0, -2700.0))
	_static_body("FloorB", Vector3(360.0, 100.0, 3000.0), Vector3(0.0, -850.0, -7320.0))
	_static_body("FloorC", Vector3(360.0, 100.0, 3500.0), Vector3(0.0, -850.0, -10950.0))
	_static_body("FloorD", Vector3(360.0, 100.0, 3000.0), Vector3(0.0, -2130.0, -14900.0))
	_static_body("FloorE", Vector3(360.0, 100.0, 2500.0), Vector3(0.0, -2130.0, -18030.0))
	_static_body("FloorF", Vector3(360.0, 100.0, 3000.0), Vector3(0.0, -3040.0, -21100.0))

	_ramp("SurfRamp1", Vector3(0.0, 10.0, -5400.0), Vector3(0.0, -790.0, -5865.0), 360.0)
	_ramp("SurfRamp2", Vector3(0.0, -790.0, -12650.0), Vector3(0.0, -1490.0, -12977.0), 360.0)
	_ramp("SurfRamp2b", Vector3(0.0, -1480.0, -12990.0), Vector3(0.0, -2080.0, -13493.0), 360.0)
	_ramp("SurfRamp4", Vector3(0.0, -2090.0, -19330.0), Vector3(0.0, -2990.0, -19658.0), 360.0)

	_trigger("StartTrigger", "res://scenes/world/StartTrigger.tscn", Vector3(0.0, 50.0, -80.0))
	_trigger("FinishTrigger", "res://scenes/world/FinishTrigger.tscn", Vector3(0.0, -2950.0, -22400.0))
	_checkpoint("Checkpoint1", Vector3(0.0, 40.0, -2700.0))
	_checkpoint("Checkpoint2", Vector3(0.0, -760.0, -7300.0))
	_checkpoint("Checkpoint3", Vector3(0.0, -760.0, -10900.0))
	_checkpoint("Checkpoint4", Vector3(0.0, -2040.0, -13600.0))
	_checkpoint("Checkpoint5", Vector3(0.0, -2040.0, -18000.0))
	_checkpoint("Checkpoint6", Vector3(0.0, -2950.0, -21500.0))
	_marker(Vector3(0.0, 30.0, -40.0))

	_lighting()
	_finish_map("advanced")


# ------------------------------------------------------------------- extras --

func build_metadata_and_presets() -> void:
	var casual := MovementConfig.new()
	casual.jump_buffer_ms = 80.0
	casual.coyote_time_ms = 100.0
	casual.surf_angle_min_deg = 42.0
	casual.floor_max_angle_deg = 40.0  # 45-degree ramps count as surf walls on tutorial
	print("casual.tres: ", error_string(ResourceSaver.save(casual, "res://resources/movement/casual.tres")))

	for m: Array in [
		["tutorial", "Tutorial", 1, ["bhop", "surf", "air-strafe", "tutorial"], "res://resources/movement/casual.tres"],
		["beginner", "Beginner", 2, ["bhop", "surf"], "res://resources/movement/default.tres"],
		["intermediate", "Intermediate", 3, ["bhop", "surf", "air-strafe"], "res://resources/movement/default.tres"],
		["advanced", "Advanced", 4, ["bhop", "surf", "air-strafe", "high-speed"], "res://resources/movement/default.tres"],
	]:
		var meta := MapMetadata.new()
		meta.map_id = m[0]
		meta.display_name = m[1]
		meta.author = "Velocity Engine"
		meta.difficulty = m[2]
		meta.tags = PackedStringArray(m[3])
		meta.movement_config_path = m[4]
		print("%s metadata: %s" % [m[0], error_string(ResourceSaver.save(
			meta, "res://resources/maps/%s_metadata.tres" % m[0]))])


func build_dev_scenes() -> void:
	for dev: Array in [
		["dev_tutorial", "res://scenes/maps/tutorial.tscn"],
		["dev_beginner", "res://scenes/maps/beginner.tscn"],
		["dev_intermediate", "res://scenes/maps/intermediate.tscn"],
		["dev_advanced", "res://scenes/maps/advanced.tscn"],
	]:
		var dev_root := Node3D.new()
		dev_root.name = dev[0]
		var script := load("res://scripts/game/DevMain.gd")
		if script == null or not script.can_instantiate():
			push_error("DevMain.gd failed to compile; aborting dev scene generation")
			continue
		dev_root.set_script(script)
		dev_root.set("default_map", dev[1])
		var scene := PackedScene.new()
		var pack_err := scene.pack(dev_root)
		if pack_err != OK:
			push_error("%s pack failed: %s" % [dev[0], error_string(pack_err)])
			continue
		print("%s save: %s" % [dev[0], error_string(
			ResourceSaver.save(scene, "res://scenes/world/%s.tscn" % dev[0]))])


func _initialize() -> void:
	build_metadata_and_presets()
	build_tutorial()
	build_beginner()
	build_intermediate()
	build_advanced()
	build_dev_scenes()
	print("ALL MAPS REGENERATED")
	quit()
