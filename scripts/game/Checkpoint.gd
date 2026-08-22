class_name Checkpoint
extends Area3D

## Checkpoint trigger volume (Gameplay Systems §6.2). Touching it updates the
## respawn point and records a race split. Registering with GameManager in
## _ready assigns sequential ids by scene-tree order.

@export var checkpoint_id: int = -1


func _ready() -> void:
	add_to_group("checkpoint")
	body_entered.connect(_on_body_entered)
	var game_manager := get_node_or_null("/root/GameManager")
	if game_manager != null and checkpoint_id < 0:
		checkpoint_id = game_manager.register_checkpoint(self)


func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	var game_manager := get_node_or_null("/root/GameManager")
	var elapsed := 0.0
	if game_manager != null:
		elapsed = game_manager.elapsed_seconds()
	var bus := get_node_or_null("/root/SignalBus")
	if bus != null:
		bus.checkpoint_reached.emit({
			"checkpoint_id": checkpoint_id,
			"position": global_position,
			"basis": global_basis,
			"time": elapsed,
		})
