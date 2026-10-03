class_name TestPhase3Features
extends RefCounted

static func run_all_tests() -> Dictionary:
	var passed: int = 0
	var failed: int = 0
	var errors: Array[String] = []
	
	# Special Bubbles Tests
	if test_bomb_radius_explosion(): passed += 1
	else: failed += 1; errors.append("test_bomb_radius_explosion failed")
	
	if test_lightning_row_clear(): passed += 1
	else: failed += 1; errors.append("test_lightning_row_clear failed")
	
	if test_rainbow_wildcard_match(): passed += 1
	else: failed += 1; errors.append("test_rainbow_wildcard_match failed")
	
	if test_stone_obstacle_immunity(): passed += 1
	else: failed += 1; errors.append("test_stone_obstacle_immunity failed")
	
	if test_locked_ice_cracking(): passed += 1
	else: failed += 1; errors.append("test_locked_ice_cracking failed")
	
	# Objective Manager Tests
	if test_objective_clear_all(): passed += 1
	else: failed += 1; errors.append("test_objective_clear_all failed")
	
	if test_objective_clear_color(): passed += 1
	else: failed += 1; errors.append("test_objective_clear_color failed")
	
	if test_objective_reach_score(): passed += 1
	else: failed += 1; errors.append("test_objective_reach_score failed")
	
	if test_objective_clear_special(): passed += 1
	else: failed += 1; errors.append("test_objective_clear_special failed")
	
	# World Data & Star Gate Tests
	if test_world_definitions_and_bounds(): passed += 1
	else: failed += 1; errors.append("test_world_definitions_and_bounds failed")
	
	if test_world_star_gates(): passed += 1
	else: failed += 1; errors.append("test_world_star_gates failed")
	
	# 30 Deterministic Levels Verification
	if test_all_30_levels_integrity(): passed += 1
	else: failed += 1; errors.append("test_all_30_levels_integrity failed")
	
	# SaveManager V3 Tests
	if test_save_manager_v3_schema(): passed += 1
	else: failed += 1; errors.append("test_save_manager_v3_schema failed")
	
	if test_save_manager_v3_migration(): passed += 1
	else: failed += 1; errors.append("test_save_manager_v3_migration failed")
	
	return {"passed": passed, "failed": failed, "errors": errors}

static func test_bomb_radius_explosion() -> bool:
	var grid: BubbleGrid = BubbleGrid.new()
	# Place a bomb at (2, 4) and bubbles around it
	var bomb: Bubble = Bubble.new()
	bomb.set_bubble_type(Enums.BubbleColor.NONE, Enums.SpecialType.BOMB)
	grid.set_bubble(2, 4, bomb)
	
	var neighbors: Array[Vector2i] = grid.get_neighbors(2, 4)
	for n in neighbors:
		var b: Bubble = Bubble.new()
		b.set_bubble_type(Enums.BubbleColor.RED, Enums.SpecialType.NONE)
		grid.set_bubble_v(n, b)
		
	var cleared: Array[Vector2i] = SpecialBubbleHandler.trigger_bomb(grid, Vector2i(2, 4))
	# Cleared must include bomb center + all valid neighbors
	if not (Vector2i(2, 4) in cleared):
		return false
	if cleared.size() != (neighbors.size() + 1):
		return false
	return true

static func test_lightning_row_clear() -> bool:
	var grid: BubbleGrid = BubbleGrid.new()
	var row_idx: int = 3
	var cols: int = grid.get_cols_for_row(row_idx)
	for c in range(cols):
		var b: Bubble = Bubble.new()
		b.set_bubble_type(Enums.BubbleColor.BLUE, Enums.SpecialType.NONE)
		grid.set_bubble(row_idx, c, b)
		
	var cleared: Array[Vector2i] = SpecialBubbleHandler.trigger_lightning(grid, row_idx)
	if cleared.size() != cols:
		return false
	for c in range(cols):
		if not (Vector2i(row_idx, c) in cleared):
			return false
	return true

static func test_rainbow_wildcard_match() -> bool:
	var grid: BubbleGrid = BubbleGrid.new()
	# Place Red at (0, 0), Rainbow at (0, 1), and Red at (0, 2)
	var b1: Bubble = Bubble.new()
	b1.set_bubble_type(Enums.BubbleColor.RED, Enums.SpecialType.NONE)
	grid.set_bubble(0, 0, b1)
	
	var b2: Bubble = Bubble.new()
	b2.set_bubble_type(Enums.BubbleColor.NONE, Enums.SpecialType.RAINBOW)
	grid.set_bubble(0, 1, b2)
	
	var b3: Bubble = Bubble.new()
	b3.set_bubble_type(Enums.BubbleColor.RED, Enums.SpecialType.NONE)
	grid.set_bubble(0, 2, b3)
	
	var matches: Array[Vector2i] = MatchDetector.find_matches(grid, Vector2i(0, 0))
	if matches.size() != 3:
		return false
	if not (Vector2i(0, 1) in matches):
		return false
	return true

static func test_stone_obstacle_immunity() -> bool:
	var grid: BubbleGrid = BubbleGrid.new()
	# Place Red at (0, 0), Stone at (0, 1), and Red at (0, 2)
	var b1: Bubble = Bubble.new()
	b1.set_bubble_type(Enums.BubbleColor.RED, Enums.SpecialType.NONE)
	grid.set_bubble(0, 0, b1)
	
	var b2: Bubble = Bubble.new()
	b2.set_bubble_type(Enums.BubbleColor.NONE, Enums.SpecialType.STONE)
	grid.set_bubble(0, 1, b2)
	
	var b3: Bubble = Bubble.new()
	b3.set_bubble_type(Enums.BubbleColor.RED, Enums.SpecialType.NONE)
	grid.set_bubble(0, 2, b3)
	
	var matches: Array[Vector2i] = MatchDetector.find_matches(grid, Vector2i(0, 0))
	# Stone should not match with Red, so match size should be 1 (fails < 3 check)
	if matches.size() > 1:
		return false
	return true

static func test_locked_ice_cracking() -> bool:
	var grid: BubbleGrid = BubbleGrid.new()
	# Place Red match at (0, 0) and (0, 1); Locked bubble at (1, 0)
	var b1: Bubble = Bubble.new()
	b1.set_bubble_type(Enums.BubbleColor.RED, Enums.SpecialType.NONE)
	grid.set_bubble(0, 0, b1)
	
	var b2: Bubble = Bubble.new()
	b2.set_bubble_type(Enums.BubbleColor.RED, Enums.SpecialType.NONE)
	grid.set_bubble(0, 1, b2)
	
	var locked_b: Bubble = Bubble.new()
	locked_b.set_bubble_type(Enums.BubbleColor.GREEN, Enums.SpecialType.LOCKED)
	grid.set_bubble(1, 0, locked_b)
	
	var cleared_cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1)]
	var cracked: Array[Vector2i] = SpecialBubbleHandler.process_adjacent_locked(grid, cleared_cells)
	
	if cracked.size() != 1:
		return false
	if cracked[0] != Vector2i(1, 0):
		return false
	if locked_b.special_type != Enums.SpecialType.NONE:
		return false
	return true

static func test_objective_clear_all() -> bool:
	var level: LevelData = LevelData.new()
	level.objective_type = Enums.ObjectiveType.CLEAR_ALL
	
	var grid: BubbleGrid = BubbleGrid.new()
	# Empty grid -> complete
	if not ObjectiveManager.is_objective_complete(level, grid, 0, {}, 0):
		return false
		
	# Add 1 bubble -> not complete
	var b: Bubble = Bubble.new()
	b.set_bubble_type(Enums.BubbleColor.RED, Enums.SpecialType.NONE)
	grid.set_bubble(0, 0, b)
	if ObjectiveManager.is_objective_complete(level, grid, 0, {}, 0):
		return false
	return true

static func test_objective_clear_color() -> bool:
	var level: LevelData = LevelData.new()
	level.objective_type = Enums.ObjectiveType.CLEAR_COLOR
	level.target_color = Enums.BubbleColor.RED
	level.target_count = 5
	
	var grid: BubbleGrid = BubbleGrid.new()
	var counts_incomplete: Dictionary = {Enums.BubbleColor.RED: 4}
	if ObjectiveManager.is_objective_complete(level, grid, 0, counts_incomplete, 0):
		return false
		
	var counts_complete: Dictionary = {Enums.BubbleColor.RED: 5}
	if not ObjectiveManager.is_objective_complete(level, grid, 0, counts_complete, 0):
		return false
	return true

static func test_objective_reach_score() -> bool:
	var level: LevelData = LevelData.new()
	level.objective_type = Enums.ObjectiveType.REACH_SCORE
	level.target_score = 1500
	
	var grid: BubbleGrid = BubbleGrid.new()
	if ObjectiveManager.is_objective_complete(level, grid, 1200, {}, 0):
		return false
	if not ObjectiveManager.is_objective_complete(level, grid, 1500, {}, 0):
		return false
	return true

static func test_objective_clear_special() -> bool:
	var level: LevelData = LevelData.new()
	level.objective_type = Enums.ObjectiveType.CLEAR_SPECIAL
	level.target_count = 3
	
	var grid: BubbleGrid = BubbleGrid.new()
	if ObjectiveManager.is_objective_complete(level, grid, 0, {}, 2):
		return false
	if not ObjectiveManager.is_objective_complete(level, grid, 0, {}, 3):
		return false
	return true

static func test_world_definitions_and_bounds() -> bool:
	var worlds: Array[WorldData.WorldInfo] = WorldData.get_all_worlds()
	if worlds.size() != 3:
		return false
	if worlds[0].start_level != 1 or worlds[0].end_level != 10:
		return false
	if worlds[1].start_level != 11 or worlds[1].end_level != 20:
		return false
	if worlds[2].start_level != 21 or worlds[2].end_level != 30:
		return false
	return true

static func test_world_star_gates() -> bool:
	# World 1 requires 0 stars
	if not WorldData.is_world_unlocked(Enums.WorldID.WHISPERING_WOODS, 0):
		return false
	# World 2 requires 10 stars
	if WorldData.is_world_unlocked(Enums.WorldID.CRYSTAL_CAVERNS, 9):
		return false
	if not WorldData.is_world_unlocked(Enums.WorldID.CRYSTAL_CAVERNS, 10):
		return false
	# World 3 requires 25 stars
	if WorldData.is_world_unlocked(Enums.WorldID.SUNKEN_GROVE, 24):
		return false
	if not WorldData.is_world_unlocked(Enums.WorldID.SUNKEN_GROVE, 25):
		return false
	return true

static func test_all_30_levels_integrity() -> bool:
	for lvl in range(1, 31):
		var data: LevelData = LevelManager.load_level(lvl)
		if data == null:
			return false
		if data.level_id != lvl:
			return false
		if data.layout_rows.is_empty():
			return false
		if data.max_shots <= 0:
			return false
		if data.allowed_colors.is_empty():
			return false
	return true

static func test_save_manager_v3_schema() -> bool:
	var save_dict: Dictionary = {
		"version": 3,
		"current_level": 5,
		"unlocked_levels": [1, 2, 3, 4, 5],
		"high_scores": {"1": 1200, "2": 2400},
		"stars_earned": {"1": 3, "2": 3, "3": 2},
		"seen_tutorials": ["lvl_1", "lvl_4"],
		"settings": {
			"sound_enabled": true,
			"music_enabled": true,
			"reduced_effects": false,
			"show_accessibility_symbols": true
		}
	}
	var res: bool = SaveManager.load_from_dict(save_dict)
	if not res:
		return false
	if SaveManager.get_total_stars() != 8:
		return false
	if not SaveManager.is_tutorial_seen("lvl_1"):
		return false
	if SaveManager.is_tutorial_seen("lvl_7"):
		return false
	return true

static func test_save_manager_v3_migration() -> bool:
	var v1_save: Dictionary = {
		"version": 1,
		"current_level": 3,
		"unlocked_levels": [1, 2, 3],
		"high_scores": {"1": 500, "2": 600},
		"sound_enabled": false
	}
	var res: bool = SaveManager.load_from_dict(v1_save)
	if not res:
		return false
	# Migrated should be at v3, give default 1 star per unlocked level, and maintain scores
	if SaveManager.SAVE_VERSION != 3:
		return false
	if SaveManager.get_stars_earned(1) < 1:
		return false
	if SaveManager.get_high_score(2) != 600:
		return false
	return true
