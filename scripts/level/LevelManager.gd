extends Node
var current_level := 1
signal level_completed(level_id)
func load_level(level_id: int) -> void: current_level = maxi(1, level_id)
func restart_level() -> void: get_tree().reload_current_scene()
func complete_level() -> void: level_completed.emit(current_level)
func get_current_level() -> int: return current_level
