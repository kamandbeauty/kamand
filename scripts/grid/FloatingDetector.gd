class_name FloatingDetector
extends RefCounted

## Identifies all occupied bubbles that are disconnected from the ceiling (row 0).
## Returns Array of Vector2i coordinates of all floating bubbles.
static func find_floating_bubbles(grid: BubbleGrid) -> Array[Vector2i]:
	var all_occupied: Array[Vector2i] = grid.get_all_occupied_cells()
	if all_occupied.is_empty():
		return []
		
	var connected_to_ceiling: Dictionary = {}
	var queue: Array[Vector2i] = []
	
	# Step 1: Collect all occupied bubbles in ceiling row (row 0)
	var ceiling_cols: int = grid.get_cols_for_row(0)
	for col in range(ceiling_cols):
		var ceiling_coord: Vector2i = Vector2i(0, col)
		if grid.get_bubble_v(ceiling_coord) != null:
			connected_to_ceiling[ceiling_coord] = true
			queue.append(ceiling_coord)
			
	# Step 2: Flood-fill traversal to find all bubbles connected to ceiling
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		var neighbors: Array[Vector2i] = grid.get_occupied_neighbors(current.x, current.y)
		for neighbor in neighbors:
			if not connected_to_ceiling.has(neighbor):
				connected_to_ceiling[neighbor] = true
				queue.append(neighbor)
				
	# Step 3: Any occupied bubble NOT in connected_to_ceiling is floating
	var floating_bubbles: Array[Vector2i] = []
	for coord in all_occupied:
		if not connected_to_ceiling.has(coord):
			floating_bubbles.append(coord)
			
	return floating_bubbles
