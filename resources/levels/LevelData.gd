extends Resource
class_name LevelData
@export var level_id := 1
@export var level_name := "Prototype Highway"
@export var player_start_position := Vector3.ZERO
@export var enemy_groups: Array[Dictionary] = []
@export var gates: Array[Dictionary] = []
@export var finish_position := Vector3(0, 0, -82)
