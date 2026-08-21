extends Resource
class_name LevelData
@export var level_id := 1
@export var level_name := "Level 1"
@export var start_position := Vector3(0, 0.8, 5)
@export var gate_groups: Array[Dictionary] = []
@export var enemy_waves: Array[Dictionary] = []
@export var finish_position := Vector3(0, 0, -100)
