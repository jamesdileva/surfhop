extends Node

## HUD updates, menu navigation, notifications. Stub until Sprint 16 (HUD).

const AVAILABLE_MENUS := ["main", "pause", "settings", "results", "credits", "map_select"]

var current_menu: String = ""


func show_menu(menu_name: String) -> void:
	assert(AVAILABLE_MENUS.has(menu_name), "Unknown menu: %s" % menu_name)
	current_menu = menu_name
	print("UIManager: showing menu '%s'" % menu_name)


func update_hud(data: Dictionary) -> void:
	pass # Stub: implemented in Sprint 16 (HUD).
