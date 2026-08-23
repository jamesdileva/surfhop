class_name ResultsScreen
extends CanvasLayer

## Post-race overlay (Phase 6 P1): finish time, PB callout, checkpoint splits,
## and next-step buttons. Reacts to race_finished only while a menu-driven
## game session is active (UIManager.session_active), so dev scenes and
## direct signal emissions are unaffected.

@onready var _ui_manager: Node = get_node("/root/UIManager")
@onready var _game_manager: Node = get_node("/root/GameManager")

var _time_label: Label
var _pb_label: Label
var _splits_label: Label


func _enter_tree() -> void:
	var bus := get_node_or_null("/root/SignalBus")
	if bus != null:
		bus.race_finished.connect(_on_race_finished)


func _exit_tree() -> void:
	var bus := get_node_or_null("/root/SignalBus")
	if bus != null and bus.race_finished.is_connected(_on_race_finished):
		bus.race_finished.disconnect(_on_race_finished)


func _ready() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.custom_minimum_size = Vector2(520, 0)
	column.add_theme_constant_override("separation", 10)
	root.add_child(column)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "FINISH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	column.add_child(title)

	_time_label = Label.new()
	_time_label.name = "TimeLabel"
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.add_theme_font_size_override("font_size", 40)
	column.add_child(_time_label)

	_pb_label = Label.new()
	_pb_label.name = "PbLabel"
	_pb_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pb_label.modulate = Color(1.0, 0.85, 0.2)
	column.add_child(_pb_label)

	_splits_label = Label.new()
	_splits_label.name = "SplitsLabel"
	_splits_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_splits_label.modulate = Color(1, 1, 1, 0.75)
	column.add_child(_splits_label)

	column.add_child(HSeparator.new())

	column.add_child(_menu_button("RetryButton", "Retry",
		func() -> void:
			_game_manager.player_restart()
			_ui_manager.close_menu()))
	column.add_child(_menu_button("MapSelectButton", "Map Select",
		func() -> void:
			_ui_manager.get_game().return_to_menu()
			_ui_manager.show_menu("map_select")))
	column.add_child(_menu_button("MenuButton", "Main Menu",
		func() -> void:
			_ui_manager.get_game().return_to_menu()))

	visible = false
	_disable_focus(root)


func _on_race_finished(payload: Dictionary) -> void:
	if not _ui_manager.session_active:
		return
	_time_label.text = TimerSystem.format_time(float(payload["time"]))
	if bool(payload["is_pb"]):
		_pb_label.text = "NEW PERSONAL BEST!"
	else:
		var save_manager := get_node_or_null("/root/SaveManager")
		var pb := INF
		if save_manager != null:
			pb = float(save_manager.get_pb(_game_manager.map_name))
		_pb_label.text = "PB --" if pb == INF \
			else "PB %s" % TimerSystem.format_time(pb)
	var splits: Array[float] = _game_manager.checkpoint_splits
	var split_texts: Array[String] = []
	for i in splits.size():
		split_texts.append("CP%d  %s" % [i + 1, TimerSystem.format_time(splits[i])])
	_splits_label.text = " · ".join(split_texts) if not split_texts.is_empty() \
		else "no checkpoints"
	_ui_manager.show_menu("results")


## Called by UIManager on every menu open; nothing to re-sync (labels are set
## from the finish event).
func refresh_all() -> void:
	pass


func _menu_button(button_name: String, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = text
	button.custom_minimum_size = Vector2(0, 46)
	button.pressed.connect(action)
	return button


func _disable_focus(node: Node) -> void:
	if node is Control:
		(node as Control).focus_mode = Control.FOCUS_NONE
	for child in node.get_children():
		_disable_focus(child)
