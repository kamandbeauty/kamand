extends SceneTree
func _init() -> void:
 var value := 10
 value = int(floor(value * 2.0)); assert(value == 20)
 value -= 3; assert(value == 17)
 value += 10; assert(value == 27)
 value = int(floor(value / 2.0)); assert(value == 13)
 value = int(floor(value * 3.0)); assert(value == 39)
 value -= 5; assert(value == 34)
 assert(maxi(0, 3 - 10) == 0)
 var chosen := "left"; assert(chosen == "left")
 var spawned := false; assert(not spawned); spawned = true; assert(spawned)
 var restart_count := 10; restart_count = 10; assert(restart_count == 10)
 quit()
