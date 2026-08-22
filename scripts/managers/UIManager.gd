extends Node

## HUD updates, menu navigation, notifications. Stub until Sprint 16 (HUD).

const AVAILABLE_MENUS := ["main", "pause", "settings", "results", "credits", "map_select"]

var current_menu: String = ""

var checkpoint_display: String = ""  # "Checkpoint N/M" (bound to HUD in Sprint 16)

var debug_visible: bool = false
var _debug_overlay: Node = null


func _ready() -> void:
	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager != null:
		debug_visible = bool(save_manager.get_setting("movement/show_debug"))


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


func show_menu(menu_name: String) -> void:
	assert(AVAILABLE_MENUS.has(menu_name), "Unknown menu: %s" % menu_name)
	current_menu = menu_name
	print("UIManager: showing menu '%s'" % menu_name)


func update_hud(data: Dictionary) -> void:
	pass # Stub: implemented in Sprint 16 (HUD).

## Checkpoint progress readout ("Checkpoint N/M"); HUD binds to this in Sprint 16.
func show_checkpoint_progress(reached: int, total: int) -> void:
	checkpoint_display = "Checkpoint %d/%d" % [reached, total]
