extends SceneTree
func _init() -> void:
 assert(maxi(0, 3 - 10) == 0)
 assert(int(floor(10 * 2.0)) == 20 and int(floor(10 * 3.0)) == 30)
 assert(10 + 5 == 15 and 10 + 10 == 20 and 10 - 3 == 7 and 10 - 5 == 5)
 assert(int(floor(10.0 / 2.0)) == 5)
 quit()
