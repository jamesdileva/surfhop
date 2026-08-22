class_name TutorialSign
extends Area3D

## Proximity-revealed instruction sign for the tutorial map. The attached
## Label3D becomes visible while the player is inside the trigger radius.

@export_multiline var sign_text: String = ""

@onready var _label: Label3D = $SignLabel


func _ready() -> void:
	_label.text = sign_text
	_label.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_label.visible = true


func _on_body_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_label.visible = false
