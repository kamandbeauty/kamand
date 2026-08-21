extends MeshInstance3D
class_name FormationSoldier
signal died(soldier: FormationSoldier)
@export var max_health := 1
var current_health := 1
var state := "ALIVE"
func reset() -> void: current_health = max_health; state = "ALIVE"; visible = true; scale = Vector3.ONE
func take_damage(amount: int) -> void:
 if state == "DEAD": return
 current_health = maxi(0, current_health - maxi(0, amount)); scale = Vector3(0.8, 0.8, 0.8)
 if current_health == 0: state = "DEAD"; visible = false; died.emit(self)
func heal(amount: int) -> void:
 if state == "ALIVE": current_health = mini(max_health, current_health + maxi(0, amount))
func is_alive() -> bool: return state == "ALIVE" and current_health > 0
