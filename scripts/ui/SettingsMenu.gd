class_name SettingsMenu
extends CanvasLayer

## Full settings overlay (architecture §15): Graphics / Audio / Input /
## Gameplay tabs. All changes persist immediately to settings.cfg (bindings
## to bindings.cfg); engine-impacting settings apply live via
## SaveManager.apply_settings_to_engine(). Built programmatically; the .tscn
## is just a CanvasLayer root.

const FPS_CAPS := [0, 30, 60, 120, 144, 240]
const RESOLUTIONS := ["1280x720", "1600x900", "1920x1080", "2560x1440"]

var _tabs: TabContainer
var _rebind_awaiting: String = ""  # action name waiting for a key press
var _status: Label

@onready var _save_manager: Node = get_node("/root/SaveManager")
@onready var _audio_manager: Node = get_node("/root/AudioManager")
@onready var _input_manager: Node = get_node("/root/InputManager")
@onready var _ui_manager: Node = get_node("/root/UIManager")


func _ready() -> void:
	visible = false  # shown via UIManager.show_menu()
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var panel := PanelContainer.new()
	panel.name = "Panel"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(680, 500)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(panel)

	var column := VBoxContainer.new()
	column.name = "Column"
	panel.add_child(column)

	_tabs = TabContainer.new()
	_tabs.name = "Tabs"
	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_tabs)
	_build_graphics_tab()
	_build_audio_tab()
	_build_input_tab()
	_build_gameplay_tab()

	var footer := HBoxContainer.new()
	footer.name = "Footer"
	column.add_child(footer)
	var reset := Button.new()
	reset.name = "ResetButton"
	reset.text = "Reset to Defaults"
	reset.pressed.connect(_on_reset_defaults)
	footer.add_child(reset)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)
	var back := Button.new()
	back.name = "BackButton"
	back.text = "Back"
	back.pressed.connect(func() -> void: _ui_manager.close_menu())
	footer.add_child(back)

	_status = Label.new()
	_status.name = "StatusLine"
	column.add_child(_status)

	# No control keeps focus: keyboard events reach our handlers untouched
	# (no ui_accept double-activating buttons during rebinding).
	_disable_focus(root)


func _disable_focus(node: Node) -> void:
	if node is Control:
		(node as Control).focus_mode = Control.FOCUS_NONE
	for child in node.get_children():
		_disable_focus(child)


## Re-syncs every control from current settings/menu state (called on open).
func refresh_all() -> void:
	if _tabs == null:
		return
	var fullscreen := bool(_save_manager.get_setting("graphics/fullscreen"))
	(_tabs.get_node("Graphics/FullscreenToggle") as CheckButton) \
		.button_pressed = fullscreen
	(_tabs.get_node("Graphics/VsyncToggle") as CheckButton).button_pressed = \
		bool(_save_manager.get_setting("graphics/vsync"))
	(_tabs.get_node("Graphics/FpsCapRow/FpsCapOption") as OptionButton) \
		.selected = FPS_CAPS.find(int(_save_manager.get_setting("graphics/fps_cap")))
	var res_option: OptionButton = _tabs.get_node(
		"Graphics/ResolutionRow/ResolutionOption")
	res_option.selected = RESOLUTIONS.find(
		str(_save_manager.get_setting("video/resolution")))
	res_option.disabled = fullscreen
	for bus_name: String in ["Master", "Music", "SFX"]:
		var slider: HSlider = _tabs.get_node("Audio/%sRow/%sSlider" % [bus_name, bus_name])
		slider.set_value_no_signal(float(_audio_manager.get_volume(bus_name)))
	var station_option: OptionButton = _tabs.get_node(
		"Audio/MusicStationRow/MusicStationOption")
	station_option.clear()
	var current_station := str(_save_manager.get_setting("audio/music_track"))
	var stations := _music_stations()
	var selected_station := 0
	for i: int in stations.size():
		station_option.add_item(stations[i])
		if stations[i] == current_station:
			selected_station = i
	station_option.select(selected_station)
	for action: String in _input_manager.ACTIONS:
		var button: Button = _tabs.get_node("Input/%sRow/BindButton" % action)
		button.text = binding_text(action)
	(_tabs.get_node("Gameplay/DebugToggle") as CheckButton).button_pressed = \
		_ui_manager.debug_visible
	(_tabs.get_node("Gameplay/GhostSaveToggle") as CheckButton).button_pressed \
		= bool(_save_manager.get_setting("gameplay/auto_save_ghost"))
	set_rebind_status("")


func set_rebind_status(text: String) -> void:
	_status.text = text


# ------------------------------------------------------------------ tabs --

func _build_graphics_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Graphics"
	_tabs.add_child(tab)

	var fullscreen := CheckButton.new()
	fullscreen.name = "FullscreenToggle"
	fullscreen.text = "Fullscreen"
	fullscreen.button_pressed = bool(
		_save_manager.get_setting("graphics/fullscreen"))
	fullscreen.toggled.connect(_on_setting_bool.bind("graphics/fullscreen"))
	tab.add_child(fullscreen)

	var vsync := CheckButton.new()
	vsync.name = "VsyncToggle"
	vsync.text = "VSync"
	vsync.button_pressed = bool(_save_manager.get_setting("graphics/vsync"))
	vsync.toggled.connect(_on_setting_bool.bind("graphics/vsync"))
	tab.add_child(vsync)

	var fps_row := HBoxContainer.new()
	fps_row.name = "FpsCapRow"
	var fps_label := Label.new()
	fps_label.text = "FPS Cap"
	fps_label.custom_minimum_size.x = 200.0
	fps_row.add_child(fps_label)
	var fps := OptionButton.new()
	fps.name = "FpsCapOption"
	for cap: int in FPS_CAPS:
		fps.add_item("Uncapped" if cap == 0 else "%d FPS" % cap)
	fps.selected = FPS_CAPS.find(int(_save_manager.get_setting("graphics/fps_cap")))
	fps.item_selected.connect(_on_fps_cap_selected)
	fps_row.add_child(fps)
	tab.add_child(fps_row)

	var res_row := HBoxContainer.new()
	res_row.name = "ResolutionRow"
	var res_label := Label.new()
	res_label.text = "Resolution (windowed)"
	res_label.custom_minimum_size.x = 200.0
	res_row.add_child(res_label)
	var res := OptionButton.new()
	res.name = "ResolutionOption"
	for resolution: String in RESOLUTIONS:
		res.add_item(resolution)
	res.selected = RESOLUTIONS.find(str(_save_manager.get_setting("video/resolution")))
	res.disabled = bool(_save_manager.get_setting("graphics/fullscreen"))
	res.item_selected.connect(_on_resolution_selected)
	res_row.add_child(res)
	tab.add_child(res_row)


func _build_audio_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Audio"
	_tabs.add_child(tab)
	for bus_name: String in ["Master", "Music", "SFX"]:
		var row := HBoxContainer.new()
		row.name = "%sRow" % bus_name
		var label := Label.new()
		label.text = bus_name
		label.custom_minimum_size.x = 200.0
		row.add_child(label)
		var slider := HSlider.new()
		slider.name = "%sSlider" % bus_name
		slider.min_value = 0.0
		slider.max_value = 1.0
		slider.step = 0.05
		slider.value = float(_audio_manager.get_volume(bus_name))
		slider.custom_minimum_size.x = 340.0
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		slider.value_changed.connect(_on_volume_changed.bind(bus_name))
		row.add_child(slider)
		tab.add_child(row)

	# Music station picker: scans assets/audio/music/ so dropped tracks
	# appear without a rebuild (re-populated by refresh_all on open).
	var station_row := HBoxContainer.new()
	station_row.name = "MusicStationRow"
	var station_label := Label.new()
	station_label.text = "Music Station"
	station_label.custom_minimum_size.x = 200.0
	station_row.add_child(station_label)
	var station_option := OptionButton.new()
	station_option.name = "MusicStationOption"
	station_option.item_selected.connect(_on_music_station_selected)
	station_row.add_child(station_option)
	tab.add_child(station_row)


## Available stations: the virtual "placeholder" default plus every audio
## file basename in assets/audio/music/ (menu_placeholder is the internal
## fallback file, not a selectable station).
func _music_stations() -> Array[String]:
	var stations: Array[String] = ["placeholder"]
	var dir := DirAccess.open("res://assets/audio/music/")
	if dir != null:
		var found: Array[String] = []
		dir.list_dir_begin()
		var fname := dir.get_next()
		while fname != "":
			if not dir.current_is_dir():
				for ext: String in [".ogg", ".wav", ".mp3", ".tres"]:
					if fname.ends_with(ext) \
							and fname.get_basename() != "menu_placeholder":
						found.append(fname.get_basename())
						break
			fname = dir.get_next()
		found.sort()
		stations.append_array(found)
	return stations


func _on_music_station_selected(index: int) -> void:
	var option: OptionButton = _tabs.get_node(
		"Audio/MusicStationRow/MusicStationOption")
	var track := option.get_item_text(index)
	_save_manager.set_setting("audio/music_track", track)
	_save_manager.save_settings()
	_audio_manager.play_music(track)
	set_rebind_status("Music station: %s" % track)


func _build_input_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Input"
	_tabs.add_child(tab)
	var hint := Label.new()
	hint.text = "Click a binding, then press a key. Esc cancels."
	tab.add_child(hint)
	for action: String in _input_manager.ACTIONS:
		var row := HBoxContainer.new()
		row.name = "%sRow" % action
		var label := Label.new()
		label.text = humanize_action(action)
		label.custom_minimum_size.x = 200.0
		row.add_child(label)
		var bind_button := Button.new()
		bind_button.name = "BindButton"
		bind_button.text = binding_text(action)
		bind_button.pressed.connect(_on_rebind_pressed.bind(action))
		row.add_child(bind_button)
		tab.add_child(row)


func _build_gameplay_tab() -> void:
	var tab := VBoxContainer.new()
	tab.name = "Gameplay"
	_tabs.add_child(tab)

	var debug_toggle := CheckButton.new()
	debug_toggle.name = "DebugToggle"
	debug_toggle.text = "Debug Overlay (F1)"
	debug_toggle.button_pressed = _ui_manager.debug_visible
	debug_toggle.toggled.connect(func(on: bool) -> void:
		_ui_manager.set_debug_visible(on))
	tab.add_child(debug_toggle)

	var ghost_toggle := CheckButton.new()
	ghost_toggle.name = "GhostSaveToggle"
	ghost_toggle.text = "Auto-save PB Ghost"
	ghost_toggle.button_pressed = bool(
		_save_manager.get_setting("gameplay/auto_save_ghost"))
	ghost_toggle.toggled.connect(
		_on_setting_bool.bind("gameplay/auto_save_ghost"))
	tab.add_child(ghost_toggle)

	var tick_label := Label.new()
	tick_label.name = "TickRateLabel"
	tick_label.text = "Physics Tick Rate: %d Hz (engine-fixed)" \
		% int(_save_manager.get_setting("movement/tick_rate"))
	tab.add_child(tick_label)


# -------------------------------------------------------------- handlers --

func _on_setting_bool(value: bool, key: String) -> void:
	_save_manager.set_setting(key, value)
	_save_manager.save_settings()
	if key.begins_with("graphics/"):
		_save_manager.apply_settings_to_engine()
	if key == "graphics/fullscreen":
		var res_option: OptionButton = _tabs.get_node(
			"Graphics/ResolutionRow/ResolutionOption")
		res_option.disabled = value


func _on_fps_cap_selected(index: int) -> void:
	_save_manager.set_setting("graphics/fps_cap", FPS_CAPS[index])
	_save_manager.save_settings()
	_save_manager.apply_settings_to_engine()


func _on_resolution_selected(index: int) -> void:
	_save_manager.set_setting("video/resolution", RESOLUTIONS[index])
	_save_manager.save_settings()
	_save_manager.apply_windowed_resolution()


## Live preview: bus volume updates instantly, setting persists, and a UI
## blip plays so the change is audible.
func _on_volume_changed(value: float, bus_name: String) -> void:
	_audio_manager.set_volume(bus_name, value)
	_save_manager.set_setting(
		"audio/%s_volume" % bus_name.to_lower(), value)
	_save_manager.save_settings()
	_audio_manager.play_sfx("ui_click")


func _on_reset_defaults() -> void:
	_save_manager.reset_settings_to_defaults()
	for bus_name: String in ["Master", "Music", "SFX"]:
		_audio_manager.set_volume(bus_name,
			float(_save_manager.get_setting("audio/%s_volume"
				% bus_name.to_lower())))
	refresh_all()
	set_rebind_status("Settings restored to defaults.")


# ---------------------------------------------------------------- rebinding --

func _on_rebind_pressed(action: String) -> void:
	_rebind_awaiting = action
	set_rebind_status("Press a new key for '%s' (Esc cancels)"
		% humanize_action(action))


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# Esc closes the menu (or cancels an in-progress rebinding first).
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		if _rebind_awaiting != "":
			_rebind_awaiting = ""
			set_rebind_status("")
		else:
			_ui_manager.close_menu()
		return
	if _rebind_awaiting == "":
		return
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	get_viewport().set_input_as_handled()
	var action := _rebind_awaiting
	_rebind_awaiting = ""
	if key.physical_keycode == KEY_ESCAPE:
		set_rebind_status("")
		return
	var button: Button = _tabs.get_node("Input/%sRow/BindButton" % action)
	if _input_manager.rebind_action(action, key):
		button.text = binding_text(action)
		set_rebind_status("")
	else:
		set_rebind_status("%s is already in use" % binding_text(key))


# ----------------------------------------------------------------- helpers --

static func humanize_action(action: String) -> String:
	var parts := action.split("_", false)
	for i in parts.size():
		parts[i] = parts[i].capitalize()
	return " ".join(parts)


static func binding_text(event: Variant) -> String:
	if event is InputEventKey:
		var code := (event as InputEventKey).physical_keycode
		return OS.get_keycode_string(code) if code != KEY_NONE else "???"
	if event is String:
		return str(event)
	return "???"


## Current binding description for an action ("Space", "W", ...).
func binding_text_for_action(action: String) -> String:
	var events: Array = InputMap.action_get_events(action)
	for e: Variant in events:
		if e is InputEventKey:
			return binding_text(e)
	return "unbound" if events.is_empty() else binding_text(events[0])
