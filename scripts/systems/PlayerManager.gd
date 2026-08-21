extends Node
signal soldiers_changed(value: int)
var soldier_count := 10
func add_soldiers(amount: int) -> void: set_soldier_count(soldier_count + amount)
func remove_soldiers(amount: int) -> void: set_soldier_count(soldier_count - amount)
func set_soldier_count(value: int) -> void:
 soldier_count = maxi(0, value); soldiers_changed.emit(soldier_count)
func get_soldier_count() -> int: return soldier_count
func apply_multiplier(factor: float) -> void: set_soldier_count(int(floor(soldier_count * factor)))
func apply_delta(amount: int) -> void: set_soldier_count(soldier_count + amount)
