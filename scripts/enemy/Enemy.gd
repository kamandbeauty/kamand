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
var cooldown := 0.0
func setup(new_target: Node3D) -> void:
 target = new_target; health = max_health; cooldown = 0.0; active = true; visible = true; monitoring = true
func take_damage(amount: int) -> void:
 if not active: return
 health -= maxi(0, amount); scale = Vector3.ONE * 0.8
 if health <= 0: active = false; visible = false; monitoring = false; defeated.emit(self)
func _physics_process(delta: float) -> void:
 if not active or not is_instance_valid(target): return
 var distance := global_position.distance_to(target.global_position)
 if distance > attack_range: global_position = global_position.move_toward(target.global_position, move_speed * delta)
 else:
  cooldown -= delta
  if cooldown <= 0.0:
   PlayerManager.remove_soldiers(attack_damage); cooldown = attack_cooldown
 scale = scale.lerp(Vector3.ONE, delta * 8.0)
