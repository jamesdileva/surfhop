class_name PauseMenu
extends CanvasLayer

## In-game pause overlay (Phase 6 P1). Esc during gameplay routes here via
## UIManager.toggle_pause(); the tree is paused while visible so the timer
## freezes and movement stops.

@onready var _ui_manager: Node = get_node("/root/UIManager")
@onready var _game_manager: Node = get_node("/root/GameManager")


func _ready() -> void:
	visible = false  # shown via UIManager.show_menu()
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.custom_minimum_size = Vector2(380, 0)
	column.add_theme_constant_override("separation", 12)
	root.add_child(column)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	column.add_child(title)

	column.add_child(_menu_button("ResumeButton", "Resume",
		func() -> void: _ui_manager.close_menu()))
	column.add_child(_menu_button("RestartButton", "Restart Run",
		func() -> void:
			_game_manager.player_restart()
			_ui_manager.close_menu()))
	column.add_child(_menu_button("SettingsButton", "Settings",
		func() -> void: _ui_manager.show_menu("settings")))
	column.add_child(_menu_button("QuitToMenuButton", "Quit to Menu",
		func() -> void: _ui_manager.get_game().return_to_menu()))
	column.add_child(_menu_button("QuitDesktopButton", "Quit to Desktop",
		func() -> void: get_tree().quit()))

	_disable_focus(root)


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


func refresh_all() -> void:
	pass  # static screen
