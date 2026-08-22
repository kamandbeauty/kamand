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
 target = new_target
 target_provider = provider
 health = max_health
 cooldown = 0.0
 death_timer = -1.0
 state = "IDLE"
 active = true
 visible = true
 monitoring = true
 scale = Vector3.ONE
func take_damage(amount: int) -> void:
 if not active: return
 health -= maxi(0, amount)
 scale = Vector3.ONE * 0.8
 if health <= 0:
  active = false
  state = "DEAD"
  target = null
  monitoring = false
  death_timer = 1.0
func _physics_process(delta: float) -> void:
 if death_timer >= 0.0:
  death_timer -= delta
  if death_timer <= 0.0:
   visible = false
   defeated.emit(self)
   death_timer = -1.0
  return
 if not active: return
 target_check -= delta
 if target_check <= 0.0:
  target_check = 0.25
  if is_instance_valid(target_provider): target = target_provider.get_active_target()
  if not is_instance_valid(target): return
 var distance := global_position.distance_to(target.global_position)
 state = "CHASING" if distance > attack_range else "ATTACKING"
 if distance > attack_range:
  global_position = global_position.move_toward(target.global_position, move_speed * delta)
 else:
  cooldown = maxf(0.0, cooldown - delta)
 scale = scale.lerp(Vector3.ONE, delta * 8.0)
