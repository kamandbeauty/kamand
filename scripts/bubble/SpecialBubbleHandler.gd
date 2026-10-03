class_name SpecialBubbleHandler
extends RefCounted

## Triggers Bomb explosion: removes all occupied bubbles in neighbor radius 1
static func trigger_bomb(grid: BubbleGrid, center_coord: Vector2i) -> Array[Vector2i]:
	var affected: Array[Vector2i] = [center_coord]
	var neighbors: Array[Vector2i] = grid.get_occupied_neighbors(center_coord.x, center_coord.y)
	for n in neighbors:
		if not affected.has(n):
			affected.append(n)
	return affected

## Triggers Lightning line clear: removes all occupied bubbles in row
static func trigger_lightning(grid: BubbleGrid, row: int) -> Array[Vector2i]:
	var affected: Array[Vector2i] = []
	var cols: int = grid.get_cols_for_row(row)
	for c in range(cols):
		var coord: Vector2i = Vector2i(row, c)
		if grid.get_bubble_v(coord) != null:
			affected.append(coord)
	return affected

## Finds and cracks any locked bubbles neighboring matched/cleared cells
static func process_adjacent_locked(grid: BubbleGrid, cleared_coords: Array[Vector2i]) -> Array[Vector2i]:
	var cracked: Array[Vector2i] = []
	var checked: Dictionary = {}
	
	for coord in cleared_coords:
		var neighbors: Array[Vector2i] = grid.get_occupied_neighbors(coord.x, coord.y)
		for n in neighbors:
			if not checked.has(n):
				checked[n] = true
				var b: Bubble = grid.get_bubble_v(n)
				if b != null and b.special_type == Enums.SpecialType.LOCKED:
					b.crack_locked_shell()
					cracked.append(n)
					
	return cracked
