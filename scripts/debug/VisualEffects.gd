class_name VisualEffects
extends Node

## Event-driven visual effects coordinator (architecture §16.4): landing and
## takeoff dust puffs, high-speed trail, surf-ramp glow. Listens on SignalBus
## with the same pattern as AudioManager. Every dynamic effect is gated by the
## video/vfx_enabled setting, toggled via UIManager.set_vfx_enabled().

const LANDING_EFFECT_SCENE := preload("res://scenes/props/LandingEffect.tscn")
const SPEED_TRAIL_SCENE := preload("res://scenes/props/SpeedTrail.tscn")
const SURF_RAMP_SHADER := preload("res://assets/shaders/surf_ramp.gdshader")

const RAMP_NAME_PREFIX := "SurfRamp"
const TRAIL_SPEED_THRESHOLD := 600.0
const LAND_MIN_FALL_SPEED := 150.0
const TAKEOFF_INTENSITY := 0.6
const POOL_SIZE := 6
const GLOW_FADE_PER_SEC := 2.0

var enabled := true

## Test/telemetry hook: {"land": n, "takeoff": n}.
var effects_spawned := {}
## Intensity of the most recent landing puff (scales with fall speed).
var last_land_intensity := 0.0

var _pool: Array[CPUParticles3D] = []
var _trail: CPUParticles3D
var _latest_speed := 0.0
var _surfing := false
var _glow := 0.0
var _active_ramp: GeometryInstance3D = null
var _ramp_meshes := {}  # StaticBody3D -> Array[GeometryInstance3D]
# Hot-path cache (Sprint 27): avoid a group query every render frame.
var _player_cache: Node3D = null


func _ready() -> void:
	# Deferred setup: UIManager constructs us during its own _ready, before
	# later autoloads (SaveManager, SignalBus) exist.
	call_deferred("_late_setup")


func set_enabled(value: bool) -> void:
	enabled = value
	if not value:
		if _trail != null:
			_trail.emitting = false
		if _active_ramp != null and is_instance_valid(_active_ramp):
			_active_ramp.set_instance_shader_parameter("glow", 0.0)


func _late_setup() -> void:
	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager != null:
		set_enabled(bool(save_manager.get_setting("video/vfx_enabled")))
	for i in POOL_SIZE:
		var puff: CPUParticles3D = LANDING_EFFECT_SCENE.instantiate()
		puff.emitting = false
		add_child(puff)
		_pool.append(puff)
	_trail = SPEED_TRAIL_SCENE.instantiate()
	_trail.emitting = false
	add_child(_trail)

	var bus := get_node_or_null("/root/SignalBus")
	if bus != null:
		bus.player_landed.connect(_on_player_landed)
		bus.player_takeoff.connect(_on_player_takeoff)
		bus.velocity_updated.connect(func(speed: float) -> void: _latest_speed = speed)
		bus.surf_entered.connect(_on_surf_entered)
		bus.surf_exited.connect(_on_surf_exited)
	# Surf-ramp glow: tag every SurfRamp* body's meshes with the shift shader
	# as they enter the tree (covers LevelLoader loads and dev scenes alike).
	get_tree().node_added.connect(_on_node_added)


func _process(delta: float) -> void:
	_update_trail()
	_update_glow(delta)


# ------------------------------------------------------------------ events --

func _on_player_landed(payload: Dictionary) -> void:
	if not enabled:
		return
	var fall_speed := absf(float(payload.get("fall_speed", 0.0)))
	if fall_speed < LAND_MIN_FALL_SPEED:
		return
	last_land_intensity = clampf(
		(fall_speed - LAND_MIN_FALL_SPEED) / 500.0, 0.35, 1.5)
	_spawn_puff(payload.get("position"), last_land_intensity)
	effects_spawned["land"] = int(effects_spawned.get("land", 0)) + 1


func _on_player_takeoff(payload: Dictionary) -> void:
	if not enabled:
		return
	_spawn_puff(payload.get("position"), TAKEOFF_INTENSITY)
	effects_spawned["takeoff"] = int(effects_spawned.get("takeoff", 0)) + 1


func _on_surf_entered(payload: Dictionary) -> void:
	_surfing = true
	_active_ramp = _find_ramp_mesh(payload.get("position"), payload.get("normal"))


func _on_surf_exited() -> void:
	_surfing = false  # intensity decays back to zero in _update_glow()


# ----------------------------------------------------------------- helpers --

func _spawn_puff(at: Variant, intensity: float) -> void:
	if not enabled or at == null:
		return
	var puff := _grab_pooled()
	puff.initial_velocity_min = 40.0 * intensity
	puff.initial_velocity_max = 130.0 * intensity
	puff.scale_amount_min = 0.8 * intensity
	puff.scale_amount_max = 2.2 * intensity
	puff.global_position = at
	puff.emitting = true
	puff.restart()


func _grab_pooled() -> CPUParticles3D:
	for p in _pool:
		if not p.emitting:
			return p
	return _pool[0]  # pool exhausted: recycle the oldest voice


func _update_trail() -> void:
	if _trail == null:
		return
	if _player_cache == null or not is_instance_valid(_player_cache):
		_player_cache = get_tree().get_first_node_in_group("player") as Node3D
	var fast := enabled and _player_cache != null \
		and _latest_speed > TRAIL_SPEED_THRESHOLD
	_trail.emitting = fast
	if fast:
		_trail.global_position = _player_cache.global_position


func _update_glow(delta: float) -> void:
	if _surfing:
		# Brightness scales with surf speed (architecture §16.4).
		_glow = clampf(0.35 + _latest_speed / 900.0, 0.35, 1.0)
	elif _glow > 0.0:
		_glow = maxf(0.0, _glow - GLOW_FADE_PER_SEC * delta)
	if _active_ramp != null:
		if not is_instance_valid(_active_ramp):
			_active_ramp = null
			return
		_active_ramp.set_instance_shader_parameter("glow", _glow if enabled else 0.0)
		if not _surfing and _glow <= 0.0:
			_active_ramp = null


func _on_node_added(node: Node) -> void:
	if node is StaticBody3D and String(node.name).begins_with(RAMP_NAME_PREFIX):
		_apply_ramp_shader.call_deferred(node)


## Deferred because children of a freshly entering body may not all be in the
## tree yet when node_added fires for the parent.
func _apply_ramp_shader(body: StaticBody3D) -> void:
	var meshes: Array[GeometryInstance3D] = []
	# Playtest P2: ramps carry the map's accent color as their BASE so they
	# read against the white floors at a glance (previously both were white
	# until the glow kicked in).
	var tint := _map_accent_tint()
	for child in body.find_children("*", "MeshInstance3D", true, false):
		var mesh := child as MeshInstance3D
		var mat := ShaderMaterial.new()
		mat.shader = SURF_RAMP_SHADER
		mesh.material_override = mat
		mesh.set_instance_shader_parameter("glow", 0.0)
		mesh.set_instance_shader_parameter("base_color", tint.darkened(0.45))
		mesh.set_instance_shader_parameter("glow_color", tint)
		meshes.append(mesh)
	_ramp_meshes[body] = meshes


## Map accent color (metadata tint or difficulty palette), resolved through
## WorldMaterials so the palette lives in exactly one place.
func _map_accent_tint() -> Color:
	var world_materials := get_node_or_null("/root/UIManager/WorldMaterials")
	var loader := get_node_or_null("/root/LevelLoader")
	var metadata: MapMetadata = loader.current_metadata if loader != null else null
	if world_materials != null and world_materials.has_method("tint_for_metadata"):
		return world_materials.tint_for_metadata(metadata)
	return Color(0.15, 0.85, 1.0)


## Resolves the ramp mesh under a surf contact point: raycast backwards along
## the surface normal to the touching body, then look up its tagged meshes.
func _find_ramp_mesh(at: Variant, normal: Variant) -> GeometryInstance3D:
	if at == null or normal == null:
		return null
	var space := get_tree().root.get_world_3d().direct_space_state
	var from: Vector3 = at + normal * 10.0
	var query := PhysicsRayQueryParameters3D.create(from, from - normal * 200.0)
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return null
	var body: Object = hit.get("collider")
	if body is StaticBody3D and _ramp_meshes.has(body):
		var meshes: Array = _ramp_meshes[body]
		return meshes[0] if not meshes.is_empty() else null
	return null
