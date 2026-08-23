class_name WorldMaterials
extends Node

## Visual materials pass (architecture §16 aesthetic, Phase 6 P3): applies
## the neon-edge surface shader to every loaded map's meshes — tinted per
## map via MapMetadata.vertex_color_tint, falling back to a difficulty
## palette — and owns the shared WorldEnvironment (procedural skybox).
## SurfRamp* bodies are skipped: VisualEffects owns their glow shader.

const NEON_SHADER := preload("res://assets/shaders/neon_edge.gdshader")
const RAMP_PREFIX := "SurfRamp"

## Per-difficulty accent colors (1=casual .. 5=extreme).
const DIFFICULTY_TINTS := {
	1: Color(0.15, 0.85, 1.0),  # cyan
	2: Color(0.25, 1.0, 0.55),  # green
	3: Color(1.0, 0.8, 0.2),    # amber
	4: Color(1.0, 0.45, 0.15),  # orange
	5: Color(1.0, 0.15, 0.35),  # magenta
}


func _ready() -> void:
	_ensure_environment()
	var loader := get_node_or_null("/root/LevelLoader")
	if loader != null:
		# map_loaded fires after current_metadata is set (finalize order).
		loader.map_loaded.connect(_style_map)


func _ensure_environment() -> void:
	if get_node_or_null("WorldEnvironment") != null:
		return
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.02, 0.03, 0.08)
	sky_material.sky_horizon_color = Color(0.10, 0.14, 0.22)
	sky_material.ground_bottom_color = Color(0.01, 0.01, 0.03)
	sky_material.ground_horizon_color = Color(0.08, 0.11, 0.18)
	sky_material.sun_angle_max = 10.0
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_sky_contribution = 1.0
	world_env.environment = environment
	add_child(world_env)


## Tint resolution: explicit metadata tint wins; otherwise difficulty palette.
func tint_for_metadata(metadata: MapMetadata) -> Color:
	if metadata != null and metadata.vertex_color_tint != Color.WHITE:
		return metadata.vertex_color_tint
	var difficulty := 1
	if metadata != null:
		difficulty = clampi(metadata.difficulty, 1, 5)
	return DIFFICULTY_TINTS[difficulty]


func _style_map(map_node: Node) -> void:
	var loader := get_node_or_null("/root/LevelLoader")
	var metadata: MapMetadata = loader.current_metadata if loader != null else null
	var tint := tint_for_metadata(metadata)
	for body in _surface_bodies(map_node):
		for mesh in body.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := mesh as MeshInstance3D
			var material := ShaderMaterial.new()
			material.shader = NEON_SHADER
			mesh_instance.material_override = material
			mesh_instance.set_instance_shader_parameter("tint", tint)


## Every collision body that renders level geometry. SurfRamp* is excluded:
## its surfaces carry the interactive surf-glow shader instead.
func _surface_bodies(map_node: Node) -> Array[Node]:
	var result: Array[Node] = []
	for child in map_node.get_children():
		if child is StaticBody3D or child is AnimatableBody3D:
			if not String(child.name).begins_with(RAMP_PREFIX):
				result.append(child)
	return result
