class_name MatchDetector
extends RefCounted

const MIN_MATCH_COUNT: int = 3

## Finds all same-color (or Rainbow wildcard) connected bubbles starting from start_coord.
## Returns Array of Vector2i coordinates if count >= MIN_MATCH_COUNT, otherwise empty Array.
static func find_matches(grid: BubbleGrid, start_coord: Vector2i) -> Array[Vector2i]:
	var start_bubble: Bubble = grid.get_bubble_v(start_coord)
	if start_bubble == null:
		return []
		
	# If start bubble is stone or locked, it cannot form normal color matches
	if start_bubble.special_type == Enums.SpecialType.STONE or start_bubble.special_type == Enums.SpecialType.LOCKED:
		return []
		
	var target_color: int = start_bubble.bubble_color
	
	# If start bubble is RAINBOW, adopt the color of the first adjacent colored neighbor
	if start_bubble.special_type == Enums.SpecialType.RAINBOW:
		var n_list: Array[Vector2i] = grid.get_occupied_neighbors(start_coord.x, start_coord.y)
		for n in n_list:
			var nb: Bubble = grid.get_bubble_v(n)
			if nb != null and nb.bubble_color != Enums.BubbleColor.NONE and nb.special_type != Enums.SpecialType.STONE:
				target_color = nb.bubble_color
				break
				
	if target_color == Enums.BubbleColor.NONE:
		return []
		
	var matched: Array[Vector2i] = []
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start_coord]
	visited[start_coord] = true
	
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		matched.append(current)
		
		var neighbors: Array[Vector2i] = grid.get_neighbors_v(current)
		for neighbor in neighbors:
			if not visited.has(neighbor):
				var n_bubble: Bubble = grid.get_bubble_v(neighbor)
				if n_bubble != null:
					# Stone and locked bubbles do not match by color
					if n_bubble.special_type == Enums.SpecialType.STONE or n_bubble.special_type == Enums.SpecialType.LOCKED:
						continue
						
					var is_same_color: bool = (n_bubble.bubble_color == target_color)
					var is_wildcard: bool = (n_bubble.special_type == Enums.SpecialType.RAINBOW)
					
					if is_same_color or is_wildcard:
						visited[neighbor] = true
						queue.append(neighbor)
						
	if matched.size() >= MIN_MATCH_COUNT:
		return matched
		
	return []
