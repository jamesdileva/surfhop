class_name MovementController
extends Node

## Owns the physics tick: reads InputState, delegates to movement modules,
## writes velocity to the parent CharacterBody3D and calls move_and_slide()
## (architecture §8.2 pipeline).

const MODULES := [
	preload("res://scripts/movement/modules/Friction.gd"),
	preload("res://scripts/movement/modules/GroundMovement.gd"),
	preload("res://scripts/movement/modules/Gravity.gd"),
	preload("res://scripts/movement/modules/AirMovement.gd"),
	preload("res://scripts/movement/modules/Surf.gd"),
	preload("res://scripts/movement/modules/Collision.gd"),
	preload("res://scripts/movement/modules/Jump.gd"),
	preload("res://scripts/movement/modules/BunnyHop.gd"),
	preload("res://scripts/movement/modules/Velocity.gd"),
]

@export var config: MovementConfig

var state: int = MovementState.AIR

var _body: CharacterBody3D
var _camera: Camera3D
var _input_manager: Node
var _modules: Array[MovementModule] = []
var _collision: Collision
var _jump: Jump
var _surf: Surf


func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	_camera = _body.get_node_or_null("PlayerCamera") if _body != null else null
	_input_manager = get_node_or_null("/root/InputManager")
	if config == null:
		push_error("MovementController: no MovementConfig resource assigned")
		return
	# Surfaces steeper than floor_max_angle are treated as walls by
	# move_and_slide (grounded mode), which slides along them preserving
	# tangential velocity - exactly Source-style surf behavior. The Surf
	# module classifies such contacts via their slide-collision normals.
	_body.floor_max_angle = deg_to_rad(config.floor_max_angle_deg)
	_body.floor_stop_on_slope = false
	for module_class: Resource in MODULES:
		var module: MovementModule = module_class.new()
		module.init(self)
		_modules.append(module)
	_collision = _get_module(Collision)
	_jump = _get_module(Jump)
	_surf = _get_module(Surf)


## Friction multiplier for the next Friction module run. Defaults to full
## friction; BunnyHop lowers it on buffered landings (§2.5). Consumed once.
var friction_override: float = 1.0

var _was_in_contact: bool = false
var _steep_normal: Vector3 = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if _body == null or config == null or _input_manager == null:
		return
	var input: InputState = _input_manager.get_state()
	state = _resolve_state()

	for module in _modules:
		if module.enabled_in_state(state):
			module.process(input, delta)

	# friction_override applies to exactly one Friction run (§2.2): consume
	# it here so a value set by a later landing survives until the next tick.
	friction_override = 1.0

	var pre_move_velocity := _body.velocity
	_body.move_and_slide()

	# Post-move contact classification (architecture §8.2 pipeline). Surf
	# ramps are WALL contacts steeper than floor_max_angle; gravity pressing
	# the player into them each tick is what maintains the surf.
	_steep_normal = _collision.steep_normal()
	var on_floor_now := _collision.on_floor()
	var in_contact := on_floor_now or _steep_normal != Vector3.ZERO
	if in_contact and not _was_in_contact:
		var fall_speed := maxf(0.0, -pre_move_velocity.y)
		for module in _modules:
			module.on_land(pre_move_velocity, fall_speed)
	elif not in_contact and _was_in_contact:
		for module in _modules:
			module.on_takeoff(pre_move_velocity)
	_was_in_contact = in_contact


## State transitions come from post-move contact classification
## (architecture §9.3): walkable floors are GROUND, steep wall contacts are
## SURF, everything else is AIR.
func _resolve_state() -> int:
	if _collision.on_floor():
		return MovementState.GROUND
	if _steep_normal != Vector3.ZERO:
		return MovementState.SURF
	return MovementState.AIR


func is_on_floor() -> bool:
	return _collision.on_floor()


## Normal of the steep (surf ramp) contact from the last move_and_slide,
## or ZERO when not touching one.
func get_surface_normal() -> Vector3:
	return _steep_normal


func get_body() -> CharacterBody3D:
	return _body


## Entry point for jump application (also used by BunnyHop from Sprint 8).
func apply_jump_impulse() -> void:
	_jump.apply_jump_impulse()


func get_module(module_type: Variant) -> MovementModule:
	return _get_module(module_type)


func _get_module(module_type: Variant) -> MovementModule:
	for module in _modules:
		if is_instance_of(module, module_type):
			return module
	return null


func get_velocity() -> Vector3:
	return _body.velocity


func set_velocity(new_velocity: Vector3) -> void:
	_body.velocity = new_velocity


func get_camera() -> Camera3D:
	return _camera
