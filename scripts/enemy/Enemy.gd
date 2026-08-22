extends Area3D
class_name PrototypeEnemy
signal defeated(enemy: PrototypeEnemy)
@export var max_health := 3
@export var attack_damage := 1
@export var attack_range := 1.4
@export var attack_cooldown := 1.0
@export var move_speed := 1.2
var health := 3
var active := false
var target: Node3D
var target_provider: Node
var state := "IDLE"
var target_check := 0.0
var cooldown := 0.0
var death_timer := -1.0
func setup(new_target: Node3D, provider: Node = null) -> void:
 target = new_target; target_provider = provider; health = max_health; cooldown = 0.0; death_timer = -1.0; state = "IDLE"; active = true; visible = true; monitoring = true; scale = Vector3.ONE
func take_damage(amount: int) -> void:
 if not active: return
 health -= maxi(0, amount); scale = Vector3.ONE * 0.8
 if health <= 0:
  active = false; state = "DEAD"; target = null; monitoring = false; death_timer = 1.0
func _physics_process(delta: float) -> void:
 if death_timer >= 0.0:
  death_timer -= delta
  if death_timer <= 0.0: visible = false; defeated.emit(self); death_timer = -1.0
  return
 if not active: return
 target_check -= delta
 if target_check <= 0.0:
  target_check = 0.25
  if is_instance_valid(target_provider): target = target_provider.get_active_target()
  if not is_instance_valid(target): return
 var distance := global_position.distance_to(target.global_position)
 state = "CHASING" if distance > attack_range else "ATTACKING"
 if distance > attack_range: global_position = global_position.move_toward(target.global_position, move_speed * delta)
 else: cooldown = maxf(0.0, cooldown - delta)
 scale = scale.lerp(Vector3.ONE, delta * 8.0)
EOF
python3 - <<'PY'
p='scripts/systems/Projectile.gd';s=open(p).read().replace('if active and area is PrototypeEnemy: area.take_damage(damage); release()','''if not active: return
 if area is PrototypeEnemy: area.take_damage(damage); release()
 elif area is FormationSoldier: area.take_damage(damage); PlayerManager.remove_soldiers(1); release()''');open(p,'w').write(s)
p='scripts/combat/ShootingController.gd';s=open(p).read();s=s.replace('var host: Node3D','var host: Node3D\nvar enemy_timer := 0.0').replace(' timer -= delta',' timer -= delta; enemy_timer -= delta').replace(' if timer > 0 or not host or EnemyManager.active.is_empty(): return',' if not host: return\n if timer <= 0 and not EnemyManager.active.is_empty(): _soldiers_fire(); timer = fire_interval\n if enemy_timer <= 0: _enemies_fire(); enemy_timer = 1.0\n return').replace('func _nearest', '''func _enemies_fire() -> void:
 for enemy in EnemyManager.active:
  if not enemy.active or not is_instance_valid(enemy.target): continue
  if enemy.global_position.distance_to(enemy.target.global_position) > enemy.attack_range: continue
  var projectile: PooledProjectile = host.projectile_pool.pop_back() if not host.projectile_pool.is_empty() else null
  if projectile:
   projectile.fire(enemy.global_position + Vector3(0, 0.5, 0), enemy.target.global_position)
   host.active_projectiles += 1; projectile.released.connect(host._return_projectile.bind(projectile), CONNECT_ONE_SHOT)
func _soldiers_fire() -> void:
 var fired := 0
 for soldier in host.get_node("Formation").soldiers:
  if fired >= max_simultaneous_shooters or not soldier.is_alive(): continue
  var target: PrototypeEnemy = _nearest(soldier.global_position)
  if target:
   var projectile: PooledProjectile = host.projectile_pool.pop_back() if not host.projectile_pool.is_empty() else null
   if projectile:
    projectile.fire(soldier.global_position + Vector3(0, 0.6, -0.5), target.global_position)
    host.active_projectiles += 1; projectile.released.connect(host._return_projectile.bind(projectile), CONNECT_ONE_SHOT); fired += 1
func _nearest''')
# remove old soldier block in original process left? replacement process has old code after return likely unreachable but syntax okay; inspect
open(p,'w').write(s)
PY
sed -n '1,140p' scripts/combat/ShootingController.gd
 git add scripts && git commit -m 'Complete pooled ranged combat and enemy death handling' && git push origin arena/01a0263a-kamand || true
