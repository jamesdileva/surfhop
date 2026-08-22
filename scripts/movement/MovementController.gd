class_name MovementController
extends Node

## Owns the physics tick: reads InputState, delegates to movement modules,
## writes velocity to the parent CharacterBody3D and calls move_and_slide()
## (architecture §8.2 pipeline).

const MODULES := [
	preload("res://scripts/movement/modules/Friction.gd"),
	preload("res://scripts/movement/modules/GroundMovement.gd"),
	preload("res://scripts/movement/modules/Gravity.gd"),
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


func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	_camera = _body.get_node_or_null("PlayerCamera") if _body != null else null
	_input_manager = get_node_or_null("/root/InputManager")
	if config == null:
		push_error("MovementController: no MovementConfig resource assigned")
		return
	for module_class: Resource in MODULES:
		var module: MovementModule = module_class.new()
		module.init(self)
		_modules.append(module)
	_collision = _get_module(Collision)
	_jump = _get_module(Jump)
	_bunny_hop = _get_module(BunnyHop)


## Friction multiplier for the next Friction module run. Defaults to full
## friction; BunnyHop lowers it on buffered landings (§2.5). Consumed once.
var friction_override: float = 1.0

var _bunny_hop: BunnyHop
var _was_on_floor: bool = false


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

	# Post-move landing detection (architecture §8.2 pipeline).
	var on_floor_now := _collision.on_floor()
	if on_floor_now and not _was_on_floor:
		var fall_speed := maxf(0.0, -pre_move_velocity.y)
		_bunny_hop.on_landing(fall_speed)
	_was_on_floor = on_floor_now


## State transitions come from the Collision module's ground detection
## (architecture §9.3). SURF classification arrives in Sprint 10.
func _resolve_state() -> int:
	if _collision.on_floor():
		return MovementState.GROUND
	return MovementState.AIR


func is_on_floor() -> bool:
	return _collision.on_floor()


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
