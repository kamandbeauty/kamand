class_name TestFloating
extends RefCounted

static func run_all_tests() -> Dictionary:
	var results: Dictionary = {"passed": 0, "failed": 0, "errors": []}
	
	test_ceiling_connected_remain(results)
	test_single_disconnected_bubble(results)
	test_multiple_disconnected_groups(results)
	test_full_board_drop_on_ceiling_clear(results)
	
	return results

static func _assert(condition: bool, test_name: String, results: Dictionary) -> void:
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("FAIL: " + test_name)

static func test_ceiling_connected_remain(results: Dictionary) -> void:
	var grid: BubbleGrid = BubbleGrid.new()
	var b1: Bubble = Bubble.new()
	var b2: Bubble = Bubble.new()
	var b3: Bubble = Bubble.new()
	
	# (0, 0) -> (1, 0) -> (2, 0) all connected to ceiling (row 0)
	grid.set_bubble(0, 0, b1)
	grid.set_bubble(1, 0, b2)
	grid.set_bubble(2, 0, b3)
	
	var floating: Array[Vector2i] = FloatingDetector.find_floating_bubbles(grid)
	_assert(floating.is_empty(), "Bubbles connected to ceiling must not be marked floating", results)
	
	b1.free()
	b2.free()
	b3.free()
	grid.free()

static func test_single_disconnected_bubble(results: Dictionary) -> void:
	var grid: BubbleGrid = BubbleGrid.new()
	var b1: Bubble = Bubble.new()
	var b_float: Bubble = Bubble.new()
	
	grid.set_bubble(0, 0, b1) # ceiling
	grid.set_bubble(3, 3, b_float) # isolated in row 3
	
	var floating: Array[Vector2i] = FloatingDetector.find_floating_bubbles(grid)
	_assert(floating.size() == 1, "Exactly 1 floating bubble detected", results)
	_assert(floating.has(Vector2i(3, 3)), "Floating bubble is at (3, 3)", results)
	
	b1.free()
	b_float.free()
	grid.free()

static func test_multiple_disconnected_groups(results: Dictionary) -> void:
	var grid: BubbleGrid = BubbleGrid.new()
	var b_ceil: Bubble = Bubble.new()
	grid.set_bubble(0, 7, b_ceil)
	
	# Cluster A at (2, 0), (2, 1)
	var b_a1: Bubble = Bubble.new()
	var b_a2: Bubble = Bubble.new()
	grid.set_bubble(2, 0, b_a1)
	grid.set_bubble(2, 1, b_a2)
	
	# Cluster B at (4, 4), (4, 5), (5, 4)
	var b_b1: Bubble = Bubble.new()
	var b_b2: Bubble = Bubble.new()
	var b_b3: Bubble = Bubble.new()
	grid.set_bubble(4, 4, b_b1)
	grid.set_bubble(4, 5, b_b2)
	grid.set_bubble(5, 4, b_b3)
	
	var floating: Array[Vector2i] = FloatingDetector.find_floating_bubbles(grid)
	_assert(floating.size() == 5, "5 floating bubbles detected across two disconnected clusters", results)
	_assert(floating.has(Vector2i(2, 0)) and floating.has(Vector2i(2, 1)), "Cluster A included", results)
	_assert(floating.has(Vector2i(4, 4)) and floating.has(Vector2i(4, 5)) and floating.has(Vector2i(5, 4)), "Cluster B included", results)
	
	b_ceil.free()
	b_a1.free()
	b_a2.free()
	b_b1.free()
	b_b2.free()
	b_b3.free()
	grid.free()

static func test_full_board_drop_on_ceiling_clear(results: Dictionary) -> void:
	var grid: BubbleGrid = BubbleGrid.new()
	# No bubbles in row 0, bubbles only in rows 1, 2, 3
	var b1: Bubble = Bubble.new()
	var b2: Bubble = Bubble.new()
	grid.set_bubble(1, 0, b1)
	grid.set_bubble(2, 0, b2)
	
	var floating: Array[Vector2i] = FloatingDetector.find_floating_bubbles(grid)
	_assert(floating.size() == 2, "All bubbles drop when ceiling has no connections", results)
	
	b1.free()
	b2.free()
	grid.free()
