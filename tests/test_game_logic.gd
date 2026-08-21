extends SceneTree
func _init() -> void:
 assert(maxi(0, 3 - 10) == 0)
 assert(int(floor(10 * 2.0)) == 20 and int(floor(10 * 3.0)) == 30)
 assert(10 + 5 == 15 and 20 + 10 == 30 and 30 / 2 == 15)
 var health := 100
 for damage in [25, 25, 25, 25]: health = maxi(0, health - damage)
 assert(health == 0)
 quit()
