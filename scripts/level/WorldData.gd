class_name WorldData
extends Resource

@export var world_id: int = 1
@export var world_name: String = "Whispering Woods"
@export var description: String = "Mystical enchanted forest filled with glowing crystals and ancient trees."
@export var theme_color: Color = Color(0.2, 0.85, 0.55)
@export var min_level_id: int = 1
@export var max_level_id: int = 10
@export var unlock_star_requirement: int = 0

static func get_all_worlds() -> Array[WorldData]:
	var w1: WorldData = WorldData.new()
	w1.world_id = 1
	w1.world_name = "Whispering Woods"
	w1.description = "Mystical enchanted forest filled with glowing crystals and ancient trees."
	w1.theme_color = Color(0.2, 0.85, 0.55)
	w1.min_level_id = 1
	w1.max_level_id = 10
	w1.unlock_star_requirement = 0
	
	var w2: WorldData = WorldData.new()
	w2.world_id = 2
	w2.world_name = "Crystal Caverns"
	w2.description = "Deep underground crystalline grottos with pulsing geode formations and stone blockers."
	w2.theme_color = Color(0.25, 0.65, 0.95)
	w2.min_level_id = 11
	w2.max_level_id = 20
	w2.unlock_star_requirement = 15
	
	var w3: WorldData = WorldData.new()
	w3.world_id = 3
	w3.world_name = "Sunken Grove"
	w3.description = "Ancient submerged canopy with bioluminescent flora and complex puzzle arrangements."
	w3.theme_color = Color(0.85, 0.45, 0.90)
	w3.min_level_id = 21
	w3.max_level_id = 30
	w3.unlock_star_requirement = 35
	
	return [w1, w2, w3]
