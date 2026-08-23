extends Node

## HUD updates, menu navigation, notifications. Stub until Sprint 16 (HUD).

const AVAILABLE_MENUS := ["main", "pause", "settings", "results", "credits", "map_select"]

const VISUAL_EFFECTS := preload("res://scripts/debug/VisualEffects.gd")
const SETTINGS_MENU_SCENE := preload("res://scenes/menus/SettingsMenu.tscn")

var current_menu: String = ""

var checkpoint_display: String = ""  # "Checkpoint N/M" (bound to HUD in Sprint 16)

var vfx_enabled: bool = true

var _hud: Node = null
var _vfx: Node = null
var _settings_menu: Node = null
var _previous_menu: String = ""


func _ready() -> void:
	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager != null:
		debug_visible = bool(save_manager.get_setting("movement/show_debug"))
		vfx_enabled = bool(save_manager.get_setting("video/vfx_enabled"))
	# VisualEffects listens on SignalBus itself; UIManager owns the node and
	# the settings toggle.
	_vfx = VISUAL_EFFECTS.new()
	_vfx.name = "VisualEffects"
	add_child(_vfx)


## HUDController registers itself here on _ready.
func register_hud(hud: Node) -> void:
	_hud = hud
	hud.set_debug_visible(debug_visible)


func get_hud() -> Node:
	return _hud


func clear_hud() -> void:
	_hud = null

var debug_visible: bool = false
var _debug_overlay: Node = null


## MovementDebugger registers itself here on _ready.
func register_debug_overlay(overlay: Node) -> void:
	_debug_overlay = overlay
	overlay.visible = debug_visible


func toggle_debug() -> void:	set_debug_visible(not debug_visible)


func set_debug_visible(value: bool) -> void:
	debug_visible = value
	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager != null:
		save_manager.set_setting("movement/show_debug", value)
		save_manager.save_settings()
	if _debug_overlay != null:
		_debug_overlay.visible = value
	if _hud != null:
		_hud.set_debug_visible(value)


## Performance toggle for all visual effects (Sprint 25); persisted to
## video/vfx_enabled. UI binding lands in Sprint 26 (Settings menu).
func set_vfx_enabled(value: bool) -> void:
	vfx_enabled = value
	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager != null:
		save_manager.set_setting("video/vfx_enabled", value)
		save_manager.save_settings()
	if _vfx != null:
		_vfx.set_enabled(value)


func show_menu(menu_name: String) -> void:
	assert(AVAILABLE_MENUS.has(menu_name), "Unknown menu: %s" % menu_name)
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null:
		audio_manager.play_sfx("ui_click")
	current_menu = menu_name
	_previous_menu = ""
	if menu_name == "settings":
		if _settings_menu == null:
			_settings_menu = SETTINGS_MENU_SCENE.instantiate()
			add_child(_settings_menu)
		else:
			_settings_menu.visible = true
		_settings_menu.refresh_all()
		set_mouse_captured(false)
	print("UIManager: showing menu '%s'" % menu_name)


## Closes the current menu; returns to the previous one if there is a menu
## stack, otherwise back to gameplay (recaptures the mouse).
func close_menu() -> void:
	if current_menu == "":
		return
	var closed := current_menu
	current_menu = _previous_menu
	_previous_menu = ""
	if closed == "settings" and _settings_menu != null:
		_settings_menu.visible = false
	if current_menu != "":
		show_menu(current_menu)
	else:
		set_mouse_captured(true)


func set_mouse_captured(captured: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured \
		else Input.MOUSE_MODE_VISIBLE


func update_hud(data: Dictionary) -> void:
	pass # Stub: implemented in Sprint 16 (HUD).

## Checkpoint progress readout ("Checkpoint N/M"); HUD binds to this in Sprint 16.
func show_checkpoint_progress(reached: int, total: int) -> void:
	checkpoint_display = "Checkpoint %d/%d" % [reached, total]
