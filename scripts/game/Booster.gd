class_name Booster
extends Area3D

## CS2-style trigger_push (game layer, S1 Skypark slice).
## Sets the rider's velocity to an exact vector once per entry, then
## re-arms on exit so it cannot be farmed by sitting inside. Non-player
## bodies are ignored. Placer adds the CollisionShape3D, or a default
## sphere is built in _ready so bare fixtures still detect.

@export var boost_velocity: Vector3 = Vector3(0.0, 0.0, -1200.0)
@export var default_radius: float = 120.0

var _inside: Dictionary = {}


func _ready() -> void:
	_ensure_shape()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _ensure_shape() -> void:
	for child in get_children():
		if child is CollisionShape3D:
			return
	var holder := CollisionShape3D.new()
	holder.name = "CollisionShape3D"
	var sphere := SphereShape3D.new()
	sphere.radius = default_radius
	holder.shape = sphere
	add_child(holder)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	var id := body.get_instance_id()
	if _inside.has(id):
		return
	_inside[id] = true
	var p := body as CharacterBody3D
	if p != null:
		p.velocity = boost_velocity


func _on_body_exited(body: Node3D) -> void:
	_inside.erase(body.get_instance_id())
