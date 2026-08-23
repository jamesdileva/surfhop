extends SceneTree

const MAP_METADATA := preload("res://scripts/core/MapMetadata.gd")

## Generates the Endless Movement skatepark (Phase 7 E1):
##   godot --headless --path . --script res://tools/generate_endless_map.gd
## Creates resources/maps/endless_metadata.tres and scenes/maps/endless.tscn
## programmatically (resources are never hand-edited).

const RATE_FLOOR_SIZE := Vector3(8000, 100, 8000)


func _initialize() -> void:
	process_frame.connect(_run)


func _run() -> void:
	process_frame.disconnect(_run)
	_generate_metadata()
	var built: Node = _generate_map()
	print("ENDLESS MAP GENERATED")
	built.free()  # avoid leak noise at exit
	quit(0)


func _generate_metadata() -> void:
	var meta: Resource = MAP_METADATA.new()
	meta.map_id = "endless"
	meta.display_name = "Endless Skatepark"
	meta.author = "Velocity Engine"
	meta.difficulty = 2
	meta.tags = PackedStringArray(["endless", "surf", "bhop", "air-strafe"])
	meta.movement_config_path = "res://resources/movement/default.tres"
	meta.kill_plane_y = -2000.0
	var error := ResourceSaver.save(
		meta, "res://resources/maps/endless_metadata.tres")
	print("metadata saved: %s (error %d)" % ["endless_metadata.tres", error])


func _generate_map() -> Node:
	var root := Node3D.new()
	root.name = "EndlessPark"

	var meta: Resource = MAP_METADATA.new()
	meta.map_id = "endless"
	meta.display_name = "Endless Skatepark"
	meta.author = "Velocity Engine"
	meta.difficulty = 2
	meta.tags = PackedStringArray(["endless", "surf", "bhop", "air-strafe"])
	meta.movement_config_path = "res://resources/movement/default.tres"
	meta.kill_plane_y = -2000.0
	root.set_meta("map_metadata", meta)

	var spawn := Marker3D.new()
	spawn.name = "RespawnPoint"
	spawn.position = Vector3(0, 10, 3000)
	root.add_child(spawn)

	# Floor slab, top surface at y = 0.
	_add_box(root, "Floor", Vector3(0, -50, 0), RATE_FLOOR_SIZE)

	# --- Surf ramps (SurfRamp* prefix: glow shader, skipped by tinting) ---
	_add_box(root, "SurfRamp1", Vector3(0, -95, 1200),
		Vector3(1600, 40, 2200), Vector3(-50, 0, 0))
	_add_box(root, "SurfRamp2", Vector3(1900, -130, -400),
		Vector3(2200, 40, 1600), Vector3(0, 0, 60))
	_add_box(root, "SurfRamp3", Vector3(-1900, -75, -400),
		Vector3(2200, 40, 1600), Vector3(0, 0, -45))

	# --- Elevated platforms with walkable approach ramps ---
	# Platform A: top at y = 200, reached by a ~16-degree incline from the
	# floor to its southern edge.
	_add_box(root, "PlatformA", Vector3(0, 180, -2600),
		Vector3(1800, 40, 1800))
	_add_box(root, "UpRampA", Vector3(0, 88, -1180),
		Vector3(1200, 40, 1450), Vector3(-16, 0, 0))
	# Platform B: top at y = 340, steeper ~28-degree approach off Platform A.
	_add_box(root, "PlatformB", Vector3(0, 320, -5300),
		Vector3(1400, 40, 1400))
	_add_box(root, "UpRampB", Vector3(0, 245, -3950),
		Vector3(1000, 40, 1350), Vector3(-28, 0, 0))

	# --- Strafe corridor near spawn: carve speed between the walls ---
	_add_box(root, "CorridorWallL", Vector3(-700, 110, 2000),
		Vector3(60, 240, 2400))
	_add_box(root, "CorridorWallR", Vector3(700, 110, 2000),
		Vector3(60, 240, 2400))

	# pack() only serializes nodes owned by the root — assign ownership
	# through the whole tree first.
	_set_owner_recursive(root, root)
	var packed := PackedScene.new()
	packed.pack(root)
	var error := ResourceSaver.save(packed, "res://scenes/maps/endless.tscn")
	print("scene saved: %s (error %d)" % ["endless.tscn", error])
	return root


func _set_owner_recursive(node: Node, owner: Node) -> void:
	for child in node.get_children():
		child.owner = owner
		_set_owner_recursive(child, owner)


func _add_box(parent: Node3D, body_name: String, pos: Vector3,
		size: Vector3, rot_deg := Vector3.ZERO) -> void:
	var body := StaticBody3D.new()
	body.name = body_name
	body.position = pos
	body.rotation_degrees = rot_deg
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	body.add_child(mesh)
	parent.add_child(body)
