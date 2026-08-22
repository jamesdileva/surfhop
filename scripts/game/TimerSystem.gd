class_name TimerSystem
extends Node

## Time-trial glue (Gameplay Systems §8). Wires StartTrigger/FinishTrigger
## scenes to the GameManager race state machine and provides time formatting.
## Triggers are plain Area3D nodes in groups ("start_trigger"/"finish_trigger");
## this component connects their body signals dynamically so maps need no
## scripting. Add one TimerSystem instance per map (or main scene).

const START_GROUP := "start_trigger"
const FINISH_GROUP := "finish_trigger"


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)
	for node in get_tree().root.find_children("*", "", true, false):
		_wire(node)


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


func _on_node_added(node: Node) -> void:
	_wire(node)


func _wire(node: Node) -> void:
	if not node is Area3D:
		return
	if node.is_in_group(START_GROUP) \
			and not node.body_exited.is_connected(_on_start_body_exited):
		node.body_exited.connect(_on_start_body_exited)
	elif node.is_in_group(FINISH_GROUP) \
			and not node.body_entered.is_connected(_on_finish_body_entered):
		node.body_entered.connect(_on_finish_body_entered)


func _on_start_body_exited(body: Node3D) -> void:
	if not is_inside_tree() or not body.is_in_group("player"):
		return
	var game_manager := get_node_or_null("/root/GameManager")
	if game_manager == null:
		return
	if game_manager.race_state == game_manager.RaceState.IDLE:
		game_manager.start_race()


func _on_finish_body_entered(body: Node3D) -> void:
	if not is_inside_tree() or not body.is_in_group("player"):
		return
	var game_manager := get_node_or_null("/root/GameManager")
	if game_manager == null:
		return
	if game_manager.race_state == game_manager.RaceState.RUNNING:
		game_manager.finish_race()


## Formats seconds as 0:00.000 (acceptance format for the timer display).
static func format_time(seconds: float) -> String:
	var minutes := int(seconds) / 60
	var remaining := seconds - float(minutes * 60)
	return "%d:%06.3f" % [minutes, remaining]
