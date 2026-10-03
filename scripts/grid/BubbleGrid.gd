class_name BubbleGrid
extends Node2D

## Internal storage: Dictionary[Vector2i, Bubble]
var _grid: Dictionary = {}

var max_rows: int = Constants.MAX_GRID_ROWS
var danger_row: int = Constants.DEFAULT_DANGER_ROW

func _ready() -> void:
	pass

## Returns number of columns for a given row in hexagonal layout
func get_cols_for_row(row: int) -> int:
	if row < 0 or row >= max_rows:
		return 0
	return Constants.GRID_COLUMNS_EVEN if (row % 2 == 0) else Constants.GRID_COLUMNS_ODD

## Verifies if coordinate is within logical board bounds
func is_valid_coord(row: int, col: int) -> bool:
	if row < 0 or row >= max_rows:
		return false
	var max_cols: int = get_cols_for_row(row)
	return col >= 0 and col < max_cols

func is_valid_coord_v(coord: Vector2i) -> bool:
	return is_valid_coord(coord.x, coord.y)

## Checks if cell is inside bounds and currently empty
func is_cell_empty(row: int, col: int) -> bool:
	if not is_valid_coord(row, col):
		return false
	return not _grid.has(Vector2i(row, col))

func is_cell_empty_v(coord: Vector2i) -> bool:
	return is_cell_empty(coord.x, coord.y)

## Retrieves bubble at cell, or null
func get_bubble(row: int, col: int) -> Bubble:
	var key: Vector2i = Vector2i(row, col)
	if _grid.has(key):
		return _grid[key]
	return null

func get_bubble_v(coord: Vector2i) -> Bubble:
	return get_bubble(coord.x, coord.y)

## Sets bubble at cell and updates its internal position & state
func set_bubble(row: int, col: int, bubble: Bubble) -> void:
	if not is_valid_coord(row, col):
		push_error("Cannot place bubble at invalid coordinate: (%d, %d)" % [row, col])
		return
	var key: Vector2i = Vector2i(row, col)
	_grid[key] = bubble
	if bubble != null:
		bubble.set_grid_coordinate(key)
		bubble.position = grid_to_world(row, col)

func set_bubble_v(coord: Vector2i, bubble: Bubble) -> void:
	set_bubble(coord.x, coord.y, bubble)

## Removes bubble from cell without necessarily destroying it
func remove_bubble(row: int, col: int) -> Bubble:
	var key: Vector2i = Vector2i(row, col)
	if _grid.has(key):
		var b: Bubble = _grid[key]
		_grid.erase(key)
		return b
	return null

func remove_bubble_v(coord: Vector2i) -> Bubble:
	return remove_bubble(coord.x, coord.y)

## Clears all bubbles from grid
func clear_grid() -> void:
	for key in _grid.keys():
		var b: Bubble = _grid[key]
		if is_instance_valid(b):
			b.queue_free()
	_grid.clear()

## Converts logical grid coordinate (row, col) to world Vector2 center
func grid_to_world(row: int, col: int) -> Vector2:
	var x: float = Constants.LEFT_WALL_X + Constants.BUBBLE_RADIUS + (float(col) * Constants.BUBBLE_DIAMETER)
	if row % 2 == 1:
		x += Constants.BUBBLE_RADIUS
	var y: float = Constants.GRID_START_Y + Constants.BUBBLE_RADIUS + (float(row) * Constants.ROW_SPACING)
	return Vector2(x, y)

func grid_to_world_v(coord: Vector2i) -> Vector2:
	return grid_to_world(coord.x, coord.y)

## Converts world position to nearest grid coordinate (approximate search)
func world_to_grid(world_pos: Vector2) -> Vector2i:
	var approx_row: int = clampi(int(round((world_pos.y - Constants.GRID_START_Y - Constants.BUBBLE_RADIUS) / Constants.ROW_SPACING)), 0, max_rows - 1)
	var best_coord: Vector2i = Vector2i(approx_row, 0)
	var min_dist_sq: float = INF
	
	var r_start: int = maxi(0, approx_row - 1)
	var r_end: int = mini(max_rows - 1, approx_row + 1)
	
	for r in range(r_start, r_end + 1):
		var cols: int = get_cols_for_row(r)
		for c in range(cols):
			var center: Vector2 = grid_to_world(r, c)
			var d_sq: float = center.distance_squared_to(world_pos)
			if d_sq < min_dist_sq:
				min_dist_sq = d_sq
				best_coord = Vector2i(r, c)
				
	return best_coord

## Returns up to 6 valid neighboring cell coordinates in hexagonal offset grid
func get_neighbors(row: int, col: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var candidates: Array[Vector2i] = []
	
	if row % 2 == 0:
		# Even row neighbor offsets
		candidates = [
			Vector2i(row, col - 1),     # Left
			Vector2i(row, col + 1),     # Right
			Vector2i(row - 1, col - 1), # Top-Left
			Vector2i(row - 1, col),     # Top-Right
			Vector2i(row + 1, col - 1), # Bottom-Left
			Vector2i(row + 1, col)      # Bottom-Right
		]
	else:
		# Odd row neighbor offsets
		candidates = [
			Vector2i(row, col - 1),     # Left
			Vector2i(row, col + 1),     # Right
			Vector2i(row - 1, col),     # Top-Left
			Vector2i(row - 1, col + 1), # Top-Right
			Vector2i(row + 1, col),     # Bottom-Left
			Vector2i(row + 1, col + 1)  # Bottom-Right
		]
		
	for cand in candidates:
		if is_valid_coord(cand.x, cand.y):
			result.append(cand)
			
	return result

func get_neighbors_v(coord: Vector2i) -> Array[Vector2i]:
	return get_neighbors(coord.x, coord.y)

## Returns occupied neighbor coordinates
func get_occupied_neighbors(row: int, col: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for n in get_neighbors(row, col):
		if _grid.has(n):
			result.append(n)
	return result

## Returns empty legal neighbor coordinates
func get_empty_neighbors(row: int, col: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for n in get_neighbors(row, col):
		if not _grid.has(n):
			result.append(n)
	return result

## Finds the best legal grid cell to snap a projectile at world position
func find_best_snap_cell(pos: Vector2) -> Vector2i:
	# If board is completely empty, snap to nearest ceiling row cell
	if _grid.is_empty():
		return _find_nearest_empty_ceiling_cell(pos)
		
	# Collect all legal empty candidate cells:
	# 1. Empty cells that neighbor at least one occupied bubble
	# 2. Empty cells in ceiling row (row 0)
	var candidate_set: Dictionary = {}
	
	# Add empty ceiling cells
	for c in range(get_cols_for_row(0)):
		var ceiling_coord: Vector2i = Vector2i(0, c)
		if not _grid.has(ceiling_coord):
			candidate_set[ceiling_coord] = true
			
	# Add empty neighbors of all occupied cells
	for occ_coord in _grid.keys():
		for empty_n in get_empty_neighbors(occ_coord.x, occ_coord.y):
			candidate_set[empty_n] = true
			
	if candidate_set.is_empty():
		return world_to_grid(pos)
		
	# Find candidate with minimal distance to pos
	var best_coord: Vector2i = candidate_set.keys()[0]
	var min_dist_sq: float = INF
	
	for coord in candidate_set.keys():
		var cell_world_pos: Vector2 = grid_to_world(coord.x, coord.y)
		var dist_sq: float = cell_world_pos.distance_squared_to(pos)
		if dist_sq < min_dist_sq:
			min_dist_sq = dist_sq
			best_coord = coord
			
	return best_coord

func _find_nearest_empty_ceiling_cell(pos: Vector2) -> Vector2i:
	var best_c: int = 0
	var min_dist_sq: float = INF
	var cols: int = get_cols_for_row(0)
	for c in range(cols):
		var coord: Vector2i = Vector2i(0, c)
		if not _grid.has(coord):
			var center: Vector2 = grid_to_world(0, c)
			var d_sq: float = center.distance_squared_to(pos)
			if d_sq < min_dist_sq:
				min_dist_sq = d_sq
				best_c = c
	return Vector2i(0, best_c)

## Checks if no bubbles remain on board
func is_board_empty() -> bool:
	return _grid.is_empty()

## Total count of currently occupied bubbles
func get_occupied_count() -> int:
	return _grid.size()

## Returns lowest row index that currently has a bubble (-1 if empty)
func get_lowest_occupied_row() -> int:
	if _grid.is_empty():
		return -1
	var lowest: int = -1
	for coord in _grid.keys():
		if coord.x > lowest:
			lowest = coord.x
	return lowest

## Returns all occupied coordinates
func get_all_occupied_cells() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for coord in _grid.keys():
		result.append(coord)
	return result

## Returns list of distinct bubble colors currently present on the board
func get_active_colors() -> Array[int]:
	var color_set: Dictionary = {}
	for b in _grid.values():
		if is_instance_valid(b) and b.bubble_color != Enums.BubbleColor.NONE:
			color_set[b.bubble_color] = true
	var result: Array[int] = []
	for col in color_set.keys():
		result.append(col)
	return result
