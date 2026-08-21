extends Node

## Async map loading, unloading, transitions. Stub until Sprint 15 (Map Loading).

var current_map: Node = null


func load_map(_path: String) -> void:
	pass # Stub: implemented in Sprint 15 (Map Loading).


func unload_current() -> void:
	if current_map != null:
		current_map.queue_free()
		current_map = null
