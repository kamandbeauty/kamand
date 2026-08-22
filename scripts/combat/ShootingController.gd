extends Node
@export var fire_interval := 0.65
@export var max_simultaneous_shooters := 3
var timer := 0.0
var host: Node3D
func _ready() -> void: host = get_parent()
func _process(delta: float) -> void:
 timer -= delta
 if timer > 0 or not host or EnemyManager.active.is_empty(): return
 timer = fire_interval
 var fired := 0
 for soldier in host.get_node("Formation").soldiers:
  if fired >= max_simultaneous_shooters or not soldier.is_alive(): continue
  var target: PrototypeEnemy = _nearest(soldier.global_position)
  if target:
   var projectile: PooledProjectile = host.projectile_pool.pop_back() if not host.projectile_pool.is_empty() else null
   if projectile:
    projectile.fire(soldier.global_position + Vector3(0, 0.6, -0.5), target.global_position)
    host.active_projectiles += 1; projectile.released.connect(host._return_projectile.bind(projectile), CONNECT_ONE_SHOT); fired += 1
func _nearest(pos: Vector3) -> PrototypeEnemy:
 var best: PrototypeEnemy; var distance := INF
 for enemy in EnemyManager.active:
  if is_instance_valid(enemy) and enemy.active and pos.distance_squared_to(enemy.global_position) < distance: best = enemy; distance = pos.distance_squared_to(enemy.global_position)
 return best
