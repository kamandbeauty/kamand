extends Area3D
class_name PooledProjectile
signal released(projectile: PooledProjectile)
@export var speed := 18.0
@export var damage := 1
@export var lifetime := 3.0
var active := false
var remaining := 0.0
func fire(pos: Vector3) -> void:
 global_position = pos; remaining = lifetime; active = true; visible = true; monitoring = true
func _physics_process(delta: float) -> void:
 if not active: return
 global_position += Vector3(0, 0, -1) * speed * delta; remaining -= delta
 if remaining <= 0.0: release()
func hit(area: Area3D) -> void:
 if active and area is PrototypeEnemy: area.take_damage(damage); release()
func release() -> void:
 if not active: return
 active = false; visible = false; monitoring = false; released.emit(self)
