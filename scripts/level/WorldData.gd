class_name WorldData
extends Resource

class WorldInfo:
	var world_id: int = 1
	var world_name: String = "Whispering Woods"
	var description: String = ""
	var start_level: int = 1
	var end_level: int = 10
	var unlock_star_requirement: int = 0
	var theme_color: Color = Color(0.2, 0.85, 0.55)

@export var world_id: int = 1
@export var world_name: String = "Whispering Woods"
@export var description: String = "Mystical enchanted forest filled with glowing crystals and ancient trees."
@export var theme_color: Color = Color(0.2, 0.85, 0.55)
@export var start_level: int = 1
@export var end_level: int = 10
@export var unlock_star_requirement: int = 0

static func is_world_unlocked(wid: int, stars: int) -> bool:
	match wid:
		1: return true
		2: return stars >= 10
		3: return stars >= 25
		_: return false

static func get_all_worlds() -> Array[WorldInfo]:
	var w1: WorldInfo = WorldInfo.new()
	w1.world_id = 1
	w1.world_name = "Whispering Woods"
	w1.description = "Mystical enchanted forest filled with glowing crystals and ancient trees."
	w1.theme_color = Color(0.2, 0.85, 0.55)
	w1.start_level = 1
	w1.end_level = 10
	w1.unlock_star_requirement = 0
	
	var w2: WorldInfo = WorldInfo.new()
	w2.world_id = 2
	w2.world_name = "Crystal Caverns"
	w2.description = "Deep underground crystalline grottos with pulsing geode formations and stone blockers."
	w2.theme_color = Color(0.25, 0.65, 0.95)
	w2.start_level = 11
	w2.end_level = 20
	w2.unlock_star_requirement = 10
	
	var w3: WorldInfo = WorldInfo.new()
	w3.world_id = 3
	w3.world_name = "Sunken Grove"
	w3.description = "Ancient submerged canopy with bioluminescent flora and complex puzzle arrangements."
	w3.theme_color = Color(0.85, 0.45, 0.90)
	w3.start_level = 21
	w3.end_level = 30
	w3.unlock_star_requirement = 25
	
	return [w1, w2, w3]
