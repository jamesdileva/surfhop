class_name MovementDebugger
extends Node3D

## Debug overlay: draws velocity and surface-normal arrows plus a state label,
## updated every physics tick (100Hz). Toggled via F1 (toggle_debug action);
## visibility persists through the movement/show_debug setting.

const STATE_NAMES := ["GROUND", "AIR", "SURF", "JUMP", "LAND", "FALL"]
const VELOCITY_SCALE: float = 0.15  # world units of arrow per u/s
const NORMAL_LENGTH: float = 64.0
const ARROW_HEAD: float = 12.0

@onready var _velocity_vector: MeshInstance3D = $VelocityVector
@onready var _normal_vector: MeshInstance3D = $NormalVector
@onready var _state_label: Label3D = $StateLabel

var _body: CharacterBody3D


func _ready() -> void:
	_body = get_parent() as CharacterBody3D
	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager != null:
		visible = bool(save_manager.get_setting("movement/show_debug"))
	var bus := get_node_or_null("/root/SignalBus")
	if bus != null:
		bus.settings_changed.connect(_on_settings_changed)
	var ui_manager := get_node_or_null("/root/UIManager")
	if ui_manager != null and ui_manager.has_method("register_debug_overlay"):
		ui_manager.register_debug_overlay(self)


func _on_settings_changed(key: String, value: Variant) -> void:
	if key == "movement/show_debug":
		visible = value


func _physics_process(_delta: float) -> void:
	if not visible or _body == null or _body.movement_controller == null:
		return
	global_position = _body.global_position
	_draw_arrow(_velocity_vector, Vector3.ZERO, _body.velocity * VELOCITY_SCALE)

	var controller: MovementController = _body.movement_controller
	var normal := Vector3.ZERO
	if controller.state == MovementState.SURF:
		normal = controller.get_surface_normal()
	elif controller.is_on_floor():
		normal = Vector3.UP
	_draw_arrow(_normal_vector, Vector3.ZERO, normal * NORMAL_LENGTH)

	var speed := int(Vector2(_body.velocity.x, _body.velocity.z).length())
	var state_name: String = STATE_NAMES[controller.state] \
		if controller.state < STATE_NAMES.size() else "?"
	_state_label.text = "%s\n%d u/s\nslope limit %.0f°" % [state_name, speed,
		rad_to_deg(_body.floor_max_angle)]


func _draw_arrow(mesh_instance: MeshInstance3D, from: Vector3, offset: Vector3) -> void:
	var mesh := mesh_instance.mesh as ImmediateMesh
	mesh.clear_surfaces()
	if offset.length_squared() < 1.0:
		return
	var dir := offset.normalized()
	var side := dir.cross(Vector3.UP)
	side = (side.normalized() if side.length_squared() > 0.001 else Vector3.RIGHT) * ARROW_HEAD
	var tip := from + offset

	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(from)
	mesh.surface_add_vertex(tip)
	mesh.surface_add_vertex(tip)  # head left barb
	mesh.surface_add_vertex(tip - dir * ARROW_HEAD + side)
	mesh.surface_add_vertex(tip)  # head right barb
	mesh.surface_add_vertex(tip - dir * ARROW_HEAD - side)
	mesh.surface_end()
