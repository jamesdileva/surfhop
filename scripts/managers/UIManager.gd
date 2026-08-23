extends Node

## Menu navigation, HUD wiring, notifications. Phase 6 P1: stack-based menus
## (main / map_select / pause / results / settings) owned here as lazily
## instantiated scenes; gameplay sessions are driven through the Game scene.

const AVAILABLE_MENUS := ["main", "pause", "settings", "results", "credits", "map_select"]

const VISUAL_EFFECTS := preload("res://scripts/debug/VisualEffects.gd")
const WORLD_MATERIALS := preload("res://scripts/debug/WorldMaterials.gd")
const MENU_SCENES := {
	"main": preload("res://scenes/menus/MainMenu.tscn"),
	"pause": preload("res://scenes/menus/PauseMenu.tscn"),
	"results": preload("res://scenes/menus/ResultsScreen.tscn"),
	"map_select": preload("res://scenes/menus/MapSelect.tscn"),
	"settings": preload("res://scenes/menus/SettingsMenu.tscn"),
}

var current_menu: String = ""

## True while a menu-launched map session is running (Game.start_map .. return_to_menu).
## Gates the results screen so dev scenes and direct signal emissions don't
## pop menus.
var session_active: bool = false

var checkpoint_display: String = ""  # "Checkpoint N/M" (bound to HUD in Sprint 16)

var vfx_enabled: bool = true

var _hud: Node = null
var _vfx: Node = null
var _game: Node = null
var _menu_instances := {}  # menu name -> CanvasLayer
var _menu_stack: Array[String] = []


func _ready() -> void:
	# Menus must keep processing while the tree is paused.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager != null:
		debug_visible = bool(save_manager.get_setting("movement/show_debug"))
		vfx_enabled = bool(save_manager.get_setting("video/vfx_enabled"))
	# VisualEffects listens on SignalBus itself; UIManager owns the node and
	# the settings toggle.
	_vfx = VISUAL_EFFECTS.new()
	_vfx.name = "VisualEffects"
	add_child(_vfx)
	# WorldMaterials styles loaded maps (neon edges + tint) and owns the
	# shared skybox environment.
	var world_materials: Node = WORLD_MATERIALS.new()
	world_materials.name = "WorldMaterials"
	add_child(world_materials)
	# All menus are created up front and kept hidden: ResultsScreen must exist
	# to open itself on race_finished, and eager creation keeps show_menu()
	# side-effect-free for hidden layers.
	for menu_name: String in MENU_SCENES:
		var instance: Node = MENU_SCENES[menu_name].instantiate()
		add_child(instance)
		_menu_instances[menu_name] = instance


func _unhandled_input(event: InputEvent) -> void:
	# Esc resumes from the pause menu (opening pause is PlayerCamera's job;
	# SettingsMenu handles Esc for its own layer first).
	if event.is_action_pressed("ui_cancel") and current_menu == "pause":
		get_viewport().set_input_as_handled()
		close_menu()


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


## Opens a menu, pushing it onto the menu stack. Per-menu setup: pause stops
## the tree (timer freeze), everything else releases the mouse.
func show_menu(menu_name: String) -> void:
	assert(AVAILABLE_MENUS.has(menu_name), "Unknown menu: %s" % menu_name)
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null:
		audio_manager.play_sfx("ui_click")
	var instance: Node = _menu_instances[menu_name]
	instance.visible = true
	if instance.has_method("refresh_all"):
		instance.refresh_all()
	if not _menu_stack.has(menu_name):
		_menu_stack.append(menu_name)
	current_menu = menu_name
	match menu_name:
		"pause":
			get_tree().paused = true
			get_node("/root/GameManager").pause()
			set_mouse_captured(false)
		"settings", "main", "map_select":
			set_mouse_captured(false)
	print("UIManager: showing menu '%s'" % menu_name)


## Closes the top menu. An empty stack returns to gameplay: unpauses and
## recaptures the mouse (only when a session is actually running).
func close_menu() -> void:
	if _menu_stack.is_empty():
		return
	var closed: String = _menu_stack.pop_back()
	var instance: Node = _menu_instances.get(closed)
	if instance != null:
		instance.visible = false
	if closed == "pause":
		get_tree().paused = false
		get_node("/root/GameManager").resume()
	if _menu_stack.is_empty():
		current_menu = ""
		if session_active:
			set_mouse_captured(true)
	else:
		current_menu = _menu_stack.back()


## Hides every menu and empties the stack without resuming side effects.
func dismiss_menus() -> void:
	for menu_name: String in _menu_stack:
		var instance: Node = _menu_instances.get(menu_name)
		if instance != null:
			instance.visible = false
	_menu_stack.clear()
	current_menu = ""
	get_tree().paused = false


## Esc during gameplay opens pause; Esc again resumes.
func toggle_pause() -> void:
	if current_menu == "":
		show_menu("pause")
	elif current_menu == "pause":
		close_menu()


## Game scene registers itself on _ready (boot / map sessions).
func register_game(game: Node) -> void:
	_game = game


func get_game() -> Node:
	return _game


## Menu-flow entry point: dismiss menus and start the chosen map.
func launch_map(map_path: String) -> void:
	dismiss_menus()
	if _game != null:
		_game.start_map(map_path)


func set_mouse_captured(captured: bool) -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if captured \
		else Input.MOUSE_MODE_VISIBLE


func update_hud(data: Dictionary) -> void:
	pass # Stub: implemented in Sprint 16 (HUD).

## Checkpoint progress readout ("Checkpoint N/M"); HUD binds to this in Sprint 16.
func show_checkpoint_progress(reached: int, total: int) -> void:
	checkpoint_display = "Checkpoint %d/%d" % [reached, total]
