extends Node
var pool: Array[PrototypeEnemy] = []
var active: Array[PrototypeEnemy] = []
var enemy_scene: PackedScene
@export var warmup_size := 20
func setup(scene: PackedScene, target: Node3D = null) -> void:
 enemy_scene = scene
 for i in warmup_size: _create_pool_enemy(target)
func _create_pool_enemy(_target: Node3D) -> PrototypeEnemy:
 var enemy: PrototypeEnemy = enemy_scene.instantiate(); get_tree().current_scene.add_child(enemy); enemy.visible = false; enemy.active = false; pool.append(enemy); return enemy
func spawn_enemy(position: Vector3, target: Node3D = null) -> PrototypeEnemy:
 if pool.is_empty(): return null
 var enemy: PrototypeEnemy = pool.pop_back(); enemy.global_position = position; enemy.setup(target); active.append(enemy); enemy.defeated.connect(despawn_enemy.bind(enemy), CONNECT_ONE_SHOT); return enemy
func despawn_enemy(enemy: PrototypeEnemy) -> void:
 if not is_instance_valid(enemy) or not active.has(enemy): return
 active.erase(enemy); enemy.active = false; enemy.visible = false; pool.append(enemy)
func damage_enemy(enemy: PrototypeEnemy, damage: int) -> void:
 if active.has(enemy): enemy.take_damage(damage)
