class_name MapSelect
extends CanvasLayer

## Map select grid (Phase 6 P1): lists every map discovered by LevelLoader
## with its difficulty; choosing one starts the race through Game.start_map().

const DIFFICULTY_LABELS := ["", "★", "★★", "★★★", "★★★★", "★★★★★"]

@onready var _ui_manager: Node = get_node("/root/UIManager")
@onready var _level_loader: Node = get_node("/root/LevelLoader")

var _rows_container: VBoxContainer


func _ready() -> void:
	visible = false  # shown via UIManager.show_menu()
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(560, 520)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(panel)

	var column := VBoxContainer.new()
	column.name = "Column"
	panel.add_child(column)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "SELECT MAP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	column.add_child(title)

	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)

	_rows_container = VBoxContainer.new()
	_rows_container.name = "Rows"
	_rows_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows_container)

	var back := Button.new()
	back.name = "BackButton"
	back.text = "Back"
	back.pressed.connect(func() -> void: _ui_manager.close_menu())
	column.add_child(back)

	_disable_focus(root)


## Rebuilds the map list from the loader (called every time the menu opens).
func refresh_all() -> void:
	if _rows_container == null:
		return
	for child in _rows_container.get_children():
		child.queue_free()
	for entry: Dictionary in _level_loader.discover_maps():
		_rows_container.add_child(_make_row(entry))
	if _rows_container.get_child_count() == 0:
		var empty := Label.new()
		empty.name = "EmptyLabel"
		empty.text = "No maps found."
		_rows_container.add_child(empty)


func _make_row(entry: Dictionary) -> Button:
	var meta: MapMetadata = entry["metadata"]
	var difficulty: String = DIFFICULTY_LABELS[clampi(meta.difficulty, 1, 5)]
	var button := Button.new()
	button.name = "%sButton" % meta.map_id
	button.text = "%s   %s" % [meta.display_name, difficulty]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(500, 52)
	button.pressed.connect(func() -> void:
		_ui_manager.launch_map(entry["path"]))
	return button


func _disable_focus(node: Node) -> void:
	if node is Control:
		(node as Control).focus_mode = Control.FOCUS_NONE
	for child in node.get_children():
		_disable_focus(child)
