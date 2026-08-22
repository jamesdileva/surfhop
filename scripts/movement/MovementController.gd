class_name MovementController
extends Node

## Owns the physics tick: reads InputState, delegates to movement modules,
## writes velocity to the parent CharacterBody3D and calls move_and_slide()
## (architecture §8.2 pipeline).

const MODULES := [
	preload("res://scripts/movement/modules/Friction.gd"),
	preload("res://scripts/movement/modules/GroundMovement.gd"),
	preload("res://scripts/movement/modules/Gravity.gd"),
	preload("res://scripts/movement/modules/Velocity.gd"),
]

@export var config: MovementConfig

var state: int = MovementState.AIR

var _body: CharacterBody3D
var _camera: Camera3D
var _input_manager: Node
var _modules: Array[MovementModule] = []


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


func _physics_process(delta: float) -> void:
	if _body == null or config == null or _input_manager == null:
		return
	var input: InputState = _input_manager.get_state()
	state = MovementState.GROUND if _body.is_on_floor() else MovementState.AIR

	for module in _modules:
		if module.enabled_in_state(state):
			module.process(input, delta)

	# Stub jump until the Jump module arrives in Sprint 7.
	if state == MovementState.GROUND and input.jump_just_pressed:
		_body.velocity.y += config.jump_impulse

	_body.move_and_slide()


func get_velocity() -> Vector3:
	return _body.velocity


func set_velocity(new_velocity: Vector3) -> void:
	_body.velocity = new_velocity


func get_camera() -> Camera3D:
	return _camera
