class_name MainMenu
extends CanvasLayer

## Title screen (Phase 6 P1): Play -> map select, Settings, Quit. Owned by
## UIManager like the other menus; built programmatically.

@onready var _ui_manager: Node = get_node("/root/UIManager")


func _ready() -> void:
	visible = false  # shown via UIManager.show_menu()
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.05, 0.05, 0.08, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var column := VBoxContainer.new()
	column.name = "Column"
	column.set_anchors_preset(Control.PRESET_CENTER)
	column.grow_horizontal = Control.GROW_DIRECTION_BOTH
	column.grow_vertical = Control.GROW_DIRECTION_BOTH
	column.custom_minimum_size = Vector2(420, 0)
	column.add_theme_constant_override("separation", 14)
	root.add_child(column)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "VELOCITY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	column.add_child(title)

	var subtitle := Label.new()
	subtitle.name = "SubtitleLabel"
	subtitle.text = "bhop · air-strafe · surf time trials"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(1, 1, 1, 0.6)
	column.add_child(subtitle)

	column.add_child(_menu_button("PlayButton", "Play",
		func() -> void: _ui_manager.show_menu("map_select")))
	column.add_child(_menu_button("SettingsButton", "Settings",
		func() -> void: _ui_manager.show_menu("settings")))
	column.add_child(_menu_button("QuitButton", "Quit",
		func() -> void: get_tree().quit()))

	var version := Label.new()
	version.name = "VersionLabel"
	version.text = "dev build — v1.0 pending (Sprint P6)"
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.modulate = Color(1, 1, 1, 0.35)
	column.add_child(version)

	_disable_focus(root)


func _menu_button(button_name: String, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.name = button_name
	button.text = text
	button.custom_minimum_size = Vector2(0, 48)
	button.pressed.connect(action)
	return button


func _disable_focus(node: Node) -> void:
	if node is Control:
		(node as Control).focus_mode = Control.FOCUS_NONE
	for child in node.get_children():
		_disable_focus(child)


func refresh_all() -> void:
	pass  # static screen
