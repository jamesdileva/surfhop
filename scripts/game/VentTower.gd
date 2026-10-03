class_name VentTower
extends Area3D

## Updraft column (game layer, S1 Skypark slice): the tower that pushes
## riders back up. While the player overlaps, upward accel is added each
## physics tick, clamped to max_rise_speed. Enter/exit manage the
## "in_vent" group, which GameManager's kill plane honors (exempt inside
## the column). Builds its own cylinder from radius/height unless the
## placer added a shape.

@export var radius: float = 80.0
@export var height: float = 600.0
@export var lift_accel: float = 1500.0
@export var max_rise_speed: float = 700.0


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
	var column := CylinderShape3D.new()
	column.radius = radius
	column.height = height
	holder.shape = column
	add_child(holder)


func _physics_process(delta: float) -> void:
	for body in get_overlapping_bodies():
		if not body.is_in_group("player"):
			continue
		var p := body as CharacterBody3D
		if p == null:
			continue
		# Belt and suspenders with the enter signal: teleports can land a
		# body inside for a frame before body_entered fires.
		if not body.is_in_group("in_vent"):
			body.add_to_group("in_vent")
		p.velocity.y = minf(p.velocity.y + lift_accel * delta, max_rise_speed)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.add_to_group("in_vent")


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("in_vent"):
		body.remove_from_group("in_vent")
