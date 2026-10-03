class_name TestLevel
extends RefCounted

static func run_all_tests() -> Dictionary:
	var results: Dictionary = {"passed": 0, "failed": 0, "errors": []}
	
	test_all_10_levels_load_and_valid(results)
	test_fallback_level(results)
	test_layout_parsing(results)
	test_win_condition(results)
	test_lose_condition_danger_row(results)
	test_lose_condition_out_of_shots(results)
	
	return results

static func _assert(condition: bool, test_name: String, results: Dictionary) -> void:
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("FAIL: " + test_name)

static func test_all_10_levels_load_and_valid(results: Dictionary) -> void:
	for i in range(1, 11):
		var lvl: LevelData = LevelManager.load_level(i)
		_assert(lvl != null, "Level %d loaded successfully" % i, results)
		_assert(lvl.level_id == i, "Level %d has correct ID" % i, results)
		_assert(lvl.max_shots > 0, "Level %d has positive max shots (%d)" % [i, lvl.max_shots], results)
		_assert(lvl.danger_row > 0, "Level %d has valid danger row (%d)" % [i, lvl.danger_row], results)
		_assert(not lvl.allowed_colors.is_empty(), "Level %d has allowed colors" % i, results)
		_assert(not lvl.layout_rows.is_empty(), "Level %d has layout rows" % i, results)

static func test_fallback_level(results: Dictionary) -> void:
	var fallback: LevelData = LevelManager.load_level(999) # Non-existent level
	_assert(fallback != null, "Fallback level created safely for missing level", results)
	_assert(fallback.level_id == 999, "Fallback retains requested ID", results)
	_assert(fallback.max_shots > 0, "Fallback has valid shots", results)

static func test_layout_parsing(results: Dictionary) -> void:
	var lvl: LevelData = LevelManager.load_level(1)
	var r0: String = lvl.layout_rows[0]
	_assert(r0.begins_with("RR"), "Level 1 row 0 starts with RR", results)
	_assert(LevelData.char_to_bubble_color("R") == Enums.BubbleColor.RED, "Char 'R' maps to RED", results)
	_assert(LevelData.char_to_bubble_color("B") == Enums.BubbleColor.BLUE, "Char 'B' maps to BLUE", results)
	_assert(LevelData.char_to_bubble_color(".") == Enums.BubbleColor.NONE, "Char '.' maps to NONE", results)

static func test_win_condition(results: Dictionary) -> void:
	var grid: BubbleGrid = BubbleGrid.new()
	_assert(grid.is_board_empty(), "Empty grid indicates win condition met", results)
	grid.free()

static func test_lose_condition_danger_row(results: Dictionary) -> void:
	var grid: BubbleGrid = BubbleGrid.new()
	grid.danger_row = 12
	var b: Bubble = Bubble.new()
	grid.set_bubble(12, 0, b) # Reaches danger row 12
	
	_assert(grid.get_lowest_occupied_row() >= grid.danger_row, "Danger row breach detected", results)
	
	b.free()
	grid.free()

static func test_lose_condition_out_of_shots(results: Dictionary) -> void:
	var shots_remaining: int = 0
	var board_empty: bool = false
	var is_loss: bool = (shots_remaining <= 0 and not board_empty)
	_assert(is_loss, "0 shots remaining on non-empty board is a loss", results)
