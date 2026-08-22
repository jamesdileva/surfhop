class_name Player
extends CharacterBody3D

## Thin physics-body holder (architecture §17.1). All movement logic lives in
## the MovementController child; the camera rotates the body via PlayerCamera.

@onready var movement_controller: MovementController = $MovementController
@onready var player_camera: PlayerCamera = $PlayerCamera


func _ready() -> void:
	add_to_group("player")
