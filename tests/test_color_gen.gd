class_name TestColorGen
extends RefCounted

static func run_all_tests() -> Dictionary:
	var results: Dictionary = {"passed": 0, "failed": 0, "errors": []}
	
	test_deterministic_seed(results)
	test_board_color_restriction(results)
	test_empty_board_fallback(results)
	
	return results

static func _assert(condition: bool, test_name: String, results: Dictionary) -> void:
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("FAIL: " + test_name)

static func test_deterministic_seed(results: Dictionary) -> void:
	var gen1: ColorGenerator = ColorGenerator.new(12345)
	var gen2: ColorGenerator = ColorGenerator.new(12345)
	var pool: Array[int] = [Enums.BubbleColor.RED, Enums.BubbleColor.BLUE, Enums.BubbleColor.GREEN]
	
	var c1: int = gen1.get_next_color(pool, [])
	var c2: int = gen2.get_next_color(pool, [])
	_assert(c1 == c2, "Same seed produces identical color sequence", results)

static func test_board_color_restriction(results: Dictionary) -> void:
	var gen: ColorGenerator = ColorGenerator.new(42)
	var allowed: Array[int] = [Enums.BubbleColor.RED, Enums.BubbleColor.BLUE, Enums.BubbleColor.GREEN, Enums.BubbleColor.YELLOW]
	var active: Array[int] = [Enums.BubbleColor.RED] # Only Red on board!
	
	for i in range(10):
		var col: int = gen.get_next_color(allowed, active)
		if col != Enums.BubbleColor.RED:
			_assert(false, "Generated color must only be RED when only RED is active on board", results)
			return
	_assert(true, "Color generator strictly generated active RED color", results)

static func test_empty_board_fallback(results: Dictionary) -> void:
	var gen: ColorGenerator = ColorGenerator.new(99)
	var allowed: Array[int] = [Enums.BubbleColor.GREEN]
	var active: Array[int] = [] # Empty board
	
	var col: int = gen.get_next_color(allowed, active)
	_assert(col == Enums.BubbleColor.GREEN, "Empty board falls back to allowed color list", results)
