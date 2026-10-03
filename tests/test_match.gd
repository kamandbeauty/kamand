class_name TestMatch
extends RefCounted

static func run_all_tests() -> Dictionary:
	var results: Dictionary = {"passed": 0, "failed": 0, "errors": []}
	
	test_two_same_colors_no_match(results)
	test_three_same_colors_match(results)
	test_four_plus_same_colors_match(results)
	test_different_adjacent_colors_no_match(results)
	test_disconnected_same_color_no_match(results)
	
	return results

static func _assert(condition: bool, test_name: String, results: Dictionary) -> void:
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("FAIL: " + test_name)

static func test_two_same_colors_no_match(results: Dictionary) -> void:
	var grid: BubbleGrid = BubbleGrid.new()
	var b1: Bubble = Bubble.new()
	b1.set_bubble_type(Enums.BubbleColor.RED)
	var b2: Bubble = Bubble.new()
	b2.set_bubble_type(Enums.BubbleColor.RED)
	
	grid.set_bubble(0, 0, b1)
	grid.set_bubble(0, 1, b2)
	
	var matches: Array[Vector2i] = MatchDetector.find_matches(grid, Vector2i(0, 0))
	_assert(matches.is_empty(), "2 same-color bubbles must return empty match list", results)
	
	b1.free()
	b2.free()
	grid.free()

static func test_three_same_colors_match(results: Dictionary) -> void:
	var grid: BubbleGrid = BubbleGrid.new()
	var b1: Bubble = Bubble.new()
	b1.set_bubble_type(Enums.BubbleColor.BLUE)
	var b2: Bubble = Bubble.new()
	b2.set_bubble_type(Enums.BubbleColor.BLUE)
	var b3: Bubble = Bubble.new()
	b3.set_bubble_type(Enums.BubbleColor.BLUE)
	
	grid.set_bubble(0, 0, b1)
	grid.set_bubble(0, 1, b2)
	grid.set_bubble(1, 0, b3) # (1, 0) is neighbor of (0, 0) and (0, 1)
	
	var matches: Array[Vector2i] = MatchDetector.find_matches(grid, Vector2i(1, 0))
	_assert(matches.size() == 3, "3 connected same-color bubbles must form a match of 3", results)
	_assert(matches.has(Vector2i(0, 0)), "Matches contains (0, 0)", results)
	_assert(matches.has(Vector2i(0, 1)), "Matches contains (0, 1)", results)
	_assert(matches.has(Vector2i(1, 0)), "Matches contains (1, 0)", results)
	
	b1.free()
	b2.free()
	b3.free()
	grid.free()

static func test_four_plus_same_colors_match(results: Dictionary) -> void:
	var grid: BubbleGrid = BubbleGrid.new()
	var bubbles: Array[Bubble] = []
	for i in range(5):
		var b: Bubble = Bubble.new()
		b.set_bubble_type(Enums.BubbleColor.GREEN)
		bubbles.append(b)
		grid.set_bubble(0, i, b)
		
	var matches: Array[Vector2i] = MatchDetector.find_matches(grid, Vector2i(0, 2))
	_assert(matches.size() == 5, "5 connected same-color bubbles match all 5", results)
	
	for b in bubbles:
		b.free()
	grid.free()

static func test_different_adjacent_colors_no_match(results: Dictionary) -> void:
	var grid: BubbleGrid = BubbleGrid.new()
	var b1: Bubble = Bubble.new()
	b1.set_bubble_type(Enums.BubbleColor.RED)
	var b2: Bubble = Bubble.new()
	b2.set_bubble_type(Enums.BubbleColor.BLUE)
	var b3: Bubble = Bubble.new()
	b3.set_bubble_type(Enums.BubbleColor.RED)
	
	grid.set_bubble(0, 0, b1)
	grid.set_bubble(0, 1, b2)
	grid.set_bubble(0, 2, b3)
	
	var matches: Array[Vector2i] = MatchDetector.find_matches(grid, Vector2i(0, 0))
	_assert(matches.is_empty(), "RED + BLUE + RED does not match", results)
	
	b1.free()
	b2.free()
	b3.free()
	grid.free()

static func test_disconnected_same_color_no_match(results: Dictionary) -> void:
	var grid: BubbleGrid = BubbleGrid.new()
	var b1: Bubble = Bubble.new()
	b1.set_bubble_type(Enums.BubbleColor.YELLOW)
	var b2: Bubble = Bubble.new()
	b2.set_bubble_type(Enums.BubbleColor.YELLOW)
	var b3: Bubble = Bubble.new()
	b3.set_bubble_type(Enums.BubbleColor.YELLOW)
	
	# b1 and b2 are at (0, 0) and (0, 1). b3 is far away at (0, 5)
	grid.set_bubble(0, 0, b1)
	grid.set_bubble(0, 1, b2)
	grid.set_bubble(0, 5, b3)
	
	var matches: Array[Vector2i] = MatchDetector.find_matches(grid, Vector2i(0, 0))
	_assert(matches.is_empty(), "Disconnected yellow bubble at (0, 5) does not join (0, 0)-(0, 1)", results)
	
	b1.free()
	b2.free()
	b3.free()
	grid.free()
