extends Node
## Global game state coordinator. Keeps orchestration separate from gameplay systems.
signal game_paused_changed(is_paused: bool)
var is_paused := false
func toggle_pause() -> void:
 is_paused = not is_paused
 get_tree().paused = is_paused
 game_paused_changed.emit(is_paused)
