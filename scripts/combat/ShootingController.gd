extends Node
@export var fire_interval := 0.65
@export var enemy_fire_interval := 1.0
@export var max_simultaneous_shooters := 3
var timer := 0.0
var enemy_timer := 0.0
var host: Node3D
func _ready() -> void: host = get_parent()
func _process(delta: float) -> void:
 if not host or GameManager.is_paused: return
 timer -= delta; enemy_timer -= delta
 if timer <= 0.0 and not EnemyManager.active.is_empty(): _soldiers_fire(); timer = fire_interval
 if enemy_timer <= 0.0: _enemies_fire(); enemy_timer = enemy_fire_interval
func _soldiers_fire() -> void:
 var fired := 0
 for soldier in host.get_node("Formation").soldiers:
  if fired >= max_simultaneous_shooters or not soldier.is_alive(): continue
  var target := _nearest(soldier.global_position)
  if target: _fire(soldier.global_position + Vector3(0, 0.6, -0.5), target.global_position); fired += 1
func _enemies_fire() -> void:
 for enemy in EnemyManager.active:
  if enemy.active and is_instance_valid(enemy.target) and enemy.global_position.distance_to(enemy.target.global_position) <= enemy.attack_range:
   _fire(enemy.global_position + Vector3(0, 0.5, 0), enemy.target.global_position)
func _fire(pos: Vector3, target: Vector3) -> void:
 if host.projectile_pool.is_empty(): return
 var projectile: PooledProjectile = host.projectile_pool.pop_back()
 projectile.fire(pos, target); host.active_projectiles += 1
 projectile.released.connect(host._return_projectile.bind(projectile), CONNECT_ONE_SHOT)
func _nearest(pos: Vector3) -> PrototypeEnemy:
 var best: PrototypeEnemy; var distance := INF
 for enemy in EnemyManager.active:
  if is_instance_valid(enemy) and enemy.active and pos.distance_squared_to(enemy.global_position) < distance: best = enemy; distance = pos.distance_squared_to(enemy.global_position)
 return best
