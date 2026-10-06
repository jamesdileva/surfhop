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



func _static_body(body_name: String, size: Vector3, pos: Vector3,
		role := "floor") -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	# Two-tone role for WorldMaterials: "floor" (white neon) or "obstacle"
	# (dark base). Read at style time via body metadata.
	body.set_meta("surface_role", role)
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


func _ramp(ramp_name: String, e1: Vector3, e2: Vector3, width: float,
		ascending := false) -> StaticBody3D:
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
	# Descending ramps tilt one way, ascending kickers the other â€” a kicker
	# rotated as a descender becomes a steep drop that throws players into
	# the void (caught by the beginner traversal test).
	body.rotation.x = deg_to_rad(angle) if ascending else -deg_to_rad(angle)
	body.position = (e1 + e2) / 2.0 - Vector3(0.0, 14.0 / cos(deg_to_rad(angle)), 0.0)
	if map != null:
		map.set_meta("%s_e1" % ramp_name, e1)
		map.set_meta("%s_e2" % ramp_name, e2)
	map.add_child(body)
	return body


## CS-style V-channel junction (playtest P2 round 3): two opposing 56-degree
## banked surf walls meeting a flat bottom lip. Players fall in and carve
## face to face - walls can't be hopped over AT INTENDED SPEEDS like the old
## top-ridable slopes (catch distance grows with speed squared, so fast
## players flew right over them - and 600+ bhoppers still clear these
## channels too: accepted prehop expression, landings stay safe, audit M9).
## Face proportions follow the classic 512:384 CS ramp.
## base_y is the channel floor level (= the next platform's top).
func _surf_channel(prefix: String, center_z: float, length: float,
		base_y: float) -> void:
	var rad := deg_to_rad(34.0)  # wall tilt from vertical; face = 56 from horizontal
	var slope := 200.0           # half the face length (box local Y half-extent)
	var lip_half := 60.0
	# Lip deliberately breaks the SurfRamp prefix: it is FLOOR (white neon
	# treatment) so the channel reads ground-vs-wall by color (playtest P2).
	# Sunk 2u: lip tops elsewhere sit exactly coplanar with the floors they
	# meet, which flickers (audit m7) — a 2u step-down rides unnoticed.
	_static_body("Channel" + prefix.substr(8) + "Lip",
		Vector3(120.0, 40.0, length), Vector3(0.0, base_y - 22.0, center_z))
	for side: int in [-1, 1]:
		var wall := StaticBody3D.new()
		wall.name = prefix + ("R" if side > 0 else "L")
		var shape := CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		var box := BoxShape3D.new()
		box.size = Vector3(40.0, 400.0, length)
		shape.shape = box
		wall.add_child(shape)
		var visual := MeshInstance3D.new()
		visual.name = "Visual"
		var mesh := BoxMesh.new()
		mesh.size = Vector3(40.0, 400.0, length)
		visual.mesh = mesh
		visual.material_override = _floor_material()
		wall.add_child(visual)
		# Ridable face is the wall's inner big face (normal tilts up toward
		# the channel center at 56 degrees from horizontal).
		wall.rotation.z = -side * rad
		wall.position = Vector3(
			side * (lip_half + slope * sin(rad) + 20.0 * cos(rad)),
			base_y + slope * cos(rad) - 20.0 * sin(rad),
			center_z)
		map.add_child(wall)


## Standalone banked surf wall (obstacle course had no surfable geometry:
## flat tops and vertical faces don't glide). Same 56-degree face math as
## the channel walls, but a single face placed beside the main line so the
## bhop route stays pure — riders veer toward it, carve along it, exit with
## speed. face_x is where the ridable face plane sits at base level; side
## picks which side the wall body stands on (+1: body at +x, face toward -x).
func _surf_wall(wall_name: String, face_x: float, center_z: float,
		length: float, side: int, base_y: float, slope := 120.0) -> void:
	var rad := deg_to_rad(34.0)  # wall tilt from vertical; face = 56 from horizontal
	var wall := StaticBody3D.new()
	wall.name = wall_name
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(40.0, slope * 2.0, length)
	shape.shape = box
	wall.add_child(shape)
	var visual := MeshInstance3D.new()
	visual.name = "Visual"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(40.0, slope * 2.0, length)
	visual.mesh = mesh
	visual.material_override = _floor_material()
	wall.add_child(visual)
	wall.rotation.z = -side * rad
	wall.position = Vector3(
		face_x + side * (slope * sin(rad) + 20.0 * cos(rad)),
		base_y + slope * cos(rad) - 20.0 * sin(rad),
		center_z)
	map.add_child(wall)


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


## Lighting for every map (missing lights rendered the world as a uniform
## gray in earlier builds). Single-skybox contract: NO WorldEnvironment is
## baked — WorldMaterials owns the shared dark-sky env at runtime and strips
## any map-owned one on load. Only the sun ships with the map.
func _lighting() -> void:
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
	# Slice A: top sits AT CourseFloor top (was +31 floating 221u before
	# the edge) — same 48 deg line, walkers meet a 30u nub instead of a
	# 61u wall, and jump-overs land on the face below (drop-mounts).
	_ramp("SurfRamp", Vector3(0.0, 0.0, -1457.0), Vector3(0.0, -405.0, -1822.0), 400.0)

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
	meta.tags = PackedStringArray(["bhop", "flow"])
	meta.movement_config_path = "res://resources/movement/default.tres"
	# Playtest P2 fix: the old default (-1000) sliced through the descending
	# course (lowest surface -460); anything past ramp two insta-reset.
	meta.kill_plane_y = -950.0
	map.set_meta("map_metadata", meta)

	# Playtest P2 round 3 layout: V-channel surf junctions (CS-style). The
	# round-2 restoration proved the original top-ridable slopes unfixable at
	# speed — catch distance grows with speed squared, so fast players bhopped
	# clean over them. Channels are walls: riders fall in and carve face to
	# face at intended speeds (600+ bhop can still clear them lengthwise —
	# accepted, safe landing, audit M9), exiting with the speed
	# the frictionless faces build. Junctions are 600 deep (spacing = the
	# channel itself) with 250u drops.
	meta.kill_plane_y = -960.0
	map.set_meta("map_metadata", meta)

	_static_body("FloorA", Vector3(800.0, 100.0, 2600.0), Vector3(0.0, -50.0, -1250.0))
	_surf_channel("SurfRamp1", -2860.0, 600.0, -250.0)
	_static_body("FloorB", Vector3(800.0, 100.0, 1600.0), Vector3(0.0, -300.0, -3960.0))
	_surf_channel("SurfRamp2", -5170.0, 600.0, -500.0)
	_static_body("FloorC", Vector3(800.0, 100.0, 1600.0), Vector3(0.0, -550.0, -6220.0))
	_surf_channel("SurfRamp3", -7330.0, 600.0, -750.0)
	_static_body("FloorD", Vector3(800.0, 100.0, 1600.0), Vector3(0.0, -800.0, -8430.0))

	_trigger("StartTrigger", "res://scenes/world/StartTrigger.tscn", Vector3(0.0, 50.0, -80.0))
	_trigger("FinishTrigger", "res://scenes/world/FinishTrigger.tscn", Vector3(0.0, -710.0, -8700.0))
	_checkpoint("Checkpoint1", Vector3(0.0, 40.0, -1200.0))
	_checkpoint("Checkpoint2", Vector3(0.0, -210.0, -3960.0))
	_checkpoint("Checkpoint3", Vector3(0.0, -460.0, -6220.0))
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

	_static_body("FloorA", Vector3(340.0, 100.0, 3425.0), Vector3(0.0, -50.0, -1662.5))
	_static_body("FloorB", Vector3(340.0, 100.0, 2625.0), Vector3(0.0, -50.0, -4887.5))
	# Audit M2: extended 70u north (-6640 -> -6570) so SurfRamp1's face
	# meets FloorC top right at its edge (face crosses -480 ~6u past the
	# edge). Before, the face hit landing level 48u over the void and riders
	# fell short into the slab edge. CS2 rule: exit meets the next surface.
	_static_body("FloorC", Vector3(340.0, 100.0, 2630.0), Vector3(0.0, -530.0, -7885.0))
	_static_body("FloorD", Vector3(340.0, 100.0, 2690.0), Vector3(0.0, -1060.0, -10845.0))
	_static_body("FloorE", Vector3(340.0, 100.0, 2310.0), Vector3(0.0, -1060.0, -13545.0))
	_static_body("FloorF", Vector3(340.0, 100.0, 2140.0), Vector3(0.0, -1850.0, -16130.0))

	# Hop entries mount these faces (rising arc into the face, jump held);
	# the prow nubs sit ~10u above the approach slabs. M10c lips and tall
	# prows were both tried and reverted (audit verdict table): lips are
	# jumpable (capsule clears +75), tall prows softlock walkers at a 150u
	# wall and still can't catch speed flyovers (a steep face falls away
	# faster than gravity). Forcing comes from void-routing: sail-overs
	# fall to the kill plane, and the next floors sit beyond jump range.
	# Slice A: R1 BRIDGES its gap (e1 flush at FloorB's edge, e2 daylights
	# 35u over FloorC at its edge, 50.2 deg keeps R1<R2<R3). Jump-overs
	# land on the face below (drop-mounts) instead of skipping to FloorC;
	# only 700+ flyovers clear all 370u of it (accepted mega-skips).
	_ramp("SurfRamp1", Vector3(0.0, 0.0, -6200.0), Vector3(0.0, -445.0, -6570.0), 340.0)
	# Slice 2: R2's prow is EMBEDDED (e1 -535 vs slab top -480, R4 pattern).
	# Its old +10 nub's box-end cap trapped hop/cruise entries
	# phase-dependently (diag: same spawn ±40u mounted/stalled by hop-phase
	# luck) — riders pinned in SURF at the slab. The box's 8%-oversize end
	# corner rises ~32u above e1, so the embed must clear that, not just
	# e1: corner sits ~23u under the slab, face emerges past it, hop arcs
	# meet open face with nothing to clip early. 51.6 deg keeps R1<R2<R3.
	_ramp("SurfRamp2", Vector3(0.0, -535.0, -9150.0), Vector3(0.0, -1020.0, -9535.0), 340.0)
	_ramp("SurfRamp3", Vector3(0.0, -1000.0, -14650.0), Vector3(0.0, -1800.0, -15112.0), 340.0)

	# Slice 3: hop-entry telegraphs (SignR4 pattern, one per face). The
	# hop-mount is suite-proven but undiscoverable — riders cruise into
	# the nubs and stall. Right side, 40u above the slab, ~180u before
	# each prow.
	_sign("SignR1", "SURF RAMP\nHop onto the face\nand ride it down!", Vector3(140.0, 40.0, -6000.0))
	_sign("SignR2", "SURF RAMP\nHop onto the face\nand ride it down!", Vector3(140.0, -440.0, -8970.0))
	_sign("SignR3", "SURF RAMP\nHop onto the face\nand ride it down!", Vector3(140.0, -970.0, -14470.0))

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
	_static_body("FloorB", Vector3(360.0, 100.0, 3090.0), Vector3(0.0, -850.0, -7365.0))
	_static_body("FloorC", Vector3(360.0, 100.0, 3590.0), Vector3(0.0, -850.0, -10905.0))
	_static_body("FloorD", Vector3(360.0, 100.0, 3090.0), Vector3(0.0, -2130.0, -14945.0))
	# Audit M10b: extended 50u south so R4's face emerges from FloorE's top
	# (embedded prow, intermediate-R2 pattern) instead of floating 50u past
	# its edge over the void. Riders mount the emerging 70-degree face at
	# grade; no feed ramp, no interleave zone, no caps in the rider path.
	_static_body("FloorE", Vector3(360.0, 100.0, 2640.0), Vector3(0.0, -2130.0, -18010.0))
	_static_body("FloorF", Vector3(360.0, 100.0, 3000.0), Vector3(0.0, -3040.0, -21100.0))

	# Hop entries mount these faces (rising arc into the face, jump held).
	# Slice A: R1 LONG-BRIDGES (nub at FloorA's edge, 50.0 deg, 1115u run
	# diving under FloorB with a bridge transition at -6124). Jump-overs
	# land on the face (drop-mounts); only 1100+ clears it all (elite).
	_ramp("SurfRamp1", Vector3(0.0, 10.0, -5450.0), Vector3(0.0, -1317.0, -6565.0), 360.0)
	# Slice 2: R2's prow EMBEDDED (e1 -856 vs slab top -800, R4 pattern)
	# — same phase-trap cap as intermediate R2 (suite: mounted but pinned
	# at spawn). Corner rises ~35u above e1 (8% oversize + half-thickness),
	# so embed clears that: corner ~21u under the slab. 62.7 deg stays in
	# the 50-70 band; R2 e2, R2b seam, and drop-transfer untouched.
	_ramp("SurfRamp2", Vector3(0.0, -856.0, -12650.0), Vector3(0.0, -1490.0, -12977.0), 360.0)
	# Audit M10b: exit daylights over FloorD (was 80u buried — ride to the
	# bottom clipped into the slab). Same 50.0-degree family, shortened so
	# the face ends 16u above the top, 8u past its edge: launch off the end
	# and drop onto FloorD. Touchdown math holds at 0/320/600 entry speeds.
	_ramp("SurfRamp2b", Vector3(0.0, -1560.0, -12985.0), Vector3(0.0, -2064.0, -13408.0), 360.0)
	# Audit M10b: R4's top sits 25u down-face along the SAME 70-degree line
	# (e1 (-2114,-19339), e2 untouched): its box north end then rests flush
	# at FloorE's extended edge like intermediate R2's proven 1u prow.
	# Before, the box end hovered 25u above the slab directly in the cruise
	# lane — riders ground into it and bootstrap-stalled (no SURF in 200
	# ticks). Same line, same angle, entry unblocked.
	# Advanced R4: M10b flush anchor (e1 -2114,-19339), same 70-degree line,
	# box end flush at FloorE's extended edge (intermediate-R2 pattern).
	_ramp("SurfRamp4", Vector3(0.0, -2114.0, -19339.0), Vector3(0.0, -2990.0, -19658.0), 360.0)
	# Slice 2: R4 hop-entry sign (jump 350u, mount emerging face at grade).
	_sign("SignR4", "SURF RAMP\nHop onto the face\nand ride it down!", Vector3(150.0, -2040.0, -19150.0))
	# Slice 3: same telegraph for R1/R2 (right side, 40u above slab).
	_sign("SignR1", "SURF RAMP\nHop onto the face\nand ride it down!", Vector3(150.0, 40.0, -5270.0))
	_sign("SignR2", "SURF RAMP\nHop onto the face\nand ride it down!", Vector3(150.0, -760.0, -12470.0))

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


## S2 Skypark slice: CS2 trigger_push volume (Booster entity).
func _booster(booster_name: String, pos: Vector3, velocity: Vector3,
		radius: float) -> void:
	var b := Area3D.new()
	b.name = booster_name
	b.set_script(load("res://scripts/game/Booster.gd"))
	b.set("boost_velocity", velocity)
	b.set("default_radius", radius)
	b.position = pos
	map.add_child(b)


## S2 Skypark slice: updraft column (VentTower entity).
func _vent(vent_name: String, pos: Vector3, radius: float,
		height: float) -> void:
	var v := Area3D.new()
	v.name = vent_name
	v.set_script(load("res://scripts/game/VentTower.gd"))
	v.set("radius", radius)
	v.set("height", height)
	v.position = pos
	map.add_child(v)


# --------------------------------------------------------------- challenges --

## Oscillating wall/platform (AnimatableBody3D + MovingPlatform script).
# ------------------------------------------------------------- rollercoaster --
# Audit M10a: dedicated flow map. Start high, drop into linked surf faces
# with kickers and drop-transfers between them — no flat slogs. Pools
# double as checkpoints, catch zones, and launch pads. Angles progress
# 52 -> 58 -> 63 with a 68 finale; kickers are net-zero (up ~50-90,
# land back at grade into the next drop). Gravity stays 800 throughout:
# airtime comes from speed + geometry, never config tweaks.
func build_rollercoaster() -> void:
	map = Node3D.new()
	map.name = "RollercoasterMap"
	var meta := MapMetadata.new()
	meta.map_id = "rollercoaster"
	meta.display_name = "Rollercoaster"
	meta.author = "Velocity Engine"
	meta.difficulty = 3
	meta.tags = PackedStringArray(["surf", "flow", "air"])
	meta.movement_config_path = "res://resources/movement/default.tres"
	meta.kill_plane_y = -2600.0
	map.set_meta("map_metadata", meta)

	# Spawn platform + drop-in opener (48.7-degree face, prow mount).
	_static_body("SpawnPlatform", Vector3(400.0, 100.0, 500.0), Vector3(0.0, 550.0, 250.0))
	_ramp("SurfRampR1", Vector3(0.0, 595.0, -150.0), Vector3(0.0, 60.0, -620.0), 340.0)

	# Pool 1 catch + kicker launch pad. Short 26.6-degree face: a 320 cruise
	# barely exits it, so the transfer is tuned for real flow speed (450+,
	# which R1 + pool bhop always provides) — the kicker rewards speed.
	# North end starts 100u back along the face line, buried 45u deep inside
	# the pool slab: box end caps are walkable-angled walls, and a cap
	# sitting at grade in the rider's path perches them (trace-proven
	# stall). Buried start = clean emerging face, smooth mount.
	_static_body("Pool1", Vector3(400.0, 100.0, 900.0), Vector3(0.0, -50.0, -1050.0))
	# Renamed for style/shader matching: bodies with a SurfRamp prefix get the
	# dark-base + glow treatment (kickers read as ramps too). This was the
	# "hidden kicker" report — same white as the pool before the rename.
	_ramp("SurfRampKicker1", Vector3(0.0, -45.0, -1261.0), Vector3(0.0, 45.0, -1440.0), 250.0, true)

	# Transfer ramp 55 degrees, top meets the kicker flight (M10a anchor —
	# M10c's +75 raise was reverted: it perched the prow 145u over Pool1).
	_ramp("SurfRampR2", Vector3(0.0, 70.0, -1680.0), Vector3(0.0, -430.0, -2030.0), 320.0)

	# Pool 2 catch + drop-transfer to the 60-degree face (M7 pattern:
	# steeper exit path converges onto the shallower face below).
	_static_body("Pool2", Vector3(400.0, 100.0, 800.0), Vector3(0.0, -530.0, -2400.0))
	# R3 keeps its M10a prow (59.9°): the +75 raise here steepened it to
	# 62.7° and displaced the drop into P2 (rider grazed the raised prow,
	# trace-proven). Drop-transfer alignment beats lip-blocking mid-map.
	_ramp("SurfRampR3", Vector3(0.0, -510.0, -2060.0), Vector3(0.0, -1110.0, -2408.0), 300.0)

	# Pool 3 catch + optional banked carve wall on its east side.
	_static_body("Pool3", Vector3(520.0, 100.0, 700.0), Vector3(0.0, -1210.0, -2750.0))
	_surf_wall("SurfRampW1", 90.0, -2900.0, 400.0, 1, -1160.0)

	# Mini V-channel across the 100u gap onto Floor4 (beginner pattern).
	_surf_channel("SurfRampC", -3400.0, 400.0, -1410.0)
	_static_body("Floor4", Vector3(400.0, 100.0, 550.0), Vector3(0.0, -1460.0, -3875.0))

	# 65-degree finale ramp into the finish pool (M10a anchor — M10c raise
	# reverted: prow at -1325 stood too tall over Floor4 for the report).
	_ramp("SurfRampR4", Vector3(0.0, -1400.0, -3900.0), Vector3(0.0, -2000.0, -4180.0), 300.0)
	_static_body("Pool4", Vector3(400.0, 100.0, 600.0), Vector3(0.0, -2100.0, -4450.0))

	_trigger("StartTrigger", "res://scenes/world/StartTrigger.tscn", Vector3(0.0, 650.0, 150.0))
	_trigger("FinishTrigger", "res://scenes/world/FinishTrigger.tscn", Vector3(0.0, -2010.0, -4650.0))
	_checkpoint("Checkpoint1", Vector3(0.0, 40.0, -1050.0))
	_checkpoint("Checkpoint2", Vector3(0.0, -440.0, -2400.0))
	_checkpoint("Checkpoint3", Vector3(0.0, -1120.0, -2750.0))
	_checkpoint("Checkpoint4", Vector3(0.0, -1370.0, -3700.0))
	_checkpoint("Checkpoint5", Vector3(0.0, -2010.0, -4400.0))
	_marker(Vector3(0.0, 630.0, 300.0))

	_sign("DropSign", "FIRST DROP\nRun off the edge and ride\nthe big face down!",
		Vector3(180.0, 640.0, 150.0))
	_sign("KickerSign", "KICKER\nRide up it fast\nand fly to the next ramp!",
		Vector3(180.0, 40.0, -1200.0))
	_sign("WallSign", "CARVE WALL\nHop on and hold D\nto carve!",
		Vector3(150.0, -1080.0, -2600.0))

	_lighting()
	_finish_map("rollercoaster")


# ------------------------------------------------------------------ skypark --
# S2 Skypark slice: open fly-arena blockout (vision docs/open_maps_vision.md).
# Summit drop-in -> bowl -> terraced chains (kicker/catch, steep exit,
# booster gap) -> kill/respawn summit; vent tower recycles low misses to
# bowl level. No checkpoints/timer (arena; S3 wires top-speed scoring).
# Proven relatives reused: kicker->catch spacing copies rollercoaster's
# Kicker1->R2 pair (catch top +25, 240 past); drop-links are M7 family;
# hop entries are the slice-2 pattern.
func build_skypark() -> void:
	map = Node3D.new()
	map.name = "SkyparkMap"
	var meta := MapMetadata.new()
	meta.map_id = "skypark"
	meta.display_name = "Skypark"
	meta.author = "Velocity Engine"
	meta.difficulty = 3
	meta.tags = PackedStringArray(["surf", "flow", "air", "arena"])
	meta.movement_config_path = "res://resources/movement/default.tres"
	meta.kill_plane_y = -1600.0
	map.set_meta("map_metadata", meta)

	# Summit platform + embedded drop-in (47.6 deg; e1 40 under the top so
	# the 8%-oversize box corner stays buried — slice-2 cap-trap lesson).
	_static_body("Summit", Vector3(600.0, 100.0, 500.0), Vector3(0.0, 550.0, 250.0))
	_ramp("DropFace", Vector3(0.0, 560.0, 0.0), Vector3(0.0, 8.0, -505.0), 500.0)
	# Bowl playground.
	_static_body("BowlFloor", Vector3(1600.0, 100.0, 1450.0), Vector3(0.0, -50.0, -1175.0))

	# West kicker (26.6 deg, buried start) launches onto T1; surfing
	# resumes on T1FaceW below T1's south edge (EastFace pattern: faces
	# can never run along slab tops — steep faces bury within ~10u, so
	# edge-emerge past the edge and merge down into the lower slab).
	# Flush exit-meet onto T2 (M2 pattern). Kicker flights TRANSPORT.
	_ramp("WestKicker", Vector3(-400.0, -45.0, -1400.0), Vector3(-400.0, 45.0, -1579.0), 300.0, true)
	_ramp("T1FaceW", Vector3(-400.0, -490.0, -2605.0), Vector3(-400.0, -900.0, -2872.0), 300.0)
	# East face (58 deg) emerges BELOW the bowl south edge (R2 pattern):
	# mid-bowl hops sail over any open face steeper than ~50 (three
	# trace-proven identical misses), so the entry is an edge-drop mount.
	# Face merges into T1 top downstream (clean handoff, R4 family).
	_ramp("EastFace", Vector3(100.0, -40.0, -1905.0), Vector3(100.0, -490.0, -2185.0), 300.0)

	# Terrace 1 + kicker line (twin 26.7 deg): flights TRANSPORT to T2
	# (flat landings, huge targets) — mid-flight surf-catches of floaty
	# arcs are unmakable (trace-proven across 7 rounds: the 8% box corner
	# poisons every edge meeting). T2 south edge gap-hops onto T3 (50u
	# gap, 50 down — trivial hop, huge margins). T2->T3 grade change is
	# too small for surf faces (50u over any run is unwalkable-flat OR
	# buries instantly — both trace-proven dead); T3 is the runout.
	_static_body("Terrace1", Vector3(1600.0, 100.0, 1100.0), Vector3(0.0, -500.0, -2050.0))
	_ramp("KickerA", Vector3(-300.0, -495.0, -2300.0), Vector3(-300.0, -405.0, -2479.0), 250.0, true)
	_ramp("KickerB", Vector3(300.0, -495.0, -2300.0), Vector3(300.0, -405.0, -2479.0), 250.0, true)
	# S2 tuning: T2 runs long (to -3700) so hot catch exits land on it
	# instead of sailing the 700u slab into the void; T3 shifts south to
	# share exactly the edge (no coplanar overlap, audit m7).
	# S2 tuning: T2 runs to -3750 (slab-bridge under the nubs, R1's exact
	# 3-phase chain: nub-hop + slab-bridge + edge-drop — gap-hop mounts
	# proved phase-lottery). T3 adjacent at -3750 (50 step down, hops
	# cleanly; no coplanar, 50 apart).
	_static_body("Terrace2", Vector3(1600.0, 100.0, 1150.0), Vector3(0.0, -950.0, -3175.0))

	# Booster lane (opt-in east spur of T1): flight TRANSPORTS to T2,
	# surfing resumes on T2FaceC (same doctrine as the kicker line).
	# S2 tuning: (0,300,-800) lands mid-T2 — 1200 south overshot T2 onto
	# T3 directly (trace-proven). Sets exact vector, once per entry.
	_booster("Booster1", Vector3(650.0, -400.0, -2200.0), Vector3(0.0, 300.0, -800.0), 80.0)
	_static_body("Terrace3", Vector3(1600.0, 100.0, 900.0), Vector3(0.0, -1000.0, -4200.0))

	# Vent tower off the bowl centerline + top booster firing the south
	# Vent tower off the bowl centerline + top booster firing south:
	# flight TRANSPORTS to the bowl (lands ~-1760), surfing resumes on
	# the edge-drop VentCatch below (EastFace pattern, proven).
	_vent("VentTower1", Vector3(450.0, 0.0, -1500.0), 100.0, 750.0)
	# S2 tuning: short south push (vz -300) lands the flight on the bowl
	# inside the map (~-1750) — 500 overshot the bowl onto T1, stranding
	# riders below the VentCatch edge with no way back up (trace-proven).
	# Fully automatic still.
	_booster("VentHop", Vector3(450.0, 430.0, -1500.0), Vector3(0.0, -100.0, -300.0), 90.0)
	# Edge-drop face below the bowl south edge (EastFace copy, 58 deg):
	# hop off the edge, mount the emerging face, merge into T1.
	_ramp("VentCatch", Vector3(450.0, -40.0, -1905.0), Vector3(450.0, -490.0, -2185.0), 250.0)

	_marker(Vector3(0.0, 630.0, 350.0))

	_sign("DropSign", "SUMMIT DROP\nRide the face down\nand pick a line!",
		Vector3(200.0, 640.0, 100.0))
	_sign("KickerSignW", "KICKER\nRide up it fast\nand fly to T1!",
		Vector3(-250.0, 40.0, -1300.0))
	_sign("FaceSignW", "SURF RAMP\nHop off the edge\nand ride it down!",
		Vector3(-250.0, -410.0, -2420.0))
	_sign("EastSign", "SURF RAMP\nHop off the edge\nand ride it down!",
		Vector3(-200.0, 40.0, -1720.0))
	_sign("BoosterSign", "BOOSTER\nLine up and fly!\nHop the gap south!",
		Vector3(650.0, -410.0, -2050.0))
	_sign("VentSign", "VENT\nRide it to the top!\nDrop onto the face!",
		Vector3(300.0, 40.0, -1500.0))

	_lighting()
	_finish_map("skypark")


## Challenge 1: pillar slaloms, low walls, moving walls, narrow bridge.
func _moving_body(body_name: String, size: Vector3, pos: Vector3,
		axis: Vector3, amplitude: float, period: float) -> AnimatableBody3D:
	var body := AnimatableBody3D.new()
	body.name = body_name
	body.set_meta("surface_role", "obstacle")  # movers always read as obstacles
	body.set_script(load("res://scripts/game/MovingPlatform.gd"))
	body.move_axis = axis
	body.amplitude = amplitude
	body.period_seconds = period
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


## Challenge 1: pillar slaloms, low walls, moving walls, narrow bridge.
func build_challenge_oc() -> void:
	map = Node3D.new()
	map.name = "ObstacleCourseMap"
	var meta := MapMetadata.new()
	meta.map_id = "challenge_oc"
	meta.display_name = "Obstacle Course"
	meta.author = "Velocity Engine"
	meta.difficulty = 3
	meta.tags = PackedStringArray(["bhop", "obstacles"])
	meta.movement_config_path = "res://resources/movement/default.tres"
	meta.kill_plane_y = -1200.0
	map.set_meta("map_metadata", meta)

	_static_body("FloorA", Vector3(500.0, 100.0, 3100.0), Vector3(0.0, -50.0, -1500.0)) # y=0 z 50..-3050
	_static_body("FloorBridge", Vector3(150.0, 100.0, 1050.0), Vector3(0.0, -50.0, -3575.0)) # y=0 z -4100..-3050 (narrow!)
	_static_body("FloorC", Vector3(500.0, 100.0, 1500.0), Vector3(0.0, -50.0, -4850.0))  # y=0 z -4100..-5600

	# Banked surf wall on FloorC's right side (face at x=80, z -4550..-5050):
	# the map's only surfable geometry. Beside the main line so the bhop
	# route stays pure — veer right, hop onto the face (grounded contact
	# doesn't surf), and press D into it to carve. Face at 80 keeps the
	# whole body inside FloorC's ±250 bounds (was 90: 7u overhang).
	_surf_wall("SurfRampB1", 80.0, -4800.0, 500.0, 1, 0.0)

	# Pillar slalom 1. Sunk 2u: bodies resting exactly coplanar on floor
	# tops flicker (audit m7) — 2u embed reads identically in play.
	for x: float in [-150.0, 0.0, 150.0]:
		_static_body("PillarA%d" % int(x), Vector3(60.0, 300.0, 60.0), Vector3(x, 148.0, -800.0), "obstacle")
	# Low wall: bhop over it. Top at y=42 clears under the 56.25 jump apex
	# (the old 80-tall wall was only passable via the wall-climb exploit).
	_static_body("LowWall", Vector3(500.0, 44.0, 40.0), Vector3(0.0, 20.0, -1400.0), "obstacle")

	_trigger("StartTrigger", "res://scenes/world/StartTrigger.tscn", Vector3(0.0, 50.0, -80.0))
	_checkpoint("Checkpoint1", Vector3(0.0, 40.0, -1700.0))

	# Moving walls over the bridge approach (sunk 2u into the floor, m7).
	_moving_body("MovingWall1", Vector3(420.0, 200.0, 40.0), Vector3(0.0, 98.0, -2100.0),
		Vector3.RIGHT, 200.0, 4.0)
	_moving_body("MovingWall2", Vector3(420.0, 200.0, 40.0), Vector3(0.0, 98.0, -2500.0),
		Vector3.LEFT, 200.0, 5.0)

	# OC finale (playtest: the banked wall sat on the finish platform
	# reading random, course felt unfinished): kicker UP off FloorC,
	# fly to an ENTRY POOL, hop-mount a surf face ACROSS the void gap,
	# drop-link onto a dedicated FINISH slab. Kicker flights TRANSPORT
	# (flat landings — face-meetings of floaty arcs are unmakable, S2
	# doctrine); surfing resumes via the proven hop-mount. Slow riders
	# die in the FloorC gap (kill -> Checkpoint2, retry with speed).
	_ramp("SurfRampKickerF", Vector3(0.0, -45.0, -5350.0), Vector3(0.0, 45.0, -5529.0), 250.0, true)
	_static_body("EntryPool", Vector3(400.0, 100.0, 300.0), Vector3(0.0, -500.0, -6050.0))
	_ramp("SurfRampFinal", Vector3(0.0, -440.0, -6100.0), Vector3(0.0, -900.0, -6470.0), 300.0)
	_static_body("FinishSlab", Vector3(400.0, 100.0, 600.0), Vector3(0.0, -1000.0, -6700.0))
	_checkpoint("Checkpoint3", Vector3(0.0, -910.0, -6600.0))

	_trigger("FinishTrigger", "res://scenes/world/FinishTrigger.tscn", Vector3(0.0, -910.0, -6900.0))
	_checkpoint("Checkpoint2", Vector3(0.0, 40.0, -3600.0))
	_marker(Vector3(0.0, 30.0, -40.0))

	# Audit M8: telegraph the hop entry — grounded contact doesn't surf.
	_sign("SurfSign", "SURF WALL\nHop onto the banked face and hold D\nto carve along it.",
		Vector3(150.0, 40.0, -4300.0))
	_sign("KickerSign", "KICKER\nRide up it FAST\nand fly to the pool!",
		Vector3(150.0, 40.0, -5200.0))
	_sign("FinaleSign", "FINALE\nHop on and ride!\nAcross to finish!",
		Vector3(180.0, -410.0, -5950.0))

	_lighting()
	_finish_map("challenge_oc")


## Challenge 2: three narrow steep ramps; staying on them is the challenge.
func build_challenge_precision() -> void:
	map = Node3D.new()
	map.name = "PrecisionSurfMap"
	var meta := MapMetadata.new()
	meta.map_id = "challenge_precision"
	meta.display_name = "Precision Surf"
	meta.author = "Velocity Engine"
	meta.difficulty = 4
	meta.tags = PackedStringArray(["surf", "precision"])
	meta.movement_config_path = "res://resources/movement/default.tres"
	meta.kill_plane_y = -1800.0
	map.set_meta("map_metadata", meta)

	_static_body("StartFloor", Vector3(400.0, 100.0, 850.0), Vector3(0.0, -50.0, -375.0))   # y=0 z 50..-800
	_static_body("Pool1", Vector3(400.0, 100.0, 900.0), Vector3(0.0, -450.0, -1450.0))      # y=-400 z -1900..-1000
	_static_body("Pool2", Vector3(400.0, 100.0, 800.0), Vector3(0.0, -840.0, -2460.0))      # y=-790 z -2860..-2060
	_static_body("Pool3", Vector3(400.0, 100.0, 1100.0), Vector3(0.0, -1250.0, -3610.0))    # y=-1200 z -3160..-4060

	# SurfRamp* prefix: glow shader + dark base (skipped by floor tinting).
	# Exits daylight ABOVE their pools (audit B4/B5): the old lines ended
	# buried inside the pool slabs, so riding to the bottom meant clipping
	# into solid. Faces now end 15-40u above pool tops; riders launch off
	# the end and drop into the pool. Entries stay demanding (controlled
	# entry speed) — precision of entry IS this map's skill; exits into
	# solid never is.
	_ramp("SurfRampP1", Vector3(0.0, 10.0, -750.0), Vector3(0.0, -350.0, -1002.0), 150.0)  # ~55 deg
	_ramp("SurfRampP2", Vector3(0.0, -390.0, -1850.0), Vector3(0.0, -760.0, -2064.0), 150.0)  # ~60 deg
	# P3 re-angled 63 -> 60 (audit B4): at 63 no exit daylights over Pool3.
	# P3 re-angled 63 -> 60: at 63° no exit point can daylight over Pool3
	# (the line crosses pool-top level past the pool edge). 60° keeps the
	# steepest-in-map intent; difficulty now comes from placement (entry
	# over the void gap, 150-wide face).
	_ramp("SurfRampP3", Vector3(0.0, -790.0, -2840.0), Vector3(0.0, -1160.0, -3054.0), 150.0)  # ~60 deg

	# Slice A: speed-line telegraphs (faces are the fast line; flat pool
	# crossings are self-penalizing via the timer — geometry can't force
	# without breaking angle bands + daylight, so teach instead).
	_sign("SignP1", "FAST LINE\nSurf it!\nFlat is slow!", Vector3(100.0, 40.0, -650.0))
	_sign("SignP2", "FAST LINE\nSurf it!\nFlat is slow!", Vector3(100.0, -360.0, -1750.0))
	_sign("SignP3", "FAST LINE\nSurf it!\nFlat is slow!", Vector3(100.0, -750.0, -2740.0))

	_trigger("StartTrigger", "res://scenes/world/StartTrigger.tscn", Vector3(0.0, 50.0, -80.0))
	_trigger("FinishTrigger", "res://scenes/world/FinishTrigger.tscn", Vector3(0.0, -1160.0, -3800.0))
	_checkpoint("Checkpoint1", Vector3(0.0, -360.0, -1300.0))
	_checkpoint("Checkpoint2", Vector3(0.0, -750.0, -2400.0))
	_marker(Vector3(0.0, 30.0, -40.0))

	_lighting()
	_finish_map("challenge_precision")


## Challenge 3: one continuous flat line â€” pure bhop-chain and air-strafe test.
func build_challenge_speedrun() -> void:
	map = Node3D.new()
	map.name = "SpeedRunMap"
	var meta := MapMetadata.new()
	meta.map_id = "challenge_speedrun"
	meta.display_name = "Speed Run"
	meta.author = "Velocity Engine"
	meta.difficulty = 4
	meta.tags = PackedStringArray(["bhop", "air-strafe", "speed"])
	meta.movement_config_path = "res://resources/movement/default.tres"
	meta.kill_plane_y = -1000.0
	map.set_meta("map_metadata", meta)

	_static_body("Runway", Vector3(340.0, 100.0, 6550.0), Vector3(0.0, -50.0, -3225.0)) # y=0 z 50..-6500

	_trigger("StartTrigger", "res://scenes/world/StartTrigger.tscn", Vector3(0.0, 50.0, -80.0))
	_trigger("FinishTrigger", "res://scenes/world/FinishTrigger.tscn", Vector3(0.0, 40.0, -6200.0))
	_marker(Vector3(0.0, 30.0, -40.0))

	_lighting()
	_finish_map("challenge_speedrun")


# ------------------------------------------------------------------- extras --

func build_metadata_and_presets() -> void:
	var casual := MovementConfig.new()
	casual.jump_buffer_ms = 80.0
	casual.coyote_time_ms = 100.0
	# Threshold contract: both equal (floor_max is authoritative at runtime).
	casual.surf_angle_min_deg = 40.0
	casual.floor_max_angle_deg = 40.0  # 45-degree ramps count as surf walls on tutorial
	print("casual.tres: ", error_string(ResourceSaver.save(casual, "res://resources/movement/casual.tres")))

	for m: Array in [
		["tutorial", "Tutorial", 1, ["bhop", "surf", "air-strafe", "tutorial"], "res://resources/movement/casual.tres"],
		["beginner", "Beginner", 2, ["bhop", "surf"], "res://resources/movement/default.tres", -960.0],
		["intermediate", "Intermediate", 3, ["bhop", "surf", "air-strafe"], "res://resources/movement/default.tres"],
		["advanced", "Advanced", 4, ["bhop", "surf", "air-strafe", "high-speed"], "res://resources/movement/default.tres"],
		["challenge_oc", "Obstacle Course", 3, ["bhop", "obstacles"], "res://resources/movement/default.tres", -600.0],
		["challenge_precision", "Precision Surf", 4, ["surf", "precision"], "res://resources/movement/default.tres", -1800.0],
		["challenge_speedrun", "Speed Run", 4, ["bhop", "air-strafe", "speed"], "res://resources/movement/default.tres", -1000.0],
		["rollercoaster", "Rollercoaster", 3, ["surf", "flow", "air"], "res://resources/movement/default.tres", -2600.0],
		["skypark", "Skypark", 3, ["surf", "flow", "air", "arena"], "res://resources/movement/default.tres", -1600.0],
	]:
		var meta := MapMetadata.new()
		meta.map_id = m[0]
		meta.display_name = m[1]
		meta.author = "Velocity Engine"
		meta.difficulty = m[2]
		meta.tags = PackedStringArray(m[3])
		meta.movement_config_path = m[4]
		meta.kill_plane_y = m[5] if m.size() > 5 else -1000.0
		print("%s metadata: %s" % [m[0], error_string(ResourceSaver.save(
			meta, "res://resources/maps/%s_metadata.tres" % m[0]))])


func build_dev_scenes() -> void:
	for dev: Array in [
		["dev_tutorial", "res://scenes/maps/tutorial.tscn"],
		["dev_beginner", "res://scenes/maps/beginner.tscn"],
		["dev_intermediate", "res://scenes/maps/intermediate.tscn"],
		["dev_advanced", "res://scenes/maps/advanced.tscn"],
		["dev_challenge_oc", "res://scenes/maps/challenge_oc.tscn"],
		["dev_challenge_precision", "res://scenes/maps/challenge_precision.tscn"],
		["dev_challenge_speedrun", "res://scenes/maps/challenge_speedrun.tscn"],
		["dev_rollercoaster", "res://scenes/maps/rollercoaster.tscn"],
		["dev_skypark", "res://scenes/maps/skypark.tscn"],
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
	build_challenge_oc()
	build_challenge_precision()
	build_challenge_speedrun()
	build_rollercoaster()
	build_skypark()
	build_dev_scenes()
	print("ALL MAPS REGENERATED")
	quit()


