class_name TestGrid
extends RefCounted

static func run_all_tests() -> Dictionary:
	var results: Dictionary = {"passed": 0, "failed": 0, "errors": []}
	
	test_dimensions_and_column_counts(results)
	test_valid_invalid_coords(results)
	test_empty_cell_detection(results)
	test_set_and_remove_bubble(results)
	test_even_row_neighbors(results)
	test_odd_row_neighbors(results)
	test_corner_and_edge_neighbors(results)
	test_grid_to_world_conversions(results)
	test_world_to_grid_approx(results)
	test_find_best_snap_cell(results)
	
	return results

static func _assert(condition: bool, test_name: String, results: Dictionary) -> void:
	if condition:
		results["passed"] += 1
	else:
		results["failed"] += 1
		results["errors"].append("FAIL: " + test_name)

static func test_dimensions_and_column_counts(results: Dictionary) -> void:
	var grid: BubbleGrid = BubbleGrid.new()
	_assert(grid.get_cols_for_row(0) == 8, "Row 0 (even) must have 8 columns", results)
	_assert(grid.get_cols_for_row(1) == 7, "Row 1 (odd) must have 7 columns", results)
	_assert(grid.get_cols_for_row(2) == 8, "Row 2 (even) must have 8 columns", results)
	_assert(grid.get_cols_for_row(13) == 7, "Row 13 (odd) must have 7 columns", results)
	_assert(grid.get_cols_for_row(-1) == 0, "Negative row must return 0 cols", results)
	_assert(grid.get_cols_for_row(99) == 0, "Out of bounds row must return 0 cols", results)
	grid.free()

static func test_valid_invalid_coords(results: Dictionary) -> void:
	var grid: BubbleGrid = BubbleGrid.new()
	_assert(grid.is_valid_coord(0, 0), "(0, 0) is valid", results)
	_assert(grid.is_valid_coord(0, 7), "(0, 7) is valid for row 0", results)
	_assert(not grid.is_valid_coord(0, 8), "(0, 8) is invalid for row 0 (max 8 cols)", results)
	_assert(grid.is_valid_coord(1, 6), "(1, 6) is valid for row 1", results)
	_assert(not grid.is_valid_coord(1, 7), "(1, 7) is invalid for row 1 (max 7 cols)", results)
	_assert(not grid.is_valid_coord(-1, 0), "Negative row is invalid", results)
	_assert(not grid.is_valid_coord(0, -1), "Negative col is invalid", results)
	grid.free()

static func test_empty_cell_detection(results: Dictionary) -> void:
	var grid: BubbleGrid = BubbleGrid.new()
	_assert(grid.is_cell_empty(0, 0), "(0, 0) is initially empty", results)
	
	var b: Bubble = Bubble.new()
	grid.set_bubble(0, 0, b)
	_assert(not grid.is_cell_empty(0, 0), "(0, 0) is not empty after setting bubble", results)
	_assert(grid.get_bubble(0, 0) == b, "get_bubble returns placed bubble", results)
	
	b.free()
	grid.free()

static func test_set_and_remove_bubble(results: Dictionary) -> void:
	var grid: BubbleGrid = BubbleGrid.new()
	var b: Bubble = Bubble.new()
	grid.set_bubble(2, 3, b)
	_assert(grid.get_occupied_count() == 1, "Occupied count is 1", results)
	
	var removed: Bubble = grid.remove_bubble(2, 3)
	_assert(removed == b, "remove_bubble returns correct instance", results)
	_assert(grid.get_occupied_count() == 0, "Occupied count is 0 after removal", results)
	_assert(grid.is_board_empty(), "Grid is empty after removing only bubble", results)
	
	b.free()
	grid.free()

static func test_even_row_neighbors(results: Dictionary) -> void:
	var grid: BubbleGrid = BubbleGrid.new()
	# Row 2 is even, col 3 has 6 neighbors:
	# Left: (2, 2), Right: (2, 4)
	# Top-Left: (1, 2), Top-Right: (1, 3)
	# Bottom-Left: (3, 2), Bottom-Right: (3, 3)
	var n: Array[Vector2i] = grid.get_neighbors(2, 3)
	_assert(n.size() == 6, "Cell (2, 3) on even row has 6 neighbors", results)
	_assert(n.has(Vector2i(2, 2)), "Has left neighbor (2, 2)", results)
	_assert(n.has(Vector2i(2, 4)), "Has right neighbor (2, 4)", results)
	_assert(n.has(Vector2i(1, 2)), "Has top-left neighbor (1, 2)", results)
	_assert(n.has(Vector2i(1, 3)), "Has top-right neighbor (1, 3)", results)
	_assert(n.has(Vector2i(3, 2)), "Has bottom-left neighbor (3, 2)", results)
	_assert(n.has(Vector2i(3, 3)), "Has bottom-right neighbor (3, 3)", results)
	grid.free()

static func test_odd_row_neighbors(results: Dictionary) -> void:
	var grid: BubbleGrid = BubbleGrid.new()
	# Row 1 is odd, col 2 has 6 neighbors:
	# Left: (1, 1), Right: (1, 3)
	# Top-Left: (0, 2), Top-Right: (0, 3)
	# Bottom-Left: (2, 2), Bottom-Right: (2, 3)
	var n: Array[Vector2i] = grid.get_neighbors(1, 2)
	_assert(n.size() == 6, "Cell (1, 2) on odd row has 6 neighbors", results)
	_assert(n.has(Vector2i(1, 1)), "Has left neighbor (1, 1)", results)
	_assert(n.has(Vector2i(1, 3)), "Has right neighbor (1, 3)", results)
	_assert(n.has(Vector2i(0, 2)), "Has top-left neighbor (0, 2)", results)
	_assert(n.has(Vector2i(0, 3)), "Has top-right neighbor (0, 3)", results)
	_assert(n.has(Vector2i(2, 2)), "Has bottom-left neighbor (2, 2)", results)
	_assert(n.has(Vector2i(2, 3)), "Has bottom-right neighbor (2, 3)", results)
	grid.free()

static func test_corner_and_edge_neighbors(results: Dictionary) -> void:
	var grid: BubbleGrid = BubbleGrid.new()
	# (0, 0) top-left corner on ceiling:
	# Top row has no (r - 1) neighbors, col 0 has no (c - 1) neighbor.
	# Candidates: Right (0, 1), Bottom-Right (1, 0)
	var n: Array[Vector2i] = grid.get_neighbors(0, 0)
	_assert(n.size() == 2, "Cell (0, 0) has 2 valid neighbors on board", results)
	_assert(n.has(Vector2i(0, 1)), "(0, 0) has right neighbor (0, 1)", results)
	_assert(n.has(Vector2i(1, 0)), "(0, 0) has bottom-right neighbor (1, 0)", results)
	grid.free()

static func test_grid_to_world_conversions(results: Dictionary) -> void:
	var grid: BubbleGrid = BubbleGrid.new()
	var w00: Vector2 = grid.grid_to_world(0, 0)
	var expected_x00: float = Constants.LEFT_WALL_X + Constants.BUBBLE_RADIUS
	var expected_y00: float = Constants.GRID_START_Y + Constants.BUBBLE_RADIUS
	_assert(abs(w00.x - expected_x00) < 0.01 and abs(w00.y - expected_y00) < 0.01, "(0, 0) world position exact", results)
	
	# Row 1 (odd) offset check
	var w10: Vector2 = grid.grid_to_world(1, 0)
	_assert(abs(w10.x - (expected_x00 + Constants.BUBBLE_RADIUS)) < 0.01, "Odd row offset by +radius", results)
	grid.free()

static func test_world_to_grid_approx(results: Dictionary) -> void:
	var grid: BubbleGrid = BubbleGrid.new()
	var pos00: Vector2 = grid.grid_to_world(0, 0)
	var back00: Vector2i = grid.world_to_grid(pos00)
	_assert(back00 == Vector2i(0, 0), "world_to_grid(grid_to_world(0, 0)) == (0, 0)", results)
	
	var pos23: Vector2 = grid.grid_to_world(2, 3)
	var back23: Vector2i = grid.world_to_grid(pos23)
	_assert(back23 == Vector2i(2, 3), "world_to_grid(grid_to_world(2, 3)) == (2, 3)", results)
	grid.free()

static func test_find_best_snap_cell(results: Dictionary) -> void:
	var grid: BubbleGrid = BubbleGrid.new()
	# Empty board -> snaps to closest ceiling cell
	var target: Vector2 = Vector2(Constants.LEFT_WALL_X + Constants.BUBBLE_RADIUS, Constants.GRID_START_Y)
	var snap: Vector2i = grid.find_best_snap_cell(target)
	_assert(snap == Vector2i(0, 0), "Snaps to (0, 0) when empty at top-left", results)
	
	# Place bubble at (0, 0)
	var b: Bubble = Bubble.new()
	grid.set_bubble(0, 0, b)
	
	# Projectile comes just below (0, 0)
	var hit_pos: Vector2 = grid.grid_to_world(1, 0)
	var snap2: Vector2i = grid.find_best_snap_cell(hit_pos)
	_assert(snap2 == Vector2i(1, 0) or snap2 == Vector2i(0, 1), "Snaps to adjacent neighbor", results)
	
	b.free()
	grid.free()
